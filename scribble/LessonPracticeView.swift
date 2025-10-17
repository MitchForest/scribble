import SwiftUI
import PencilKit
import Foundation

struct LessonPracticeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var activeDialog: QuickDialog?
    @State private var dialogInitialTab: ProfileQuickActionsDialog.Tab = .today
    @State private var currentIndex: Int
    @State private var boardKey = UUID()
    @State private var boardDirection: BoardTransitionDirection = .forward
    @State private var clearToken = 0

    private let lessons: [PracticeLesson]

    init(lesson: PracticeLesson) {
        let unit = PracticeLessonLibrary.unit(for: lesson.unitId)
        let ordered = unit?.lessons.sorted(by: { $0.order < $1.order }) ?? [lesson]
        self.lessons = ordered
        let startIndex = ordered.firstIndex(where: { $0.id == lesson.id }) ?? 0
        _currentIndex = State(initialValue: startIndex)
    }

    private enum BoardTransitionDirection {
        case forward
        case backward
    }

    private var currentLesson: PracticeLesson {
        lessons[currentIndex]
    }

    private var nextLessonIndex: Int {
        guard !lessons.isEmpty else { return 0 }
        return (currentIndex + 1) % lessons.count
    }

    private var hasMultipleLessons: Bool {
        lessons.count > 1
    }

    private var canNavigateBackward: Bool {
        currentIndex > 0
    }

    private var canNavigateForward: Bool {
        guard lessons.count > 0 else { return false }
        return currentIndex < lessons.count - 1
    }

    private var boardTransition: AnyTransition {
        switch boardDirection {
        case .forward:
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity))
        case .backward:
            return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var streak: Int {
        dataStore.currentStreak()
    }

    var body: some View {
        ZStack {
            PracticeBackground()
            VStack(alignment: .leading, spacing: 24) {
                header
                lessonBoard
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if let dialog = activeDialog {
                DialogOverlay {
                    dialogView(for: dialog)
                } onDismiss: {
                    closeDialog()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeDialog)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Scribble")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.24, green: 0.33, blue: 0.57))
            }
            Spacer()
            LessonNavigationDock(canGoBackward: canNavigateBackward,
                                 canGoForward: canNavigateForward,
                                 onBackward: navigateToPreviousLesson,
                                 onClear: clearCurrentLessonProgress,
                                 onForward: navigateToNextLesson)
            Spacer(minLength: 16)
            HStack(spacing: 16) {
                StreakBadge(streak: streak) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dialogInitialTab = .streak
                        activeDialog = .profile
                    }
                }
                ProfileMenuButton(seed: dataStore.profile.avatarSeed,
                                  progress: dataStore.dailyProgressRatio(),
                                  onOpen: {
                                      withAnimation(.easeInOut(duration: 0.25)) {
                                          dialogInitialTab = .today
                                          activeDialog = .profile
                                      }
                                  })
            }
        }
    }

    private var lessonBoard: some View {
        ZStack {
            LessonPracticeBoard(lesson: currentLesson,
                                settings: dataStore.settings,
                                allowFingerInput: dataStore.settings.inputPreference.allowsFingerInput,
                                clearTrigger: clearToken,
                                onLetterAward: { award in
                                    recordLetterXP(for: award)
                                },
                                onProgressChanged: { completed, total in
                                    dataStore.updateLessonProgress(for: currentLesson,
                                                                   completedLetters: completed,
                                                                   totalLetters: total)
                                },
                                onLessonComplete: {
                                    advanceToNextLesson()
                                })
            .id(boardKey)
            .transition(boardTransition)
        }
        .animation(.easeInOut(duration: 0.45), value: boardKey)
    }

    private func navigateToLesson(at index: Int,
                                  direction: BoardTransitionDirection,
                                  animated: Bool = true) {
        guard lessons.indices.contains(index) else { return }
        boardDirection = direction
        let updates = {
            currentIndex = index
            boardKey = UUID()
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.45)) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func navigateToPreviousLesson() {
        guard canNavigateBackward else { return }
        navigateToLesson(at: currentIndex - 1, direction: .backward)
    }

    private func navigateToNextLesson() {
        guard canNavigateForward else { return }
        navigateToLesson(at: currentIndex + 1, direction: .forward)
    }

    private func clearCurrentLessonProgress() {
        guard !lessons.isEmpty else { return }
        dataStore.resetLessonProgress(for: currentLesson)
        clearToken &+= 1
    }

    private func advanceToNextLesson() {
        guard !lessons.isEmpty else { return }
        navigateToLesson(at: nextLessonIndex, direction: .forward)
    }

    private func recordLetterXP(for letter: LetterTimelineItem) {
        guard let letterId = letter.letterId else { return }
        let multiplier: Double
        switch dataStore.settings.difficulty {
        case .beginner: multiplier = 1.4
        case .intermediate: multiplier = 1.0
        case .expert: multiplier = 0.8
        }
        let baseSeconds = 5
        let adjusted = Int(Double(baseSeconds) * multiplier)
        dataStore.addWritingSeconds(max(adjusted, 1),
                                    category: .practiceLine,
                                    letterId: letterId)
    }

    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.25)) {
            activeDialog = nil
        }
    }

    @ViewBuilder
    private func dialogView(for _: QuickDialog) -> some View {
        ProfileQuickActionsDialog(initialTab: dialogInitialTab,
                                  onClose: { closeDialog() },
                                  onExitLesson: {
                                      dismiss()
                                  })
            .environmentObject(dataStore)
    }
}

