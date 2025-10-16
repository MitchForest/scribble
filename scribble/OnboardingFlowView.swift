import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    private typealias Palette = ScribbleColors

    enum ExperienceLevel: String, CaseIterable, Identifiable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .beginner:
                return "I'm brand new to cursive and ready to learn."
            case .intermediate:
                return "I know some letters and want to improve."
            case .advanced:
                return "I'm already advanced but want to become a pro."
            }
        }

        var defaultLettersPerDay: Int {
            switch self {
            case .beginner: return 45
            case .intermediate: return 80
            case .advanced: return 115
            }
        }

        var defaultDifficulty: PracticeDifficulty {
            switch self {
            case .beginner: return .beginner
            case .intermediate: return .intermediate
            case .advanced: return .expert
            }
        }

    }

    struct Weekday: Identifiable, Hashable {
        let symbol: String
        let fullName: String
        let order: Int

        static let all: [Weekday] = [
            Weekday(symbol: "Mon", fullName: "Monday", order: 0),
            Weekday(symbol: "Tue", fullName: "Tuesday", order: 1),
            Weekday(symbol: "Wed", fullName: "Wednesday", order: 2),
            Weekday(symbol: "Thu", fullName: "Thursday", order: 3),
            Weekday(symbol: "Fri", fullName: "Friday", order: 4),
            Weekday(symbol: "Sat", fullName: "Saturday", order: 5),
            Weekday(symbol: "Sun", fullName: "Sunday", order: 6)
        ]

        static let defaultSelection: Set<Weekday> = Set(all.filter { $0.order < 5 })

        var id: Int { order }
    }

    private enum Step: Int, CaseIterable, Identifiable {
        case name
        case age
        case avatar
        case skillLevel
        case goals

        var id: Int { rawValue }
    }

    let onFinish: () -> Void

    @State private var currentStep: Step = .name
    @State private var name: String = ""
    @State private var age: Int = 8
    @State private var experience: ExperienceLevel?
    @State private var selectedDays: Set<Weekday> = Weekday.defaultSelection
    @State private var lettersPerDay: Int = ExperienceLevel.beginner.defaultLettersPerDay
    @State private var avatarOptions: [String] = []
    @State private var selectedAvatarSeed: String?

    @FocusState private var nameFieldFocused: Bool

    private let secondsPerLetter = 5
    private let ageRange = 5...12

    private var totalSteps: Int { Step.allCases.count }
    private var stepIndex: Int { Step.allCases.firstIndex(of: currentStep) ?? 0 }

    private var goalSeconds: Int {
        max(lettersPerDay * secondsPerLetter, secondsPerLetter)
    }

    private var canProceed: Bool {
        switch currentStep {
        case .name:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .age:
            return ageRange.contains(age)
        case .avatar:
            return selectedAvatarSeed != nil
        case .skillLevel:
            return experience != nil
        case .goals:
            return !selectedDays.isEmpty && lettersPerDay > 0
        }
    }

    private var nextButtonTitle: String {
        currentStep == .goals ? "Start Scribbling" : "Next"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.backgroundTop, Palette.backgroundBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let step = currentStep
                let verticalPadding = max(proxy.size.height * verticalPaddingFactor(for: step), 24)
                let availableHeight = max(proxy.size.height - (verticalPadding * 2), 320)
                let cardMinHeight = cardMinimumHeight(for: step)
                let effectiveMinHeight = min(cardMinHeight, availableHeight)
                let verticalInsets = cardVerticalPadding(for: step)
                let navigationSpacing = cardNavigationSpacing(for: step)
                let intrinsicHeight = intrinsicCardHeight(for: step, verticalInsets: verticalInsets)
                let cappedIntrinsic = min(cardMaximumHeight(for: step, containerHeight: proxy.size.height), intrinsicHeight)
                let desiredHeight = min(cappedIntrinsic, availableHeight)
                let candidateHeight = max(effectiveMinHeight, desiredHeight)
                let cardHeight = adjustedCardHeight(for: step,
                                                    candidate: candidateHeight,
                                                    minimum: effectiveMinHeight)
                let cardWidth = min(cardPreferredWidth(for: step), max(proxy.size.width - 48, 360))

                VStack {
                    Spacer(minLength: verticalPadding)

                    VStack(spacing: navigationSpacing) {
                        cardContent(for: step,
                                    cardMinHeight: effectiveMinHeight,
                                    cardHeight: cardHeight)
                            .transition(.move(edge: .trailing).combined(with: .opacity))

                        navigationFloor(for: step)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, verticalInsets)
                    .frame(maxWidth: cardWidth)
                    .frame(minHeight: effectiveMinHeight,
                           maxHeight: cardHeight,
                           alignment: .top)
                    .background(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(Palette.cardBackground)
                            .shadow(color: Palette.shadow.opacity(0.18), radius: 28, x: 0, y: 18)
                    )
                    .padding(.horizontal, 24)

                    Spacer(minLength: verticalPadding)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2), value: currentStep)
        .onAppear {
            prepareInitialState()
        }
        .onChange(of: experience) { _, newValue in
            if let level = newValue {
                lettersPerDay = level.defaultLettersPerDay
            }
        }
    }

    @ViewBuilder
    private func stepView(for step: Step) -> some View {
        switch step {
        case .name:
            NameStepView(name: $name,
                         isFocused: $nameFieldFocused,
                         onSubmit: advanceIfPossible)
        case .age:
            AgeStepView(age: $age, range: ageRange)
        case .avatar:
            AvatarStepView(seeds: avatarOptions,
                           selectedSeed: $selectedAvatarSeed,
                           onShuffle: { regenerateAvatarOptions(force: true) })
        case .skillLevel:
            SkillLevelStepView(experience: $experience)
        case .goals:
            GoalsStepView(selectedDays: $selectedDays,
                          lettersPerDay: $lettersPerDay,
                          goalSeconds: goalSeconds)
        }
    }

    @ViewBuilder
    private func navigationFloor(for step: Step) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                KidSecondaryButton(title: "Back", isEnabled: step != .name) {
                    goToPreviousStep()
                }
                KidPrimaryButton(title: nextButtonTitle, isEnabled: canProceed) {
                    advanceIfPossible()
                }
            }

            if step == .name {
                Button(action: completeOnboarding) {
                    Text("Skip for now")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.secondary)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }

            ProgressDots(totalSteps: totalSteps, currentStepIndex: stepIndex)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func intrinsicCardHeight(for step: Step, verticalInsets: CGFloat) -> CGFloat {
        preferredContentHeight(for: step) + navigationReservedHeight(for: step) + (verticalInsets * 2)
    }



    private func cardMinimumHeight(for step: Step) -> CGFloat {
        switch step {
        case .name: return 260
        case .age: return 280
        case .avatar: return 540
        case .skillLevel: return 420
        case .goals: return 520
        }
    }

    private func cardMaximumHeight(for step: Step, containerHeight: CGFloat) -> CGFloat {
        let factor: CGFloat
        let cap: CGFloat
        switch step {
        case .avatar:
            factor = 0.9
            cap = 780
        case .goals:
            factor = 0.88
            cap = 740
        case .skillLevel:
            factor = 0.82
            cap = 700
        case .age:
            factor = 0.76
            cap = 620
        case .name:
            factor = 0.72
            cap = 580
        }
        let computed = containerHeight * factor
        return min(max(computed, cardMinimumHeight(for: step) + 40), cap)
    }

    private func verticalPaddingFactor(for step: Step) -> CGFloat {
        switch step {
        case .avatar, .goals:
            return 0.05
        case .skillLevel:
            return 0.055
        case .age, .name:
            return 0.06
        }
    }

    private func cardPreferredWidth(for step: Step) -> CGFloat {
        switch step {
        case .name: return 520
        case .age: return 540
        case .avatar: return 680
        case .skillLevel: return 640
        case .goals: return 720
        }
    }

    private func adjustedCardHeight(for step: Step,
                                    candidate: CGFloat,
                                    minimum: CGFloat) -> CGFloat {
        switch step {
        case .name:
            return min(candidate, minimum + 24)
        case .age:
            return min(candidate, minimum + 28)
        default:
            return candidate
        }
    }

    private func cardVerticalPadding(for step: Step) -> CGFloat {
        switch step {
        case .avatar: return 30
        case .goals: return 28
        case .skillLevel: return 28
        case .age: return 18
        case .name: return 16
        }
    }

    private func cardNavigationSpacing(for step: Step) -> CGFloat {
        switch step {
        case .name: return 16
        case .age: return 22
        case .skillLevel: return 28
        case .goals: return 28
        case .avatar: return 32
        }
    }

    private func preferredContentHeight(for step: Step) -> CGFloat {
        switch step {
        case .name: return 200
        case .age: return 240
        case .skillLevel: return 400
        case .avatar: return 640
        case .goals: return 600
        }
    }

    private func navigationReservedHeight(for step: Step) -> CGFloat {
        switch step {
        case .avatar: return 210
        case .goals: return 220
        case .skillLevel: return 190
        case .age, .name: return 120
        }
    }
    
    @ViewBuilder
    private func cardContent(for step: Step,
                             cardMinHeight: CGFloat,
                             cardHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            stepView(for: step)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func prepareInitialState() {
        if avatarOptions.isEmpty {
            regenerateAvatarOptions()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            nameFieldFocused = true
        }
    }

    private func advanceIfPossible() {
        guard canProceed else { return }

        if currentStep == .name {
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if currentStep == .goals {
            completeOnboarding()
            return
        }

        if let nextIndex = Step.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
           nextIndex < Step.allCases.endIndex {
            currentStep = Step.allCases[nextIndex]
            triggerStepChangeHaptic()
        }

        if currentStep != .name {
            nameFieldFocused = false
        }
    }

    private func goToPreviousStep() {
        guard let currentIndex = Step.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }

        let previousStep = Step.allCases[currentIndex - 1]
        currentStep = previousStep
        triggerStepChangeHaptic()

        if previousStep == .name {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFieldFocused = true
            }
        }
    }

    private func regenerateAvatarOptions(force: Bool = false) {
        if !force,
           !avatarOptions.isEmpty {
            return
        }

        var seeds: Set<String> = []
        while seeds.count < 4 {
            seeds.insert(OnboardingFlowView.randomSeed())
        }
        avatarOptions = Array(seeds)

        if let selected = selectedAvatarSeed, avatarOptions.contains(selected) {
            return
        }
        selectedAvatarSeed = avatarOptions.first
    }

    private func completeOnboarding() {
        let chosenExperience = experience ?? .beginner
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            dataStore.updateDisplayName(trimmedName)
        }

        let finalAvatar = selectedAvatarSeed ?? OnboardingFlowView.randomSeed()
        dataStore.updateAvatarSeed(finalAvatar)

        dataStore.updateDifficulty(chosenExperience.defaultDifficulty)
        dataStore.updateGoalSeconds(goalSeconds)

        var goal = dataStore.profile.goal
        let indices = Set(selectedDays.map { $0.order })
        goal.activeWeekdayIndices = indices
        dataStore.updateGoal(goal)

        onFinish()
    }

    private func triggerStepChangeHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private static func randomSeed() -> String {
        let tags = ["hero", "heroine", "explorer"]
        let prefix = tags.randomElement() ?? "hero"
        return "\(prefix)-\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - Palette

private enum Palette {
    static let backgroundTop = Color(red: 0.97, green: 0.99, blue: 1.0)
    static let backgroundBottom = Color(red: 0.95, green: 0.95, blue: 1.0)
    static let cardBackground = Color.white.opacity(0.95)
    static let shadow = Color.black.opacity(0.08)

    static let primary = Color(red: 0.24, green: 0.33, blue: 0.57)
    static let secondary = Color(red: 0.46, green: 0.55, blue: 0.72)

    static let accent = Color(red: 1.0, green: 0.82, blue: 0.4)
    static let accentDark = Color(red: 0.93, green: 0.63, blue: 0.28)

    static let inputBackground = Color.white.opacity(0.96)
    static let inputBorder = Color(red: 0.78, green: 0.86, blue: 1.0).opacity(0.85)
    static let controlDisabled = Color(red: 0.85, green: 0.9, blue: 0.98).opacity(0.6)
}

// MARK: - Step Views

private struct NameStepView: View {
    @Binding var name: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("What's your name?")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("We'll use this to cheer you on.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            ZStack(alignment: .leading) {
                if name.isEmpty {
                    Text("Type your name here")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.primary.opacity(0.68))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                }

                TextField("", text: $name)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .foregroundColor(Palette.primary)
                    .tint(Palette.accentDark)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(name.isEmpty ? Palette.inputBorder : Palette.accent, lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
                    .focused(isFocused)
                    .accessibilityLabel("Name")
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
            }
        }
    }
}

