import Foundation
import CoreGraphics
import PencilKit

/// Encapsulates the per-difficulty knobs that drive the trace analyzer.
struct StrokeValidationTuning {
    let startRadius: CGFloat
    let corridorRadius: CGFloat
    let softLimit: CGFloat
    let minimumInsideRatio: Double
    let minimumTravelRatio: Double
    let waypointFractions: [Double]

    init(startRadius: CGFloat,
         corridorRadius: CGFloat,
         softLimit: CGFloat,
         minimumInsideRatio: Double,
         minimumTravelRatio: Double,
         waypointFractions: [Double]) {
        self.startRadius = startRadius
        self.corridorRadius = corridorRadius
        self.softLimit = softLimit
        self.minimumInsideRatio = minimumInsideRatio
        self.minimumTravelRatio = minimumTravelRatio
        self.waypointFractions = waypointFractions.sorted()
    }
}

/// Minimal template representation required for validation.
struct StrokeTraceTemplate {
    struct Stroke {
        let id: String
        let order: Int
        let samples: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
    }

    let strokes: [Stroke]
}

/// Preprocessed representation of a template stroke with geometry helpers.
struct StrokeSegment {
    struct Node {
        let center: CGPoint
        let radius: CGFloat

        func contains(_ point: CGPoint) -> Bool {
            distance(to: point) <= radius
        }

        func distance(to point: CGPoint) -> CGFloat {
            hypot(point.x - center.x, point.y - center.y)
        }
    }

    struct Waypoint {
        let index: Int
        let fraction: Double
        let arcLength: CGFloat
        let position: CGPoint
    }

    fileprivate struct PolylineElement {
        let start: CGPoint
        let end: CGPoint
        let length: CGFloat
        let startLength: CGFloat

        var vector: CGVector {
            CGVector(dx: end.x - start.x, dy: end.y - start.y)
        }
    }

    struct Projection {
        let distance: CGFloat
        let arcLength: CGFloat
        let projected: CGPoint
    }

    let id: String
    let order: Int
    let start: Node
    let end: Node
    let corridorRadius: CGFloat
    let softLimit: CGFloat
    let length: CGFloat
    let points: [CGPoint]
    let waypoints: [Waypoint]

    private let elements: [PolylineElement]

    init(stroke: StrokeTraceTemplate.Stroke,
         startRadius: CGFloat,
         corridorRadius: CGFloat,
         softLimit: CGFloat,
         waypointFractions: [Double]) {
        self.id = stroke.id
        self.order = stroke.order
        self.start = Node(center: stroke.startPoint, radius: startRadius)
        self.end = Node(center: stroke.endPoint, radius: startRadius)
        self.corridorRadius = corridorRadius
        self.softLimit = softLimit

        var elements: [PolylineElement] = []
        var cumulative: CGFloat = 0
        let strokePoints = stroke.samples
        if strokePoints.count >= 2 {
            for index in 0..<(strokePoints.count - 1) {
                let a = strokePoints[index]
                let b = strokePoints[index + 1]
                let segmentLength = hypot(b.x - a.x, b.y - a.y)
                if segmentLength > 0 {
                    elements.append(PolylineElement(start: a,
                                                    end: b,
                                                    length: segmentLength,
                                                    startLength: cumulative))
                    cumulative += segmentLength
                }
            }
        }
        self.elements = elements
        self.length = cumulative
        self.points = strokePoints

        if cumulative > 0 {
            let clampedFractions = waypointFractions.filter { $0 > 0 && $0 < 1 }
            self.waypoints = clampedFractions.enumerated().map { index, fraction in
                let arcLength = CGFloat(fraction) * cumulative
                let position = StrokeSegment.point(at: arcLength, along: elements) ?? stroke.endPoint
                return Waypoint(index: index,
                                fraction: fraction,
                                arcLength: arcLength,
                                position: position)
            }
        } else {
            self.waypoints = []
        }
    }

    func startDistance(to point: CGPoint) -> CGFloat {
        start.distance(to: point)
    }

    func endDistance(to point: CGPoint) -> CGFloat {
        end.distance(to: point)
    }

