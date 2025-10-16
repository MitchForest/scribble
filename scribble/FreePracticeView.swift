import SwiftUI
import PencilKit

struct FreePracticeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    private let catalog: [PracticeCategory]

    @State private var expandedCategoryID: PracticeCategory.ID?
    @State private var selectedCategory: PracticeCategory
    @State private var selectedLesson: PracticeLesson

    @StateObject private var topViewModel: FreePracticeViewModel
    @StateObject private var bottomViewModel: FreePracticeViewModel
    @State private var topAnimationToken = 0
    @State private var bottomAnimationToken = 0

    private var difficultyMultiplier: Double {
        switch dataStore.settings.difficulty {
        case .beginner: return 1.4
        case .intermediate: return 1.0
        case .expert: return 0.8
        }
    }

    private let secondsPerLetter: Int = 5

    private var activeTopLine: PracticeLessonLine {
        selectedLesson.lines.first ?? PracticeCatalog.fallbackLine
    }

    private var activeBottomLine: PracticeLessonLine {
        selectedLesson.lines.dropFirst().first ?? PracticeCatalog.fallbackLine
    }

    init() {
        let categories = PracticeCatalog.defaultCategories.isEmpty
            ? [PracticeCatalog.fallbackCategory]
            : PracticeCatalog.defaultCategories
        self.catalog = categories

        let category = categories.first ?? PracticeCatalog.fallbackCategory
        let lesson = category.lessons.first ?? PracticeCatalog.fallbackLesson
        let topLine = lesson.lines.first ?? PracticeCatalog.fallbackLine
        let bottomLine = lesson.lines.dropFirst().first ?? PracticeCatalog.fallbackLine

        _selectedCategory = State(initialValue: category)
        _selectedLesson = State(initialValue: lesson)
        _expandedCategoryID = State(initialValue: category.id)
        _topViewModel = StateObject(wrappedValue: FreePracticeViewModel(initialText: topLine.text))
        _bottomViewModel = StateObject(wrappedValue: FreePracticeViewModel(initialText: bottomLine.text))
    }

    var body: some View {
        let today = dataStore.todayContribution()
        let guidesEnabled = dataStore.settings.difficulty.profile.showsGuides

        ZStack {
            PracticeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    PracticeTopBar(progress: dataStore.dailyProgressRatio(),
                                   today: today,
                                   goal: dataStore.profile.goal,
                                   seed: dataStore.profile.avatarSeed,
                                   difficulty: dataStore.settings.difficulty,
                                   streak: dataStore.currentStreak(),
                                   onDifficultyChange: { dataStore.updateDifficulty($0) })

                    lessonPicker

                    Text(selectedLesson.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.3, green: 0.42, blue: 0.63))

                    VStack(spacing: 38) {
                        practiceLineSection(line: activeTopLine,
                                            viewModel: topViewModel,
                                            animationToken: $topAnimationToken,
                                            guidesEnabled: guidesEnabled)

                        practiceLineSection(line: activeBottomLine,
                                            viewModel: bottomViewModel,
                                            animationToken: $bottomAnimationToken,
                                            guidesEnabled: guidesEnabled)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            topViewModel.resumeIfNeeded()
            bottomViewModel.resumeIfNeeded()
        }
        .onChange(of: topViewModel.currentLetterIndex) { _ in
            topAnimationToken &+= 1
        }
        .onChange(of: topViewModel.targetText) { _ in
            topAnimationToken &+= 1
        }
        .onChange(of: bottomViewModel.currentLetterIndex) { _ in
            bottomAnimationToken &+= 1
        }
        .onChange(of: bottomViewModel.targetText) { _ in
            bottomAnimationToken &+= 1
        }
    }

    private func awardLetterTime(for letter: LetterTimelineItem) {
        guard let letterId = letter.letterId else { return }
        let adjusted = Int(Double(secondsPerLetter) * difficultyMultiplier)
        dataStore.addWritingSeconds(max(adjusted, 1),
                                    category: .practiceLine,
                                    letterId: letterId)
    }

    @ViewBuilder
    private var lessonPicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(catalog) { category in
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        toggleCategory(category)
                    } label: {
                        HStack {
                            Text(category.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(category.id == selectedCategory.id
                                                 ? Color(red: 0.32, green: 0.42, blue: 0.6)
                                                 : Color(red: 0.38, green: 0.48, blue: 0.68))
                            Spacer()
                            Image(systemName: expandedCategoryID == category.id ? "chevron.up" : "chevron.down")
                                .foregroundColor(Color(red: 0.48, green: 0.58, blue: 0.78))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(category.id == selectedCategory.id
                                      ? Color.white.opacity(0.96)
                                      : Color.white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if expandedCategoryID == category.id {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(category.lessons) { lesson in
                                Button {
                                    selectLesson(lesson, in: category)
                                } label: {
                                    HStack {
                                        Text(lesson.title)
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(lesson.id == selectedLesson.id
                                                             ? Color(red: 0.32, green: 0.42, blue: 0.6)
                                                             : Color(red: 0.47, green: 0.55, blue: 0.72))
                                        Spacer()
                                        if lesson.id == selectedLesson.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.36))
                                                .imageScale(.medium)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(lesson.id == selectedLesson.id
                                                  ? Color.white.opacity(0.96)
                                                  : Color.white.opacity(0.7))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func practiceLineSection(line: PracticeLessonLine,
                                     viewModel: FreePracticeViewModel,
                                     animationToken: Binding<Int>,
                                     guidesEnabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(line.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.28, green: 0.4, blue: 0.62))

            PracticeBoard(viewModel: viewModel,
                          settings: dataStore.settings,
                          guidesEnabled: guidesEnabled,
                          animationToken: animationToken,
                          awardLetterTime: awardLetterTime,
                          registerWarning: { viewModel.markWarningForCurrentLetter() })
                .frame(maxHeight: .infinity)
        }
    }

    private func toggleCategory(_ category: PracticeCategory) {
        if expandedCategoryID == category.id {
            expandedCategoryID = nil
        } else {
            expandedCategoryID = category.id
            if selectedCategory.id != category.id {
                selectLesson(category.lessons.first ?? PracticeCatalog.fallbackLesson, in: category)
            }
        }
    }

    private func selectLesson(_ lesson: PracticeLesson, in category: PracticeCategory) {
        selectedCategory = category
        selectedLesson = lesson
        expandedCategoryID = category.id
        applyLesson(lesson)
    }

    private func applyLesson(_ lesson: PracticeLesson) {
        let topLine = lesson.lines.first ?? PracticeCatalog.fallbackLine
        let bottomLine = lesson.lines.dropFirst().first ?? PracticeCatalog.fallbackLine

        topViewModel.targetText = topLine.text
        bottomViewModel.targetText = bottomLine.text
        topViewModel.resumeIfNeeded()
        bottomViewModel.resumeIfNeeded()
        topAnimationToken &+= 1
        bottomAnimationToken &+= 1
    }
}

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

private struct PracticeTopBar: View {
    let progress: Double
    let today: ContributionDay
    let goal: PracticeGoal
    let seed: String
    let difficulty: PracticeDifficulty
    let streak: Int
    let onDifficultyChange: (PracticeDifficulty) -> Void

    private var statusLine: String {
        guard goal.dailySeconds > 0 else { return "Set a goal to start filling your ring." }
        let goalLetters = max(goal.dailySeconds / PracticeGoal.secondsPerLetter, 1)
        let lettersSoFar = max(today.secondsSpent / PracticeGoal.secondsPerLetter, 0)
        let remainingLetters = max(goalLetters - lettersSoFar, 0)
        guard remainingLetters > 0 else { return "Today's letter goal met! 🎉" }
        let label = remainingLetters == 1 ? "letter" : "letters"
        return "\(remainingLetters) \(label) left to sparkle today."
    }

    private var streakSubtitle: String {
        let label = streak == 1 ? "day" : "days"
        return "Streak: \(streak) \(label)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scribble")
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.24, green: 0.33, blue: 0.57))
                Text(statusLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.72))
                Text(streakSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.72))
            }
            Spacer()
            ProfileMenuButton(seed: seed,
                              progress: progress,
                              today: today,
                              goal: goal,
                              difficulty: difficulty,
                              streak: streak,
                              onDifficultyChange: onDifficultyChange)
        }
    }
}

