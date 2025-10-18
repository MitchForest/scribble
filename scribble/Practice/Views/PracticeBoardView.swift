import SwiftUI
import Foundation

struct PracticeBoardView: View {
    let lesson: PracticeLesson
    let settings: UserSettings
    let allowFingerInput: Bool
    let clearTrigger: Int
    let onLetterAward: (LetterTimelineItem) -> Void
    let onProgressChanged: (Int, Int) -> Void
    let onLessonComplete: () -> Void

    @StateObject private var timelineViewModel: FreePracticeViewModel
    @StateObject private var sessionViewModel: LessonPracticeViewModel

    @State private var rowViewModels: [PracticeRowViewModel] = []
    @State private var feedback: FeedbackMessage?
    @State private var completionGuard = false
    @State private var pendingResetWorkItem: DispatchWorkItem?
    @State private var activePracticeRow = 0
    @State private var lastLayout: WordLayout?
    @State private var lastMetrics: PracticeCanvasMetrics?
    @State private var needsInitialReset = true

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

        let timelineViewModel = FreePracticeViewModel(initialText: lesson.practiceText)
        _timelineViewModel = StateObject(wrappedValue: timelineViewModel)

        let controller = PracticeSessionController(lesson: lesson,
                                                   settings: settings,
                                                   timeline: timelineViewModel.timelineSnapshot,
                                                   repetitions: LetterPracticeCanvas.repetitionCount)
        _sessionViewModel = StateObject(wrappedValue: LessonPracticeViewModel(controller: controller))
    }

    private var guidesEnabled: Bool { settings.prefersGuides }

    private var sessionState: PracticeSessionController.State { sessionViewModel.sessionState }

    private var sessionTimeline: [LetterTimelineItem] { sessionState.timeline.items }

    private var currentLetter: LetterTimelineItem? {
        sessionTimeline[safe: sessionState.activeLetterGlobalIndex]
    }

    var body: some View {
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            let outerPadding: CGFloat = max(24 - min(safeInsets.leading, safeInsets.trailing), 18)
            let availableWidth = max(proxy.size.width - safeInsets.leading - safeInsets.trailing - outerPadding * 2, 220)
            let baseMetrics = PracticeCanvasMetrics(strokeSize: settings.difficulty.profile.strokeSize)
            let sizing = PracticeCanvasSizing.resolve(items: sessionTimeline,
                                                      availableWidth: availableWidth,
                                                      baseMetrics: baseMetrics,
                                                      isLeftHanded: settings.isLeftHanded)
            let layout = sizing.layout
            let metrics = sizing.metrics

            ZStack(alignment: .top) {
                ZStack(alignment: .topLeading) {
                    if !rowViewModels.isEmpty {
                        LetterPracticeCanvas(layout: layout,
                                             metrics: metrics,
                                             rowViewModels: rowViewModels,
                                             guidesEnabled: guidesEnabled,
                                             allowFingerInput: allowFingerInput,
                                             activeLetterIndex: sessionState.activeLetterGlobalIndex)
                        .onAppear {
                            handleCanvasLayoutChange(layout: layout, metrics: metrics, shouldReset: needsInitialReset)
                        }
                        .onChange(of: layout.cacheKey) { _ in
                            handleCanvasLayoutChange(layout: layout, metrics: metrics, shouldReset: true)
                        }
                    }

                    if let bubble = feedback,
                       let segment = layout.segments[safe: sessionState.activeLetterGlobalIndex] {
                        let baselineY = layout.ascender
                        let bubbleYUpperBound = layout.ascender + layout.descender - 32
                        let bubbleY = min(max(baselineY - 28, 32), bubbleYUpperBound)
                        let rowHeight = metrics.canvasHeight
                        let baseRowSpan = metrics.rowMetrics.ascender + metrics.rowMetrics.descender
                        let rowSpacing = max(baseRowSpan * 0.18, metrics.practiceLineWidth * 2)
                        let rowOffset = CGFloat(activePracticeRow) * (rowHeight + rowSpacing)
                        FeedbackBubbleView(message: bubble)
                            .position(x: segment.frame.midX + layout.leadingInset,
                                      y: bubbleY + rowOffset)
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
            initializeRowViewModelsIfNeeded()
            sessionViewModel.handle(event: .start)
            updateProgress(using: sessionState)
            synchronizeRows(with: sessionState)
        }
        .onChange(of: timelineViewModel.targetText) { _, _ in
            handleTargetTextChange()
        }
        .onChange(of: clearTrigger) { _, _ in
            handleClear()
        }
        .onReceive(sessionViewModel.$sessionState) { state in
            synchronizeRows(with: state)
            updateProgress(using: state)
        }
    }

    private func handleCanvasLayoutChange(layout: WordLayout,
                                          metrics: PracticeCanvasMetrics,
                                          shouldReset: Bool) {
        lastLayout = layout
        lastMetrics = metrics
        applyEnvironment(layout: layout, metrics: metrics)
        if shouldReset {
            resetRows(replayLetter: false, delayed: false, clearCompletedRows: true)
            needsInitialReset = false
        }
    }

    private func initializeRowViewModelsIfNeeded() {
        guard rowViewModels.isEmpty else { return }
        let initialLetterIndex = sessionState.activeLetterGlobalIndex
        rowViewModels = (0..<LetterPracticeCanvas.repetitionCount).map { repetition in
            PracticeRowViewModel(repetitionIndex: repetition,
                                 initialLetterIndex: initialLetterIndex,
                                 onLetterComplete: { handleRowCompletion(repetition: repetition) },
                                 onWarning: { },
                                 onSuccessFeedback: { showSuccessFeedback() },
                                 onRetryFeedback: { showRetryFeedback() })
        }
    }

    private func handleTargetTextChange() {
        completionGuard = false
        needsInitialReset = true
        timelineViewModel.rebuildTimeline()
        let updatedTimeline = timelineViewModel.timelineSnapshot
        sessionViewModel.handle(event: .updateTimeline(updatedTimeline))
        resetRows(replayLetter: true, delayed: true, clearCompletedRows: true)
    }

    private func handleClear() {
        feedback = nil
        completionGuard = false
        sessionViewModel.handle(event: .clearAll)
        resetRows(replayLetter: true, delayed: false, clearCompletedRows: true)
        updateProgress(using: sessionViewModel.sessionState)
    }

    private func handleRowCompletion(repetition: Int) {
        let previousState = sessionState
        let activeIndex = previousState.activeLetterGlobalIndex
        guard let letter = currentLetter ?? sessionTimeline[safe: activeIndex] else { return }

        onLetterAward(letter)
        sessionViewModel.handle(event: .letterCompleted(repetition: repetition, letterIndex: activeIndex))
        DispatchQueue.main.async {
            let updatedState = sessionViewModel.sessionState
            let repetitionChanged = updatedState.activeRepetitionIndex != previousState.activeRepetitionIndex
            let letterChanged = updatedState.activeLetterGlobalIndex != previousState.activeLetterGlobalIndex

            if repetitionChanged {
                resetRows(replayLetter: false,
                          delayed: false,
                          clearCompletedRows: !letterChanged)
            }

            if letterChanged {
                resetRows(replayLetter: false,
                          delayed: false,
                          clearCompletedRows: true)
            }

            updateProgress(using: updatedState)

            if isSessionComplete(updatedState) {
                triggerLessonCompletion()
            }
        }
    }

    private func applyEnvironment(layout: WordLayout, metrics: PracticeCanvasMetrics) {
        guard !rowViewModels.isEmpty else { return }
        let letterIndex = sessionState.activeLetterGlobalIndex
        let environment = PracticeRowViewModel.Environment(segment: layout.segments[safe: letterIndex],
                                                           metrics: metrics,
                                                           difficulty: settings.difficulty,
                                                           hapticsEnabled: settings.hapticsEnabled)
        rowViewModels.forEach { $0.updateEnvironment(environment) }
    }

    private func synchronizeRows(with state: PracticeSessionController.State) {
        guard !rowViewModels.isEmpty else { return }
        activePracticeRow = state.activeRepetitionIndex
        for (index, row) in rowViewModels.enumerated() {
            row.updateLetterIndex(state.activeLetterGlobalIndex)
            row.setActive(index == state.activeRepetitionIndex)
        }
        if let layout = lastLayout, let metrics = lastMetrics {
            applyEnvironment(layout: layout, metrics: metrics)
        }
        if rowViewModels.indices.contains(state.activeRepetitionIndex) {
            rowViewModels[state.activeRepetitionIndex].startPreviewIfNeeded()
        }
    }

    private func resetRows(replayLetter: Bool,
                           delayed: Bool,
                           clearCompletedRows: Bool) {
        guard !rowViewModels.isEmpty else { return }
        guard let layout = lastLayout, let metrics = lastMetrics else { return }

        pendingResetWorkItem?.cancel()
        feedback = nil

        let performReset: () -> Void = {
            var targetLetterIndex = sessionViewModel.sessionState.activeLetterGlobalIndex
            if replayLetter,
               let segment = layout.segments[safe: targetLetterIndex],
               segment.isPractiseable {
                sessionViewModel.handle(event: .replay(letterIndex: targetLetterIndex))
                targetLetterIndex = sessionViewModel.sessionState.activeLetterGlobalIndex
            }

            let state = sessionViewModel.sessionState
            let letterIndex = state.activeLetterGlobalIndex
            let environment = PracticeRowViewModel.Environment(segment: layout.segments[safe: letterIndex],
                                                               metrics: metrics,
                                                               difficulty: settings.difficulty,
                                                               hapticsEnabled: settings.hapticsEnabled)

            for (index, row) in rowViewModels.enumerated() {
                row.updateEnvironment(environment)
                row.updateLetterIndex(letterIndex)
                let phase: PracticeRowViewModel.Phase = index == state.activeRepetitionIndex ? .previewing : .frozen
                let shouldClear = clearCompletedRows || index == state.activeRepetitionIndex
                row.reset(to: phase, clearDrawing: shouldClear)
                row.setActive(index == state.activeRepetitionIndex)
            }

            activePracticeRow = state.activeRepetitionIndex
            if rowViewModels.indices.contains(state.activeRepetitionIndex) {
                rowViewModels[state.activeRepetitionIndex].startPreviewIfNeeded()
            }
            pendingResetWorkItem = nil
        }

        if delayed {
            let workItem = DispatchWorkItem(block: performReset)
            pendingResetWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + lessonBoardTransitionDuration, execute: workItem)
        } else {
            DispatchQueue.main.async(execute: performReset)
        }
    }

    private func updateProgress(using state: PracticeSessionController.State) {
        let completedAcrossRepetitions = state.repetitions.reduce(0) { count, repetition in
            count + repetition.rows.filter { $0.didCompleteLetter }.count
        }
        let totalAcrossRepetitions = max(state.totalLetters * LetterPracticeCanvas.repetitionCount, 1)
        onProgressChanged(completedAcrossRepetitions, totalAcrossRepetitions)
    }

    private func isSessionComplete(_ state: PracticeSessionController.State) -> Bool {
        let totalAcrossRepetitions = state.totalLetters * LetterPracticeCanvas.repetitionCount
        guard totalAcrossRepetitions > 0 else { return false }
        let completedAcrossRepetitions = state.repetitions.reduce(0) { count, repetition in
            count + repetition.rows.filter { $0.didCompleteLetter }.count
        }
        return completedAcrossRepetitions >= totalAcrossRepetitions
    }

    private func triggerLessonCompletion() {
        guard !completionGuard else { return }
        completionGuard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onLessonComplete()
        }
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

#if DEBUG
struct PracticeBoardView_Previews: PreviewProvider {
    static var previews: some View {
        PracticeBoardView(lesson: sampleLesson,
                          settings: .default,
                          allowFingerInput: UserSettings.default.inputPreference.allowsFingerInput,
                          clearTrigger: 0,
                          onLetterAward: { _ in },
                          onProgressChanged: { _, _ in },
                          onLessonComplete: { })
            .previewDisplayName("Practice Board")
            .frame(height: 520)
            .padding()
            .background(Color(white: 0.95))
    }

    private static var sampleLesson: PracticeLesson {
        PracticeLessonLibrary.lesson(for: "letters.lower.a") ?? PracticeLesson(
            id: "preview.lesson",
            unitId: .letters,
            kind: .letter(character: "a", style: .lower),
            title: "Preview Lesson",
            subtitle: "Demo content",
            cardGlyph: "a",
            practiceText: "aaa aaa aaa",
            referenceText: "aaa aaa aaa",
            order: 1
        )
    }
}
#endif
