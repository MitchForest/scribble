import SwiftUI
import UIKit

private enum StageBadgeState {
    case pending
    case current
    case passed
    case failed

    var background: Color {
        switch self {
        case .passed:
            return Color.green.opacity(0.85)
        case .failed:
            return Color.red.opacity(0.85)
        case .current:
            return Color.accentColor.opacity(0.18)
        case .pending:
            return Color.clear
        }
    }

    var border: Color? {
        switch self {
        case .current:
            return Color.accentColor
        case .pending:
            return Color.primary.opacity(0.25)
        default:
            return nil
        }
    }

    var iconName: String? {
        switch self {
        case .passed:
            return "checkmark"
        case .failed:
            return "xmark"
        default:
            return nil
        }
    }

    var iconColor: Color {
        switch self {
        case .passed, .failed:
            return .white
        case .current:
            return .accentColor
        case .pending:
            return .clear
        }
    }
}

private enum LetterAggregateStatus {
    case pending
    case passed
    case failed

    var symbolName: String? {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .pending: return nil
        }
    }

    var symbolColor: Color {
        switch self {
        case .passed: return Color.green
        case .failed: return Color.red
        case .pending: return .clear
        }
    }
}

struct PracticeFlowView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore

    private let letters = PracticeDataStore.focusLetters

    @State private var currentLetterIndex: Int
    @State private var furthestVisitedIndex: Int
    @State private var currentStage: PracticeStage = .guidedTrace
    @State private var currentTemplate: HandwritingTemplate?
    @State private var stageResults: [PracticeStage: StageOutcome] = [:]
    @State private var letterStart = Date()
    @State private var failCounts: [String: Int] = [:]
    @State private var isSessionComplete = false
    @State private var letterTemplates: [String: HandwritingTemplate] = [:]
    @State private var showSettingsSheet = false
    @State private var showQuickSettingsMenu = false
    @State private var hasInitialized = false
    @State private var canSwipeToAdvance = false
    @State private var showSwipeHint = false
    @State private var swipeTransitionOffset: CGFloat = 0
    @State private var activeDragOffset: CGFloat = 0
    @State private var swipeAnimationInFlight = false

    init(startingLetter: String? = nil) {
        let index = startingLetter.flatMap { PracticeDataStore.focusLetters.firstIndex(of: $0) } ?? 0
        _currentLetterIndex = State(initialValue: index)
        _furthestVisitedIndex = State(initialValue: index)
    }

    private var currentLetterId: String {
        letters[currentLetterIndex]
    }

    private var allowFingerInput: Bool {
        dataStore.settings.inputPreference.allowsFingerInput
    }

    private var currentStrokeSize: StrokeSizePreference {
        dataStore.settings.strokeSize
    }

    private var sessionIdentity: String {
        let handed = dataStore.settings.isLeftHanded ? "L" : "R"
        return "\(currentLetterId)|\(currentStrokeSize.rawValue)|\(handed)"
    }

    private var hasNextLetter: Bool {
        currentLetterIndex + 1 < letters.count
    }

    private var inputPreferenceBinding: Binding<InputPreference> {
        Binding(
            get: { dataStore.settings.inputPreference },
            set: { dataStore.updateInputPreference($0) }
        )
    }

    private var leftHandBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settings.isLeftHanded },
            set: { dataStore.updateLeftHanded($0) }
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 1.0, green: 0.96, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .trailing) {
                    VStack(spacing: 24) {
                        letterStrip

                        if isSessionComplete {
                            completionScreen
                                .padding(.top, 24)
                        } else if let template = currentTemplate {
                            PracticeSessionView(letterId: currentLetterId,
                                                template: template,
                                                stage: $currentStage,
                                                allowFingerInput: allowFingerInput,
                                                isLeftHanded: dataStore.settings.isLeftHanded,
                                                strokeSize: currentStrokeSize,
                                                difficulty: dataStore.settings.difficulty,
                                                hapticsEnabled: dataStore.settings.hapticsEnabled,
                                                onStageComplete: handleStageOutcome)
                                .padding(.vertical, 24)
                                .padding(.horizontal, 16)
                                .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.92)))
                                .padding(.horizontal, 20)
                                .id(sessionIdentity)
                        } else {
                            ProgressView()
                                .padding(.top, 32)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .offset(x: swipeTransitionOffset + activeDragOffset)
                    .gesture(swipeGesture(for: width))

                    if showSwipeHint && canSwipeToAdvance && hasNextLetter && !isSessionComplete {
                        SwipeHintView()
                            .padding(.trailing, 36)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQuickSettingsMenu = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(Color(red: 0.32, green: 0.39, blue: 0.54))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showQuickSettingsMenu) {
            PracticeQuickSettingsSheet(
                inputPreference: inputPreferenceBinding,
                isLeftHanded: leftHandBinding,
                onOpenSettings: {
                    showQuickSettingsMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showSettingsSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .environmentObject(dataStore)
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                ensureTemplatesLoaded()
                resetForCurrentLetter(startNewAttempt: true)
            } else {
                ensureTemplatesLoaded()
                if currentTemplate == nil {
                    loadTemplate()
                }
            }
        }
        .onChange(of: dataStore.settings.strokeSize) {
            resetForCurrentLetter(startNewAttempt: true)
        }
        .onChange(of: dataStore.settings.isLeftHanded) {
            resetForCurrentLetter(startNewAttempt: true)
        }
        .onChange(of: dataStore.settings.inputPreference) {
            resetForCurrentLetter(startNewAttempt: false)
        }
    }

    private func swipeGesture(for width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard canSwipeToAdvance && hasNextLetter && !swipeAnimationInFlight else { return }
                let translation = max(0, value.translation.width)
                activeDragOffset = translation
                showSwipeHint = false
            }
            .onEnded { value in
                let translation = max(0, value.translation.width)
                let shouldAdvance = canSwipeToAdvance && hasNextLetter && translation > max(80, width * 0.2)
                if shouldAdvance {
                    activeDragOffset = 0
                    triggerSwipeAdvance(width: width)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        activeDragOffset = 0
                    }
                }
            }
    }

    private func triggerSwipeAdvance(width: CGFloat) {
        guard hasNextLetter, !swipeAnimationInFlight else { return }
        swipeAnimationInFlight = true
        canSwipeToAdvance = false
        showSwipeHint = false
        let travel = width == 0 ? UIScreen.main.bounds.width : width
        withAnimation(.easeInOut(duration: 0.35)) {
            swipeTransitionOffset = -travel
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            advanceToNextLetter()
            swipeTransitionOffset = travel
            withAnimation(.easeInOut(duration: 0.35)) {
                swipeTransitionOffset = 0
            }
            swipeAnimationInFlight = false
        }
    }

    private func resetSwipeState() {
        canSwipeToAdvance = false
        if showSwipeHint {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSwipeHint = false
            }
        }
        activeDragOffset = 0
    }

    private var letterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    let isCurrent = index == currentLetterIndex && !isSessionComplete
                    let isLocked = index > furthestVisitedIndex
                    let aggregate = aggregateStatus(for: letter, index: index)
                    let stageStates = stageBadgeStates(for: letter, index: index)
                    LetterProgressCard(
                        template: letterTemplates[letter],
                        fallbackLetter: dataStore.displayName(for: letter),
                        isCurrent: isCurrent,
                        isLocked: isLocked,
                        aggregateStatus: aggregate,
                        stageStates: stageStates,
                        isLeftHanded: dataStore.settings.isLeftHanded,
                        action: { jumpToLetter(at: index) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var completionScreen: some View {
        VStack(spacing: 24) {
            Text("Great job!")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.28, green: 0.42, blue: 0.53))
            Text("You've practiced every letter in this flow.")
                .font(.title3)
                .foregroundColor(.secondary)
            Button {
                restartSession()
            } label: {
                Label("Practice Again", systemImage: "repeat")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.85)))
    }

    private func ensureTemplatesLoaded() {
        guard letterTemplates.count < letters.count else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [String: HandwritingTemplate] = [:]
            for letter in letters {
                if let template = try? HandwritingTemplateLoader.loadTemplate(for: letter) {
                    loaded[letter] = template
                }
            }
            DispatchQueue.main.async {
                letterTemplates.merge(loaded, uniquingKeysWith: { _, new in new })
            }
        }
    }

    private func resetForCurrentLetter(startNewAttempt: Bool) {
        if startNewAttempt {
            stageResults.removeAll()
            currentStage = .guidedTrace
            letterStart = Date()
        }
        resetSwipeState()
        swipeTransitionOffset = 0
        loadTemplate()
    }

    private func loadTemplate() {
        do {
            currentTemplate = try HandwritingTemplateLoader.loadTemplate(for: currentLetterId)
        } catch {
            currentTemplate = nil
        }
    }

    private func handleStageOutcome(_ outcome: StageOutcome) {
        stageResults[outcome.stage] = outcome

        if dataStore.settings.hapticsEnabled {
            if outcome.score.total >= 80 {
                HapticsManager.shared.success()
            } else {
                HapticsManager.shared.warning()
            }
        }

        switch outcome.stage {
        case .guidedTrace:
            currentStage = .dotGuided
        case .dotGuided:
            currentStage = .freePractice
        case .freePractice:
            finishLetter(with: outcome)
        }
    }

    private func finishLetter(with finalOutcome: StageOutcome) {
        let aggregate = aggregateScore() ?? finalOutcome.score
        let letterId = currentLetterId
        let completedAt = Date()
        let duration = completedAt.timeIntervalSince(letterStart)
        let pass = aggregate.total >= 80

        _ = dataStore.recordAttempt(letterId: letterId,
                                    mode: .memory,
                                    result: aggregate,
                                    tips: aggregatedTipIds(),
                                    hintUsed: false,
                                    drawingData: nil,
                                    duration: duration,
                                    startedAt: letterStart,
                                    completedAt: completedAt)

        let summaries = stageSummaryPayload()
        dataStore.recordFlowOutcome(letterId: letterId,
                                    aggregatedScore: aggregate,
                                    stageSummaries: summaries,
                                    completedAt: completedAt)

        if pass {
            failCounts[letterId] = 0
            if hasNextLetter {
                canSwipeToAdvance = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSwipeHint = true
                }
            } else {
                stageResults.removeAll()
                swipeTransitionOffset = 0
                resetSwipeState()
                isSessionComplete = true
            }
        } else {
            let failures = failCounts[letterId, default: 0] + 1
            failCounts[letterId] = failures
            if failures >= 3 {
                advanceToNextLetter()
            } else {
                resetForRetry()
            }
        }
    }

    private func advanceToNextLetter() {
        resetSwipeState()
        swipeTransitionOffset = 0
        swipeAnimationInFlight = false
        stageResults.removeAll()
        if hasNextLetter {
            currentLetterIndex += 1
            furthestVisitedIndex = max(furthestVisitedIndex, currentLetterIndex)
            currentStage = .guidedTrace
            letterStart = Date()
            loadTemplate()
        } else {
            isSessionComplete = true
        }
    }

    private func resetForRetry() {
        resetSwipeState()
        swipeTransitionOffset = 0
        stageResults.removeAll()
        currentStage = .guidedTrace
        letterStart = Date()
        loadTemplate()
    }

    private func restartSession() {
        isSessionComplete = false
        failCounts = [:]
        currentLetterIndex = 0
        furthestVisitedIndex = 0
        currentStage = .guidedTrace
        resetSwipeState()
        swipeTransitionOffset = 0
        stageResults.removeAll()
        letterStart = Date()
        loadTemplate()
    }

    private func jumpToLetter(at index: Int) {
        guard index != currentLetterIndex else { return }
        guard index <= furthestVisitedIndex else { return }
        currentLetterIndex = index
        failCounts[currentLetterId] = 0
        currentStage = .guidedTrace
        resetSwipeState()
        swipeTransitionOffset = 0
        stageResults.removeAll()
        letterStart = Date()
        isSessionComplete = false
        loadTemplate()
    }

    private func aggregateScore() -> ScoreResult? {
        let orderedStages = PracticeStage.allCases
        let outcomes = orderedStages.compactMap { stageResults[$0] }
        guard outcomes.count == orderedStages.count else { return nil }

        func average(_ keyPath: KeyPath<ScoreResult, Int>) -> Int {
            let sum = outcomes.reduce(0) { $0 + $1.score[keyPath: keyPath] }
            return Int((Double(sum) / Double(outcomes.count)).rounded())
        }

        return ScoreResult(
            total: average(\.total),
            shape: average(\.shape),
            order: average(\.order),
            direction: average(\.direction),
            start: average(\.start)
        )
    }

    private func aggregatedTipIds() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for stage in PracticeStage.allCases {
            guard let outcome = stageResults[stage] else { continue }
            for tip in outcome.tips {
                if seen.insert(tip.id).inserted {
                    result.append(tip.id)
                }
                if result.count == 2 { return result }
            }
        }
        return result
    }

    private func stageSummaryPayload() -> [StageAttemptSummary] {
        PracticeStage.allCases.compactMap { stage in
            guard let outcome = stageResults[stage] else { return nil }
            return StageAttemptSummary(stage: stage,
                                       score: outcome.score,
                                       durationMs: Int((outcome.duration * 1000).rounded()))
        }
    }

    private func stageBadgeStates(for letterId: String, index: Int) -> [StageBadgeState] {
        if index == currentLetterIndex && !isSessionComplete {
            return PracticeStage.allCases.map { stage in
                if let outcome = stageResults[stage] {
                    return outcome.score.total >= 80 ? .passed : .failed
                } else if stage == currentStage {
                    return .current
                } else if stage.rawValue < currentStage.rawValue {
                    if let outcome = stageResults[stage] {
                        return outcome.score.total >= 80 ? .passed : .failed
                    }
                    return .pending
                } else {
                    return .pending
                }
            }
        }

        if let outcome = dataStore.latestFlowOutcomes[letterId] {
            var map: [PracticeStage: StageBadgeState] = [:]
            for summary in outcome.stageSummaries {
                map[summary.stage] = summary.score.total >= 80 ? .passed : .failed
            }
            return PracticeStage.allCases.map { map[$0] ?? .pending }
        }

        return PracticeStage.allCases.map { _ in .pending }
    }

    private func aggregateStatus(for letterId: String, index: Int) -> LetterAggregateStatus {
        if index == currentLetterIndex && !isSessionComplete {
            return .pending
        }
        guard let outcome = dataStore.latestFlowOutcomes[letterId] else {
            return .pending
        }
        return outcome.aggregatedScore.total >= 80 ? .passed : .failed
    }
}