private struct StreakBadge: View {
    let streak: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.25))
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.4).opacity(0.35), radius: 8, x: 0, y: 6)
                Text("\(streak)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct LessonNavigationDock: View {
    let canGoBackward: Bool
    let canGoForward: Bool
    let onBackward: () -> Void
    let onClear: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            controlButton(systemName: "chevron.left",
                          accessibilityLabel: "Previous lesson",
                          isEnabled: canGoBackward,
                          tint: ScribbleColors.primary,
                          action: onBackward)

            controlButton(systemName: "eraser",
                          accessibilityLabel: "Clear current practice",
                          tint: ScribbleColors.accentDark,
                          background: ScribbleColors.accent.opacity(0.18),
                          action: onClear)

            controlButton(systemName: "chevron.right",
                          accessibilityLabel: "Next lesson",
                          isEnabled: canGoForward,
                          tint: ScribbleColors.primary,
                          action: onForward)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private func controlButton(systemName: String,
                               accessibilityLabel: String,
                               isEnabled: Bool = true,
                               tint: Color,
                               background: Color = Color.white.opacity(0.95),
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint.opacity(isEnabled ? 1.0 : 0.45))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(isEnabled ? background : ScribbleColors.controlDisabled.opacity(0.85))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isEnabled ? 0.65 : 0.45), lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.55)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Practice Board

private struct LessonPracticeBoard: View {
    let lesson: PracticeLesson
    let settings: UserSettings
    let allowFingerInput: Bool
    let clearTrigger: Int
    let onLetterAward: (LetterTimelineItem) -> Void
    let onProgressChanged: (Int, Int) -> Void
    let onLessonComplete: () -> Void

    @StateObject private var viewModel: FreePracticeViewModel
    @State private var feedback: FeedbackMessage?
    @State private var completionGuard = false
    @State private var resetToken = 0
    @State private var previewToken = 0


    init(lesson: PracticeLesson,
         settings: UserSettings,
         allowFingerInput: Bool,
         clearTrigger: Int,
         onLetterAward: @escaping (LetterTimelineItem) -> Void,
         onProgressChanged: @escaping (Int, Int) -> Void,
         onLessonComplete: @escaping () -> Void) {
        self.lesson = lesson
        self.settings = settings
        self.allowFingerInput = allowFingerInput
        self.clearTrigger = clearTrigger
        self.onLetterAward = onLetterAward
        self.onProgressChanged = onProgressChanged
        self.onLessonComplete = onLessonComplete
        _viewModel = StateObject(wrappedValue: FreePracticeViewModel(initialText: lesson.practiceText))
    }

    private var guidesEnabled: Bool {
        settings.prefersGuides
    }

