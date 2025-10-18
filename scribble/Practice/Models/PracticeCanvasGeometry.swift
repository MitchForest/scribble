import SwiftUI

struct PracticeCanvasSizing {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics

    static func resolve(items: [LetterTimelineItem],
                        availableWidth: CGFloat,
                        baseMetrics: PracticeCanvasMetrics,
                        isLeftHanded: Bool,
                        minimumScale: CGFloat = 0.55) -> PracticeCanvasSizing {
        guard availableWidth.isFinite, availableWidth > 0 else {
            let fallbackLayout = WordLayout(items: items,
                                            availableWidth: max(availableWidth, 0),
                                            metrics: baseMetrics,
                                            isLeftHanded: isLeftHanded)
            return PracticeCanvasSizing(layout: fallbackLayout, metrics: baseMetrics)
        }

        var scale = baseMetrics.scale
        var metrics = baseMetrics
        var layout = WordLayout(items: items,
                                availableWidth: availableWidth,
                                metrics: metrics,
                                isLeftHanded: isLeftHanded)

        for _ in 0..<4 {
            let totalWidth = layout.width + layout.leadingInset + layout.trailingInset
            if totalWidth <= availableWidth || scale <= minimumScale + 0.0001 {
                break
            }
            let ratio = max(min(availableWidth / max(totalWidth, 1), 1), 0)
            let nextScale = max(minimumScale, scale * ratio)
            if abs(nextScale - scale) < 0.001 {
                scale = nextScale
                break
            }
            scale = nextScale
            metrics = baseMetrics.scaled(by: scale)
            layout = WordLayout(items: items,
                                availableWidth: availableWidth,
                                metrics: metrics,
                                isLeftHanded: isLeftHanded)
        }

        return PracticeCanvasSizing(layout: layout, metrics: metrics)
    }
}

struct PracticeCanvasMetrics {
    let strokeSize: StrokeSizePreference
    let scale: CGFloat

    init(strokeSize: StrokeSizePreference, scale: CGFloat = 1) {
        self.strokeSize = strokeSize
        self.scale = scale
    }

    var rowMetrics: RowMetrics {
        let base = strokeSize.metrics
        return RowMetrics(ascender: base.ascender * scale,
                          descender: base.descender * scale)
    }

    var canvasPadding: CGFloat {
        baseCanvasPadding * scale
    }

    var canvasHeight: CGFloat {
        rowMetrics.ascender + rowMetrics.descender + canvasPadding
    }

    var practiceLineWidth: CGFloat {
        basePracticeLineWidth * scale
    }

    var guideLineWidth: CGFloat {
        baseGuideLineWidth * scale
    }

    var startDotSize: CGFloat {
        baseStartDotSize * scale
    }

    var userInkWidth: CGFloat {
        baseUserInkWidth * scale
    }

    func scaled(by newScale: CGFloat) -> PracticeCanvasMetrics {
        PracticeCanvasMetrics(strokeSize: strokeSize, scale: newScale)
    }

    private var baseCanvasPadding: CGFloat {
        switch strokeSize {
        case .large: return 35
        case .standard: return 28
        case .compact: return 21
        }
    }

    private var basePracticeLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 9.5
        case .standard: return 7.2
        case .compact: return 5.2
        }
    }

    private var baseGuideLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 7.5
        case .standard: return 5.8
        case .compact: return 4.4
        }
    }

    private var baseStartDotSize: CGFloat {
        switch strokeSize {
        case .large: return 32
        case .standard: return 24
        case .compact: return 18
        }
    }

    private var baseUserInkWidth: CGFloat {
        switch strokeSize {
        case .large: return 8.2
        case .standard: return 6.4
        case .compact: return 4.8
        }
    }
}

struct WordLayout {
    struct Segment: Identifiable {
        let id = UUID()
        let index: Int
        let item: LetterTimelineItem
        let strokes: [ScaledStroke]
        let frame: CGRect
        let lineWidth: CGFloat
        let strokeBounds: CGRect?
        let totalCheckpointCount: Int
        let checkpoints: [ScaledStroke.CheckpointDescriptor]
        let checkpointPlan: TraceCheckpointPlan?

