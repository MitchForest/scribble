import Foundation
import PencilKit
import SwiftUI

/// Handles per-row state transitions, validation, and feedback orchestration.
@MainActor
final class PracticeRowViewModel: ObservableObject {
    enum Phase: CustomStringConvertible, Equatable {
        case previewing
        case writing
        case frozen

        var description: String {
            switch self {
            case .previewing: return "previewing"
            case .writing: return "writing"
            case .frozen: return "frozen"
            }
        }
    }

    struct State {
        var phase: Phase = .frozen
        var drawing: PKDrawing = PKDrawing()
        var frozenDrawing: PKDrawing = PKDrawing()
        var warningMessage: String?
        var currentStrokeIndex: Int = 0
        var lastWarningTime: Date?
        var completedCheckpointCount: Int = 0
        var completedStrokeCount: Int = 0
        var didCompleteCurrentLetter: Bool = false
        var previewStrokeProgress: [CGFloat] = []
        var previewAnimationGeneration: Int = 0
        var activeStrokeSamples: [CanvasStrokeSample] = []
        var lastIgnoreReason: String?
        var loggedEmptyReset: Bool = false
        var skipNextEmptyReset: Bool = false
        var lastAnalysis: CheckpointValidator.Result?
        var completedLetterIndices: Set<Int> = []

        var isWriting: Bool { phase == .writing }
        var isPreviewing: Bool { phase == .previewing }
    }

    struct Environment {
        var segment: WordLayout.Segment?
        var metrics: PracticeCanvasMetrics
        var difficulty: PracticeDifficulty
        var hapticsEnabled: Bool
    }

    @Published private(set) var state: State = State()
    @Published private(set) var environment: Environment?
    @Published private(set) var isActive: Bool = false

    let repetitionIndex: Int
    private(set) var letterIndex: Int
    private let haptics: HapticsProviding

    private let onLetterComplete: () -> Void
    private let onWarning: () -> Void
    private let onSuccessFeedback: () -> Void
    private let onRetryFeedback: () -> Void

    private var previewWorkItems: [DispatchWorkItem] = []

    init(repetitionIndex: Int,
         initialLetterIndex: Int,
         onLetterComplete: @escaping () -> Void,
         onWarning: @escaping () -> Void,
         onSuccessFeedback: @escaping () -> Void,
         onRetryFeedback: @escaping () -> Void,
         haptics: HapticsProviding = SystemHapticsProvider.shared) {
        self.repetitionIndex = repetitionIndex
        self.letterIndex = initialLetterIndex
        self.onLetterComplete = onLetterComplete
        self.onWarning = onWarning
        self.onSuccessFeedback = onSuccessFeedback
        self.onRetryFeedback = onRetryFeedback
        self.haptics = haptics
    }

    func updateEnvironment(_ environment: Environment) {
        self.environment = environment
        state.currentStrokeIndex = 0
        state.lastAnalysis = nil
    }

    func updateLetterIndex(_ index: Int) {
        letterIndex = index
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if !active {
            cancelPreviewAnimation()
        }
    }

    func reset(to phase: Phase, clearDrawing: Bool) {
        cancelPreviewAnimation()
        let previousPhase = state.phase
        state.phase = phase
        state.drawing = PKDrawing()
        if clearDrawing {
            state.frozenDrawing = PKDrawing()
        }
        state.warningMessage = nil
        state.currentStrokeIndex = 0
        state.lastWarningTime = nil
        state.completedCheckpointCount = 0
        state.completedStrokeCount = 0
        state.didCompleteCurrentLetter = false
        state.previewStrokeProgress = []
        state.previewAnimationGeneration &+= 1
        state.activeStrokeSamples = []
        state.lastIgnoreReason = nil
        state.loggedEmptyReset = false
        state.skipNextEmptyReset = phase == .writing
        state.lastAnalysis = nil
        if clearDrawing {
            state.completedLetterIndices = []
        }

        practiceDebugLog("Row \(repetitionIndex) phase \(previousPhase) -> \(phase)")
    }