    var body: some View {
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            let outerPadding: CGFloat = max(24 - min(safeInsets.leading, safeInsets.trailing), 18)
            let availableWidth = max(proxy.size.width - safeInsets.leading - safeInsets.trailing - outerPadding * 2, 220)
            let baseMetrics = PracticeCanvasMetrics(strokeSize: settings.difficulty.profile.strokeSize)
            let sizing = PracticeCanvasSizing.resolve(items: viewModel.timeline,
                                                      availableWidth: availableWidth,
                                                      baseMetrics: baseMetrics,
                                                      isLeftHanded: settings.isLeftHanded)
            let layout = sizing.layout
            let metrics = sizing.metrics

            ZStack(alignment: .top) {
                ZStack(alignment: .topLeading) {
                    LetterPracticeCanvas(layout: layout,
                                         metrics: metrics,
                                         resetTrigger: resetToken,
                                         previewTrigger: previewToken,
                                         currentIndex: viewModel.currentLetterIndex,
                                         guidesEnabled: guidesEnabled,
                                         difficulty: settings.difficulty,
                                         hapticsEnabled: settings.hapticsEnabled,
                                         allowFingerInput: allowFingerInput,
                                         segment: layout.segments[safe: viewModel.currentLetterIndex],
                                         onWarning: {
                                             viewModel.markWarningForCurrentLetter()
                                         },
                                         onStrokeValidated: { _, _ in },
                                         onLetterComplete: {
                                             guard let letter = viewModel.currentLetter else { return }
                                             onLetterAward(letter)
                                             let lessonDone = viewModel.markLetterCompleted()
                                             onProgressChanged(viewModel.completedLetterCount,
                                                               viewModel.totalPractiseableLetters)
                                             viewModel.advanceToNextPractiseableLetter()
                                             DispatchQueue.main.async {
                                                 startPreview(resetCanvas: true, replayLetter: false)
                                             }
                                             if lessonDone {
                                                 triggerLessonCompletion()
                                             }
                                         },
                                         onSuccessFeedback: { showSuccessFeedback() },
                                         onRetryFeedback: { showRetryFeedback() })

                    if let bubble = feedback,
                       let segment = layout.segments[safe: viewModel.currentLetterIndex] {
                        let baselineY = layout.ascender
                        let bubbleYUpperBound = layout.ascender + layout.descender - 32
                        let bubbleY = min(max(baselineY - 28, 32), bubbleYUpperBound)
                        FeedbackBubbleView(message: bubble)
                            .position(x: segment.frame.midX + layout.leadingInset, y: bubbleY)
                    }
                }
                .padding(.horizontal, outerPadding)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(minHeight: 280)
        .onAppear {
            viewModel.resumeIfNeeded()
            onProgressChanged(viewModel.completedLetterCount, viewModel.totalPractiseableLetters)
            DispatchQueue.main.async {
                startPreview(resetCanvas: true, replayLetter: false)
            }
        }
        .onChange(of: viewModel.currentLetterIndex) { _, _ in
            feedback = nil
            startPreview(resetCanvas: true, replayLetter: false)
        }
        .onChange(of: viewModel.targetText) { _, _ in
            completionGuard = false
            viewModel.resetProgress()
            startPreview(resetCanvas: true, replayLetter: true)
        }
        .onChange(of: clearTrigger) { _, _ in
            handleClear()
        }
    }

    private func triggerLessonCompletion() {
        guard !completionGuard else { return }
        completionGuard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onLessonComplete()
        }
    }

    private func handleClear() {
        feedback = nil
        completionGuard = false
        viewModel.resetProgress()
        startPreview(resetCanvas: true, replayLetter: true)
        onProgressChanged(0, viewModel.totalPractiseableLetters)
    }

    private func startPreview(resetCanvas: Bool, replayLetter: Bool) {
        guard let currentSegment = viewModel.timeline[safe: viewModel.currentLetterIndex],
              currentSegment.isPractiseable else {
            if resetCanvas {
                resetToken &+= 1
            }
            previewToken &+= 1
            return
        }
        if replayLetter {
            viewModel.replay(at: viewModel.currentLetterIndex)
        }
        if resetCanvas {
            resetToken &+= 1
        }
        feedback = nil
        previewToken &+= 1
    }

    private func showSuccessFeedback() {
        showFeedback(text: FeedbackMessage.successPhrases.randomElement() ?? "Great job!",
                     color: Color(red: 0.34, green: 0.67, blue: 0.5))
    }

