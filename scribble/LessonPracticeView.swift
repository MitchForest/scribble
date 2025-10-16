import SwiftUI
import PencilKit

struct LessonPracticeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @State private var activeDialog: QuickDialog?
    @State private var currentIndex: Int
    @State private var boardKey = UUID()

    private let lessons: [PracticeLesson]

    init(lesson: PracticeLesson) {
        let unit = PracticeLessonLibrary.unit(for: lesson.unitId)
        let ordered = unit?.lessons.sorted(by: { $0.order < $1.order }) ?? [lesson]
        self.lessons = ordered
        let startIndex = ordered.firstIndex(where: { $0.id == lesson.id }) ?? 0
        _currentIndex = State(initialValue: startIndex)
    }

    private var currentLesson: PracticeLesson {
        lessons[currentIndex]
    }

    private var nextLessonIndex: Int {
        guard !lessons.isEmpty else { return 0 }
        return (currentIndex + 1) % lessons.count
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
            HStack(spacing: 16) {
                StreakBadge(streak: streak) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        activeDialog = .streak
                    }
                }
                ProfileMenuButton(seed: dataStore.profile.avatarSeed,
                                  progress: dataStore.dailyProgressRatio(),
                                  onOpen: {
                                      withAnimation(.easeInOut(duration: 0.25)) {
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
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.45), value: boardKey)
    }

    private func advanceToNextLesson() {
        guard !lessons.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            currentIndex = nextLessonIndex
            boardKey = UUID()
        }
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
    private func dialogView(for dialog: QuickDialog) -> some View {
        switch dialog {
        case .profile:
            ProfileQuickActionsDialog(onClose: { closeDialog() })
                .environmentObject(dataStore)
        case .streak:
            StreakDialog(onClose: { closeDialog() })
                .environmentObject(dataStore)
        }
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

// MARK: - Practice Board

private struct LessonPracticeBoard: View {
    let lesson: PracticeLesson
    let settings: UserSettings
    let allowFingerInput: Bool
    let onLetterAward: (LetterTimelineItem) -> Void
    let onProgressChanged: (Int, Int) -> Void
    let onLessonComplete: () -> Void

    @StateObject private var viewModel: FreePracticeViewModel
    @State private var animationToken = 0
    @State private var feedback: FeedbackMessage?
    @State private var completionGuard = false

    init(lesson: PracticeLesson,
         settings: UserSettings,
         allowFingerInput: Bool,
         onLetterAward: @escaping (LetterTimelineItem) -> Void,
         onProgressChanged: @escaping (Int, Int) -> Void,
         onLessonComplete: @escaping () -> Void) {
        self.lesson = lesson
        self.settings = settings
        self.allowFingerInput = allowFingerInput
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
            let metrics = PracticeCanvasMetrics(strokeSize: settings.difficulty.profile.strokeSize)
            let layout = WordLayout(items: viewModel.timeline,
                                    availableWidth: proxy.size.width,
                                    metrics: metrics,
                                    isLeftHanded: settings.isLeftHanded)

            ZStack(alignment: .top) {
                VStack(spacing: 18) {
                    ReferenceLineView(layout: layout,
                                      currentIndex: viewModel.currentLetterIndex,
                                      animationToken: animationToken,
                                      letterStates: viewModel.letterStates,
                                      onTap: { index, segment in
                                          guard segment.isPractiseable else { return }
                                          if index > viewModel.currentLetterIndex {
                                              return
                                          }
                                          feedback = nil
                                          if index == viewModel.currentLetterIndex {
                                              animationToken &+= 1
                                          } else {
                                              viewModel.replay(at: index)
                                              animationToken &+= 1
                                          }
                                      })

                    LetterPracticeCanvas(layout: layout,
                                         metrics: metrics,
                                         currentIndex: viewModel.currentLetterIndex,
                                         guidesEnabled: guidesEnabled,
                                         difficulty: settings.difficulty,
                                         hapticsEnabled: settings.hapticsEnabled,
                                         allowFingerInput: allowFingerInput,
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
                                             if lessonDone {
                                                 triggerLessonCompletion()
                                             }
                                         },
                                         onSuccessFeedback: { showSuccessFeedback() },
                                         onRetryFeedback: { showRetryFeedback() })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: viewModel.targetText) { _ in
                    feedback = nil
                }

                if let bubble = feedback,
                   let segment = layout.segments[safe: viewModel.currentLetterIndex] {
                    let referenceTop = layout.ascender - layout.scaledXHeight
                    let letterTop = segment.strokeBounds?.minY ?? referenceTop
                    let bubbleY = max(letterTop - 42, 16)
                    FeedbackBubbleView(message: bubble)
                        .position(x: segment.frame.midX, y: bubbleY)
                }
            }
        }
        .frame(minHeight: 280)
        .onAppear {
            viewModel.resumeIfNeeded()
            onProgressChanged(viewModel.completedLetterCount, viewModel.totalPractiseableLetters)
        }
        .onChange(of: viewModel.currentLetterIndex) { _ in
            animationToken &+= 1
        }
        .onChange(of: viewModel.targetText) { _ in
            animationToken &+= 1
            completionGuard = false
        }
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

// MARK: - Reference Line

private struct ReferenceLineView: View {
    let layout: WordLayout
    let currentIndex: Int
    let animationToken: Int
    let letterStates: [LetterState]
    let onTap: (Int, WordLayout.Segment) -> Void

    @State private var strokeProgress: [CGFloat] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.segments.enumerated()), id: \.1.id) { index, segment in
                let statusColor = status(for: index).fillColor
                let dotY = layout.ascender + 14

                if !segment.strokes.isEmpty {
                    let color = referenceColor(for: index)
                    ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { strokeIndex, stroke in
                        stroke.path
                            .trim(from: 0, to: trimAmount(for: index, strokeIndex: strokeIndex))
                            .stroke(color,
                                    style: StrokeStyle(lineWidth: segment.lineWidth,
                                                       lineCap: .round,
                                                       lineJoin: .round))
                    }

                    Circle()
                        .fill(statusColor)
                        .frame(width: 11, height: 11)
                        .position(x: segment.frame.midX,
                                  y: dotY)
                }

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: max(segment.frame.width, 32),
                           height: layout.ascender + layout.descender + 24)
                    .position(x: segment.frame.midX,
                              y: (layout.ascender + layout.descender + 24) / 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap(index, segment)
                    }
            }
        }
        .frame(height: layout.height + 12)
        .onAppear { animateCurrentLetter() }
        .onChange(of: animationToken) {
            animateCurrentLetter()
        }
        .drawingGroup()
    }

    private func status(for index: Int) -> LetterStatus {
        guard letterStates.indices.contains(index) else { return .upcoming }
        let state = letterStates[index]
        if index < currentIndex {
            return state.isComplete ? .completed : .needsWork
        } else if index == currentIndex {
            return state.hadWarning ? .needsWork : .current
        } else {
            return .upcoming
        }
    }

    private func referenceColor(for index: Int) -> Color {
        if index < letterStates.count {
            if letterStates[index].isComplete {
                return Color(red: 0.36, green: 0.66, blue: 0.46)
            }
            if letterStates[index].hadWarning {
                return Color(red: 0.91, green: 0.45, blue: 0.41)
            }
        }
        if index == currentIndex {
            return Color(red: 0.32, green: 0.52, blue: 0.98)
        }
        return Color(red: 0.75, green: 0.82, blue: 0.94)
    }

    private func trimAmount(for segmentIndex: Int, strokeIndex: Int) -> CGFloat {
        if segmentIndex == currentIndex,
           strokeIndex < strokeProgress.count {
            return strokeProgress[strokeIndex]
        }
        return 1
    }

    private func animateCurrentLetter() {
        guard layout.segments.indices.contains(currentIndex) else {
            strokeProgress = []
            return
        }
        let strokes = layout.segments[currentIndex].strokes
        if strokes.isEmpty {
            strokeProgress = []
            return
        }
        strokeProgress = Array(repeating: 0, count: strokes.count)
        for index in strokes.indices {
            let delay = 0.25 * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.6)) {
                    if index < strokeProgress.count {
                        strokeProgress[index] = 1
                    }
                }
            }
        }
    }
}

