import SwiftUI

enum QuickDialog: String, Identifiable {
    case profile

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
    enum Tab: String, CaseIterable, Identifiable {
        case today
        case streak
        case profile
        case goals
        case difficulty
        case preferences

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: return "Today"
            case .streak: return "Streak"
            case .profile: return "Profile"
            case .goals: return "Goals"
            case .difficulty: return "Difficulty"
            case .preferences: return "Preferences"
            }
        }
    }

    @EnvironmentObject private var dataStore: PracticeDataStore
    @FocusState private var nameFieldFocused: Bool

    let onClose: () -> Void
    let onExitLesson: (() -> Void)?

    @State private var selectedTab: Tab
    @State private var nameDraft: String = ""
    @State private var customLetters: Int = 60
    @State private var selectedWeekdays: Set<Int> = Set([0, 1, 2, 3, 4])
    @State private var selectedDifficulty: PracticeDifficulty
    @State private var hasSynced = false

    private let lookbackWeeks = 12
    private let weekdayOptions: [WeekdayOption] = [
        WeekdayOption(index: 0, shortLabel: "Mon", fullLabel: "Monday"),
        WeekdayOption(index: 1, shortLabel: "Tue", fullLabel: "Tuesday"),
        WeekdayOption(index: 2, shortLabel: "Wed", fullLabel: "Wednesday"),
        WeekdayOption(index: 3, shortLabel: "Thu", fullLabel: "Thursday"),
        WeekdayOption(index: 4, shortLabel: "Fri", fullLabel: "Friday"),
        WeekdayOption(index: 5, shortLabel: "Sat", fullLabel: "Saturday"),
        WeekdayOption(index: 6, shortLabel: "Sun", fullLabel: "Sunday")
    ]

    init(initialTab: Tab = .today,
         onClose: @escaping () -> Void,
         onExitLesson: (() -> Void)? = nil) {
        self.onClose = onClose
        self.onExitLesson = onExitLesson
        _selectedTab = State(initialValue: initialTab)
        _selectedDifficulty = State(initialValue: .beginner)
    }

    var body: some View {
        VStack(spacing: 22) {
            headerBar
            tabStrip

            ScrollView(showsIndicators: false) {
                tabContent(for: selectedTab)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 432)
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ScribbleColors.cardBackground)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 18)
        .onAppear {
            syncFromStore()
        }
        .onChange(of: dataStore.profile.goal) { _ in
            syncGoalState()
        }
        .onChange(of: dataStore.settings.difficulty) { newValue in
            selectedDifficulty = newValue
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Scribble hub")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                Text(selectedTab.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))
            }

            Spacer()

            Button {
                close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ScribbleColors.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close dialog")
        }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Tab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
        }
    }

    private func tabButton(for tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            nameFieldFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? ScribbleColors.primary : ScribbleColors.secondary)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? ScribbleColors.accent.opacity(0.45) : ScribbleColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isSelected ? ScribbleColors.accent : Color.white.opacity(0.3), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .today:
            todayTab
        case .streak:
            streakTab
        case .profile:
            profileTab
        case .goals:
            goalsTab
        case .difficulty:
            difficultyTab
        case .preferences:
            preferencesTab
        }
    }

    private var todayTab: some View {
        VStack(spacing: 24) {
            AvatarProgressButton(seed: dataStore.profile.avatarSeed,
                                 progress: dataStore.dailyProgressRatio())
                .frame(width: 140, height: 140)

            Text(todayProgressLine)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)

            if onExitLesson != nil {
                Button {
                    exitLesson()
                } label: {
                    Text("Exit Lesson")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(ScribbleColors.accent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var streakTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Current streak: \(streak) \(streak == 1 ? "day" : "days")")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)

            HStack {
                Spacer(minLength: 0)
                CompactStreakGrid(weeks: streakWeekColumns,
                                  goalDailySeconds: goal.dailySeconds,
                                  activeWeekdays: goal.activeWeekdayIndices,
                                  dayLabels: dayLabels)
                Spacer(minLength: 0)
            }
        }
    }

    private var profileTab: some View {
        infoCard(title: "Your Scribble identity", padding: 20) {
            VStack(spacing: 16) {
                DiceBearAvatar(seed: dataStore.profile.avatarSeed, size: 112)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

                Button {
                    shuffleAvatar()
                } label: {
                    Label("Shuffle avatar", systemImage: "shuffle")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.accentDark)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
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
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(ScribbleColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(ScribbleColors.inputBorder.opacity(0.5), lineWidth: 2)
                        )
                        .focused($nameFieldFocused)
                        .onChange(of: nameDraft) { newValue in
                            commitDisplayName(newValue)
                        }
                }
            }
        }
    }

    private var goalsTab: some View {
        infoCard(title: "Practice goals", padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily letters")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.85))

                    letterAdjuster(value: customLetters,
                                   onIncrement: { setGoalLetters(customLetters + 5) },
                                   onDecrement: { setGoalLetters(max(customLetters - 5, 5)) })
                }

                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice days")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.85))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                              spacing: 10) {
                        ForEach(weekdayOptions) { option in
                            dayToggle(option: option,
                                      isSelected: selectedWeekdays.contains(option.index)) {
                                toggleWeekday(option.index)
                            }
                        }
                    }
                }
            }
        }
    }

    private var difficultyTab: some View {
        infoCard(title: "Difficulty level") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose the challenge that fits your handwriting journey.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))

                VStack(spacing: 14) {
                    ForEach(PracticeDifficulty.allCases) { level in
                        difficultyRow(for: level)
                    }
                }
            }
        }
    }

    private var preferencesTab: some View {
        infoCard(title: "Preferences") {
            VStack(alignment: .leading, spacing: 18) {
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
    }

    private func infoCard<Content: View>(title: String? = nil,
                                         padding: CGFloat = 24,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ScribbleColors.surface)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }

    private func letterAdjuster(value: Int,
                                onIncrement: @escaping () -> Void,
                                onDecrement: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            adjustButton(systemName: "minus",
                         isEnabled: value > 5,
                         action: onDecrement)

            Text("\(value) letters")
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
                .frame(minWidth: 120)

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
                    .foregroundColor(isSelected ? ScribbleColors.accentDark.opacity(0.9) : ScribbleColors.secondary.opacity(0.7))
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
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: difficultyIcon(for: difficulty))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ScribbleColors.accentDark)
                    .frame(width: 36, height: 36)
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
                        .fixedSize(horizontal: false, vertical: true)
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

    private func defaultWeekdays(for count: Int) -> Set<Int> {
        let clamped = max(1, min(count, 7))
        return Set(0..<clamped)
    }

    private func close() {
        nameFieldFocused = false
        onClose()
    }

    private func exitLesson() {
        close()
        onExitLesson?()
    }

    private var todayProgressLine: String {
        if lettersRemaining <= 0 {
            return "Today's ring is closed! \(lettersToday) / \(goalLetters)"
        }
        let label = lettersRemaining == 1 ? "letter" : "letters"
        return "\(lettersRemaining) \(label) left to close today’s ring (\(lettersToday) / \(goalLetters))"
    }

    private var dayLabels: [String] { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] }

    private var goal: PracticeGoal {
        dataStore.profile.goal
    }

    private var lettersToday: Int {
        max(dataStore.todayContribution().secondsSpent / PracticeGoal.secondsPerLetter, 0)
    }

    private var goalLetters: Int {
        max(goal.dailySeconds / PracticeGoal.secondsPerLetter, 1)
    }

    private var lettersRemaining: Int {
        max(goalLetters - lettersToday, 0)
    }

    private var streak: Int {
        dataStore.currentStreak()
    }

    private var streakWeekColumns: [WeekColumn] {
        let contributions = dataStore.contributions(forDays: lookbackWeeks * 7)
        let calendar = calendarWithMonday
        let today = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }
        let contributionsByDay = Dictionary(uniqueKeysWithValues: contributions.map { ($0.date.stripTime(using: calendar), $0) })

        return (0..<lookbackWeeks).reversed().map { offset in
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

    private struct WeekdayOption: Identifiable {
        let index: Int
        let shortLabel: String
        let fullLabel: String

        var id: Int { index }
    }
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
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
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

private extension Date {
    func stripTime(using calendar: Calendar) -> Date {
        calendar.startOfDay(for: self)
    }
}