        var isPractiseable: Bool { item.isPractiseable && !strokes.isEmpty }

        var checkpointDescriptors: [ScaledStroke.CheckpointDescriptor] {
            checkpoints
        }

        var checkpointSegments: [ScaledStroke.CheckpointSegment] {
            strokes.flatMap { $0.checkpointSegments }
        }
    }

    let segments: [Segment]
    let ascender: CGFloat
    let descender: CGFloat
    let width: CGFloat
    let height: CGFloat
    let scaledXHeight: CGFloat
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    let verticalInset: CGFloat
    let cacheKey: String

    init(items: [LetterTimelineItem],
         availableWidth: CGFloat,
         metrics: PracticeCanvasMetrics,
         isLeftHanded: Bool) {
        let availableWidth = max(availableWidth, 160)
        let desiredInset = max(metrics.practiceLineWidth * 0.75, 18)
        let rowAscender = metrics.rowMetrics.ascender
        let rowDescender = metrics.rowMetrics.descender
        let verticalInset = metrics.practiceLineWidth * 0.75
        let totalHeight = rowAscender + rowDescender

        let baseSpacing: CGFloat = rowAscender * 0.26
        let baseSpaceWidth: CGFloat = rowAscender * 0.52

        struct Descriptor {
            let item: LetterTimelineItem
            let strokes: [HandwritingTemplate.Stroke]
            let minX: CGFloat
            let maxX: CGFloat
            let baseScale: CGFloat
            let width: CGFloat
            let lineWidth: CGFloat
            let baseline: CGFloat
            let ascenderScale: CGFloat
            let descenderScale: CGFloat
            let scaledXHeight: CGFloat?
        }

        var descriptors: [Descriptor] = []
        var rawWidths: [CGFloat] = []
        var xHeightSamples: [CGFloat] = []

        for item in items {
            if let template = item.template {
                let sorted = template.strokes.sorted { $0.order < $1.order }
                let allPoints = sorted.flatMap { $0.points }
                let minX = allPoints.map(\.x).min() ?? 0
                let maxX = allPoints.map(\.x).max() ?? 0
                let ascenderValue = CGFloat(max(template.metrics.ascender, 1))
                let descenderValue = CGFloat(abs(template.metrics.descender))
                let ascScale = rowAscender / ascenderValue
                let descScale = descenderValue > 0 ? rowDescender / descenderValue : ascScale
                let baseScale = ascScale
                let width = CGFloat(maxX - minX) * baseScale
                let baseline = CGFloat(template.metrics.baseline)
                let xHeightDistance = CGFloat(template.metrics.xHeight - template.metrics.baseline)
                let scaledXHeight = xHeightDistance > 0 ? xHeightDistance * ascScale : nil
                scaledXHeight.map { xHeightSamples.append($0) }
                let descriptor = Descriptor(item: item,
                                            strokes: sorted,
                                            minX: CGFloat(minX),
                                            maxX: CGFloat(maxX),
                                            baseScale: baseScale,
                                            width: width,
                                            lineWidth: metrics.practiceLineWidth,
                                            baseline: baseline,
                                            ascenderScale: ascScale,
                                            descenderScale: descScale,
                                            scaledXHeight: scaledXHeight)
                descriptors.append(descriptor)
                rawWidths.append(width)
            } else {
                descriptors.append(Descriptor(item: item,
                                              strokes: [],
                                              minX: 0,
                                              maxX: 0,
                                              baseScale: 1,
                                              width: item.isSpace ? baseSpaceWidth : baseSpacing,
                                              lineWidth: metrics.practiceLineWidth,
                                              baseline: 0,
                                              ascenderScale: 1,
                                              descenderScale: 1,
                                              scaledXHeight: nil))
                rawWidths.append(item.isSpace ? baseSpaceWidth : baseSpacing)
            }
        }

        let spacingCount = max(0, CGFloat(descriptors.count - 1))
        let glyphWidthSum = rawWidths.reduce(0, +)
        let gapCount = max(descriptors.count - 1, 0)
        let minimalInnerWidth = glyphWidthSum + baseSpacing * spacingCount

        var leadingInsetValue = desiredInset
        let minimalTotalWidth = minimalInnerWidth + leadingInsetValue * 2
        if minimalTotalWidth > availableWidth {
            let availableMargin = max(availableWidth - minimalInnerWidth, 0)
            let adjustedInset = availableMargin / 2
            leadingInsetValue = max(min(adjustedInset, desiredInset), 0)
        }

        var trailingInsetValue = leadingInsetValue

        let availableInnerWidth = max(availableWidth - leadingInsetValue * 2, 0)
        let targetInnerWidth = max(minimalInnerWidth, availableInnerWidth)

        var spacingBetweenSegments = baseSpacing
        if gapCount > 0 && minimalInnerWidth < targetInnerWidth {
            let extra = targetInnerWidth - minimalInnerWidth
            let additionalPerGap = min(extra / CGFloat(gapCount), baseSpacing * 0.6)
            spacingBetweenSegments = baseSpacing + additionalPerGap
        }

        var segments: [Segment] = []
        var cursor = leadingInsetValue

        for (index, descriptor) in descriptors.enumerated() {
            let segmentWidth = descriptor.width
            if descriptor.strokes.isEmpty {
                let frame = CGRect(x: cursor,
                                   y: 0,
                                   width: segmentWidth,
                                   height: totalHeight)
                segments.append(Segment(index: index,
                                        item: descriptor.item,
                                        strokes: [],
                                        frame: frame,
                                        lineWidth: descriptor.lineWidth,
                                        strokeBounds: nil,
                                        totalCheckpointCount: 0,
                                        checkpoints: [],
                                        checkpointPlan: nil))
            } else {
                let horizontalScale = descriptor.baseScale
                let frame = CGRect(x: cursor,
                                   y: 0,
                                   width: segmentWidth,
                                   height: totalHeight)

                var blueprints: [StrokeBlueprint] = []
                var unionBounds: CGRect?

                for stroke in descriptor.strokes {
                    let convertedPoints = stroke.points.map { point in
                        WordLayout.convert(point: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)),
                                           minX: descriptor.minX,
                                           horizontalScale: horizontalScale,
                                           ascenderScale: descriptor.ascenderScale,
                                           descenderScale: descriptor.descenderScale,
                                           cursor: cursor,
                                           ascender: rowAscender,
                                           baseline: descriptor.baseline,
                                           isLeftHanded: isLeftHanded,
                                           segmentWidth: segmentWidth)
                    }

                    var path = Path()
                    if let first = convertedPoints.first {
                        path.move(to: first)
                        path.addLines(Array(convertedPoints.dropFirst()))
                    }
                    let pathBounds = path.boundingRect
                    unionBounds = unionBounds.map { $0.union(pathBounds) } ?? pathBounds

                    let startPoint = WordLayout.convert(point: stroke.start ?? stroke.points.first ?? .zero,
                                                        minX: descriptor.minX,
                                                        horizontalScale: horizontalScale,
                                                        ascenderScale: descriptor.ascenderScale,
                                                        descenderScale: descriptor.descenderScale,
                                                        cursor: cursor,
                                                        ascender: rowAscender,
                                                        baseline: descriptor.baseline,
                                                        isLeftHanded: isLeftHanded,
                                                        segmentWidth: segmentWidth)
                    let endPoint = WordLayout.convert(point: stroke.end ?? stroke.points.last ?? .zero,
                                                      minX: descriptor.minX,
                                                      horizontalScale: horizontalScale,
                                                      ascenderScale: descriptor.ascenderScale,
                                                      descenderScale: descriptor.descenderScale,
                                                      cursor: cursor,
                                                      ascender: rowAscender,
                                                      baseline: descriptor.baseline,
                                                      isLeftHanded: isLeftHanded,
                                                      segmentWidth: segmentWidth)

                    blueprints.append(StrokeBlueprint(id: stroke.id,
                                                      order: stroke.order,
                                                      path: path,
                                                      points: convertedPoints,
                                                      startPoint: startPoint,
                                                      endPoint: endPoint))
                }

                let templateStrokes = blueprints.map { blueprint in
                    StrokeTraceTemplate.Stroke(id: blueprint.id,
                                               order: blueprint.order,
                                               points: blueprint.points,
                                               startPoint: blueprint.startPoint,
                                               endPoint: blueprint.endPoint)
                }
                let traceTemplate = StrokeTraceTemplate(strokes: templateStrokes)
                let checkpointPlan = TraceCheckpointPlan.make(template: traceTemplate,
                                                              checkpointLength: WordLayout.checkpointLength,
                                                              spacing: WordLayout.checkpointSpacing)

                var scaledStrokes: [ScaledStroke] = []
                for (pathIndex, blueprint) in blueprints.enumerated() {
                    let checkpoints = checkpointPlan.paths[pathIndex].checkpoints.map {
                        ScaledStroke.CheckpointSegment(index: $0.globalIndex,
                                                       startProgress: $0.startProgress,
                                                       endProgress: $0.endProgress)
                    }
                    let descriptors = checkpointPlan.paths[pathIndex].checkpoints.map {
                        ScaledStroke.CheckpointDescriptor(globalIndex: $0.globalIndex,
                                                          pathIndex: pathIndex,
                                                          startProgress: $0.startProgress,
                                                          endProgress: $0.endProgress,
                                                          length: $0.length)
                    }
                    scaledStrokes.append(ScaledStroke(id: blueprint.id,
                                                      order: blueprint.order,
                                                      path: blueprint.path,
                                                      points: blueprint.points,
                                                      startPoint: blueprint.startPoint,
                                                      endPoint: blueprint.endPoint,
                                                      checkpointSegments: checkpoints,
                                                      checkpoints: descriptors))
                }

                let aggregatedCheckpoints = scaledStrokes.flatMap { $0.checkpoints }
                segments.append(Segment(index: index,
                                        item: descriptor.item,
                                        strokes: scaledStrokes,
                                        frame: frame,
                                        lineWidth: descriptor.lineWidth,
                                        strokeBounds: unionBounds,
                                        totalCheckpointCount: checkpointPlan.totalCheckpointCount,
                                        checkpoints: aggregatedCheckpoints,
                                        checkpointPlan: checkpointPlan))
            }
            cursor += segmentWidth
            if index < descriptors.count - 1 {
                cursor += spacingBetweenSegments
            }
        }

        let trailingGap: CGFloat
        if descriptors.count > 1 {
            trailingGap = spacingBetweenSegments
        } else {
            trailingGap = baseSpacing
        }
        trailingInsetValue = max(trailingInsetValue, trailingGap)

        self.segments = segments
        let resolvedXHeight: CGFloat
        if xHeightSamples.isEmpty {
            resolvedXHeight = rowAscender * 0.6
        } else {
            resolvedXHeight = xHeightSamples.reduce(0, +) / CGFloat(xHeightSamples.count)
        }
        self.scaledXHeight = resolvedXHeight
        self.ascender = rowAscender
        self.descender = rowDescender
        let contentWidth = max(cursor - leadingInsetValue, minimalInnerWidth)
        self.width = contentWidth
        self.height = totalHeight
        self.leadingInset = leadingInsetValue
        self.trailingInset = trailingInsetValue
        self.verticalInset = verticalInset
        let scaleKey = String(format: "%.4f", Double(metrics.scale))
        self.cacheKey = "\(items.map { $0.character })|\(availableWidth)|\(rowAscender)|\(isLeftHanded)|\(scaleKey)"
    }

    private static func convert(point: CGPoint,
                                minX: CGFloat,
                                horizontalScale: CGFloat,
                                ascenderScale: CGFloat,
                                descenderScale: CGFloat,
                                cursor: CGFloat,
                                ascender: CGFloat,
                                baseline: CGFloat,
                                isLeftHanded: Bool,
                                segmentWidth: CGFloat) -> CGPoint {
        var x = (CGFloat(point.x) - minX) * horizontalScale
        if isLeftHanded {
            x = segmentWidth - x
        }
        let displacement = CGFloat(point.y) - baseline
        let verticalScale = displacement >= 0 ? ascenderScale : descenderScale
        let y = ascender - displacement * verticalScale
        return CGPoint(x: cursor + x, y: y)
    }

    static let checkpointLength: CGFloat = 6
    static let checkpointSpacing: CGFloat = 6

    struct ScaledStroke: Identifiable {
        let id: String
        let order: Int
        let path: Path
        let points: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
        let checkpointSegments: [CheckpointSegment]
        let checkpoints: [CheckpointDescriptor]
        let length: CGFloat

        struct CheckpointSegment {
            let index: Int
            let startProgress: CGFloat
            let endProgress: CGFloat
        }

        struct CheckpointDescriptor {
            let globalIndex: Int
            let pathIndex: Int
            let startProgress: CGFloat
            let endProgress: CGFloat
            let length: CGFloat
        }

        init(id: String,
             order: Int,
             path: Path,
             points: [CGPoint],
             startPoint: CGPoint,
             endPoint: CGPoint,
             checkpointSegments: [CheckpointSegment],
             checkpoints: [CheckpointDescriptor]) {
            self.id = id
            self.order = order
            self.path = path
            self.points = points
            self.startPoint = startPoint
            self.endPoint = endPoint
            self.checkpointSegments = checkpointSegments
            self.checkpoints = checkpoints
            self.length = ScaledStroke.computeLength(points: points)
        }

        var arrowAngle: Angle {
            guard let first = points.first else { return .zero }
            for point in points.dropFirst() {
                let dx = point.x - first.x
                let dy = point.y - first.y
                if abs(dx) > 0.01 || abs(dy) > 0.01 {
                    return Angle(radians: Double(atan2(dy, dx)))
                }
            }
            return .zero
        }

        var isLoop: Bool {
            hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) < 1
        }

        private static func computeLength(points: [CGPoint]) -> CGFloat {
            guard points.count > 1 else { return 0 }
            var total: CGFloat = 0
            for index in 0..<(points.count - 1) {
                let a = points[index]
                let b = points[index + 1]
                total += hypot(b.x - a.x, b.y - a.y)
            }
            return total
        }
    }

    private struct StrokeBlueprint {
        let id: String
        let order: Int
        let path: Path
        let points: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
    }
}

extension WordLayout.Segment {
    func completedStrokeCount(using statuses: [CheckpointValidator.CheckpointStatus]) -> Int {
        guard !strokes.isEmpty else { return 0 }
        let completedSet = Set(statuses.filter { $0.completed }.map { $0.globalIndex })
        return strokes.reduce(0) { count, stroke in
            guard !stroke.checkpointSegments.isEmpty else { return count }
            let allComplete = stroke.checkpointSegments.allSatisfy { completedSet.contains($0.index) }
            return count + (allComplete ? 1 : 0)
        }
    }

    func firstIncompleteStrokeIndex(using statuses: [CheckpointValidator.CheckpointStatus]) -> Int? {
        let completedSet = Set(statuses.filter { $0.completed }.map { $0.globalIndex })
        for (index, stroke) in strokes.enumerated() {
            guard !stroke.checkpointSegments.isEmpty else { continue }
            let allComplete = stroke.checkpointSegments.allSatisfy { completedSet.contains($0.index) }
            if !allComplete {
                return index
            }
        }
        return nil
    }
}