// MARK: - Practice Canvas

private struct LetterPracticeCanvas: View {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let currentIndex: Int
    let guidesEnabled: Bool
    let difficulty: PracticeDifficulty
    let hapticsEnabled: Bool
    let allowFingerInput: Bool
    let onWarning: () -> Void
    let onStrokeValidated: (Int, Int) -> Void
    let onLetterComplete: () -> Void
    let onSuccessFeedback: () -> Void
    let onRetryFeedback: () -> Void

    @State private var drawing = PKDrawing()
    @State private var frozenDrawing = PKDrawing()
    @State private var previousStrokeCount = 0
    @State private var warningMessage: String?
    @State private var currentStrokeIndex = 0
    @State private var lastWarningTime: Date?

    private var profile: PracticeDifficultyProfile {
        difficulty.profile
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
        layout.segments[safe: currentIndex]
    }

    private var expectedStrokeCount: Int {
        currentSegment?.strokes.count ?? 0
    }

    private var deviationSlack: CGFloat {
        switch difficulty {
        case .beginner: return 0.12
        case .intermediate: return 0.08
        case .expert: return 0.05
        }
    }

    private var maxOutsideRatio: CGFloat {
        switch difficulty {
        case .beginner: return 0.32
        case .intermediate: return 0.26
        case .expert: return 0.18
        }
    }