private struct AgeStepView: View {
    @Binding var age: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("How old are you?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)

                Text("Select your age, then tap Next.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
            }

            HStack(spacing: 32) {
                KidRoundButton(systemName: "minus", isEnabled: age > range.lowerBound) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        age = max(range.lowerBound, age - 1)
                    }
                }

                Text("\(age)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .frame(minWidth: 120)

                KidRoundButton(systemName: "plus", isEnabled: age < range.upperBound) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        age = min(range.upperBound, age + 1)
                    }
                }
            }
        }
    }
}

private struct AvatarStepView: View {
    let seeds: [String]
    @Binding var selectedSeed: String?
    let onShuffle: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("Choose your avatar")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("Tap the picture you like. You can shuffle for more.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 18)], spacing: 18) {
                ForEach(seeds, id: \.self) { seed in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedSeed = seed
                        }
                    } label: {
                        avatarCard(for: seed)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onShuffle) {
                HStack(spacing: 10) {
                    Image(systemName: "shuffle")
                    Text("Shuffle buddies")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundColor(Palette.accentDark)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Palette.accent.opacity(0.28))
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func avatarCard(for seed: String) -> some View {
        VStack(spacing: 14) {
            DiceBearAvatar(seed: seed, size: 132)
                .overlay(
                    Circle()
                        .stroke(selectedSeed == seed ? Palette.accent : Color.clear, lineWidth: 6)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)

            Text(selectedSeed == seed ? "This one!" : "Pick me")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(selectedSeed == seed ? Palette.inputBackground : Color.white)
        )
        .shadow(color: Color.black.opacity(selectedSeed == seed ? 0.16 : 0.08),
                radius: selectedSeed == seed ? 16 : 12,
                x: 0,
                y: selectedSeed == seed ? 12 : 8)
    }
}

private struct SkillLevelStepView: View {
    @Binding var experience: OnboardingFlowView.ExperienceLevel?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("What's your skill level?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("We’ll tailor lessons and difficulty for you.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
                ForEach(OnboardingFlowView.ExperienceLevel.allCases) { level in
                    KidSelectableOption(title: level.rawValue,
                                        subtitle: level.description,
                                        symbolName: symbol(for: level),
                                        symbolColor: color(for: level),
                                        isSelected: experience == level) {
                        experience = level
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func symbol(for level: OnboardingFlowView.ExperienceLevel) -> String {
        switch level {
        case .beginner: return "lightbulb.fill"
        case .intermediate: return "pencil.circle.fill"
        case .advanced: return "star.fill"
        }
    }

    private func color(for level: OnboardingFlowView.ExperienceLevel) -> Color {
        switch level {
        case .beginner: return Color(red: 0.95, green: 0.89, blue: 1.0)
        case .intermediate: return Color(red: 0.86, green: 0.93, blue: 1.0)
        case .advanced: return Color(red: 1.0, green: 0.88, blue: 0.74)
        }
    }
}

private struct GoalsStepView: View {
    @Binding var selectedDays: Set<OnboardingFlowView.Weekday>
    @Binding var lettersPerDay: Int
    let goalSeconds: Int

    private let sliderRange: ClosedRange<Double> = 20...150

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Set your goals")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("Choose your practice days and daily letters.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            adaptiveGoalContent()
        }
    }

    @ViewBuilder
    private func adaptiveGoalContent() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            ViewThatFits(in: .vertical) {
                wideGoalLayout()
                stackedGoalLayout()
            }
        } else {
            stackedGoalLayout()
        }
    }

