import Foundation
import CoreGraphics
import PencilKit

struct RasterStrokeValidator {
    enum FailureReason: Equatable {
        case missedStart
        case missedEnd
        case insufficientCoverage
    }

    struct StrokeReport {
        let id: String
        let coverage: Double
        let started: Bool
        let reachedEnd: Bool
        let failure: FailureReason?

        var completed: Bool { failure == nil && started && reachedEnd }
    }

    struct Result {
        let reports: [StrokeReport]
        let activeStrokeIndex: Int
        let failure: FailureReason?

        var completedCount: Int {
            reports.reduce(0) { $0 + ($1.completed ? 1 : 0) }
        }

        var totalCount: Int { reports.count }

        var isComplete: Bool { failure == nil && completedCount == totalCount }
    }

    struct Configuration {
        let rasterScale: CGFloat
        let tubeLineWidth: CGFloat
        let studentLineWidth: CGFloat
        let startRadius: CGFloat
        let coverageThreshold: Double
    }

    static func evaluate(drawing: PKDrawing,
                         template: StrokeTraceTemplate,
                         configuration: Configuration) -> Result {
        let prepared = template.strokes
            .sorted { $0.order < $1.order }
            .map { PreparedStroke(stroke: $0, configuration: configuration) }

        guard !prepared.isEmpty else {
            return Result(reports: [], activeStrokeIndex: 0, failure: nil)
        }

        var states = Array(repeating: StrokeState(), count: prepared.count)
        let samples = flattenedSamples(from: drawing)

        var index = 0
        outer: for sample in samples {
            while index < prepared.count {
                var state = states[index]
                let stroke = prepared[index]

                if !state.started {
                    if stroke.startZone.contains(sample.location) {
                        state.started = true
                        state.samples.append(sample)
                        states[index] = state
                    } else if stroke.bounds.contains(sample.location) {
                        state.attempted = true
                        states[index] = state
                    }
                    break
                } else {
                    state.samples.append(sample)
                    if stroke.endZone.contains(sample.location) {
                        state.reachedEnd = true
                        states[index] = state
                        index += 1
                        continue outer
                    } else {
                        states[index] = state
                    }
                    break
                }
            }
        }

        var failure: FailureReason?
        var failureIndex = 0

        if let index = states.firstIndex(where: { $0.attempted && !$0.started }) {
            failure = .missedStart
            failureIndex = index
        } else if let index = states.enumerated().first(where: { offset, state in
            state.started && !state.reachedEnd && offset + 1 < states.count && states[offset + 1].started
        })?.offset {
            failure = .missedEnd
            failureIndex = index
        }

        let overallCoverage = coverageRatio(states: states,
                                             strokes: prepared,
                                             configuration: configuration)

        let allReachedEnd = states.enumerated().allSatisfy { _, state in
            !state.started || state.reachedEnd
        } && (states.last?.reachedEnd ?? false)

        if failure == nil,
           allReachedEnd,
           overallCoverage < configuration.coverageThreshold {
            failure = .insufficientCoverage
            failureIndex = max(states.count - 1, 0)
        }

        var reports: [StrokeReport] = []
        for (index, stroke) in prepared.enumerated() {
            let state = states[index]
            let strokeFailure = (failureIndex == index) ? failure : nil
            reports.append(StrokeReport(id: stroke.id,
                                        coverage: overallCoverage,
                                        started: state.started,
                                        reachedEnd: state.reachedEnd,
                                        failure: strokeFailure))
        }

        let activeIndex: Int
        if failure != nil {
            activeIndex = failureIndex
        } else if let index = states.firstIndex(where: { !$0.started }) {
            activeIndex = index
        } else if let index = states.firstIndex(where: { !$0.reachedEnd }) {
            activeIndex = index
        } else {
            activeIndex = states.count
        }

        return Result(reports: reports,
                      activeStrokeIndex: activeIndex,
                      failure: failure)
    }
}

// MARK: - Helpers

private extension RasterStrokeValidator {
    struct PreparedStroke {
        let id: String
        let centerlinePath: CGPath
        let bounds: CGRect
        let startZone: Circle
        let endZone: Circle

        init(stroke: StrokeTraceTemplate.Stroke,
             configuration: Configuration) {
            self.id = stroke.id
            let path = CGMutablePath()
            if let first = stroke.points.first {
                path.move(to: first)
                for point in stroke.points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            self.centerlinePath = path.copy() ?? path

            let strokeBounds = centerlinePath.boundingBoxOfPath
            let padding = max(configuration.tubeLineWidth, configuration.studentLineWidth) * 0.6
            self.bounds = strokeBounds.insetBy(dx: -padding, dy: -padding)
            self.startZone = Circle(center: stroke.startPoint, radius: configuration.startRadius)
            self.endZone = Circle(center: stroke.endPoint, radius: configuration.startRadius)
        }
    }

