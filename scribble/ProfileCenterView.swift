import SwiftUI

struct ProfileCenterView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool

    @State private var nameDraft: String = ""
    @State private var customLetters: Int = 60
    @State private var selectedWeekdays: Set<Int> = Set([0, 1, 2, 3, 4])

    private let weekdayOptions: [WeekdayOption] = [
        WeekdayOption(index: 0, shortLabel: "Mon", fullLabel: "Monday"),
        WeekdayOption(index: 1, shortLabel: "Tue", fullLabel: "Tuesday"),
        WeekdayOption(index: 2, shortLabel: "Wed", fullLabel: "Wednesday"),
        WeekdayOption(index: 3, shortLabel: "Thu", fullLabel: "Thursday"),
        WeekdayOption(index: 4, shortLabel: "Fri", fullLabel: "Friday"),
        WeekdayOption(index: 5, shortLabel: "Sat", fullLabel: "Saturday"),
        WeekdayOption(index: 6, shortLabel: "Sun", fullLabel: "Sunday")
    ]

    private var today: ContributionDay {
        dataStore.todayContribution()
    }

    private var goalLetters: Int {
        max(dataStore.profile.goal.dailyLetterGoal, 1)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 60, height: 6)
                .padding(.top, 12)

            HStack {
                Text("Profile Center")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(ScribbleColors.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    identitySection
                    goalsSection
                    preferencesSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .background(
            ScribbleColors.cardBackground
                .ignoresSafeArea()
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            syncInitialState()
        }
        .onChange(of: dataStore.profile.goal.dailySeconds) { _, newValue in
            let letters = max(newValue / PracticeGoal.secondsPerLetter, 1)
            customLetters = letters
        }
        .onChange(of: dataStore.profile.goal.activeWeekdayIndices) { _, newValue in
            selectedWeekdays = newValue
        }
    }

    private var identitySection: some View {
        ProfileSection(title: "Your Scribble identity") {
            VStack(spacing: 18) {
                DiceBearAvatar(seed: dataStore.profile.avatarSeed, size: 140)
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)

                Button {
                    shuffleAvatar()
                } label: {
                    Label("Shuffle avatar", systemImage: "shuffle")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.accentDark)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(ScribbleColors.accent.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Display name")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.8))

                    TextField("Explorer", text: $nameDraft)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(ScribbleColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(ScribbleColors.inputBorder.opacity(0.5), lineWidth: 2)
                        )
                        .focused($nameFieldFocused)
                        .onChange(of: nameDraft) { _, newValue in
                            commitDisplayName(newValue)
                        }
                }
            }
        }
    }

    private var goalsSection: some View {
        ProfileSection(title: "Practice goals") {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily letters")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.8))

                    HStack(spacing: 12) {
                        GoalPresetButton(title: "60 letters",
                                         isSelected: goalLetters == 60) {
                            setGoalLetters(60)
                        }
                        GoalPresetButton(title: "120 letters",
                                         isSelected: goalLetters == 120) {
                            setGoalLetters(120)
                        }
                        GoalPresetButton(title: "Custom",
                                         isSelected: goalLetters != 60 && goalLetters != 120) {
                            customLetters = goalLetters
                        }
                    }

                    if goalLetters != 60 && goalLetters != 120 {
                        LetterAdjuster(value: customLetters,
                                       onIncrement: { setGoalLetters(customLetters + 5) },
                                       onDecrement: { setGoalLetters(max(customLetters - 5, 5)) })
                    }
                }

                Divider()
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice days")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.8))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(weekdayOptions) { option in
                            DayToggleButton(option: option,
                                            isSelected: selectedWeekdays.contains(option.index)) {
                                toggleWeekday(option.index)
                            }
                        }
                    }
                }
            }
        }
    }

    private var preferencesSection: some View {
        ProfileSection(title: "Preferences") {
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { dataStore.settings.hapticsEnabled },
                    set: { dataStore.updateHapticsEnabled($0) }
                )) {
                    Text("Haptic feedback")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                }
                .toggleStyle(ScribbleToggleStyle())

                Toggle(isOn: Binding(
                    get: { dataStore.settings.isLeftHanded },
                    set: { dataStore.updateLeftHanded($0) }
                )) {
                    Text("Left-handed guides")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                }
                .toggleStyle(ScribbleToggleStyle())
            }
        }
    }

    private func syncInitialState() {
        nameDraft = dataStore.profile.displayName
        customLetters = goalLetters
        selectedWeekdays = dataStore.profile.goal.activeWeekdayIndices
        if selectedWeekdays.isEmpty {
            selectedWeekdays = defaultWeekdays(for: dataStore.profile.goal.activeDaysPerWeek)
        }
    }

    private func commitDisplayName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            nameDraft = ""
            return
        }
        dataStore.updateDisplayName(trimmed)
    }

    private func setGoalLetters(_ letters: Int) {
        let sanitized = max(5, letters)
        customLetters = sanitized
        dataStore.updateGoalSeconds(sanitized * PracticeGoal.secondsPerLetter)
    }

    private func toggleWeekday(_ index: Int) {
        var updated = selectedWeekdays
        if updated.contains(index) {
            if updated.count > 1 {
                updated.remove(index)
            }
        } else {
            updated.insert(index)
        }
        guard !updated.isEmpty else { return }
        selectedWeekdays = updated
        var goal = dataStore.profile.goal
        goal.activeWeekdayIndices = updated
        dataStore.updateGoal(goal)
    }

    private func shuffleAvatar() {
        let seeds = ["storybook", "sunny-smiles", "brave-bear", "rocket-pen", "electric-nebula",
                     "doodle-dasher", "wonderwaves", "galaxy-giggles", "cobalt-star", "minty-moon"]
        var candidates = seeds
        candidates.append(UUID().uuidString.lowercased())
        let current = dataStore.profile.avatarSeed
        let filtered = candidates.filter { $0 != current }
        if let next = filtered.randomElement() {
            dataStore.updateAvatarSeed(next)
        }
    }

    private func defaultWeekdays(for count: Int) -> Set<Int> {
        let clamped = max(1, min(count, 7))
        return Set((0..<clamped))
    }
}

