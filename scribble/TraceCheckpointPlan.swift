import CoreGraphics

struct TraceCheckpointPlan {
    struct Path {
        struct Segment {
            let start: CGPoint
            let end: CGPoint
            let length: CGFloat
            let cumulativeLengthAtStart: CGFloat
        }

        struct Checkpoint {
            var globalIndex: Int = 0
            var pathIndex: Int = 0
            let startProgress: CGFloat
            let endProgress: CGFloat
            let length: CGFloat

            var midpointProgress: CGFloat {
                (startProgress + endProgress) * 0.5
            }
        }

        struct Projection {
            let distance: CGFloat
            let progress: CGFloat
        }

        let id: String
        let order: Int
        let points: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
        let segments: [Segment]
        var checkpoints: [Checkpoint]
        let totalLength: CGFloat

        init(stroke: StrokeTraceTemplate.Stroke,
             checkpointLength: CGFloat,
             spacing: CGFloat) {
            id = stroke.id
            order = stroke.order
            points = stroke.points
            startPoint = stroke.startPoint
            endPoint = stroke.endPoint

            let build = Self.makeSegments(points: stroke.points)
            segments = build.segments
            totalLength = build.totalLength
            checkpoints = Self.makeCheckpoints(points: stroke.points,
                                               totalLength: build.totalLength,
                                               checkpointLength: checkpointLength,
                                               spacing: spacing)
        }

        func projection(for point: CGPoint) -> Projection {
            guard !segments.isEmpty else {
                let distance = hypot(point.x - points.first!.x,
                                     point.y - points.first!.y)
                return Projection(distance: distance, progress: 0)
            }

            var bestDistanceSquared = CGFloat.greatestFiniteMagnitude
            var bestProgress: CGFloat = 0

            for segment in segments {
                let vx = segment.end.x - segment.start.x
                let vy = segment.end.y - segment.start.y
                let lengthSquared = vx * vx + vy * vy
                guard lengthSquared > .ulpOfOne else { continue }

                let wx = point.x - segment.start.x
                let wy = point.y - segment.start.y
                let t = max(0, min(1, (wx * vx + wy * vy) / lengthSquared))
                let closestX = segment.start.x + vx * t
                let closestY = segment.start.y + vy * t
                let dx = point.x - closestX
                let dy = point.y - closestY
                let distanceSquared = dx * dx + dy * dy

                if distanceSquared < bestDistanceSquared {
                    bestDistanceSquared = distanceSquared
                    let travelled = segment.cumulativeLengthAtStart + t * segment.length
                    bestProgress = totalLength > 0 ? travelled / totalLength : 0
                }
            }

            return Projection(distance: sqrt(bestDistanceSquared), progress: bestProgress)
        }

        func checkpointIndex(for progress: CGFloat) -> Int? {
            for (index, checkpoint) in checkpoints.enumerated() {
                if progress >= checkpoint.startProgress - 1e-4 &&
                    progress <= checkpoint.endProgress + 1e-4 {
                    return index
                }
            }
            return nil
        }

        func point(at progress: CGFloat) -> CGPoint {
            guard totalLength > .ulpOfOne else {
                return points.first ?? .zero
            }
            let target = clamp(progress, lower: 0, upper: 1) * totalLength
            for segment in segments {
                if target < segment.cumulativeLengthAtStart + segment.length {
                    let delta = target - segment.cumulativeLengthAtStart
                    let t = segment.length > .ulpOfOne ? delta / segment.length : 0
                    let x = segment.start.x + (segment.end.x - segment.start.x) * t
                    let y = segment.start.y + (segment.end.y - segment.start.y) * t
                    return CGPoint(x: x, y: y)
                }
            }
            return segments.last.map { $0.end } ?? points.last ?? .zero
        }

        private static func makeSegments(points: [CGPoint]) -> (segments: [Segment], totalLength: CGFloat) {
            guard points.count > 1 else {
                return ([], 0)
            }

            var segments: [Segment] = []
            var cumulative: CGFloat = 0

            for index in 0..<(points.count - 1) {
                let start = points[index]
                let end = points[index + 1]
                let length = hypot(end.x - start.x, end.y - start.y)
                segments.append(Segment(start: start,
                                        end: end,
                                        length: length,
                                        cumulativeLengthAtStart: cumulative))
                cumulative += length
            }

            return (segments, cumulative)
        }

        private static func makeCheckpoints(points: [CGPoint],
                                            totalLength: CGFloat,
                                            checkpointLength: CGFloat,
                                            spacing: CGFloat) -> [Checkpoint] {
            guard points.count > 1 else {
                return [Checkpoint(startProgress: 0, endProgress: 1, length: 0)]
            }

            guard totalLength > .ulpOfOne else {
                return [Checkpoint(startProgress: 0, endProgress: 1, length: 0)]
            }

            if checkpointLength <= .ulpOfOne {
                return [Checkpoint(startProgress: 0,
                                   endProgress: 1,
                                   length: totalLength)]
            }

            var checkpoints: [Checkpoint] = []
            var accumulated: CGFloat = 0
            var isCheckpoint = true
            let pattern: [CGFloat] = spacing > .ulpOfOne ? [checkpointLength, spacing] : [checkpointLength]
            var patternIndex = 0
            var remainingInPattern = pattern[patternIndex]

            while accumulated < totalLength - .ulpOfOne {
                let remaining = totalLength - accumulated
                let segmentLength = min(remainingInPattern, remaining)

                if isCheckpoint {
                    let startProgress = max(0, min(1, accumulated / totalLength))
                    let endProgress = max(startProgress,
                                          min(1, (accumulated + segmentLength) / totalLength))
                    checkpoints.append(Checkpoint(startProgress: startProgress,
                                                  endProgress: endProgress,
                                                  length: segmentLength))
                }

                accumulated += segmentLength
                remainingInPattern -= segmentLength
                if remainingInPattern <= .ulpOfOne {
                    patternIndex += 1
                    remainingInPattern = pattern[patternIndex % pattern.count]
                    isCheckpoint.toggle()
                }
            }

            if checkpoints.isEmpty {
                checkpoints.append(Checkpoint(startProgress: 0,
                                              endProgress: 1,
                                              length: totalLength))
            }

            return checkpoints
        }
    }

    let paths: [Path]
    let totalCheckpointCount: Int

    static func make(template: StrokeTraceTemplate,
                     checkpointLength: CGFloat,
                     spacing: CGFloat) -> TraceCheckpointPlan {
        let sorted = template.strokes.sorted { $0.order < $1.order }
        var paths: [Path] = sorted.map {
            Path(stroke: $0,
                 checkpointLength: checkpointLength,
                 spacing: spacing)
        }

        var globalIndex = 0
        for pathIndex in paths.indices {
            for checkpointIndex in paths[pathIndex].checkpoints.indices {
                paths[pathIndex].checkpoints[checkpointIndex].pathIndex = pathIndex
                paths[pathIndex].checkpoints[checkpointIndex].globalIndex = globalIndex
                globalIndex += 1
            }
        }

        return TraceCheckpointPlan(paths: paths,
                                   totalCheckpointCount: globalIndex)
    }
}

private func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    min(max(value, lower), upper)
}
