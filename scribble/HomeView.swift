import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @State private var showStreakHistory = false
    @State private var path = NavigationPath()

    private let contributionWindow = 42

    private var today: ContributionDay {
        dataStore.todayContribution()
    }

    private var contributions: [ContributionDay] {
        dataStore.contributions(forDays: contributionWindow)
    }

    private var progress: Double {
        dataStore.dailyProgressRatio()
    }

    private var lettersGoalPerDay: Int {
        max(dataStore.profile.goal.dailyLetterGoal, 1)
    }

    private var lettersCompletedToday: Int {
        max(today.secondsSpent / PracticeGoal.secondsPerLetter, 0)
    }

    private var streak: Int {
        dataStore.currentStreak()
    }

    private var streakChip: some View {
        Button {
            showStreakHistory = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.25))
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.4).opacity(0.35), radius: 8, x: 0, y: 6)

                Text("\(streak)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
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
        .accessibilityLabel("Current streak \(streak) \(streak == 1 ? "day" : "days"). Tap to view streak history.")
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                HomeBackground()
                GeometryReader { proxy in
                    VStack(spacing: 36) {
                        header
                        Spacer(minLength: proxy.size.height * 0.08)
                        startButton
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, proxy.size.height * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .freePractice:
                    FreePracticeView()
                        .environmentObject(dataStore)
                }
            }
            .sheet(isPresented: $showStreakHistory) {
                if #available(iOS 16.0, *) {
                    StreakHistorySheet(streak: streak,
                                       contributions: contributions,
                                       goal: dataStore.profile.goal)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                } else {
                    StreakHistorySheet(streak: streak,
                                       contributions: contributions,
                                       goal: dataStore.profile.goal)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scribble")
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.24, green: 0.33, blue: 0.57))
                Text(progressSubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.72))
            }
            Spacer()
            HStack(spacing: 16) {
                streakChip
                ProfileMenuButton(seed: dataStore.profile.avatarSeed,
                                  progress: progress,
                                  today: today,
                                  goal: dataStore.profile.goal,
                                  difficulty: dataStore.settings.difficulty,
                                  streak: streak,
                                  onDifficultyChange: { dataStore.updateDifficulty($0) })
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var startButton: some View {
        Button {
            startPractice()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 46, weight: .bold))
                Text("Practice")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.26, green: 0.18, blue: 0.07))
            .frame(width: 240, height: 140)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 1.0, green: 0.86, blue: 0.44),
                            Color(red: 1.0, green: 0.74, blue: 0.3)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start Practice")
    }

    private func startPractice() {
        path.append(HomeRoute.freePractice)
    }

    private var progressSubtitle: String {
        guard lettersGoalPerDay > 0 else {
            return "Set a goal to fill your magic ring."
        }
        let remainingLetters = max(lettersGoalPerDay - lettersCompletedToday, 0)
        guard remainingLetters > 0 else {
            return "Today's goal is complete! 🎉"
        }

        let lettersRemaining = remainingLetters
        let letterLabel = lettersRemaining == 1 ? "letter" : "letters"
        return "\(lettersRemaining) \(letterLabel) left to close today's ring."
    }

}

private enum HomeRoute: Hashable {
    case freePractice
}

private struct HomeBackground: View {
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

struct ProfileMenuButton: View {
    let seed: String
    let progress: Double
    let today: ContributionDay
    let goal: PracticeGoal
    let difficulty: PracticeDifficulty
    let streak: Int
    let onDifficultyChange: (PracticeDifficulty) -> Void

    @State private var showQuickActions = false

    var body: some View {
        Button {
            showQuickActions = true
        } label: {
            AvatarProgressButton(seed: seed, progress: progress)
                .accessibilityLabel("Open profile options")
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showQuickActions) {
            ProfileQuickActionsSheet(
                seed: seed,
                progress: progress,
                today: today,
                goal: goal,
                difficulty: difficulty,
                streak: streak,
                onDifficultyChange: { newValue in
                    onDifficultyChange(newValue)
                }
            )
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

struct AvatarProgressButton: View {
    let seed: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
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
            AvatarImage(seed: seed, size: 74)
        }
        .frame(width: 92, height: 92)
    }
}

private struct ProfileQuickActionsSheet: View {
    let seed: String
    let progress: Double
    let today: ContributionDay
    let goal: PracticeGoal
    let difficulty: PracticeDifficulty
    let streak: Int
    let onDifficultyChange: (PracticeDifficulty) -> Void