// MARK: - Helper Views

private struct ProfileSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ScribbleColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct WeekdayOption: Identifiable {
    let index: Int
    let shortLabel: String
    let fullLabel: String
    var id: Int { index }
}

private struct DayToggleButton: View {
    let option: WeekdayOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(option.shortLabel)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? ScribbleColors.accentDark : ScribbleColors.primary)
                Text(option.fullLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? ScribbleColors.accentDark.opacity(0.85) : ScribbleColors.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? ScribbleColors.accent.opacity(0.4) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? ScribbleColors.accent : Color.white.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05),
                    radius: isSelected ? 14 : 8,
                    x: 0,
                    y: isSelected ? 10 : 6)
        }
        .buttonStyle(.plain)
    }
}

private struct LetterAdjuster: View {
    let value: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            AdjustButton(systemName: "minus", action: onDecrement, isEnabled: value > 5)
            Text("\(value) letters")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
                .frame(minWidth: 140)
            AdjustButton(systemName: "plus", action: onIncrement, isEnabled: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdjustButton: View {
    let systemName: String
    let action: () -> Void
    let isEnabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isEnabled ? ScribbleColors.accentDark : ScribbleColors.secondary.opacity(0.45))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isEnabled ? ScribbleColors.accent.opacity(0.4) : ScribbleColors.controlDisabled)
                )
                .overlay(
                    Circle()
                        .stroke(isEnabled ? ScribbleColors.accent : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct GoalPresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(isSelected ? ScribbleColors.accent.opacity(0.4) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? ScribbleColors.accent : Color.white.opacity(0.3), lineWidth: 2)
                )
                .foregroundColor(isSelected ? ScribbleColors.accentDark : ScribbleColors.secondary)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05),
                radius: isSelected ? 10 : 6,
                x: 0,
                y: isSelected ? 6 : 3)
    }
}

private struct MiniGoalRing: View {
    let lettersCompleted: Int
    let lettersGoal: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 10)
            Circle()
                .stroke(Color(red: 0.9, green: 0.94, blue: 0.99), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.84, blue: 0.46),
                        Color(red: 0.99, green: 0.68, blue: 0.33),
                        Color(red: 1.0, green: 0.84, blue: 0.46)
                    ]), center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("\(lettersCompleted)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                Text("of \(lettersGoal)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary)
                Text("letters")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's progress \(lettersCompleted) of \(lettersGoal) letters")
    }
}
