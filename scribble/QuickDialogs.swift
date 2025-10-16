import SwiftUI

enum QuickDialog: String, Identifiable {
    case profile
    case streak

    var id: String { rawValue }
}

struct DialogOverlay<Content: View>: View {
    let content: () -> Content
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    onDismiss()
                }
            content()
                .transition(.scale.combined(with: .opacity))
        }
    }
}

struct ProfileQuickActionsDialog: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @FocusState private var nameFieldFocused: Bool

    private enum Mode {
        case overview
        case edit
    }

    private enum EditTab: String, CaseIterable, Identifiable {
        case profile = "Profile"
        case goals = "Goals"
        case preferences = "Preferences"

        var id: String { rawValue }
    }

    private struct WeekdayOption: Identifiable {
        let index: Int
        let shortLabel: String
        let fullLabel: String

        var id: Int { index }
    }

    let onClose: () -> Void

    @State private var mode: Mode = .overview
    @State private var selectedTab: EditTab = .profile
    @State private var nameDraft: String = ""
    @State private var customLetters: Int = 60
    @State private var selectedWeekdays: Set<Int> = Set([0, 1, 2, 3, 4])
    @State private var selectedDifficulty: PracticeDifficulty
    @State private var hasSynced = false

    private let weekdayOptions: [WeekdayOption] = [
        WeekdayOption(index: 0, shortLabel: "Mon", fullLabel: "Monday"),
        WeekdayOption(index: 1, shortLabel: "Tue", fullLabel: "Tuesday"),
        WeekdayOption(index: 2, shortLabel: "Wed", fullLabel: "Wednesday"),
        WeekdayOption(index: 3, shortLabel: "Thu", fullLabel: "Thursday"),
        WeekdayOption(index: 4, shortLabel: "Fri", fullLabel: "Friday"),
        WeekdayOption(index: 5, shortLabel: "Sat", fullLabel: "Saturday"),
        WeekdayOption(index: 6, shortLabel: "Sun", fullLabel: "Sunday")
    ]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _selectedDifficulty = State(initialValue: .beginner)
    }

    var body: some View {
        VStack(spacing: 24) {
            if mode == .overview {
                overviewContent
            } else {
                editContent
            }
        }
        .frame(width: 420)
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ScribbleColors.cardBackground)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 20)
        .onAppear {
            syncFromStore()
        }
        .onChange(of: dataStore.profile.goal) { _, _ in
            syncGoalState()
        }
        .onChange(of: dataStore.settings.difficulty) { _, newValue in
            selectedDifficulty = newValue
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 26) {
            AvatarProgressButton(seed: dataStore.profile.avatarSeed,
                                 progress: dataStore.dailyProgressRatio())
                .frame(width: 140, height: 140)

            VStack(spacing: 16) {
                Text("Today's letters")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)

                HStack(spacing: 16) {
                    overviewStat(title: "Done", value: "\(lettersToday)")
                    overviewStat(title: "Remaining", value: "\(lettersRemaining)")
                }

                Text("Goal: \(goalLetters) letters per day")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    onClose()
                } label: {
                    Text("Exit")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ScribbleColors.surface)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        mode = .edit
                    }
                } label: {
                    Text("Edit Profile")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ScribbleColors.accent.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var editContent: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    nameFieldFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .overview
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ScribbleColors.secondary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(ScribbleColors.surface)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    nameFieldFocused = false
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ScribbleColors.secondary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(ScribbleColors.surface)
                        )
                }
                .buttonStyle(.plain)
            }

            Picker("Section", selection: $selectedTab) {
                ForEach(EditTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .profile:
                        profileTab
                    case .goals:
                        goalsTab
                    case .preferences:
                        preferencesTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 340)

            HStack(spacing: 12) {
                Button {
                    nameFieldFocused = false
                    onClose()
                } label: {
                    Text("Exit")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ScribbleColors.surface)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    nameFieldFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .overview
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ScribbleColors.accent.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var profileTab: some View {
        VStack(alignment: .center, spacing: 18) {
            DiceBearAvatar(seed: dataStore.profile.avatarSeed, size: 124)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)

            Button {
                shuffleAvatar()
            } label: {
                Label("Shuffle avatar", systemImage: "shuffle")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.accentDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(ScribbleColors.accent.opacity(0.35))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Text("Display name")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))

                TextField("Explorer", text: $nameDraft)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(ScribbleColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(ScribbleColors.inputBorder.opacity(0.5), lineWidth: 2)
                    )
                    .focused($nameFieldFocused)
                    .onChange(of: nameDraft) { _, newValue in
                        commitDisplayName(newValue)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var goalsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily letters")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(ScribbleColors.secondary.opacity(0.85))

            HStack(spacing: 12) {
                goalPresetButton(title: "60", isSelected: goalLetters == 60) {
                    setGoalLetters(60)
                }
                goalPresetButton(title: "120", isSelected: goalLetters == 120) {
                    setGoalLetters(120)
                }
                goalPresetButton(title: "Custom", isSelected: goalLetters != 60 && goalLetters != 120) {
                    customLetters = goalLetters
                }
            }

            if goalLetters != 60 && goalLetters != 120 {
                letterAdjuster(value: customLetters,
                               onIncrement: { setGoalLetters(customLetters + 5) },
                               onDecrement: { setGoalLetters(max(customLetters - 5, 5)) })
            }

            Divider()
                .padding(.vertical, 4)

            Text("Practice days")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(ScribbleColors.secondary.opacity(0.85))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(weekdayOptions) { option in
                    dayToggle(option: option,
                              isSelected: selectedWeekdays.contains(option.index)) {
                        toggleWeekday(option.index)
                    }
                }
            }
        }
    }

    private var preferencesTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Difficulty")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.85))

                VStack(spacing: 12) {
                    ForEach(PracticeDifficulty.allCases) { level in
                        difficultyRow(for: level)
                    }
                }
            }

            Divider()

            preferenceToggle(title: "Haptic feedback",
                              isOn: Binding(
                                get: { dataStore.settings.hapticsEnabled },
                                set: { dataStore.updateHapticsEnabled($0) }
                              ))

            preferenceToggle(title: "Left-handed guides",
                              isOn: Binding(
                                get: { dataStore.settings.isLeftHanded },
                                set: { dataStore.updateLeftHanded($0) }
                              ))
        }
    }

    private func overviewStat(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.secondary.opacity(0.7))
            Text("\(value) letters")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ScribbleColors.surface)
        )
    }

    private func goalPresetButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(title) letters")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? ScribbleColors.accentDark : ScribbleColors.secondary)
                .padding(.vertical, 9)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(isSelected ? ScribbleColors.accent.opacity(0.45) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? ScribbleColors.accent : Color.white.opacity(0.3), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05),
                radius: isSelected ? 10 : 6,
                x: 0,
                y: isSelected ? 6 : 3)
    }

    private func letterAdjuster(value: Int,
                                onIncrement: @escaping () -> Void,
                                onDecrement: @escaping () -> Void) -> some View {
        HStack(spacing: 18) {
            adjustButton(systemName: "minus",
                         isEnabled: value > 5,
                         action: onDecrement)
            Text("\(value) letters")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
                .frame(minWidth: 140)
            adjustButton(systemName: "plus",
                         isEnabled: true,
                         action: onIncrement)
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustButton(systemName: String,
                              isEnabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isEnabled ? ScribbleColors.accentDark : ScribbleColors.secondary.opacity(0.4))
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(isEnabled ? ScribbleColors.accent.opacity(0.4) : ScribbleColors.controlDisabled)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func dayToggle(option: WeekdayOption,
                           isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(option.shortLabel)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? ScribbleColors.accentDark : ScribbleColors.primary)
                Text(option.fullLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? ScribbleColors.accentDark.opacity(0.85) : ScribbleColors.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? ScribbleColors.accent.opacity(0.35) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? ScribbleColors.accent : Color.white.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: isSelected ? 8 : 4)
        }
        .buttonStyle(.plain)
    }

    private func preferenceToggle(title: String,
                                  isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
        }
        .toggleStyle(ScribbleToggleStyle())
    }

    private func difficultyRow(for difficulty: PracticeDifficulty) -> some View {
        let isSelected = selectedDifficulty == difficulty
        return Button {
            guard selectedDifficulty != difficulty else { return }
            selectedDifficulty = difficulty
            dataStore.updateDifficulty(difficulty)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: difficultyIcon(for: difficulty))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ScribbleColors.accentDark)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(difficultyTint(for: difficulty))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                    Text(difficultyDescription(for: difficulty))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.75))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ScribbleColors.accentDark)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? ScribbleColors.accent.opacity(0.35) : ScribbleColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? ScribbleColors.accent : ScribbleColors.surface.opacity(0.7), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func syncFromStore() {
        guard !hasSynced else { return }
        hasSynced = true
        nameDraft = dataStore.profile.displayName
        selectedDifficulty = dataStore.settings.difficulty
        syncGoalState()
    }

    private func syncGoalState() {
        customLetters = goalLetters
        selectedWeekdays = dataStore.profile.goal.activeWeekdayIndices
        if selectedWeekdays.isEmpty {
            selectedWeekdays = defaultWeekdays(for: dataStore.profile.goal.activeDaysPerWeek)
        }
    }

    private func commitDisplayName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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

    private func difficultyIcon(for difficulty: PracticeDifficulty) -> String {
        switch difficulty {
        case .beginner: return "sparkles"
        case .intermediate: return "pencil.and.outline"
        case .expert: return "flame.fill"
        }
    }

    private func difficultyTint(for difficulty: PracticeDifficulty) -> Color {
        switch difficulty {
        case .beginner: return Color(red: 0.86, green: 0.94, blue: 1.0)
        case .intermediate: return Color(red: 0.8, green: 0.94, blue: 0.84)
        case .expert: return Color(red: 1.0, green: 0.88, blue: 0.76)
        }
    }

    private func difficultyDescription(for difficulty: PracticeDifficulty) -> String {
        switch difficulty {
        case .beginner:
            return "Gentle practice with wide guides."
        case .intermediate:
            return "Balanced challenge for growing writers."
        case .expert:
            return "Tight guides and faster feedback."
        }
    }

    private var lettersToday: Int {
        max(dataStore.todayContribution().secondsSpent / PracticeGoal.secondsPerLetter, 0)
    }

    private var goalLetters: Int {
        max(dataStore.profile.goal.dailySeconds / PracticeGoal.secondsPerLetter, 1)
    }

    private var lettersRemaining: Int {
        max(goalLetters - lettersToday, 0)
    }
}