    func startPreviewIfNeeded() {
        guard isActive else { return }
        guard state.phase == .previewing else {
            state.previewStrokeProgress = []
            return
        }
        guard let segment = environment?.segment, !segment.strokes.isEmpty else {
            state.previewStrokeProgress = []
            state.phase = .writing
            state.skipNextEmptyReset = true
            practiceDebugLog("Row \(repetitionIndex) has no strokes; switching directly to writing")
            return
        }

        cancelPreviewAnimation()
        state.previewAnimationGeneration &+= 1
        let generation = state.previewAnimationGeneration
        state.previewStrokeProgress = Array(repeating: 0, count: segment.strokes.count)

        let secondsPerPoint: Double = 0.002
        let minimumDuration: Double = 0.45
        let maximumDuration: Double = 1.35
        let gapDuration: Double = 0.15
        var cumulativeDelay: Double = 0
        var completionDelay: Double = 0

        for (index, stroke) in segment.strokes.enumerated() {
            let rawDuration = Double(stroke.length) * secondsPerPoint
            let duration = max(minimumDuration,
                               min(maximumDuration, rawDuration.isFinite ? rawDuration : minimumDuration))
            let localDelay = cumulativeDelay
            completionDelay = localDelay + duration

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard generation == self.state.previewAnimationGeneration else { return }
                withAnimation(.linear(duration: duration)) {
                    if index < self.state.previewStrokeProgress.count {
                        self.state.previewStrokeProgress[index] = 1
                    }
                }
            }
            previewWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + localDelay, execute: workItem)
            cumulativeDelay += duration + gapDuration
        }

        let completionItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard generation == self.state.previewAnimationGeneration else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.state.previewStrokeProgress = []
            }
            self.state.phase = .writing
            self.state.skipNextEmptyReset = true
            practiceDebugLog("Preview finished -> row \(self.repetitionIndex) now writing")
        }
        previewWorkItems.append(completionItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay + 0.05, execute: completionItem)
    }

    func cancelPreviewAnimation() {
        state.previewAnimationGeneration &+= 1
        state.previewStrokeProgress = []
        previewWorkItems.forEach { $0.cancel() }
        previewWorkItems.removeAll()
    }

    func setDrawingSnapshot(_ drawing: PKDrawing) {
        state.drawing = drawing
    }

    func handleLiveStrokeSample(_ sample: CanvasStrokeSample) {
        var samples = state.activeStrokeSamples
        if let last = samples.last,
           last.timestamp == sample.timestamp,
           last.location == sample.location {
            return
        }
        samples.append(sample)
        state.activeStrokeSamples = samples
        handleDrawingChange(state.drawing)
    }

    func handleLiveStrokeDidEnd() {
        state.activeStrokeSamples.removeAll()
        handleDrawingChange(state.drawing)
    }

    func handleDrawingChange(_ updated: PKDrawing) {
        guard state.phase == .writing else {
            if state.phase == .previewing {
                state.drawing = PKDrawing()
            }
            logIgnoredInput(reason: "phase=\(state.phase)")
            return
        }

        guard isActive else {
            logIgnoredInput(reason: "inactive")
            return
        }

        guard let environment else {
            practiceDebugLog("Row \(repetitionIndex) missing environment; resetting")
            reset(to: .writing, clearDrawing: false)
            return
        }

        guard let segment = environment.segment else {
            practiceDebugLog("Row \(repetitionIndex) missing segment; resetting")
            reset(to: .writing, clearDrawing: false)
            return
        }

        state.lastIgnoreReason = nil
        state.drawing = updated

        if updated.strokes.isEmpty && state.activeStrokeSamples.isEmpty {
            if state.skipNextEmptyReset {
                state.skipNextEmptyReset = false
                return
            }
            if !state.loggedEmptyReset {
                practiceDebugLog("Row \(repetitionIndex) reset because drawing is empty")
                state.loggedEmptyReset = true
            }
            reset(to: .writing, clearDrawing: false)
            return
        }
        state.loggedEmptyReset = false
        state.skipNextEmptyReset = false

        let config = validationConfiguration(for: environment.metrics, difficulty: environment.difficulty)
        let template = makeTraceTemplate(for: segment)
        let usesPrecomputedPlan = abs(config.checkpointLength - WordLayout.checkpointLength) < .ulpOfOne &&
            abs(config.spacingLength - WordLayout.checkpointSpacing) < .ulpOfOne
        let precomputedPlan = usesPrecomputedPlan ? segment.checkpointPlan : nil
        let liveSamples = state.activeStrokeSamples.map {
            CheckpointValidator.LiveSample(location: $0.location, timestamp: $0.timestamp)
        }
        let analysis = CheckpointValidator.evaluate(drawing: updated,
                                                    template: template,
                                                    configuration: config,
                                                    liveStrokeSamples: liveSamples,
                                                    precomputedPlan: precomputedPlan)
        state.lastAnalysis = analysis

        let completedCheckpointCount = analysis.completedCheckpointCount
        if completedCheckpointCount > state.completedCheckpointCount {
            state.completedCheckpointCount = completedCheckpointCount
            triggerSoftSuccessIfNeeded()
        } else if completedCheckpointCount < state.completedCheckpointCount {
            state.completedCheckpointCount = completedCheckpointCount
        }

        if let failure = analysis.failure {
            restartRow()
            presentFailure(failure)
            practiceDebugLog("Row \(repetitionIndex) failure -> \(failure)")
            return
        }

        state.warningMessage = nil

        let completedStrokes = segment.completedStrokeCount(using: analysis.checkpointStatuses)
        if completedStrokes > state.completedStrokeCount {
            onSuccessFeedback()
            state.completedStrokeCount = completedStrokes
            triggerSuccessHaptic()
        } else if completedStrokes < state.completedStrokeCount {
            state.completedStrokeCount = completedStrokes
        }

        state.currentStrokeIndex = segment.firstIncompleteStrokeIndex(using: analysis.checkpointStatuses) ?? segment.strokes.count

        if analysis.isComplete && !state.didCompleteCurrentLetter {
            state.didCompleteCurrentLetter = true
            practiceDebugLog("Row \(repetitionIndex) completed letter")
            completeRow()
        } else if !analysis.isComplete {
            state.didCompleteCurrentLetter = false
        }
    }

    private func restartRow() {
        reset(to: .writing, clearDrawing: false)
        practiceDebugLog("restartRow -> \(repetitionIndex)")
    }

    private func completeRow() {
        state.frozenDrawing = state.frozenDrawing.appending(state.drawing)
        reset(to: .frozen, clearDrawing: false)
        triggerSuccessHaptic()
        state.completedLetterIndices.insert(letterIndex)
        onLetterComplete()
    }

    private func presentFailure(_ failure: CheckpointValidator.FailureReason) {
        let message: String
        switch failure {
        case .outOfOrder:
            message = "Hit the checkpoints in order"
        default:
            message = "Keep following the path"
        }
        showWarning(message)
    }

    private func showWarning(_ message: String) {
        onWarning()
        onRetryFeedback()
        practiceDebugLog("showWarning row \(repetitionIndex): \(message)")
        state.warningMessage = message
        let now = Date()
        let shouldThrottle = state.lastWarningTime.map { now.timeIntervalSince($0) < warningCooldown } ?? false
        if !shouldThrottle {
            state.lastWarningTime = now
            triggerWarningHaptic()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.state.warningMessage = nil
            }
        }
    }

    private func logIgnoredInput(reason: String) {
        if state.lastIgnoreReason != reason {
            state.lastIgnoreReason = reason
            practiceDebugLog("Row \(repetitionIndex) ignoring input: \(reason)")
        }
    }

    private func makeTraceTemplate(for segment: WordLayout.Segment) -> StrokeTraceTemplate {
        let strokes = segment.strokes
            .sorted { $0.order < $1.order }
            .map { stroke in
                StrokeTraceTemplate.Stroke(id: stroke.id,
                                           order: stroke.order,
                                           points: stroke.points,
                                           startPoint: stroke.startPoint,
                                           endPoint: stroke.endPoint)
            }
        return StrokeTraceTemplate(strokes: strokes)
    }

    private func validationConfiguration(for metrics: PracticeCanvasMetrics,
                                         difficulty: PracticeDifficulty) -> CheckpointValidator.Configuration {
        let profile = difficulty.profile
        return profile.validationConfiguration(rowHeight: metrics.rowMetrics.ascender,
                                               visualStartRadius: metrics.startDotSize / 2,
                                               userInkWidth: metrics.userInkWidth)
    }

    private var warningCooldown: TimeInterval {
        environment?.difficulty.profile.warningCooldown ?? 1.5
    }

    private var hapticStyle: PracticeDifficultyProfile.HapticStyle {
        environment?.difficulty.profile.hapticStyle ?? .none
    }

    private func triggerWarningHaptic() {
        guard environment?.hapticsEnabled == true else { return }
        switch hapticStyle {
        case .none:
            break
        case .soft:
            haptics.notice(intensity: 0.75)
        case .warning:
            haptics.warning()
        }
    }

    private func triggerSoftSuccessIfNeeded() {
        guard environment?.hapticsEnabled == true else { return }
        switch hapticStyle {
        case .none:
            break
        case .soft, .warning:
            haptics.notice(intensity: 0.75)
        }
    }

    private func triggerSuccessHaptic() {
        guard environment?.hapticsEnabled == true else { return }
        switch hapticStyle {
        case .none:
            break
        case .soft, .warning:
            haptics.success()
        }
    }
}