private struct SwipeHintView: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Swipe right to continue")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.22, green: 0.34, blue: 0.52))
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.22, green: 0.34, blue: 0.52))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.92))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

private struct PracticeQuickSettingsSheet: View {
    @Binding var inputPreference: InputPreference
    @Binding var isLeftHanded: Bool
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 58, height: 6)
                .padding(.top, 16)

            VStack(spacing: 10) {
                Text("Quick practice settings")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)

                Text("Change how you draw and which guides show up.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 18) {
                Text("Drawing input")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)

                VStack(spacing: 14) {
                    ForEach(InputPreference.allCases) { option in
                        ScribbleSelectableOption(
                            title: option.title,
                            subtitle: subtitle(for: option),
                            systemName: icon(for: option),
                            tint: tint(for: option),
                            isSelected: inputPreference == option
                        ) {
                            inputPreference = option
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Toggle(isOn: $isLeftHanded) {
                Text("Left-handed mode")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }
            .toggleStyle(ScribbleToggleStyle())
            .padding(.horizontal, 24)
            .accessibilityHint("Mirrors practice overlays and repositions buttons.")

            Button {
                dismiss()
                onOpenSettings()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Open full settings")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
                .foregroundColor(ScribbleColors.accentDark)
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                        .fill(ScribbleColors.accent.opacity(0.35))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary)
                    .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 24)
        .background(
            ScribbleColors.cardBackground
                .ignoresSafeArea()
        )
    }

    private func subtitle(for preference: InputPreference) -> String {
        switch preference {
        case .pencilOnly:
            return "Best for crisp strokes and pressure control."
        case .fingerAndPencil:
            return "Great when sharing or practicing without Pencil."
        }
    }

    private func icon(for preference: InputPreference) -> String {
        switch preference {
        case .pencilOnly:
            return "pencil.tip"
        case .fingerAndPencil:
            return "hand.draw"
        }
    }

    private func tint(for preference: InputPreference) -> Color {
        switch preference {
        case .pencilOnly:
            return Color(red: 0.83, green: 0.91, blue: 1.0)
        case .fingerAndPencil:
            return Color(red: 0.87, green: 0.96, blue: 0.87)
        }
    }
}