struct StreakDialog: View {
    @EnvironmentObject private var dataStore: PracticeDataStore

    let onClose: () -> Void

    private let lookbackWeeks = 8

    var body: some View {
        VStack(spacing: 24) {
            AvatarProgressButton(seed: dataStore.profile.avatarSeed,
                                 progress: dataStore.dailyProgressRatio())
                .frame(width: 132, height: 132)

            VStack(spacing: 10) {
                Text("Current streak")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.9))
                Text("\(streak)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                Text(streak == 1 ? "day in a row" : "days in a row")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))
            }

            CompactStreakGrid(weeks: weekColumns,
                              goalDailySeconds: dataStore.profile.goal.dailySeconds,
                              activeWeekdays: dataStore.profile.goal.activeWeekdayIndices,
                              dayLabels: dayLabels)
                .frame(maxWidth: .infinity)

            Button {
                onClose()
            } label: {
                Text("Exit")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(ScribbleColors.surface)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 420)
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ScribbleColors.cardBackground)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 20)
    }

    private var dayLabels: [String] { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] }

    private var streak: Int {
        dataStore.currentStreak()
    }

    private var weekColumns: [WeekColumn] {
        let calendar = calendarWithMonday
        let today = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

        let contributions = dataStore.contributions(forDays: lookbackWeeks * 7)
        let contributionsByDay = Dictionary(uniqueKeysWithValues: contributions.map { ($0.date.stripTime(using: calendar), $0) })

        return (0..<lookbackWeeks).reversed().compactMap { offset in
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) ?? currentWeekStart
            let days: [ContributionDay?] = (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
                return contributionsByDay[date.stripTime(using: calendar)]
            }
            return WeekColumn(startDate: start, days: days)
        }
    }

    private var calendarWithMonday: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private struct WeekColumn: Identifiable {
        let startDate: Date
        let days: [ContributionDay?]

        var id: Date { startDate }
    }

    private struct CompactStreakGrid: View {
        let weeks: [WeekColumn]
        let goalDailySeconds: Int
        let activeWeekdays: Set<Int>
        let dayLabels: [String]

        private let squareSize: CGFloat = 24
        private let spacing: CGFloat = 6
        private let labelWidth: CGFloat = 36

        private let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()

        var body: some View {
            VStack(alignment: .center, spacing: spacing) {
                HStack(spacing: spacing) {
                    Text("")
                        .frame(width: labelWidth)
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, _ in
                        Text("W\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(ScribbleColors.secondary.opacity(0.65))
                            .frame(width: squareSize, alignment: .center)
                    }
                }

                ForEach(dayLabels.indices, id: \.self) { dayIndex in
                    HStack(spacing: spacing) {
                        Text(dayLabels[dayIndex])
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(ScribbleColors.secondary.opacity(0.7))
                            .frame(width: labelWidth, alignment: .trailing)

                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            let day = dayIndex < week.days.count ? week.days[dayIndex] : nil
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color(for: day, dayIndex: dayIndex))
                                .frame(width: squareSize, height: squareSize)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .accessibilityLabel(label(for: day, dayIndex: dayIndex))
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ScribbleColors.surface)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)
        }

        private func color(for day: ContributionDay?, dayIndex: Int) -> Color {
            let isGoalDay = activeWeekdays.contains(dayIndex)
            guard let day else {
                return isGoalDay ? Color(red: 0.87, green: 0.92, blue: 1.0) : Color(red: 0.95, green: 0.96, blue: 0.98)
            }
            guard day.goalSeconds > 0 else {
                return isGoalDay ? Color(red: 0.9, green: 0.95, blue: 1.0) : Color.white.opacity(0.12)
            }
            let ratio = min(Double(day.secondsSpent) / Double(day.goalSeconds), 1)
            if !isGoalDay {
                return Color.white.opacity(ratio > 0 ? 0.25 : 0.12)
            }
            switch ratio {
            case 0:
                return Color.white.opacity(0.3)
            case 0..<0.33:
                return Color(red: 0.74, green: 0.86, blue: 1.0)
            case 0..<0.66:
                return Color(red: 0.52, green: 0.72, blue: 1.0)
            case 0..<1:
                return Color(red: 0.4, green: 0.62, blue: 0.98)
            default:
                return Color(red: 1.0, green: 0.8, blue: 0.4)
            }
        }

        private func label(for day: ContributionDay?,
                           dayIndex: Int) -> String {
            let isGoalDay = activeWeekdays.contains(dayIndex)
            guard let day else {
                return isGoalDay ? "No practice recorded." : "Rest day."
            }
            if day.goalSeconds == 0 { return "Goal paused on \(dayFormatter.string(from: day.date))." }
            let goalLetters = max(goalDailySeconds / PracticeGoal.secondsPerLetter, 1)
            let letters = max(day.secondsSpent / PracticeGoal.secondsPerLetter, 0)
            if day.didHitGoal { return "Goal met on \(dayFormatter.string(from: day.date))." }
            return "\(letters) of \(goalLetters) letters on \(dayFormatter.string(from: day.date))."
        }
    }
}

private extension Date {
    func stripTime(using calendar: Calendar) -> Date {
        calendar.startOfDay(for: self)
    }
}
