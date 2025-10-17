import Foundation
import CoreGraphics
import PencilKit

struct CheckpointValidator {
    enum FailureReason: Equatable {
        case outOfOrder
        case insufficientCoverage
        case excessiveOutside
    }

    struct CheckpointStatus {
        let pathID: String
        let pathIndex: Int
        let globalIndex: Int
        let completed: Bool
        let hasContact: Bool
    }

    struct Result {
        let checkpointStatuses: [CheckpointStatus]
        let activeCheckpointIndex: Int
        let totalCheckpointCount: Int
        let failure: FailureReason?

        var completedCheckpointCount: Int {
            checkpointStatuses.reduce(0) { $0 + ($1.completed ? 1 : 0) }
        }

        var isComplete: Bool {
            failure == nil && activeCheckpointIndex >= totalCheckpointCount
        }
    }

    struct Configuration {
        let corridorRadius: CGFloat
        let checkpointLength: CGFloat
        let spacingLength: CGFloat
        let coverageThreshold: Double
        let outsideAllowance: Double
        let studentLineWidth: CGFloat
    }

    static func evaluate(drawing: PKDrawing,
                         template: StrokeTraceTemplate,
                         configuration: Configuration) -> Result {
        let plan = TraceCheckpointPlan.make(template: template,
                                            checkpointLength: configuration.checkpointLength,
                                            spacing: configuration.spacingLength)

        guard plan.totalCheckpointCount > 0 else {
            return Result(checkpointStatuses: [],
                          activeCheckpointIndex: 0,
                          totalCheckpointCount: 0,
                          failure: nil)
        }

        let descriptors = plan.paths.flatMap { path in
            path.checkpoints.map { descriptor -> CheckpointDescriptor in
                CheckpointDescriptor(globalIndex: descriptor.globalIndex,
                                     pathIndex: descriptor.pathIndex,
                                     startProgress: descriptor.startProgress,
                                     endProgress: descriptor.endProgress,
                                     length: descriptor.length,
                                     pathID: path.id)
            }
        }

        var checkpointStates = Array(repeating: CheckpointProgress(), count: descriptors.count)
        var nextCheckpointIndex = 0
        var failure: FailureReason?
        var failureCheckpointIndex: Int?

        let samples = flattenedSamples(from: drawing)

        outer: for sample in samples {
            guard failure == nil else { break }

            // Step 1: update coverage/outside for current checkpoint.
            if nextCheckpointIndex < descriptors.count {
                let pointerDescriptor = descriptors[nextCheckpointIndex]
                let path = plan.paths[pointerDescriptor.pathIndex]
                let projection = path.projection(for: sample.location)
                var pointerState = checkpointStates[nextCheckpointIndex]

                if projection.distance <= configuration.corridorRadius &&
                    projection.progress >= pointerDescriptor.startProgress - 1e-4 {

                    pointerState.hasContact = true
                    pointerState.completed = true
                    checkpointStates[nextCheckpointIndex] = pointerState
                    nextCheckpointIndex += 1
                    continue
                } else if pointerState.hasContact && projection.distance > configuration.corridorRadius {
                    checkpointStates[nextCheckpointIndex] = pointerState
                }
            }

            // Step 2: detect out-of-order interactions.
            if let nearest = nearestPath(for: sample.location, in: plan.paths),
               nearest.projection.distance <= configuration.corridorRadius,
               let checkpointLocalIndex = plan.paths[nearest.index].checkpointIndex(for: nearest.projection.progress) {
                let globalCheckpoint = plan.paths[nearest.index].checkpoints[checkpointLocalIndex].globalIndex
                if globalCheckpoint > nextCheckpointIndex {
                    if globalCheckpoint >= nextCheckpointIndex {
                        if globalCheckpoint > nextCheckpointIndex {
                            failure = .outOfOrder
                            failureCheckpointIndex = globalCheckpoint
                            break outer
                        } else {
                            // Touching the current checkpoint again is fine.
                            continue
                        }
                    }
                }
            }
        }

        let statuses: [CheckpointStatus] = checkpointStates.enumerated().map { index, state in
            let descriptor = descriptors[index]
            return CheckpointStatus(pathID: descriptor.pathID,
                                    pathIndex: descriptor.pathIndex,
                                    globalIndex: descriptor.globalIndex,
                                    completed: state.completed,
                                    hasContact: state.hasContact)
        }

        let resolvedActiveCheckpoint = failure == nil ? nextCheckpointIndex : (failureCheckpointIndex ?? nextCheckpointIndex)

        return Result(checkpointStatuses: statuses,
                      activeCheckpointIndex: resolvedActiveCheckpoint,
                      totalCheckpointCount: descriptors.count,
                      failure: failure)
    }
}

// MARK: - Helpers

private extension CheckpointValidator {
    struct CheckpointDescriptor {
        let globalIndex: Int
        let pathIndex: Int
        let startProgress: CGFloat
        let endProgress: CGFloat
        let length: CGFloat
        let pathID: String
    }

    struct CheckpointProgress {
        var hasContact: Bool = false
        var completed: Bool = false
    }

    struct Sample {
        let location: CGPoint
        let timestamp: TimeInterval
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

    static func nearestPath(for point: CGPoint,
                            in paths: [TraceCheckpointPlan.Path]) -> (index: Int, projection: TraceCheckpointPlan.Path.Projection)? {
        var best: (index: Int, projection: TraceCheckpointPlan.Path.Projection)?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, path) in paths.enumerated() {
            let projection = path.projection(for: point)
            if projection.distance < bestDistance {
                bestDistance = projection.distance
                best = (index, projection)
            }
        }
        return best
    }

}

private func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    min(max(value, lower), upper)
}