    @State private var selectedDifficulty: PracticeDifficulty
    @State private var activePage: Page = .overview
    @Environment(\.dismiss) private var dismiss

    private enum Page {
        case overview
        case profileCenter
    }

    init(seed: String,
         progress: Double,
         today: ContributionDay,
         goal: PracticeGoal,
         difficulty: PracticeDifficulty,
         streak: Int,
         onDifficultyChange: @escaping (PracticeDifficulty) -> Void) {
        self.seed = seed
        self.progress = progress
        self.today = today
        self.goal = goal
        self.difficulty = difficulty
        self.streak = streak
        self.onDifficultyChange = onDifficultyChange
        _selectedDifficulty = State(initialValue: difficulty)
    }

    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 26) {
            VStack(spacing: 18) {
                AvatarProgressButton(seed: seed, progress: progress)
                    .frame(width: 120, height: 120)

                Text("Keep scribbling!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }

            statsCard

            VStack(alignment: .leading, spacing: 18) {
                Text("Adjust your level")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)

                VStack(spacing: 16) {
                    ForEach(PracticeDifficulty.allCases) { level in
                        ScribbleSelectableOption(
                            title: level.title,
                            subtitle: difficultyDescription(for: level),
                            systemName: difficultyIcon(for: level),
                            tint: difficultyTint(for: level),
                            isSelected: selectedDifficulty == level
                        ) {
                            selectedDifficulty = level
                            dismiss()
                        }
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.85, blendDuration: 0.15)) {
                    activePage = .profileCenter
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24, weight: .bold))
                    Text("Open Profile Center")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
                .foregroundColor(ScribbleColors.accentDark)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                        .fill(ScribbleColors.accent.opacity(0.4))
                )
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary)
                    .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 60, height: 6)
                .padding(.top, 16)

            Group {
                switch activePage {
                case .overview:
                    overviewContent
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .profileCenter:
                    ProfileCenterView(showsHandle: false,
                                      onBack: { withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { activePage = .overview } },
                                      onClose: { dismiss() })
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.85, blendDuration: 0.2), value: activePage)
        .onChange(of: selectedDifficulty) { _, newValue in
            guard newValue != difficulty else { return }
            onDifficultyChange(newValue)
        }
        .background(
            ScribbleColors.cardBackground
                .ignoresSafeArea()
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's letters")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)

            HStack {
                statTile(title: "Today", value: "\(lettersToday) letters")
                statTile(title: "Goal", value: "\(goalLetters) letters")
                statTile(title: "Streak", value: streakLabel)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ScribbleColors.surface)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 12)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(ScribbleColors.secondary.opacity(0.7))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(ScribbleColors.inputBackground.opacity(0.6))
        )
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
        max(today.secondsSpent / PracticeGoal.secondsPerLetter, 0)
    }

    private var goalLetters: Int {
        max(goal.dailySeconds / PracticeGoal.secondsPerLetter, 1)
    }

    private var streakLabel: String {
        let label = streak == 1 ? "day" : "days"
        return "\(streak) \(label)"
    }
}
struct AvatarImage: View {
    let seed: String
    let size: CGFloat

    private var url: URL? {
        var components = URLComponents(string: "https://api.dicebear.com/7.x/adventurer/png")
        components?.queryItems = [
            URLQueryItem(name: "seed", value: seed),
            URLQueryItem(name: "backgroundColor", value: "ffefd5"),
            URLQueryItem(name: "radius", value: "50"),
            URLQueryItem(name: "size", value: "\(Int(size * 2))")
        ]
        return components?.url
    }

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure:
                Circle()
                    .fill(Color(red: 0.98, green: 0.9, blue: 0.68))
                    .frame(width: size, height: size)
                    .overlay(
                        Text("😊")
                            .font(.system(size: size * 0.4))
                    )
            @unknown default:
                Circle()
                    .fill(Color(red: 0.98, green: 0.9, blue: 0.68))
                    .frame(width: size, height: size)
            }
        }
    }
}

private struct StreakHistorySheet: View {
    let streak: Int
    let contributions: [ContributionDay]
    let goal: PracticeGoal