private struct LetterProgressCard: View {
    let template: HandwritingTemplate?
    let fallbackLetter: String
    let isCurrent: Bool
    let isLocked: Bool
    let aggregateStatus: LetterAggregateStatus
    let stageStates: [StageBadgeState]
    let isLeftHanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isLocked ? 0.4 : 0.92))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(isCurrent ? 0.0 : 0.08), lineWidth: 1)
                        )

                    if let template {
                        LetterGlyphView(template: template,
                                        isLeftHanded: isLeftHanded,
                                        strokeColor: Color(red: 0.22, green: 0.34, blue: 0.52),
                                        lineWidth: 5)
                            .frame(width: 48, height: 48)
                    } else {
                        Text(fallbackLetter.prefix(1))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.22, green: 0.34, blue: 0.52))
                    }

                    if let symbol = aggregateStatus.symbolName {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(aggregateStatus.symbolColor)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 26, height: 26)
                            )
                            .offset(x: 26, y: 26)
                    }

                    if isLocked {
                        Circle()
                            .fill(Color.black.opacity(0.28))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                }

                StageBadgeRow(states: stageStates)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.5 : 1.0)
    }
}

private struct StageBadgeRow: View {
    let states: [StageBadgeState]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                StageBadgeView(state: state)
            }
        }
    }
}