    private var mergeCoverageCorridor: CGFloat {
        let inkWidth = metrics.userInkWidth
        let guideWidth = metrics.practiceLineWidth
        return max(inkWidth * 1.05, guideWidth * 0.7, 10)
    }

    var body: some View {
        let canvasWidth = layout.width + layout.leadingInset * 2
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)

            PracticeRowGuides(width: layout.width,
                              ascender: layout.ascender,
                              descender: layout.descender,
                              scaledXHeight: layout.scaledXHeight,
                              guideLineWidth: metrics.guideLineWidth)
            .padding(.horizontal, layout.leadingInset)

            WordGuidesOverlay(layout: layout,
                              metrics: metrics,
                              currentIndex: currentIndex,
                              currentStrokeIndex: currentStrokeIndex,
                              guidesEnabled: guidesEnabled)

            StaticDrawingView(drawing: frozenDrawing)
                .allowsHitTesting(false)

            PencilCanvasView(drawing: $drawing,
                             onDrawingChanged: { updated in
                                 processDrawingChange(updated)
                             },
                             allowFingerFallback: allowFingerInput,
                             lineWidth: metrics.userInkWidth)
                .padding(.horizontal, 0)

            if let warningMessage {
                Text(warningMessage)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    .position(x: canvasWidth / 2,
                              y: layout.ascender + metrics.startDotSize * 0.8)
                    .transition(.opacity)
            }
        }
        .frame(height: canvasHeight)
        .padding(.vertical, 6)
        .onChange(of: layout.cacheKey) {
            DispatchQueue.main.async {
                resetCanvas()
            }
        }
        .onChange(of: currentIndex) {
            DispatchQueue.main.async {
                drawing = PKDrawing()
                previousStrokeCount = 0
                currentStrokeIndex = 0
            }
        }
    }

    private func resetCanvas() {
        drawing = PKDrawing()
        frozenDrawing = PKDrawing()
        warningMessage = nil
        previousStrokeCount = 0
        currentStrokeIndex = 0
        lastWarningTime = nil
    }

    private func processDrawingChange(_ updated: PKDrawing) {
        guard let segment = currentSegment else {
            drawing = PKDrawing()
            return
        }
        let strokes = updated.strokes
        guard !strokes.isEmpty else {
            previousStrokeCount = 0
            currentStrokeIndex = 0
            return
        }

        if strokes.count > previousStrokeCount, let newStroke = strokes.last {
            let strokeIndex = min(strokes.count - 1, segment.strokes.count - 1)
            let templateStroke = segment.strokes[strokeIndex]

            guard validateStartPoint(for: newStroke, templateStroke: templateStroke) else {
                revertDrawing(updated)
                return
            }

            guard validateDeviation(for: newStroke, templateStroke: templateStroke) else {
                showWarning("Stay close to the dotted path")
                revertDrawing(updated)
                return
            }

            currentStrokeIndex = min(segment.strokes.count,
                                     max(currentStrokeIndex, strokeIndex + 1))
            onStrokeValidated(strokeIndex, segment.strokes.count)
            onSuccessFeedback()
            if hapticsEnabled {
                HapticsManager.shared.success()
            }
        }

        previousStrokeCount = strokes.count

        if shouldCompleteLetter(strokes: strokes, templateStrokes: segment.strokes) {
            completeLetter()
        }
    }

    private func validateStartPoint(for stroke: PKStroke, templateStroke: WordLayout.ScaledStroke) -> Bool {
        guard let firstPoint = stroke.path.firstLocation else { return false }
        let tolerance = metrics.startTolerance(for: difficulty)
        let snapRadius = tolerance * difficulty.profile.startSnapMultiplier
        let distance = hypot(firstPoint.x - templateStroke.startPoint.x,
                             firstPoint.y - templateStroke.startPoint.y)

        if distance <= snapRadius || distance <= tolerance {
            return true
        }

        let forgiveness = tolerance * difficulty.profile.startForgivenessMultiplier
        if distance <= forgiveness {
            showWarning("Start closer to the green dot")
            return true
        }

        showWarning("Start at the green dot")
        return false
    }

    private func validateDeviation(for stroke: PKStroke, templateStroke: WordLayout.ScaledStroke) -> Bool {
        let userPoints = stroke.sampledPoints(step: 4)
        guard !userPoints.isEmpty else { return false }

        let corridor = metrics.corridorRadius(for: difficulty)
        let softLimit = metrics.corridorSoftLimit(for: difficulty)
        let hardLimit = softLimit + max(12, corridor * 0.6)

        var outside = 0
        var softBreaches = 0

        for point in userPoints {
            let distance = nearestDistance(for: point,
                                           templateStroke: templateStroke,
                                           corridor: corridor)
            if distance > hardLimit {
                return false
            }
            if distance > softLimit {
                softBreaches += 1
                outside += 1
                continue
            }
            if distance > corridor {
                outside += 1
            }
        }

        let samples = userPoints.count
        let allowedSoftBreaches = max(2, Int(round(CGFloat(samples) * deviationSlack)))
        if softBreaches > allowedSoftBreaches {
            return false
        }

        let outsideRatio = samples > 0 ? CGFloat(outside) / CGFloat(samples) : 0
        return outsideRatio <= maxOutsideRatio
    }

    private func nearestDistance(for point: CGPoint,
                                 templateStroke: WordLayout.ScaledStroke,
                                 corridor: CGFloat) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for templatePoint in templateStroke.sampledPoints {
            let distance = hypot(point.x - templatePoint.x, point.y - templatePoint.y)
            if distance < nearest {
                nearest = distance
                if nearest < corridor * 0.25 {
                    break
                }
            }
        }
        return nearest
    }

    private func nearestDistanceToTemplate(_ point: CGPoint,
                                           templateStrokes: [WordLayout.ScaledStroke],
                                           corridor: CGFloat) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for stroke in templateStrokes {
            let distance = nearestDistance(for: point,
                                           templateStroke: stroke,
                                           corridor: corridor)
            if distance < nearest {
                nearest = distance
                if nearest < corridor * 0.2 {
                    break
                }
            }
        }
        return nearest
    }

    private func nearestDistanceToUser(_ point: CGPoint,
                                       userPoints: [CGPoint],
                                       corridor: CGFloat) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for candidate in userPoints {
            let distance = hypot(point.x - candidate.x, point.y - candidate.y)
            if distance < nearest {
                nearest = distance
                if nearest < corridor * 0.2 {
                    break
                }
            }
        }
        return nearest
    }

    private func coverageRatio(for strokes: [PKStroke],
                               templateStrokes: [WordLayout.ScaledStroke],
                               corridor: CGFloat,
                               perStroke: inout [Double]) -> Double {
        let userSamples = strokes.flatMap { $0.sampledPoints(step: 3) }
        guard !userSamples.isEmpty else { return 0 }

        let templateSamples = templateStrokes.flatMap(\.sampledPoints)
        guard !templateSamples.isEmpty else { return 0 }

        var userInside = 0
        for point in userSamples {
            let distance = nearestDistanceToTemplate(point,
                                                     templateStrokes: templateStrokes,
                                                     corridor: corridor)
            if distance <= corridor {
                userInside += 1
            }
        }
        let userCoverage = Double(userInside) / Double(userSamples.count)

        perStroke = templateStrokes.map { stroke in
            let points = stroke.sampledPoints
            guard !points.isEmpty else { return 1 }
            var inside = 0
            for point in points {
                let distance = nearestDistanceToUser(point,
                                                     userPoints: userSamples,
                                                     corridor: corridor)
                if distance <= corridor {
                    inside += 1
                }
            }
            return Double(inside) / Double(points.count)
        }

        var templateInside = 0
        for point in templateSamples {
            let distance = nearestDistanceToUser(point,
                                                 userPoints: userSamples,
                                                 corridor: corridor)
            if distance <= corridor {
                templateInside += 1
            }
        }
        let templateCoverage = Double(templateInside) / Double(templateSamples.count)

        return min(userCoverage, templateCoverage)
    }

    private func shouldCompleteLetter(strokes: [PKStroke],
                                      templateStrokes: [WordLayout.ScaledStroke]) -> Bool {
        guard !templateStrokes.isEmpty else { return false }

        if currentStrokeIndex >= templateStrokes.count {
            return true
        }

        guard profile.mergedStrokeAllowance > 0 else { return false }

        let remaining = templateStrokes.count - currentStrokeIndex
        guard remaining <= profile.mergedStrokeAllowance else { return false }

        var perStrokeCoverage: [Double] = []
        let coverage = coverageRatio(for: strokes,
                                     templateStrokes: templateStrokes,
                                     corridor: mergeCoverageCorridor,
                                     perStroke: &perStrokeCoverage)
        if coverage >= profile.completionCoverageThreshold {
            let tailRange = currentStrokeIndex..<templateStrokes.count
            let tailSatisfied = tailRange.allSatisfy { index in
                perStrokeCoverage[safe: index] ?? 0 >= profile.completionCoverageThreshold
            }
            if tailSatisfied {
                currentStrokeIndex = templateStrokes.count
                return true
            }
        }
        return false
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

    private func revertDrawing(_ updated: PKDrawing) {
        let trimmed = StartPointGate.removeLastStroke(from: updated)
        drawing = trimmed
        previousStrokeCount = trimmed.strokes.count
    }

    private func completeLetter() {
        if hapticsEnabled {
            HapticsManager.shared.success()
        }
        frozenDrawing = frozenDrawing.appending(drawing)
        drawing = PKDrawing()
        previousStrokeCount = 0
        currentStrokeIndex = 0
        onSuccessFeedback()
        onLetterComplete()
    }
}