    @Environment(\.dismiss) private var dismiss

    private var streakLabel: String {
        streak == 1 ? "day" : "days"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.25))
                            .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.32).opacity(0.4), radius: 16, x: 0, y: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(streak)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundColor(ScribbleColors.primary)
                            Text("Current streak • \(streakLabel)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(ScribbleColors.secondary.opacity(0.8))
                        }

                        Spacer()
                    }

                    Text("Great job! Keep the flame burning by practicing on your goal days.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GoalTrackerCard(contributions: contributions, goal: goal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 48)
        }
        .background(
            ScribbleColors.cardBackground
                .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
    }
}

private struct GoalTrackerCard: View {
    let contributions: [ContributionDay]
    let goal: PracticeGoal
    private let calendar = Calendar(identifier: .gregorian)
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Streaks")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)
            if contributions.isEmpty {
                EmptyTrackerView()
            } else {
                let weekCount = max(weekColumns.count, 1)
                let squareSize = dynamicSquareSize(for: weekCount)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ContributionCalendarGrid(weeks: weekColumns,
                                             goalDailySeconds: goal.dailySeconds,
                                             activeWeekdays: goal.activeWeekdayIndices,
                                             dayLabels: dayLabels,
                                             squareSize: squareSize)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            Text("Goal: \(goal.dailyLetterGoal) letters • \(goal.activeWeekdayIndices.count) days per week")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(ScribbleColors.secondary.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(ScribbleColors.surface)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private func dynamicSquareSize(for weekCount: Int) -> CGFloat {
        switch weekCount {
        case 0...3: return 34
        case 4: return 30
        case 5: return 26
        default: return 24
        }
    }

    private var calendarWithMonday: Calendar {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private var weekColumns: [WeekColumn] {
        guard !contributions.isEmpty else { return [] }
        var columns: [WeekColumn] = []
        var currentKey: DateComponents?
        var currentColumn = Array<ContributionDay?>(repeating: nil, count: 7)
        var currentStart: Date?

        for day in contributions {
            let key = calendarWithMonday.dateComponents([.weekOfYear, .yearForWeekOfYear], from: day.date)
            if currentKey == nil {
                currentKey = key
                currentStart = startOfWeek(for: day.date)
            } else if key != currentKey {
                if let start = currentStart {
                    columns.append(WeekColumn(startDate: start, days: currentColumn))
                }
                currentColumn = Array(repeating: nil, count: 7)
                currentKey = key
                currentStart = startOfWeek(for: day.date)
            }

            let index = weekdayIndex(for: day.date)
            if index >= 0 && index < currentColumn.count {
                currentColumn[index] = day
            }
        }

        if let start = currentStart {
            columns.append(WeekColumn(startDate: start, days: currentColumn))
        }

        return columns
    }

    private func startOfWeek(for date: Date) -> Date {
        let cal = calendarWithMonday
        if let interval = cal.dateInterval(of: .weekOfYear, for: date) {
            return interval.start
        }
        return date
    }

    private func weekdayIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7 // shift so Monday = 0
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

private struct WeekColumn: Identifiable {
    let startDate: Date
    let days: [ContributionDay?]

    var id: Date { startDate }
}

private struct ContributionCalendarGrid: View {
    let weeks: [WeekColumn]
    let goalDailySeconds: Int
    let activeWeekdays: Set<Int>
    let dayLabels: [String]
    let squareSize: CGFloat
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Text("")
                    .frame(width: 36)
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    Text(weekLabel(for: index))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.65))
                        .frame(width: squareSize, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            ForEach(dayLabels.indices, id: \.self) { dayIndex in
                HStack(spacing: 6) {
                    Text(dayLabels[dayIndex])
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary.opacity(0.7))
                        .frame(width: 36, alignment: .trailing)

                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        let day: ContributionDay? = dayIndex < week.days.count ? week.days[dayIndex] : nil
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
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekLabel(for index: Int) -> String {
        return "W\(index + 1)"
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

private struct EmptyTrackerView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Your practice days will show up here.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ScribbleColors.secondary)
            Text("Practice to light up each square.")
                .font(.caption)
                .foregroundStyle(ScribbleColors.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PracticeDataStore())
    }
}