    @ViewBuilder
    private func wideGoalLayout() -> some View {
        HStack(alignment: .top, spacing: 32) {
            dayPicker()
                .frame(maxWidth: .infinity, alignment: .leading)
            sliderControls()
                .frame(maxWidth: 320, alignment: .leading)
        }
    }

    @ViewBuilder
    private func stackedGoalLayout() -> some View {
        VStack(spacing: 24) {
            dayPicker()
            sliderControls()
        }
    }

    @ViewBuilder
    private func dayPicker() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice days")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(OnboardingFlowView.Weekday.all) { day in
                    KidDayButton(day: day, isSelected: selectedDays.contains(day)) {
                        toggle(day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sliderControls() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letters each practice day")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primary)

            VStack(spacing: 12) {
                Slider(value: Binding(
                    get: { Double(lettersPerDay) },
                    set: { lettersPerDay = Int($0) }
                ), in: sliderRange, step: 5)
                .tint(Palette.accent)

                Text("\(lettersPerDay) letters ≈ \(formatDuration(goalSeconds))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func toggle(_ day: OnboardingFlowView.Weekday) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        switch (minutes, remainder) {
        case (0, _):
            return "\(seconds) sec"
        case (_, 0):
            return "\(minutes) min"
        default:
            return "\(minutes) min \(remainder) sec"
        }
    }
}

// MARK: - Shared Components

private struct KidPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.accentDark)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(isEnabled ? Palette.accent : Palette.accent.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(isEnabled ? Palette.accentDark.opacity(0.2) : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .shadow(color: Color.black.opacity(isEnabled ? 0.12 : 0.04), radius: isEnabled ? 18 : 4, x: 0, y: isEnabled ? 10 : 2)
    }
}

private struct KidSecondaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(isEnabled ? Palette.secondary : Palette.secondary.opacity(0.4))
                .frame(width: 120, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(isEnabled ? 0.9 : 0.4), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct KidRoundButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(isEnabled ? Palette.accentDark : Palette.secondary.opacity(0.5))
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(isEnabled ? Palette.accent.opacity(0.4) : Palette.controlDisabled)
                )
                .overlay(
                    Circle()
                        .stroke(isEnabled ? Palette.accent : Color.clear, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct KidSelectableOption: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let symbolColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(symbolColor.opacity(0.85))
                        .frame(width: 64, height: 64)

                    Image(systemName: symbolName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Palette.primary.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.primary)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Palette.accent)
                        .font(.system(size: 32, weight: .bold))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(isSelected ? Palette.inputBackground : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Color.white.opacity(0.0), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.07),
                    radius: isSelected ? 18 : 12,
                    x: 0,
                    y: isSelected ? 12 : 8)
        }
        .buttonStyle(.plain)
    }
}

private struct KidDayButton: View {
    let day: OnboardingFlowView.Weekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(day.symbol)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? Palette.accentDark : Palette.primary)
                Text(day.fullName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? Palette.accentDark.opacity(0.8) : Palette.secondary.opacity(0.7))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Palette.accent.opacity(0.4) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Color.white.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05),
                    radius: isSelected ? 14 : 8,
                    x: 0,
                    y: isSelected ? 10 : 6)
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressDots: View {
    let totalSteps: Int
    let currentStepIndex: Int

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStepIndex ? Palette.accent : Palette.controlDisabled)
                    .frame(width: index == currentStepIndex ? 18 : 16, height: index == currentStepIndex ? 18 : 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .scaleEffect(index == currentStepIndex ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStepIndex)
            }
        }
    }
}
