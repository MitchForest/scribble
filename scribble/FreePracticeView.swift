import SwiftUI
import PencilKit

struct FreePracticeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @StateObject private var viewModel = FreePracticeViewModel()
    @State private var animationToken = 0
    @State private var showProfileSheet = false

    private var difficultyMultiplier: Double {
        switch dataStore.settings.difficulty {
        case .easy: return 1.4
        case .medium: return 1.0
        case .hard: return 0.8
        }
    }

    private func xpPerStroke(totalStrokes: Int) -> Int {
        let base: Double = 14 * difficultyMultiplier
        let strokes = max(totalStrokes, 1)
        return max(1, Int(round(base / Double(strokes))))
    }

    private func xpBonusForLetter() -> Int {
        max(2, Int(round(12 * difficultyMultiplier)))
    }

    var body: some View {
        let today = dataStore.todayContribution()
        ZStack {
            PracticeBackground()
            VStack(spacing: 24) {
                PracticeTopBar(progress: dataStore.dailyProgressRatio(),
                               today: today,
                               goal: dataStore.profile.goal,
                               seed: dataStore.profile.avatarSeed,
                               difficulty: dataStore.settings.difficulty,
                               onDifficultyChange: { dataStore.updateDifficulty($0) },
                               guidesBinding: $viewModel.guidesEnabled,
                               onOpenProfile: { showProfileSheet = true })
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                GeometryReader { proxy in
                    VStack(spacing: 26) {
                        PresetChips(viewModel: viewModel)
                        LetterStatusRow(viewModel: viewModel)
                        PracticeBoard(viewModel: viewModel,
                                      settings: dataStore.settings,
                                      animationToken: animationToken,
                                      awardStrokeXP: awardStrokeXP,
                                      awardLetterXP: awardLetterXP,
                                      registerWarning: { viewModel.markWarningForCurrentLetter() })
                            .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .onAppear { viewModel.resumeIfNeeded() }
        .onChange(of: viewModel.currentLetterIndex) { _ in
            animationToken &+= 1
        }
        .onChange(of: viewModel.targetText) { _ in
            animationToken &+= 1
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileCenterView()
                .environmentObject(dataStore)
        }
    }

    private func awardStrokeXP(for letter: LetterTimelineItem, strokeIndex: Int, totalStrokes: Int) {
        guard let letterId = letter.letterId else { return }
        dataStore.awardXP(amount: xpPerStroke(totalStrokes: totalStrokes),
                          category: .practiceStroke,
                          letterId: letterId)
    }

    private func awardLetterXP(for letter: LetterTimelineItem) {
        guard let letterId = letter.letterId else { return }
        dataStore.awardXP(amount: xpBonusForLetter(),
                          category: .practiceLine,
                          letterId: letterId)
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
    let onDifficultyChange: (PracticeDifficulty) -> Void
    let guidesBinding: Binding<Bool>
    let onOpenProfile: () -> Void

    private var statusLine: String {
        guard goal.dailyXP > 0 else { return "Set a goal to start filling your ring." }
        let remaining = max(goal.dailyXP - today.xpEarned, 0)
        return remaining == 0 ? "Goal met today! 🎉" : "\(remaining) XP left to sparkle today."
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
            }
            Spacer()
            ProfileMenuButton(seed: seed,
                              progress: progress,
                              today: today,
                              goal: goal,
                              difficulty: difficulty,
                              onDifficultyChange: onDifficultyChange,
                              guidesBinding: .some(guidesBinding),
                              onOpenProfile: onOpenProfile)
        }
    }
}

// MARK: - Top Controls

private struct PresetChips: View {
    @ObservedObject var viewModel: FreePracticeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.presets) { preset in
                    Button {
                        viewModel.selectPreset(preset)
                    } label: {
                        Text(preset.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(viewModel.targetText == preset.text
                                          ? Color(red: 1.0, green: 0.86, blue: 0.42)
                                          : Color.white.opacity(0.9))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
                            )
                            .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
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

private struct LetterStatusRow: View {
    @ObservedObject var viewModel: FreePracticeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(viewModel.timeline.enumerated()), id: \.1.id) { index, item in
                    VStack(spacing: 6) {
                        Text(display(for: item))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.26, green: 0.36, blue: 0.56))
                        Circle()
                            .fill(status(for: index).fillColor)
                            .frame(width: 12, height: 12)
                    }
                    .opacity(item.isPractiseable ? 1 : 0.45)
                    .onTapGesture {
                        viewModel.jump(to: index)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func display(for item: LetterTimelineItem) -> String {
        if item.character == " " { return "⎵" }
        return String(item.character).uppercased()
    }

    private func status(for index: Int) -> LetterStatus {
        guard viewModel.letterStates.indices.contains(index) else { return .upcoming }
        let state = viewModel.letterStates[index]
        if index < viewModel.currentLetterIndex {
            return state.isComplete ? .completed : .needsWork
        } else if index == viewModel.currentLetterIndex {
            return state.hadWarning ? .needsWork : .current
        } else {
            return .upcoming
        }
    }
}

// MARK: - Practice Board

private struct PracticeBoard: View {
    @ObservedObject var viewModel: FreePracticeViewModel
    let settings: UserSettings
    let animationToken: Int
    let awardStrokeXP: (LetterTimelineItem, Int, Int) -> Void
    let awardLetterXP: (LetterTimelineItem) -> Void
    let registerWarning: () -> Void

    @State private var layoutKey: String = ""
    @State private var resetSignal = 0
    @State private var feedback: FeedbackMessage?

    private let positiveMessages = ["Great job!", "Awesome!", "Nice stroke!", "Super work!", "You got it!"]
    private let retryMessages = ["Try again!", "Give it another go!", "Reset and retry!", "Almost!", "Keep practicing!"]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                VStack(spacing: 22) {
                    let metrics = PracticeCanvasMetrics(strokeSize: strokePreference(for: settings.difficulty))
                    let layout = WordLayout(items: viewModel.timeline,
                                            availableWidth: proxy.size.width,
                                            metrics: metrics,
                                            isLeftHanded: settings.isLeftHanded)

                    ReferenceLineView(layout: layout,
                                      currentIndex: viewModel.currentLetterIndex,
                                      animationToken: animationToken,
                                      letterStates: viewModel.letterStates)

                    LetterPracticeCanvas(layout: layout,
                                         metrics: metrics,
                                         currentIndex: viewModel.currentLetterIndex,
                                         guidesEnabled: viewModel.guidesEnabled,
                                         difficulty: settings.difficulty,
                                         hapticsEnabled: settings.hapticsEnabled,
                                         resetSignal: resetSignal,
                                         onWarning: {
                                             registerWarning()
                                         },
                                         onStrokeValidated: { strokeIndex, total in
                                             if let letter = viewModel.currentLetter {
                                                 awardStrokeXP(letter, strokeIndex, total)
                                             }
                                         },
                                         onLetterComplete: {
                                             if let letter = viewModel.currentLetter {
                                                 awardLetterXP(letter)
                                             }
                                             viewModel.markLetterCompleted()
                                             viewModel.advanceToNextPractiseableLetter()
                                         },
                                         onSuccessFeedback: { showSuccessFeedback() },
                                         onRetryFeedback: { showRetryFeedback() })

                    ControlBar(resetAction: { resetSignal &+= 1 })
                }
                .onChange(of: viewModel.targetText) { _ in
                    layoutKey = ""
                    feedback = nil
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let bubble = feedback {
                    FeedbackBubbleView(message: bubble)
                        .padding(.top, 8)
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func strokePreference(for difficulty: PracticeDifficulty) -> StrokeSizePreference {
        switch difficulty {
        case .easy: return .large
        case .medium: return .standard
        case .hard: return .compact
        }
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

private struct ControlBar: View {
    let resetAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: resetAction) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Reference Line

private struct ReferenceLineView: View {
    let layout: WordLayout
    let currentIndex: Int
    let animationToken: Int
    let letterStates: [LetterState]

    @State private var strokeProgress: [CGFloat] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.segments.enumerated()), id: \.1.id) { index, segment in
                if segment.strokes.isEmpty {
                    Text(display(for: segment))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.68, green: 0.74, blue: 0.86))
                        .position(x: segment.frame.midX,
                                  y: layout.ascender / 2)
                } else {
                    let color = referenceColor(for: index)
                    ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { strokeIndex, stroke in
                        stroke.path
                            .trim(from: 0, to: trimAmount(for: index, strokeIndex: strokeIndex))
                            .stroke(color,
                                    style: StrokeStyle(lineWidth: segment.lineWidth,
                                                       lineCap: .round,
                                                       lineJoin: .round))
                    }
                }
            }
        }
        .frame(height: layout.height + 12)
        .onAppear { animateCurrentLetter() }
        .onChange(of: animationToken) { _ in
            animateCurrentLetter()
        }
        .drawingGroup()
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

    private func display(for segment: WordLayout.Segment) -> String {
        if segment.item.character == " " { return "⎵" }
        return String(segment.item.character).uppercased()
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
    let resetSignal: Int
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

    private var canvasHeight: CGFloat {
        metrics.canvasHeight
    }

    private var currentSegment: WordLayout.Segment? {
        layout.segments[safe: currentIndex]
    }

    private var expectedStrokeCount: Int {
        currentSegment?.strokes.count ?? 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
        .frame(height: canvasHeight)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        .onChange(of: layout.cacheKey) { _ in
            resetCanvas()
        }
        .onChange(of: currentIndex) { _ in
            drawing = PKDrawing()
            previousStrokeCount = 0
            currentStrokeIndex = 0
        }
        .onChange(of: resetSignal) { _ in
            resetCurrentLetter()
        }
    }

    private func resetCanvas() {
        drawing = PKDrawing()
        frozenDrawing = PKDrawing()
        warningMessage = nil
        previousStrokeCount = 0
        currentStrokeIndex = 0
    }

    private func resetCurrentLetter() {
        drawing = PKDrawing()
        previousStrokeCount = 0
        currentStrokeIndex = 0
        warningMessage = nil
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

            currentStrokeIndex = min(strokeIndex + 1, segment.strokes.count)
            onStrokeValidated(strokeIndex, segment.strokes.count)
            onSuccessFeedback()
            if hapticsEnabled {
                HapticsManager.shared.success()
            }
        }

        previousStrokeCount = strokes.count

        if strokes.count >= segment.strokes.count {
            completeLetter()
        }
    }

    private func validateStartPoint(for stroke: PKStroke, templateStroke: ScaledStroke) -> Bool {
        guard let firstPoint = stroke.path.firstLocation else { return false }
        let tolerance = metrics.startTolerance(for: difficulty)
        let isValid = StartPointGate.isStartValid(startPoint: firstPoint,
                                                 expectedStart: templateStroke.startPoint,
                                                 tolerance: tolerance)
        if !isValid {
            showWarning("Start at the green dot")
        }
        return isValid
    }

    private func validateDeviation(for stroke: PKStroke, templateStroke: ScaledStroke) -> Bool {
        let userPoints = stroke.sampledPoints(step: 4)
        guard !userPoints.isEmpty else { return false }
        let tolerance = metrics.deviationTolerance(for: difficulty)

        var maxDistance: CGFloat = 0
        for point in userPoints {
            var nearest = CGFloat.greatestFiniteMagnitude
            for templatePoint in templateStroke.sampledPoints {
                let distance = hypot(point.x - templatePoint.x, point.y - templatePoint.y)
                nearest = min(nearest, distance)
                if nearest < tolerance / 2 {
                    break
                }
            }
            maxDistance = max(maxDistance, nearest)
            if maxDistance > tolerance {
                break
            }
        }
        return maxDistance <= tolerance
    }

    private func showWarning(_ message: String) {
        onWarning()
        onRetryFeedback()
        warningMessage = message
        if hapticsEnabled {
            HapticsManager.shared.warning()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                warningMessage = nil
            }
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.segments.enumerated()), id: \.1.id) { index, segment in
                if !segment.strokes.isEmpty {
                    let style = overlayStyle(for: index)
                    ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { strokeIndex, stroke in
                        stroke.path
                            .stroke(style.color.opacity(style.opacity),
                                    style: StrokeStyle(lineWidth: style.lineWidth,
                                                       lineCap: .round,
                                                       lineJoin: .round,
                                                       dash: guidesEnabled ? style.dash : []))
                    }
                    if guidesEnabled {
                        if index == currentIndex {
                            if currentStrokeIndex < segment.strokes.count {
                                let activeStroke = segment.strokes[currentStrokeIndex]
                                StartDot(position: activeStroke.startPoint,
                                         diameter: metrics.startDotSize)
                                EndDot(position: activeStroke.endPoint,
                                       diameter: metrics.startDotSize * 0.9)
                            } else if let finalStroke = segment.strokes.last {
                                EndDot(position: finalStroke.endPoint,
                                       diameter: metrics.startDotSize * 0.9)
                            }
                        } else if index < currentIndex, let finalStroke = segment.strokes.last {
                            EndDot(position: finalStroke.endPoint,
                                   diameter: metrics.startDotSize * 0.7)
                        }
                    }
                }
            }
        }
    }

    private func overlayStyle(for index: Int) -> (color: Color, opacity: Double, lineWidth: CGFloat, dash: [CGFloat]) {
        if index < currentIndex {
            return (Color(red: 0.38, green: 0.68, blue: 0.49), 0.9, metrics.practiceLineWidth, [])
        }
        if index == currentIndex {
            return (Color(red: 0.33, green: 0.53, blue: 0.92), guidesEnabled ? 0.7 : 0.35, guidesEnabled ? metrics.guideLineWidth : metrics.practiceLineWidth, guidesEnabled ? [12, 14] : [])
        }
        return (Color(red: 0.78, green: 0.84, blue: 0.95), guidesEnabled ? 0.5 : 0.2, guidesEnabled ? metrics.guideLineWidth : metrics.practiceLineWidth, guidesEnabled ? [16, 16] : [])
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
            let scale: CGFloat
            let width: CGFloat
            let lineWidth: CGFloat
        }

        var descriptors: [Descriptor] = []
        var rawWidths: [CGFloat] = []
        var scaledXHeight: CGFloat = 0

        for item in items {
            if let template = item.template {
                let sorted = template.strokes.sorted { $0.order < $1.order }
                let allPoints = sorted.flatMap { $0.points }
                let minX = allPoints.map(\.x).min() ?? 0
                let maxX = allPoints.map(\.x).max() ?? 0
                let baseScale = rowAscender / CGFloat(max(template.metrics.ascender, 1))
                let width = CGFloat(maxX - minX) * baseScale
                let descriptor = Descriptor(item: item,
                                            strokes: sorted,
                                            minX: CGFloat(minX),
                                            maxX: CGFloat(maxX),
                                            scale: baseScale,
                                            width: width,
                                            lineWidth: metrics.practiceLineWidth)
                descriptors.append(descriptor)
                rawWidths.append(width)
                if scaledXHeight == 0 {
                    let xRatio = CGFloat(template.metrics.xHeight / template.metrics.ascender)
                    scaledXHeight = rowAscender * xRatio
                }
            } else {
                descriptors.append(Descriptor(item: item,
                                              strokes: [],
                                              minX: 0,
                                              maxX: 0,
                                              scale: 1,
                                              width: item.isSpace ? baseSpaceWidth : baseSpacing,
                                            lineWidth: metrics.practiceLineWidth))
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
                                        lineWidth: descriptor.lineWidth))
            } else {
                var scaledStrokes: [ScaledStroke] = []
                let scale = descriptor.scale * compression
                let minX = descriptor.minX
                let segmentFrame = CGRect(x: cursor,
                                          y: 0,
                                          width: segmentWidth,
                                          height: totalHeight)

                for stroke in descriptor.strokes {
                    let convertedPoints = stroke.points.map { point in
                        WordLayout.convert(point: point,
                                           minX: minX,
                                           scale: scale,
                                           cursor: cursor,
                                           ascender: rowAscender,
                                           isLeftHanded: isLeftHanded,
                                           segmentWidth: segmentWidth)
                    }
                    var path = Path()
                    if let first = convertedPoints.first {
                        path.move(to: first)
                        path.addLines(Array(convertedPoints.dropFirst()))
                    }
                    let startPoint = WordLayout.convert(point: stroke.start ?? stroke.points.first ?? .zero,
                                                        minX: minX,
                                                        scale: scale,
                                                        cursor: cursor,
                                                        ascender: rowAscender,
                                                        isLeftHanded: isLeftHanded,
                                                        segmentWidth: segmentWidth)
                    let endPoint = WordLayout.convert(point: stroke.end ?? stroke.points.last ?? .zero,
                                                      minX: minX,
                                                      scale: scale,
                                                      cursor: cursor,
                                                      ascender: rowAscender,
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
                                        lineWidth: descriptor.lineWidth))
            }
            cursor += segmentWidth + baseSpacing * compression
        }

        self.segments = segments
        self.scaledXHeight = scaledXHeight == 0 ? rowAscender * 0.6 : scaledXHeight
        self.ascender = rowAscender
        self.descender = rowDescender
        self.width = availableWidth
        self.height = totalHeight
        self.leadingInset = leadingInsetValue
        self.cacheKey = "\(items.map { $0.character })|\(availableWidth)|\(rowAscender)|\(isLeftHanded)"
    }

    private static func convert(point: CGPoint,
                                minX: CGFloat,
                                scale: CGFloat,
                                cursor: CGFloat,
                                ascender: CGFloat,
                                isLeftHanded: Bool,
                                segmentWidth: CGFloat) -> CGPoint {
        var x = (CGFloat(point.x) - minX) * scale
        if isLeftHanded {
            x = segmentWidth - x
        }
        let y = ascender - CGFloat(point.y) * scale
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
        switch difficulty {
        case .easy: return base * 1.6
        case .medium: return base
        case .hard: return base * 0.7
        }
    }

    func deviationTolerance(for difficulty: PracticeDifficulty) -> CGFloat {
        let base: CGFloat = 40 * (rowMetrics.ascender / StrokeSizePreference.standard.metrics.ascender)
        switch difficulty {
        case .easy: return base * 1.6
        case .medium: return base
        case .hard: return base * 0.65
        }
    }
}