private enum LetterStatus {
    case completed
    case current
    case needsWork
    case upcoming

    var fillColor: Color {
        switch self {
        case .completed:
            return Color(red: 0.45, green: 0.74, blue: 0.51)
        case .current:
            return Color(red: 1.0, green: 0.82, blue: 0.36)
        case .needsWork:
            return Color(red: 0.93, green: 0.43, blue: 0.39)
        case .upcoming:
            return Color(red: 0.8, green: 0.86, blue: 0.94)
        }
    }
}

private struct WordGuidesOverlay: View {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let currentIndex: Int
    let currentStrokeIndex: Int
    let guidesEnabled: Bool

    #if DEBUG
    private static let showCorridorDebug = false
    #else
    private static let showCorridorDebug = false
    #endif

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
            let appearance = style(for: index,
                                   strokeIndex: strokeIndex,
                                   isCurrent: isCurrent,
                                   isCompleted: isCompleted,
                                   isActiveStroke: strokeIndex == activeStroke)

            stroke.path
                .stroke(appearance.color,
                        style: StrokeStyle(lineWidth: appearance.lineWidth,
                                           lineCap: .round,
                                           lineJoin: .round,
                                           dash: guidesEnabled ? appearance.dash : []))

            if Self.showCorridorDebug {
                stroke.path
                    .stroke(Color(red: 0.23, green: 0.45, blue: 0.9).opacity(0.15),
                            style: StrokeStyle(lineWidth: metrics.practiceLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
            }

            if strokeIndex == activeStroke {
                StartDot(position: stroke.startPoint,
                         diameter: metrics.startDotSize * 0.9)
                EndDot(position: stroke.endPoint,
                       diameter: metrics.startDotSize * 0.8)
            }
        }
    }