    func project(_ point: CGPoint) -> Projection {
        guard !elements.isEmpty else {
            let distance = hypot(point.x - start.center.x, point.y - start.center.y)
            return Projection(distance: distance, arcLength: 0, projected: start.center)
        }

        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestArcLength: CGFloat = 0
        var bestPoint = start.center

        for element in elements {
            let projection = StrokeSegment.project(point, onto: element)
            if projection.distance < bestDistance {
                bestDistance = projection.distance
                bestArcLength = projection.arcLength
                bestPoint = projection.projected
                if bestDistance < 0.5 {
                    break
                }
            }
        }

        return Projection(distance: bestDistance,
                          arcLength: bestArcLength,
                          projected: bestPoint)
    }

    private static func project(_ point: CGPoint, onto element: PolylineElement) -> Projection {
        let dx = element.end.x - element.start.x
        let dy = element.end.y - element.start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            let distance = hypot(point.x - element.start.x, point.y - element.start.y)
            return Projection(distance: distance,
                              arcLength: element.startLength,
                              projected: element.start)
        }

        let tNumerator = (point.x - element.start.x) * dx + (point.y - element.start.y) * dy
        let rawT = tNumerator / lengthSquared
        let t = min(max(rawT, 0), 1)
        let projectedX = element.start.x + t * dx
        let projectedY = element.start.y + t * dy
        let distance = hypot(point.x - projectedX, point.y - projectedY)
        let arcLength = element.startLength + element.length * CGFloat(t)

        return Projection(distance: distance,
                          arcLength: arcLength,
                          projected: CGPoint(x: projectedX, y: projectedY))
    }

    private static func point(at arcLength: CGFloat, along elements: [PolylineElement]) -> CGPoint? {
        guard arcLength >= 0 else { return elements.first?.start }
        for element in elements {
            let start = element.startLength
            let end = element.startLength + element.length
            if arcLength <= end {
                let lengthAlong = min(max(arcLength - start, 0), element.length)
                let ratio = element.length > 0 ? lengthAlong / element.length : 0
                let x = element.start.x + ratio * (element.end.x - element.start.x)
                let y = element.start.y + ratio * (element.end.y - element.start.y)
                return CGPoint(x: x, y: y)
            }
        }
        return elements.last?.end ?? elements.first?.start
    }
}

/// Analyzer that streams PencilKit samples against preprocessed segments and produces rich reports.
struct StrokeTraceAnalyzer {
    struct StrokeReport {
        struct WaypointReport {
            let fraction: Double
            let arcLength: CGFloat
            var hit: Bool
            var timestamp: TimeInterval?
        }

        var startDistance: CGFloat = .greatestFiniteMagnitude
        var endDistance: CGFloat = .greatestFiniteMagnitude
        var coverageRatio: Double = 0
        var outsideRatio: Double = 1
        var travelledRatio: Double = 0
        var maxDeviation: CGFloat = 0
        var sampleCount: Int = 0
        var insideSampleCount: Int = 0
        var duration: TimeInterval = 0
        var waypoints: [WaypointReport] = []
        var completed: Bool = false
    }

    enum FailureReason: Equatable {
        case missedStart
        case leftCorridor
        case insufficientCoverage
        case missedWaypoint
    }

    enum WarningKind: Equatable {
        case deviation
        case slowProgress
    }

    struct WarningEvent: Equatable {
        let strokeIndex: Int
        let kind: WarningKind
        let timestamp: TimeInterval
    }

    enum State {
        case waiting
        case inside
    }

    struct Result {
        let reports: [StrokeReport]
        let failure: FailureReason?
        let completedCount: Int
        let nextIndex: Int
        let state: State
        let activeWarning: WarningEvent?

        var isComplete: Bool {
            failure == nil && completedCount == reports.count && state == .waiting
        }
    }

    private struct Sample {
        let location: CGPoint
        let timestamp: TimeInterval
        let strokeIndex: Int
    }

    private struct RuntimeWaypoint {
        let index: Int
        let fraction: Double
        let arcLength: CGFloat
        var hit: Bool = false
        var timestamp: TimeInterval?
    }

    private struct SegmentRuntimeState {
        var totalSamples: Int = 0
        var insideSamples: Int = 0
        var outsideSamples: Int = 0
        var maxArcLength: CGFloat = 0
        var lastArcLength: CGFloat = 0
        var firstTimestamp: TimeInterval?
        var lastTimestamp: TimeInterval?
        var waypoints: [RuntimeWaypoint]