    private func showRetryFeedback() {
        showFeedback(text: FeedbackMessage.retryPhrases.randomElement() ?? "Try again!",
                     color: Color(red: 0.96, green: 0.53, blue: 0.32))
    }

    private func showFeedback(text: String, color: Color) {
        let message = FeedbackMessage(text: text, color: color)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            feedback = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            if feedback?.id == message.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    feedback = nil
                }
            }
        }
    }
}

// MARK: - Feedback Message

private struct FeedbackMessage: Identifiable {
    let id = UUID()
    let text: String
    let color: Color

    static let successPhrases = ["Great job!", "Awesome!", "Nice stroke!", "Super work!", "You got it!"]
    static let retryPhrases = ["Try again!", "Give it another go!", "Reset and retry!", "Almost!", "Keep practicing!"]
}

// MARK: - Practice Background

private struct PracticeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.99, blue: 1.0),
                Color(red: 0.95, green: 0.95, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Practice Canvas

private struct LetterPracticeCanvas: View {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let resetTrigger: Int
    let previewTrigger: Int
    let currentIndex: Int
    let guidesEnabled: Bool
    let difficulty: PracticeDifficulty
    let hapticsEnabled: Bool
    let allowFingerInput: Bool
    let segment: WordLayout.Segment?
    let onWarning: () -> Void
    let onStrokeValidated: (Int, Int) -> Void
    let onLetterComplete: () -> Void
    let onSuccessFeedback: () -> Void
    let onRetryFeedback: () -> Void

    @State private var drawing = PKDrawing()
    @State private var frozenDrawing = PKDrawing()
    @State private var warningMessage: String?
    @State private var currentStrokeIndex = 0
    @State private var lastWarningTime: Date?
    @State private var previousCompletedCount = 0
    @State private var previousCheckpointCount = 0
    @State private var didCompleteCurrentLetter = false
    @State private var lastAnalysis: CheckpointValidator.Result?
    @State private var activeStrokeSamples: [CanvasStrokeSample] = []
    @State private var letterCelebrationVisible = false
    @State private var letterCelebrationToken = 0
    @State private var previewStrokeProgress: [CGFloat] = []
    @State private var isPreviewing = false
    @State private var previewAnimationGeneration = 0

    private var profile: PracticeDifficultyProfile {
        difficulty.profile
    }

    private var validationConfiguration: CheckpointValidator.Configuration {
        profile.validationConfiguration(rowHeight: metrics.rowMetrics.ascender,
                                        visualStartRadius: metrics.startDotSize / 2,
                                        userInkWidth: metrics.userInkWidth)
    }

    private var warningCooldown: TimeInterval {
        profile.warningCooldown
    }

    private var hapticStyle: PracticeDifficultyProfile.HapticStyle {
        profile.hapticStyle
    }

    private var canvasHeight: CGFloat {
        metrics.canvasHeight
    }

    private var currentSegment: WordLayout.Segment? {
        segment ?? layout.segments[safe: currentIndex]
    }

    var body: some View {
        let canvasWidth = layout.width + layout.leadingInset + layout.trailingInset
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                .frame(width: canvasWidth, height: canvasHeight)

            PracticeRowGuides(width: layout.width,
                              ascender: layout.ascender,
                              descender: layout.descender,
                              scaledXHeight: layout.scaledXHeight,
                              guideLineWidth: metrics.guideLineWidth)
            .padding(.leading, layout.leadingInset)
            .padding(.trailing, layout.trailingInset)

            WordGuidesOverlay(layout: layout,
                              metrics: metrics,
                              currentIndex: currentIndex,
                              currentStrokeIndex: currentStrokeIndex,
                              guidesEnabled: guidesEnabled,
                              analysis: lastAnalysis)

            if isPreviewing,
               let previewSegment = currentSegment {
                PreviewStrokeOverlay(segment: previewSegment,
                                     progress: previewStrokeProgress,
                                     lineWidth: previewSegment.lineWidth)
                    .padding(.leading, layout.leadingInset)
                    .padding(.trailing, layout.trailingInset)
            }

            StaticDrawingView(drawing: frozenDrawing)
                .allowsHitTesting(false)
                .frame(width: canvasWidth, height: canvasHeight)

            PencilCanvasView(drawing: $drawing,
                             onDrawingChanged: { updated in
                                 processDrawingChange(updated, activeSamples: activeStrokeSamples)
                             },
                             onLiveStrokeSample: { sample in
                                 if let last = activeStrokeSamples.last,
                                    last.timestamp == sample.timestamp,
                                    last.location == sample.location {
                                     return
                                  }
                                  activeStrokeSamples.append(sample)
                                  processDrawingChange(drawing, activeSamples: activeStrokeSamples)
                              },
                              onLiveStrokeDidEnd: {
                                  activeStrokeSamples.removeAll()
                                  processDrawingChange(drawing, activeSamples: activeStrokeSamples)
                              },
                              allowFingerFallback: allowFingerInput,
                              lineWidth: validationConfiguration.studentLineWidth)
                .allowsHitTesting(!isPreviewing)
                .padding(.horizontal, 0)
                .frame(width: canvasWidth, height: canvasHeight)

            if let warningMessage {
                VStack {
                    Spacer(minLength: 0)
                    Text(warningMessage)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, max(metrics.rowMetrics.ascender * 0.2, 12))
                        .transition(.opacity)
                }
                .frame(width: canvasWidth, height: canvasHeight)
            }

            if letterCelebrationVisible {
                LetterCelebrationOverlay()
                    .frame(width: canvasWidth, height: canvasHeight)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: canvasWidth, height: canvasHeight, alignment: .topLeading)
        .padding(.vertical, 6)
        .onChange(of: layout.cacheKey) { _, _ in
            DispatchQueue.main.async {
                resetCanvas()
            }
        }
        .onChange(of: currentIndex) { _, _ in
            DispatchQueue.main.async {
                drawing = PKDrawing()
                currentStrokeIndex = 0
                previousCompletedCount = 0
                didCompleteCurrentLetter = false
                warningMessage = nil
                lastAnalysis = nil
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            DispatchQueue.main.async {
                restartCurrentAttempt(clearCompleted: true)
            }
        }
        .onChange(of: previewTrigger) { _, _ in
            DispatchQueue.main.async {
                startPreviewAnimation()
            }
        }
    }

    private func resetCanvas() {
        cancelPreview()
        drawing = PKDrawing()
        frozenDrawing = PKDrawing()
        warningMessage = nil
        currentStrokeIndex = 0
        lastWarningTime = nil
        previousCompletedCount = 0
        previousCheckpointCount = 0
        didCompleteCurrentLetter = false
        lastAnalysis = nil
        activeStrokeSamples = []
        letterCelebrationVisible = false
        letterCelebrationToken &+= 1
    }

    private func restartCurrentAttempt(clearCompleted: Bool = false) {
        cancelPreview()
        drawing = PKDrawing()
        if clearCompleted {
            frozenDrawing = PKDrawing()
        }
        warningMessage = nil
        currentStrokeIndex = 0
        lastWarningTime = nil
        previousCompletedCount = 0
        previousCheckpointCount = 0
        didCompleteCurrentLetter = false
        lastAnalysis = nil
        activeStrokeSamples = []
        letterCelebrationVisible = false
        letterCelebrationToken &+= 1
    }

    private func startPreviewAnimation() {
        previewAnimationGeneration &+= 1
        let generation = previewAnimationGeneration
        previewStrokeProgress = []
        isPreviewing = false

        guard let segment = currentSegment,
              !segment.strokes.isEmpty else {
            return
        }

        isPreviewing = true
        previewStrokeProgress = Array(repeating: 0, count: segment.strokes.count)

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

            DispatchQueue.main.asyncAfter(deadline: .now() + localDelay) {
                guard generation == previewAnimationGeneration else { return }
                withAnimation(.linear(duration: duration)) {
                    if index < previewStrokeProgress.count {
                        previewStrokeProgress[index] = 1
                    }
                }
            }

            cumulativeDelay += duration + gapDuration
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay + 0.05) {
            guard generation == previewAnimationGeneration else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isPreviewing = false
            }
            previewStrokeProgress = []
        }
    }

    private func cancelPreview() {
        previewAnimationGeneration &+= 1
        previewStrokeProgress = []
        isPreviewing = false
    }

    private func processDrawingChange(_ updated: PKDrawing,
                                      activeSamples: [CanvasStrokeSample] = []) {
        if isPreviewing {
            drawing = PKDrawing()
            return
        }

        guard let segment = currentSegment else {
            drawing = PKDrawing()
            currentStrokeIndex = 0
            previousCompletedCount = 0
            previousCheckpointCount = 0
            didCompleteCurrentLetter = false
            warningMessage = nil
            activeStrokeSamples = []
            letterCelebrationVisible = false
            letterCelebrationToken &+= 1
            return
        }

        drawing = updated

        if updated.strokes.isEmpty && activeSamples.isEmpty {
            currentStrokeIndex = 0
            previousCompletedCount = 0
            previousCheckpointCount = 0
            didCompleteCurrentLetter = false
            warningMessage = nil
            lastAnalysis = nil
            letterCelebrationVisible = false
            letterCelebrationToken &+= 1
            return
        }

        let template = makeTraceTemplate(for: segment)
        let usesPrecomputedPlan = abs(validationConfiguration.checkpointLength - WordLayout.checkpointLength) < .ulpOfOne &&
            abs(validationConfiguration.spacingLength - WordLayout.checkpointSpacing) < .ulpOfOne
        let precomputedPlan = usesPrecomputedPlan ? segment.checkpointPlan : nil
        let liveSamples = activeSamples.map {
            CheckpointValidator.LiveSample(location: $0.location, timestamp: $0.timestamp)
        }
        let analysis = CheckpointValidator.evaluate(drawing: updated,
                                                    template: template,
                                                    configuration: validationConfiguration,
                                                    liveStrokeSamples: liveSamples,
                                                    precomputedPlan: precomputedPlan)
        lastAnalysis = analysis

#if DEBUG
        print("segment index: \(segment.index) checkpoints: \(analysis.totalCheckpointCount) next: \(analysis.activeCheckpointIndex)")
#endif

        let completedCheckpointCount = analysis.completedCheckpointCount
        if completedCheckpointCount > previousCheckpointCount {
            if hapticsEnabled {
                switch hapticStyle {
                case .none:
                    break
                case .soft, .warning:
                    HapticsManager.shared.notice()
                }
            }
            previousCheckpointCount = completedCheckpointCount
        } else if completedCheckpointCount < previousCheckpointCount {
            previousCheckpointCount = completedCheckpointCount
        }

        #if DEBUG
        print(
            """
            validator checkpoints \(analysis.completedCheckpointCount)/\(analysis.totalCheckpointCount) \
            next:\(analysis.activeCheckpointIndex) \
            failure:\(String(describing: analysis.failure))
            """
        )
        #endif

        if let failure = analysis.failure {
            restartCurrentAttempt()
            presentFailure(failure)
            return
        }

        warningMessage = nil

        let completedStrokes = segment.completedStrokeCount(using: analysis.checkpointStatuses)

        if completedStrokes > previousCompletedCount {
            for index in previousCompletedCount..<completedStrokes {
                onStrokeValidated(index, segment.strokes.count)
            }
            previousCompletedCount = completedStrokes
            if hapticsEnabled {
                HapticsManager.shared.success()
            }
            onSuccessFeedback()
        } else if completedStrokes < previousCompletedCount {
            previousCompletedCount = completedStrokes
        }

        currentStrokeIndex = segment.firstIncompleteStrokeIndex(using: analysis.checkpointStatuses) ?? segment.strokes.count

        let isComplete = analysis.isComplete

        if isComplete && !didCompleteCurrentLetter {
            didCompleteCurrentLetter = true
            completeLetter()
        } else if !isComplete {
            didCompleteCurrentLetter = false
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
        warningMessage = message
        let now = Date()
        let shouldThrottle = lastWarningTime.map { now.timeIntervalSince($0) < warningCooldown } ?? false
        if !shouldThrottle {
            lastWarningTime = now
            if hapticsEnabled {
                sendWarningHaptic()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                warningMessage = nil
            }
        }
    }

    private func sendWarningHaptic() {
        switch hapticStyle {
        case .none:
            break
        case .soft:
            HapticsManager.shared.notice()
        case .warning:
            HapticsManager.shared.warning()
        }
    }

    // Advance to the next letter without animating the canvas itself.
    // The parent view is responsible for any set-level transition once all letters finish.
    private func completeLetter() {
        if hapticsEnabled {
            HapticsManager.shared.success()
        }
        frozenDrawing = frozenDrawing.appending(drawing)
        drawing = PKDrawing()
        currentStrokeIndex = 0
        previousCompletedCount = 0
        previousCheckpointCount = 0
        didCompleteCurrentLetter = false
        warningMessage = nil
        lastWarningTime = nil
        lastAnalysis = nil
        letterCelebrationToken &+= 1
        let celebrationToken = letterCelebrationToken
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            letterCelebrationVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [celebrationToken] in
            guard celebrationToken == letterCelebrationToken else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                letterCelebrationVisible = false
            }
        }
        onSuccessFeedback()
        onLetterComplete()
    }

}