private struct StageBadgeView: View {
    let state: StageBadgeState

    var body: some View {
        ZStack {
            Circle()
                .fill(state.background)

            if let border = state.border {
                Circle()
                    .stroke(border, lineWidth: state == .current ? 1.8 : 1.2)
            } else if state == .pending {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            }

            switch state {
            case .passed, .failed:
                if let symbol = state.iconName {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(state.iconColor)
                }
            case .current:
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            case .pending:
                EmptyView()
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct LetterGlyphView: View {
    let template: HandwritingTemplate
    let isLeftHanded: Bool
    let strokeColor: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if let scaled = scaledTemplate(for: size) {
                ZStack {
                    ForEach(Array(scaled.strokes.enumerated()), id: \.offset) { _, stroke in
                        stroke.path
                            .stroke(strokeColor.opacity(0.9),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .center)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func scaledTemplate(for size: CGSize) -> ScaledTemplate? {
        guard size.width > 0, size.height > 0 else { return nil }
        let ascender = size.height * 0.65
        let descender = size.height * 0.25
        return ScaledTemplate(template: template,
                              availableWidth: size.width,
                              rowAscender: ascender,
                              rowDescender: descender,
                              isLeftHanded: isLeftHanded)
    }
}

private extension Color {
    func darker(by percentage: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: max(r - percentage, 0),
                     green: max(g - percentage, 0),
                     blue: max(b - percentage, 0),
                     opacity: Double(a))
    }
}