// MARK: - Lesson Catalog

private struct PracticeLessonLine: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
}

private struct PracticeLesson: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let lines: [PracticeLessonLine]
}

private struct PracticeCategory: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let lessons: [PracticeLesson]
}

private enum PracticeCatalog {
    static let fallbackLine = PracticeLessonLine(title: "Practice", text: "a a a a a")
    static let fallbackLesson = PracticeLesson(title: "Starter", lines: [
        PracticeLessonLine(title: "Uppercase A", text: "A A A A A"),
        PracticeLessonLine(title: "Lowercase a", text: "a a a a a")
    ])
    static let fallbackCategory = PracticeCategory(title: "Letters", lessons: [fallbackLesson])

    static let defaultCategories: [PracticeCategory] = [
        PracticeCategory(title: "Letters", lessons: [
            PracticeLesson(title: "Letter A", lines: [
                PracticeLessonLine(title: "Uppercase A", text: "A A A A A"),
                PracticeLessonLine(title: "Lowercase a", text: "a a a a a")
            ]),
            PracticeLesson(title: "Letter B", lines: [
                PracticeLessonLine(title: "Uppercase B", text: "B B B B B"),
                PracticeLessonLine(title: "Lowercase b", text: "b b b b b")
            ]),
            PracticeLesson(title: "Letter C", lines: [
                PracticeLessonLine(title: "Uppercase C", text: "C C C C C"),
                PracticeLessonLine(title: "Lowercase c", text: "c c c c c")
            ])
        ]),
        PracticeCategory(title: "Alphabet", lessons: [
            PracticeLesson(title: "A – E", lines: [
                PracticeLessonLine(title: "Uppercase Set", text: "A B C D E"),
                PracticeLessonLine(title: "Lowercase Set", text: "a b c d e")
            ]),
            PracticeLesson(title: "F – J", lines: [
                PracticeLessonLine(title: "Uppercase Set", text: "F G H I J"),
                PracticeLessonLine(title: "Lowercase Set", text: "f g h i j")
            ]),
            PracticeLesson(title: "K – O", lines: [
                PracticeLessonLine(title: "Uppercase Set", text: "K L M N O"),
                PracticeLessonLine(title: "Lowercase Set", text: "k l m n o")
            ])
        ]),
        PracticeCategory(title: "Sentences", lessons: [
            PracticeLesson(title: "Morning Cheer", lines: [
                PracticeLessonLine(title: "Line 1", text: "Rise and glow with joy"),
                PracticeLessonLine(title: "Line 2", text: "Take a breath and begin")
            ]),
            PracticeLesson(title: "Kind Wishes", lines: [
                PracticeLessonLine(title: "Line 1", text: "Share a smile with a friend"),
                PracticeLessonLine(title: "Line 2", text: "Write a note to brighten days")
            ]),
            PracticeLesson(title: "Little Adventure", lines: [
                PracticeLessonLine(title: "Line 1", text: "Pack a snack for the trail"),
                PracticeLessonLine(title: "Line 2", text: "Follow the sun over hills")
            ])
        ])
    ]
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

// MARK: - Practice Board

private struct PracticeBoard: View {
    @ObservedObject var viewModel: FreePracticeViewModel
    let settings: UserSettings
    let guidesEnabled: Bool
    @Binding var animationToken: Int
    let awardLetterTime: (LetterTimelineItem) -> Void
    let registerWarning: () -> Void