    private func style(for segmentIndex: Int,
                       strokeIndex: Int,
                       isCurrent: Bool,
                       isCompleted: Bool,
                       isActiveStroke: Bool) -> (color: Color, lineWidth: CGFloat, dash: [CGFloat]) {
        let baseDash: [CGFloat] = [6, 8]

        if isCompleted {
            return (Color(red: 0.35, green: 0.62, blue: 0.48), metrics.guideLineWidth * 0.9, [])
        }

        if isCurrent {
            if isActiveStroke {
                return (Color(red: 0.21, green: 0.41, blue: 0.88).opacity(0.85), metrics.guideLineWidth, [6, 6])
            } else {
                return (Color(red: 0.29, green: 0.49, blue: 0.86).opacity(0.35), metrics.guideLineWidth, baseDash)
            }
        }

        return (Color(red: 0.72, green: 0.82, blue: 0.94).opacity(0.22), metrics.guideLineWidth, baseDash)
    }
}

private struct StartDot: View {
    let position: CGPoint
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(Color(red: 0.35, green: 0.8, blue: 0.46))
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .frame(width: diameter, height: diameter)
            .position(position)
    }
}

private struct EndDot: View {
    let position: CGPoint
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(Color(red: 0.98, green: 0.86, blue: 0.34))
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .frame(width: diameter, height: diameter)
            .position(position)
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
        var isPractiseable: Bool { item.isPractiseable && !strokes.isEmpty }
    }

    let segments: [Segment]
    let ascender: CGFloat
    let descender: CGFloat
    let width: CGFloat
    let height: CGFloat
    let scaledXHeight: CGFloat
    let leadingInset: CGFloat
    let cacheKey: String

    init(items: [LetterTimelineItem],
         availableWidth: CGFloat,
         metrics: PracticeCanvasMetrics,
         isLeftHanded: Bool) {
        let rowAscender = metrics.rowMetrics.ascender
        let rowDescender = metrics.rowMetrics.descender
        let totalHeight = rowAscender + rowDescender

        let baseSpacing: CGFloat = rowAscender * 0.35
        let baseSpaceWidth: CGFloat = rowAscender * 0.8
        let horizontalPadding: CGFloat = 40

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

        let totalRawWidth = rawWidths.reduce(0, +) + baseSpacing * max(0, CGFloat(items.count - 1))
        let usableWidth = max(availableWidth - horizontalPadding, 80)
        let compression = totalRawWidth > usableWidth ? usableWidth / totalRawWidth : 1
        let contentWidth = totalRawWidth * compression
        let leadingInsetValue = max((availableWidth - contentWidth) / 2, 16)

        var segments: [Segment] = []
        var cursor = leadingInsetValue

        for (index, descriptor) in descriptors.enumerated() {
            let segmentWidth = descriptor.width * compression
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
                                        strokeBounds: nil))
            } else {
                var scaledStrokes: [ScaledStroke] = []
                let horizontalScale = descriptor.baseScale * compression
                let minX = descriptor.minX
                let segmentFrame = CGRect(x: cursor,
                                          y: 0,
                                          width: segmentWidth,
                                          height: totalHeight)
                var unionBounds: CGRect?

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
                    scaledStrokes.append(ScaledStroke(id: stroke.id,
                                                      order: stroke.order,
                                                      path: path,
                                                      points: convertedPoints,
                                                      startPoint: startPoint,
                                                      endPoint: endPoint))
                }

                segments.append(Segment(index: index,
                                        item: descriptor.item,
                                        strokes: scaledStrokes,
                                        frame: segmentFrame,
                                        lineWidth: descriptor.lineWidth,
                                        strokeBounds: unionBounds))
            }
            cursor += segmentWidth + baseSpacing * compression
        }

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
        self.width = availableWidth
        self.height = totalHeight
        self.leadingInset = leadingInsetValue
        self.cacheKey = "\(items.map { $0.character })|\(availableWidth)|\(rowAscender)|\(isLeftHanded)"
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

    struct ScaledStroke: Identifiable {
        let id: String
        let order: Int
        let path: Path
        let points: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
        let sampledPoints: [CGPoint]

        init(id: String,
             order: Int,
             path: Path,
             points: [CGPoint],
             startPoint: CGPoint,
             endPoint: CGPoint) {
            self.id = id
            self.order = order
            self.path = path
            self.points = points
            self.startPoint = startPoint
            self.endPoint = endPoint
            self.sampledPoints = ScaledStroke.sample(points: points, stride: 6)
        }

        private static func sample(points: [CGPoint], stride: Int) -> [CGPoint] {
            guard stride > 0 else { return points }
            var result: [CGPoint] = []
            var index = 0
            for point in points {
                if index % stride == 0 {
                    result.append(point)
                }
                index += 1
            }
            if let last = points.last, result.last != last {
                result.append(last)
            }
            return result
        }

        func closestDistance(to point: CGPoint, sampleCount: Int) -> CGFloat {
            guard !sampledPoints.isEmpty else { return CGFloat.greatestFiniteMagnitude }
            let samples = max(sampleCount, 12)
            let stride = max(sampledPoints.count / samples, 1)
            var nearest = CGFloat.greatestFiniteMagnitude
            for (index, strokePoint) in sampledPoints.enumerated() where index % stride == 0 {
                let distance = hypot(point.x - strokePoint.x, point.y - strokePoint.y)
                if distance < nearest {
                    nearest = distance
                }
            }
            return nearest
        }

        func corridorPath(expand radius: CGFloat) -> Path {
            var path = Path()
            guard !points.isEmpty else { return path }
            path.addLines(points)
            return path.strokedPath(.init(lineWidth: radius * 2,
                                          lineCap: .round,
                                          lineJoin: .round))
        }
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

private struct PracticeCanvasMetrics {
    let strokeSize: StrokeSizePreference

    var rowMetrics: RowMetrics { strokeSize.metrics }

    var canvasPadding: CGFloat {
        switch strokeSize {
        case .large: return 110
        case .standard: return 90
        case .compact: return 70
        }
    }

    var canvasHeight: CGFloat {
        rowMetrics.ascender + rowMetrics.descender + canvasPadding
    }

    var practiceLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 9.5
        case .standard: return 7.2
        case .compact: return 5.2
        }
    }

    var guideLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 7.5
        case .standard: return 5.8
        case .compact: return 4.4
        }
    }

    var startDotSize: CGFloat {
        switch strokeSize {
        case .large: return 26
        case .standard: return 20
        case .compact: return 16
        }
    }

    var userInkWidth: CGFloat {
        switch strokeSize {
        case .large: return 8.2
        case .standard: return 6.4
        case .compact: return 4.8
        }
    }

    func startTolerance(for difficulty: PracticeDifficulty) -> CGFloat {
        let base: CGFloat = 32 * (rowMetrics.ascender / StrokeSizePreference.standard.metrics.ascender)
        return base * difficulty.profile.startToleranceMultiplier
    }

    func deviationTolerance(for difficulty: PracticeDifficulty) -> CGFloat {
        let base: CGFloat = 40 * (rowMetrics.ascender / StrokeSizePreference.standard.metrics.ascender)
        return base * difficulty.profile.deviationToleranceMultiplier
    }

    func corridorRadius(for difficulty: PracticeDifficulty) -> CGFloat {
        deviationTolerance(for: difficulty) * difficulty.profile.corridorWidthMultiplier
    }

    func corridorSoftLimit(for difficulty: PracticeDifficulty) -> CGFloat {
        corridorRadius(for: difficulty) + difficulty.profile.corridorSoftness
    }
}