private struct LetterCelebrationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.66, blue: 0.46))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
                Text("Letter Complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
        }
    }
}

private struct PreviewStrokeOverlay: View {
    let segment: WordLayout.Segment
    let progress: [CGFloat]
    let lineWidth: CGFloat

    private let previewColor = Color(red: 0.32, green: 0.52, blue: 0.98)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { index, stroke in
                let amount = index < progress.count ? progress[index] : 0
                stroke.path
                    .trim(from: 0, to: amount)
                    .stroke(previewColor,
                            style: StrokeStyle(lineWidth: lineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
        .drawingGroup()
    }
}

private struct WordGuidesOverlay: View {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let currentIndex: Int
    let currentStrokeIndex: Int
    let guidesEnabled: Bool
    let analysis: CheckpointValidator.Result?

    private let completedColor = Color(red: 0.35, green: 0.62, blue: 0.48)
    private let activeColor = Color(red: 0.21, green: 0.41, blue: 0.88)
    private let gradientColor = Color(red: 0.29, green: 0.49, blue: 0.86)
    private let dormantColor = Color(red: 0.72, green: 0.82, blue: 0.94)
    private let cautionColor = Color(red: 0.93, green: 0.43, blue: 0.39)

    private let guidanceDepth = 10

    #if DEBUG
    private static let showCorridorDebug = false
    #else
    private static let showCorridorDebug = false
    #endif

    private var completedCheckpointSet: Set<Int> {
        guard let analysis else { return [] }
        return Set(analysis.checkpointStatuses.filter { $0.completed }.map { $0.globalIndex })
    }

    private var activeCheckpointIndex: Int? {
        guard let analysis, analysis.totalCheckpointCount > 0 else { return nil }
        let clamped = min(max(analysis.activeCheckpointIndex, 0), analysis.totalCheckpointCount - 1)
        return clamped
    }

    @ViewBuilder
    var body: some View {
        if guidesEnabled {
            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.segments.enumerated()), id: \.1.id) { index, segment in
                    if !segment.strokes.isEmpty {
                        drawSegment(segment,
                                    at: index,
                                    isCurrent: index == currentIndex,
                                    isCompleted: index < currentIndex)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    private func drawSegment(_ segment: WordLayout.Segment,
                             at index: Int,
                             isCurrent: Bool,
                             isCompleted: Bool) -> some View {
        let activeStroke = isCurrent && currentStrokeIndex < segment.strokes.count ? currentStrokeIndex : nil

        return ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { strokeIndex, stroke in
            ZStack(alignment: .topLeading) {
                if isCompleted {
                    stroke.path
                        .stroke(completedColor,
                                style: StrokeStyle(lineWidth: metrics.guideLineWidth * 0.95,
                                                   lineCap: .round,
                                                   lineJoin: .round))
                } else {
                    let baseDash: [CGFloat] = isCurrent ? [] : [6, 8]
                    let baseOpacity = isCurrent ? 0.12 : 0.22
                    stroke.path
                        .stroke(dormantColor.opacity(baseOpacity),
                                style: StrokeStyle(lineWidth: metrics.guideLineWidth,
                                                   lineCap: .round,
                                                   lineJoin: .round,
                                                   dash: baseDash))

                    if isCurrent && strokeIndex == activeStroke {
                        ForEach(stroke.checkpointSegments, id: \.index) { checkpoint in
                            if let color = colorForCheckpoint(checkpoint.index) {
                                stroke.path
                                    .trimmedPath(from: checkpoint.startProgress, to: checkpoint.endProgress)
                                    .stroke(color,
                                            style: StrokeStyle(lineWidth: metrics.guideLineWidth,
                                                               lineCap: .round,
                                                               lineJoin: .round))
                            }
                        }
                    }
                }

                if Self.showCorridorDebug {
                    stroke.path
                        .stroke(Color(red: 0.23, green: 0.45, blue: 0.9).opacity(0.15),
                                style: StrokeStyle(lineWidth: metrics.practiceLineWidth,
                                                   lineCap: .round,
                                                   lineJoin: .round))
                }
            }
        }
    }

    private func colorForCheckpoint(_ index: Int) -> Color? {
        if completedCheckpointSet.contains(index) {
            return completedColor
        }

        if let analysis {
            if analysis.isComplete {
                return completedColor
            }

            let activeIndex = activeCheckpointIndex ?? 0

            if index == activeIndex {
                return activeColor.opacity(0.95)
            }

            if index < activeIndex {
                return cautionColor.opacity(0.75)
            }

            let offset = index - activeIndex
            if offset <= guidanceDepth {
                let startOpacity: Double = 0.9
                let endOpacity: Double = 0.12
                let fraction = Double(offset) / Double(max(guidanceDepth, 1))
                let opacity = startOpacity + (endOpacity - startOpacity) * fraction
                return gradientColor.opacity(opacity)
            }

            return nil
        } else {
            if index == 0 {
                return activeColor.opacity(0.95)
            }
            if index <= guidanceDepth {
                let fraction = Double(index) / Double(max(guidanceDepth, 1))
                let opacity = 0.9 + (0.12 - 0.9) * fraction
                return gradientColor.opacity(opacity)
            }
            return nil
        }
    }
}

private struct WordLayout {
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
                let minX = descriptor.minX
                let segmentFrame = CGRect(x: cursor,
                                          y: 0,
                                          width: segmentWidth,
                                          height: totalHeight)
                var unionBounds: CGRect?
                struct StrokeBlueprint {
                    let id: String
                    let order: Int
                    let path: Path
                    let points: [CGPoint]
                    let startPoint: CGPoint
                    let endPoint: CGPoint
                }
                var blueprints: [StrokeBlueprint] = []

                for stroke in descriptor.strokes {
                    let convertedPoints = stroke.points.map { point in
                        WordLayout.convert(point: point,
                                           minX: minX,
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
                                                        minX: minX,
                                                        horizontalScale: horizontalScale,
                                                        ascenderScale: descriptor.ascenderScale,
                                                        descenderScale: descriptor.descenderScale,
                                                        cursor: cursor,
                                                        ascender: rowAscender,
                                                        baseline: descriptor.baseline,
                                                        isLeftHanded: isLeftHanded,
                                                        segmentWidth: segmentWidth)
                    let endPoint = WordLayout.convert(point: stroke.end ?? stroke.points.last ?? .zero,
                                                      minX: minX,
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
                                        frame: segmentFrame,
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
}

private extension WordLayout.Segment {
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

private struct FeedbackBubbleView: View {
    let message: FeedbackMessage
    @State private var floatUp = false
    @State private var fadeOut = false

    var body: some View {
        Text(message.text)
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(message.color)
                    .shadow(color: message.color.opacity(0.25), radius: 12, x: 0, y: 6)
            )
            .offset(y: floatUp ? -120 : -80)
            .opacity(fadeOut ? 0 : 1)
            .scaleEffect(floatUp ? 1 : 0.85)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    floatUp = true
                }
                withAnimation(.easeInOut(duration: 0.4).delay(0.9)) {
                    fadeOut = true
                }
            }
    }
}

private struct StaticDrawingView: UIViewRepresentable {
    var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.drawing = drawing
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }
}

private extension PKDrawing {
    func appending(_ other: PKDrawing) -> PKDrawing {
        PKDrawing(strokes: strokes + other.strokes)
    }
}

private struct PracticeCanvasSizing {
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

private struct PracticeCanvasMetrics {
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
        case .large: return 110
        case .standard: return 90
        case .compact: return 70
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
