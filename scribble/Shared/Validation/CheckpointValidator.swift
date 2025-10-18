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

    struct LiveSample {
        let location: CGPoint
        let timestamp: TimeInterval
    }

    static func evaluate(drawing: PKDrawing,
                         template: StrokeTraceTemplate,
                         configuration: Configuration,
                         liveStrokeSamples: [LiveSample] = [],
                         precomputedPlan: TraceCheckpointPlan? = nil) -> Result {
        let plan: TraceCheckpointPlan
        if let provided = precomputedPlan {
            plan = provided
        } else {
            plan = TraceCheckpointPlan.make(template: template,
                                            checkpointLength: configuration.checkpointLength,
                                            spacing: configuration.spacingLength)
        }

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

        let samples = combinedSamples(committed: flattenedSamples(from: drawing),
                                      live: liveStrokeSamples)

        outer: for sample in samples {
            guard failure == nil else { break }

            if nextCheckpointIndex < descriptors.count {
                let pointerDescriptor = descriptors[nextCheckpointIndex]
                let path = plan.paths[pointerDescriptor.pathIndex]
                let projection = path.projection(for: sample.location)
                var pointerState = checkpointStates[nextCheckpointIndex]

                if projection.distance <= configuration.corridorRadius {
                    let endProgress = pointerDescriptor.startProgress + pointerDescriptor.length
                    let startTolerance = max(pointerDescriptor.length * 0.4, configuration.studentLineWidth * 1.2)
                    let endTolerance = max(pointerDescriptor.length * 0.3, configuration.studentLineWidth)

                    if projection.progress >= pointerDescriptor.startProgress - startTolerance {
                        pointerState.hasContact = true
                        pointerState.maxProgress = max(pointerState.maxProgress, projection.progress)
                        if projection.progress <= pointerDescriptor.startProgress + startTolerance {
                            pointerState.touchedStart = true
                        }

                        if pointerState.maxProgress <= pointerDescriptor.startProgress {
                            pointerState.touchedStart = true
                        }

                        if pointerState.touchedStart && pointerState.maxProgress >= endProgress - endTolerance {
                            pointerState.completed = true
                            checkpointStates[nextCheckpointIndex] = pointerState
                            nextCheckpointIndex += 1
                            continue
                        }
                        checkpointStates[nextCheckpointIndex] = pointerState
                        continue
                    }
                } else if pointerState.hasContact && projection.distance > configuration.corridorRadius {
                    checkpointStates[nextCheckpointIndex] = pointerState
                }
            }

            if let nearest = nearestPath(for: sample.location, in: plan.paths),
               nearest.projection.distance <= configuration.corridorRadius,
               let checkpointLocalIndex = plan.paths[nearest.index].checkpointIndex(for: nearest.projection.progress) {
                let globalCheckpoint = plan.paths[nearest.index].checkpoints[checkpointLocalIndex].globalIndex
                if globalCheckpoint > nextCheckpointIndex {
                    let currentPathIndex = nextCheckpointIndex < descriptors.count ? descriptors[nextCheckpointIndex].pathIndex : nil
                    if let currentPathIndex, nearest.index != currentPathIndex {
                        continue
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
        var touchedStart: Bool = false
        var maxProgress: CGFloat = 0
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

    static func combinedSamples(committed: [Sample],
                                live: [CheckpointValidator.LiveSample]) -> [Sample] {
        guard !live.isEmpty else { return committed }
        var combined = committed
        combined.reserveCapacity(committed.count + live.count)
        for sample in live {
            combined.append(Sample(location: sample.location, timestamp: sample.timestamp))
        }
        combined.sort { $0.timestamp < $1.timestamp }
        return combined
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