    @State private var feedback: FeedbackMessage?

    private let positiveMessages = ["Great job!", "Awesome!", "Nice stroke!", "Super work!", "You got it!"]
    private let retryMessages = ["Try again!", "Give it another go!", "Reset and retry!", "Almost!", "Keep practicing!"]

    var body: some View {
        GeometryReader { proxy in
            let metrics = PracticeCanvasMetrics(strokeSize: strokePreference(for: settings.difficulty))
            let layout = WordLayout(items: viewModel.timeline,
                                    availableWidth: proxy.size.width,
                                    metrics: metrics,
                                    isLeftHanded: settings.isLeftHanded)

            ZStack(alignment: .top) {
                VStack(spacing: 22) {
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
                                         onWarning: {
                                             registerWarning()
                                         },
                                         onStrokeValidated: { _, _ in },
                                         onLetterComplete: {
                                             if let letter = viewModel.currentLetter {
                                                 awardLetterTime(letter)
                                             }
                                             viewModel.markLetterCompleted()
                                             viewModel.advanceToNextPractiseableLetter()
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
        .frame(minHeight: 260)
    }

    private func strokePreference(for difficulty: PracticeDifficulty) -> StrokeSizePreference {
        difficulty.profile.strokeSize
    }

    private func showSuccessFeedback() {
        showFeedback(text: positiveMessages.randomElement() ?? "Great job!",
                     color: Color(red: 0.34, green: 0.67, blue: 0.5))
    }

    private func showRetryFeedback() {
        showFeedback(text: retryMessages.randomElement() ?? "Try again!",
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
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.96, green: 0.98, blue: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color(red: 0.78, green: 0.86, blue: 1.0).opacity(0.7), lineWidth: 2)
                )

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
                             allowFingerFallback: false,
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
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
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
        guard let segment = currentSegment, !segment.strokes.isEmpty else {
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

    private func validateStartPoint(for stroke: PKStroke, templateStroke: ScaledStroke) -> Bool {
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

    private func validateDeviation(for stroke: PKStroke, templateStroke: ScaledStroke) -> Bool {
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
                                 templateStroke: ScaledStroke,
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
                                           templateStrokes: [ScaledStroke],
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
        for userPoint in userPoints {
            let distance = hypot(point.x - userPoint.x, point.y - userPoint.y)
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
                               templateStrokes: [ScaledStroke],
                               corridor: CGFloat,
                               perStroke: inout [Double]) -> Double {
        guard !strokes.isEmpty, !templateStrokes.isEmpty, corridor > 0 else { return 0 }

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
                                      templateStrokes: [ScaledStroke]) -> Bool {
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

// MARK: - Guides Overlay

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

// MARK: - Word Layout

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
}

// MARK: - Drawing Helpers

struct FeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
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