    struct Circle {
        let center: CGPoint
        let radius: CGFloat

        func contains(_ point: CGPoint) -> Bool {
            hypot(point.x - center.x, point.y - center.y) <= radius
        }
    }

    struct Sample {
        let location: CGPoint
        let timestamp: TimeInterval
    }

    struct StrokeState {
        var samples: [Sample] = []
        var started: Bool = false
        var reachedEnd: Bool = false
        var attempted: Bool = false
    }

    static func flattenedSamples(from drawing: PKDrawing) -> [Sample] {
        var results: [Sample] = []
        for stroke in drawing.strokes {
            let base = stroke.path.creationDate.timeIntervalSinceReferenceDate
            for point in stroke.path {
                let location = point.location.applying(stroke.transform)
                let timestamp = base + point.timeOffset
                results.append(Sample(location: location, timestamp: timestamp))
            }
        }
        return results.sorted { $0.timestamp < $1.timestamp }
    }

    static func coverageRatio(states: [StrokeState],
                              strokes: [PreparedStroke],
                              configuration: Configuration) -> Double {
        let samples = states.flatMap { $0.samples }
        guard !samples.isEmpty else { return 0 }

        var bounds = CGRect.null
        for stroke in strokes {
            bounds = bounds.union(stroke.bounds)
        }
        if bounds.isNull {
            return 0
        }

        let scale = configuration.rasterScale
        let width = max(1, Int(ceil(bounds.width * scale)))
        let height = max(1, Int(ceil(bounds.height * scale)))
        let bytesPerRow = width

        let space = CGColorSpaceCreateDeviceGray()
        guard let templateContext = CGContext(data: nil,
                                              width: width,
                                              height: height,
                                              bitsPerComponent: 8,
                                              bytesPerRow: bytesPerRow,
                                              space: space,
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let studentContext = CGContext(data: nil,
                                             width: width,
                                             height: height,
                                             bitsPerComponent: 8,
                                             bytesPerRow: bytesPerRow,
                                             space: space,
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return 0
        }

        templateContext.translateBy(x: -bounds.minX, y: -bounds.minY)
        templateContext.scaleBy(x: scale, y: scale)
        templateContext.setAllowsAntialiasing(true)
        templateContext.setLineCap(.round)
        templateContext.setLineJoin(.round)
        templateContext.setLineWidth(configuration.tubeLineWidth)
        templateContext.setStrokeColor(gray: 1, alpha: 1)
        for stroke in strokes {
            templateContext.addPath(stroke.centerlinePath)
        }
        templateContext.strokePath()

        studentContext.translateBy(x: -bounds.minX, y: -bounds.minY)
        studentContext.scaleBy(x: scale, y: scale)
        studentContext.setAllowsAntialiasing(true)
        studentContext.setLineCap(.round)
        studentContext.setLineJoin(.round)
        studentContext.setLineWidth(configuration.studentLineWidth)
        studentContext.setStrokeColor(gray: 1, alpha: 1)
        studentContext.setFillColor(gray: 1, alpha: 1)

        draw(samples: samples, in: studentContext, lineWidth: configuration.studentLineWidth)

        guard let templateData = templateContext.data,
              let studentData = studentContext.data else {
            return 0
        }

        let templatePixels = templateData.bindMemory(to: UInt8.self, capacity: width * height)
        let studentPixels = studentData.bindMemory(to: UInt8.self, capacity: width * height)

        var tubePixels = 0
        var overlapPixels = 0

        for row in 0..<height {
            let base = row * bytesPerRow
            for column in 0..<width {
                let templateValue = templatePixels[base + column]
                if templateValue > 0 {
                    tubePixels += 1
                    if studentPixels[base + column] > 0 {
                        overlapPixels += 1
                    }
                }
            }
        }

        guard tubePixels > 0 else { return 0 }
        return Double(overlapPixels) / Double(tubePixels)
    }

    static func draw(samples: [Sample], in context: CGContext, lineWidth: CGFloat) {
        guard let first = samples.first else { return }
        var lastPoint = first.location

        let radius = lineWidth / 2
        let circleRect = CGRect(x: lastPoint.x - radius,
                                y: lastPoint.y - radius,
                                width: radius * 2,
                                height: radius * 2)
        context.fillEllipse(in: circleRect)

        for sample in samples.dropFirst() {
            let point = sample.location
            context.beginPath()
            context.move(to: lastPoint)
            context.addLine(to: point)
            context.strokePath()
            lastPoint = point
        }
    }
}
