import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    private typealias Palette = ScribbleColors

    enum Gender: String, CaseIterable, Identifiable {
        case male = "Boy"
        case female = "Girl"
        case unspecified = "Surprise me"

        var id: String { rawValue }

        var shortLabel: String {
            switch self {
            case .male: return "Boy"
            case .female: return "Girl"
            case .unspecified: return "Surprise me"
            }
        }

        var friendlyDescription: String {
            switch self {
            case .male: return "Use boy words like he/him."
            case .female: return "Use girl words like she/her."
            case .unspecified: return "Skip for now or choose later."
            }
        }

        var seedTag: String {
            switch self {
            case .male: return "hero"
            case .female: return "heroine"
            case .unspecified: return "explorer"
            }
        }
    }

    enum ExperienceLevel: String, CaseIterable, Identifiable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case expert = "Expert"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .beginner:
                return "I'm new to cursive and want friendly helpers."
            case .intermediate:
                return "I know some letters and want a good challenge."
            case .expert:
                return "I'm ready for tiny guides and fast feedback."
            }
        }

        var defaultLettersPerDay: Int {
            switch self {
            case .beginner: return 45
            case .intermediate: return 80
            case .expert: return 115
            }
        }

        var defaultDifficulty: PracticeDifficulty {
            switch self {
            case .beginner: return .beginner
            case .intermediate: return .intermediate
            case .expert: return .expert
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
        case gender
        case age
        case avatar
        case skillLevel
        case goals

        var id: Int { rawValue }
    }

    let onFinish: () -> Void

    @State private var currentStep: Step = .name
    @State private var name: String = ""
    @State private var gender: Gender?
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
        case .gender:
            return gender != nil
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
                let verticalPadding = max(proxy.size.height * 0.06, 24)
                let availableHeight = max(proxy.size.height - (verticalPadding * 2), 360)
                let cardMinHeight = cardMinimumHeight(for: step)
                let cardMaxHeight = min(max(availableHeight, cardMinHeight), cardMaximumHeight(for: step, containerHeight: proxy.size.height))
                let verticalInsets = cardVerticalPadding(for: step)
                let navigationSpacing = cardNavigationSpacing(for: step)

                VStack {
                    Spacer(minLength: verticalPadding)

                    VStack(spacing: navigationSpacing) {
                        cardContent(for: step,
                                    cardMinHeight: cardMinHeight,
                                    cardMaxHeight: cardMaxHeight)
                            .transition(.move(edge: .trailing).combined(with: .opacity))

                        navigationFloor(for: step)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, verticalInsets)
                    .frame(maxWidth: 560)
                    .frame(minHeight: cardMinHeight,
                           maxHeight: cardMaxHeight,
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
        .onChange(of: gender) { _, newValue in
            regenerateAvatarOptions(for: newValue)
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
        case .gender:
            GenderStepView(gender: $gender)
        case .age:
            AgeStepView(age: $age, range: ageRange)
        case .avatar:
            AvatarStepView(seeds: avatarOptions,
                           selectedSeed: $selectedAvatarSeed,
                           gender: gender,
                           onShuffle: { regenerateAvatarOptions(for: gender, force: true) })
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


    private func cardMinimumHeight(for step: Step) -> CGFloat {
        switch step {
        case .name: return 360
        case .age: return 380
        case .gender: return 420
        case .avatar: return 520
        case .skillLevel: return 440
        case .goals: return 500
        }
    }

    private func cardMaximumHeight(for step: Step, containerHeight: CGFloat) -> CGFloat {
        let factor: CGFloat
        let cap: CGFloat
        switch step {
        case .avatar:
            factor = 0.88
            cap = 780
        case .goals:
            factor = 0.84
            cap = 700
        case .gender, .skillLevel:
            factor = 0.8
            cap = 680
        case .age:
            factor = 0.74
            cap = 600
        case .name:
            factor = 0.7
            cap = 560
        }
        let computed = containerHeight * factor
        return min(max(computed, cardMinimumHeight(for: step) + 40), cap)
    }

    private func cardVerticalPadding(for step: Step) -> CGFloat {
        switch step {
        case .avatar, .goals: return 32
        case .skillLevel, .gender: return 30
        case .age: return 28
        case .name: return 26
        }
    }

    private func cardNavigationSpacing(for step: Step) -> CGFloat {
        switch step {
        case .name: return 24
        case .age: return 26
        case .gender: return 28
        case .skillLevel, .goals: return 30
        case .avatar: return 32
        }
    }

    private func preferredContentHeight(for step: Step) -> CGFloat {
        switch step {
        case .name: return 360
        case .age: return 400
        case .gender: return 540
        case .skillLevel: return 540
        case .avatar: return 640
        case .goals: return 620
        }
    }

    private func navigationReservedHeight(for step: Step) -> CGFloat {
        switch step {
        case .avatar: return 220
        case .goals: return 210
        case .skillLevel, .gender: return 200
        case .age, .name: return 190
        }
    }

    private func scrollBottomPadding(for step: Step) -> CGFloat {
        switch step {
        case .avatar: return 24
        case .goals: return 18
        default: return 0
        }
    }

    @ViewBuilder
    private func cardContent(for step: Step,
                             cardMinHeight: CGFloat,
                             cardMaxHeight: CGFloat) -> some View {
        let effectiveMaxHeight = max(cardMaxHeight - navigationReservedHeight(for: step), cardMinHeight - 40)
        let baseContent = stepView(for: step)

        if shouldEnableScroll(for: step, cardMaxHeight: cardMaxHeight) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    baseContent
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, scrollBottomPadding(for: step))
            }
            .frame(maxHeight: max(effectiveMaxHeight, cardMinHeight * 0.75))
        } else {
            VStack(spacing: 0) {
                baseContent
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func shouldEnableScroll(for step: Step, cardMaxHeight: CGFloat) -> Bool {
        preferredContentHeight(for: step) > cardMaxHeight
    }

    private func prepareInitialState() {
        if avatarOptions.isEmpty {
            regenerateAvatarOptions(for: gender)
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

        if currentStep == .gender {
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

    private func regenerateAvatarOptions(for gender: Gender?, force: Bool = false) {
        let baseGender = gender ?? .unspecified
        if !force,
           !avatarOptions.isEmpty,
           avatarOptions.allSatisfy({ $0.contains(baseGender.seedTag) }) {
            return
        }

        var seeds: Set<String> = []
        while seeds.count < 4 {
            seeds.insert(OnboardingFlowView.randomSeed(for: baseGender))
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

        let finalAvatar = selectedAvatarSeed ?? OnboardingFlowView.randomSeed(for: gender ?? .unspecified)
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

    private static func randomSeed(for gender: Gender) -> String {
        "\(gender.seedTag)-\(UUID().uuidString.prefix(8))"
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

private struct GenderStepView: View {
    @Binding var gender: OnboardingFlowView.Gender?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("What's your gender?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("Pick an option and tap Next.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 18) {
                ForEach(OnboardingFlowView.Gender.allCases) { option in
                    KidSelectableOption(title: option.shortLabel,
                                        subtitle: option.friendlyDescription,
                                        symbolName: symbol(for: option),
                                        symbolColor: color(for: option),
                                        isSelected: gender == option) {
                        gender = option
                    }
                }
            }
        }
    }

    private func symbol(for gender: OnboardingFlowView.Gender) -> String {
        switch gender {
        case .male: return "figure.wave"
        case .female: return "smiley.fill"
        case .unspecified: return "sparkles"
        }
    }

    private func color(for gender: OnboardingFlowView.Gender) -> Color {
        switch gender {
        case .male: return Color(red: 0.53, green: 0.72, blue: 0.98)
        case .female: return Color(red: 1.0, green: 0.77, blue: 0.87)
        case .unspecified: return Color(red: 0.82, green: 0.89, blue: 1.0)
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
    let gender: OnboardingFlowView.Gender?
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 18)], spacing: 18) {
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
            DiceBearAvatar(seed: seed, size: 140)
                .overlay(
                    Circle()
                        .stroke(selectedSeed == seed ? Palette.accent : Color.clear, lineWidth: 6)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)

            Text(selectedSeed == seed ? "This one!" : "Pick me")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                Text("How much cursive have you practiced?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("We’ll tailor your lessons based on how confident you feel.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 18) {
                ForEach(OnboardingFlowView.ExperienceLevel.allCases) { level in
                    KidSelectableOption(title: level.rawValue,
                                        subtitle: level.description,
                                        symbolName: symbol(for: level),
                                        symbolColor: color(for: level),
                                        isSelected: experience == level) {
                        experience = level
                    }
                }
            }
        }
    }

    private func symbol(for level: OnboardingFlowView.ExperienceLevel) -> String {
        switch level {
        case .beginner: return "lightbulb.fill"
        case .intermediate: return "pencil.circle.fill"
        case .expert: return "star.fill"
        }
    }

    private func color(for level: OnboardingFlowView.ExperienceLevel) -> Color {
        switch level {
        case .beginner: return Color(red: 0.95, green: 0.89, blue: 1.0)
        case .intermediate: return Color(red: 0.86, green: 0.93, blue: 1.0)
        case .expert: return Color(red: 1.0, green: 0.88, blue: 0.74)
        }
    }
}

private struct GoalsStepView: View {
    @Binding var selectedDays: Set<OnboardingFlowView.Weekday>
    @Binding var lettersPerDay: Int
    let goalSeconds: Int

    private let sliderRange: ClosedRange<Double> = 20...150

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Set your practice plan")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .multilineTextAlignment(.center)

                Text("Choose your practice days and daily letters.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Practice days")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(OnboardingFlowView.Weekday.all) { day in
                        KidDayButton(day: day, isSelected: selectedDays.contains(day)) {
                            toggle(day)
                        }
                    }
                }
            }

            VStack(spacing: 20) {
                Text("Letters each practice day")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    Slider(value: Binding(
                        get: { Double(lettersPerDay) },
                        set: { lettersPerDay = Int($0) }
                    ), in: sliderRange, step: 5)
                    .tint(Palette.accent)

                    Text("\(lettersPerDay) letters ≈ \(formatDuration(goalSeconds))")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.secondary)
                }
                .padding(.horizontal, 8)
            }
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
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(symbolColor.opacity(0.85))
                        .frame(width: 70, height: 70)

                    Image(systemName: symbolName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Palette.primary.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.primary)

                    Text(subtitle)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
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
            .padding(20)
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
            VStack(spacing: 6) {
                Text(day.symbol)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? Palette.accentDark : Palette.primary)
                Text(day.fullName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? Palette.accentDark.opacity(0.8) : Palette.secondary.opacity(0.7))
            }
            .padding(.vertical, 14)
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