        init(waypoints: [StrokeSegment.Waypoint]) {
            self.waypoints = waypoints.map { RuntimeWaypoint(index: $0.index,
                                                              fraction: $0.fraction,
                                                              arcLength: $0.arcLength,
                                                              hit: false,
                                                              timestamp: nil) }
        }
    }

    static func analyze(drawing: PKDrawing,
                        template: StrokeTraceTemplate,
                        tuning: StrokeValidationTuning) -> Result {
        let segments = template.strokes
            .sorted { $0.order < $1.order }
            .map { StrokeSegment(stroke: $0,
                                 startRadius: tuning.startRadius,
                                 corridorRadius: tuning.corridorRadius,
                                 softLimit: tuning.softLimit,
                                 waypointFractions: tuning.waypointFractions) }

        guard !segments.isEmpty else {
            return Result(reports: [],
                          failure: nil,
                          completedCount: 0,
                          nextIndex: 0,
                          state: .waiting,
                          activeWarning: nil)
        }

        var reports = segments.enumerated().map { index, segment -> StrokeReport in
            let waypointReports = segment.waypoints.map {
                StrokeReport.WaypointReport(fraction: $0.fraction,
                                            arcLength: $0.arcLength,
                                            hit: false,
                                            timestamp: nil)
            }
            var report = StrokeReport()
            report.waypoints = waypointReports
            return report
        }

        let samples = flattenedSamples(from: drawing)
        var index = 0
        var state: State = .waiting
        var failure: FailureReason?
        var warning: WarningEvent?

        var runtimeState = SegmentRuntimeState(waypoints: segments[0].waypoints)

        for sample in samples {
            guard failure == nil else { break }
            guard index < segments.count else { break }

            let segment = segments[index]
            var report = reports[index]

            report.startDistance = min(report.startDistance, segment.startDistance(to: sample.location))

            switch state {
            case .waiting:
                if segment.start.contains(sample.location) {
                    state = .inside
                    runtimeState = SegmentRuntimeState(waypoints: segment.waypoints)
                    runtimeState.firstTimestamp = sample.timestamp
                    fallthrough
                } else if hitNextStart(sample.location, currentIndex: index, segments: segments, startRadius: tuning.startRadius) {
                    failure = .missedStart
                    reports[index] = report
                    break
                } else {
                    reports[index] = report
                    continue
                }
            case .inside:
                runtimeState.totalSamples += 1
                runtimeState.lastTimestamp = sample.timestamp

                let projection = segment.project(sample.location)
                report.maxDeviation = max(report.maxDeviation, projection.distance)

                if projection.distance <= tuning.corridorRadius {
                    runtimeState.insideSamples += 1
                } else {
                    runtimeState.outsideSamples += 1
                    if projection.distance > tuning.softLimit {
                        failure = .leftCorridor
                        reports[index] = report
                        break
                    }
                    if warning == nil {
                        warning = WarningEvent(strokeIndex: index,
                                               kind: .deviation,
                                               timestamp: sample.timestamp)
                    }
                }

                runtimeState.maxArcLength = max(runtimeState.maxArcLength, projection.arcLength)
                runtimeState.lastArcLength = projection.arcLength
                report.sampleCount = runtimeState.totalSamples
                report.insideSampleCount = runtimeState.insideSamples

                let travelRatio = segment.length > 0 ? runtimeState.maxArcLength / segment.length : 0
                report.travelledRatio = max(report.travelledRatio, Double(travelRatio))

                for waypointIndex in runtimeState.waypoints.indices {
                    var runtimeWaypoint = runtimeState.waypoints[waypointIndex]
                    guard !runtimeWaypoint.hit else { continue }
                    if runtimeState.maxArcLength + 0.5 >= runtimeWaypoint.arcLength {
                        runtimeWaypoint.hit = true
                        runtimeWaypoint.timestamp = sample.timestamp
                        if waypointIndex < report.waypoints.count {
                            report.waypoints[waypointIndex].hit = true
                            report.waypoints[waypointIndex].timestamp = sample.timestamp
                        }
                        runtimeState.waypoints[waypointIndex] = runtimeWaypoint
                    }
                }

                let endDistance = segment.endDistance(to: sample.location)
                report.endDistance = min(report.endDistance, endDistance)

                if segment.end.contains(sample.location) {
                    let insideRatio = runtimeState.totalSamples > 0
                        ? Double(runtimeState.insideSamples) / Double(runtimeState.totalSamples)
                        : 0
                    let waypointsSatisfied = runtimeState.waypoints.allSatisfy(\.hit)
                    let outsideRatio = runtimeState.totalSamples > 0
                        ? Double(runtimeState.outsideSamples) / Double(runtimeState.totalSamples)
                        : 1
                    let travelRatioValue = segment.length > 0
                        ? Double(min(runtimeState.maxArcLength / segment.length, 1))
                        : 0
                    report.coverageRatio = insideRatio
                    report.outsideRatio = outsideRatio
                    report.duration = max(0, (runtimeState.lastTimestamp ?? sample.timestamp) - (runtimeState.firstTimestamp ?? sample.timestamp))
                    report.travelledRatio = max(report.travelledRatio, travelRatioValue)

                    if !waypointsSatisfied {
                        failure = .missedWaypoint
                        reports[index] = report
                    } else if insideRatio < tuning.minimumInsideRatio {
                        failure = .insufficientCoverage
                        reports[index] = report
                    } else if travelRatioValue < tuning.minimumTravelRatio {
                        failure = .insufficientCoverage
                        reports[index] = report
                    } else {
                        report.completed = true
                        report.travelledRatio = min(1, report.travelledRatio)
                        reports[index] = report

                        index += 1
                        if index < segments.count {
                            state = .waiting
                            runtimeState = SegmentRuntimeState(waypoints: segments[index].waypoints)
                            continue
                        } else {
                            state = .waiting
                            break
                        }
                    }
                } else {
                    reports[index] = report
                }
            }
        }

        if failure == nil {
            if samples.isEmpty {
                reports[0].startDistance = .greatestFiniteMagnitude
            } else if state == .waiting, index < segments.count {
                let startDistance = reports[index].startDistance
                if !startDistance.isFinite || startDistance > tuning.startRadius * 1.3 {
                    failure = .missedStart
                }
            } else if state == .inside, index < segments.count {
                let insideRatio = runtimeState.totalSamples > 0
                    ? Double(runtimeState.insideSamples) / Double(runtimeState.totalSamples)
                    : 0
                reports[index].coverageRatio = insideRatio
                reports[index].outsideRatio = runtimeState.totalSamples > 0
                    ? Double(runtimeState.outsideSamples) / Double(runtimeState.totalSamples)
                    : 1
                reports[index].travelledRatio = segments[index].length > 0
                    ? Double(min(runtimeState.maxArcLength / segments[index].length, 1))
                    : 0
                reports[index].duration = max(0, (runtimeState.lastTimestamp ?? samples.last!.timestamp) - (runtimeState.firstTimestamp ?? samples.first!.timestamp))
            }
        }

        let completedCount = reports.filter { $0.completed }.count
        let nextIndex: Int
        switch state {
        case .waiting:
            nextIndex = min(index, segments.count)
        case .inside:
            nextIndex = min(index, segments.count - 1)
        }

        return Result(reports: reports,
                      failure: failure,
                      completedCount: completedCount,
                      nextIndex: nextIndex,
                      state: state,
                      activeWarning: warning)
    }

    private static func hitNextStart(_ point: CGPoint,
                                     currentIndex: Int,
                                     segments: [StrokeSegment],
                                     startRadius: CGFloat) -> Bool {
        guard currentIndex < segments.count - 1 else { return false }
        let next = segments[currentIndex + 1]
        return next.start.distance(to: point) <= startRadius
    }

    private static func flattenedSamples(from drawing: PKDrawing) -> [Sample] {
        var result: [Sample] = []
        for (strokeIndex, stroke) in drawing.strokes.enumerated() {
            let base = stroke.path.creationDate.timeIntervalSinceReferenceDate
            for point in stroke.path {
                let location = point.location.applying(stroke.transform)
                let timestamp = base + point.timeOffset
                result.append(Sample(location: location,
                                     timestamp: timestamp,
                                     strokeIndex: strokeIndex))
            }
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }
}
