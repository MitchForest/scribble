import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @State private var showProfile = false
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
                        GoalTrackerCard(contributions: contributions,
                                        goal: dataStore.profile.goal)
                        .padding(.bottom, proxy.size.height * 0.04)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
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
            .sheet(isPresented: $showProfile) {
                ProfileCenterView()
                    .environmentObject(dataStore)
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
            ProfileMenuButton(seed: dataStore.profile.avatarSeed,
                              progress: progress,
                              today: today,
                              goal: dataStore.profile.goal,
                              difficulty: dataStore.settings.difficulty,
                              onDifficultyChange: { dataStore.updateDifficulty($0) },
                              guidesBinding: nil,
                              onOpenProfile: { showProfile = true })
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
                Text("Start Practice")
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
        .accessibilityLabel("Start Free Practice")
    }

    private func startPractice() {
        path.append(HomeRoute.freePractice)
    }

    private var progressSubtitle: String {
        guard today.goalXP > 0 else {
            return "Set a goal to fill your magic ring."
        }
        let remaining = max(today.goalXP - today.xpEarned, 0)
        return remaining == 0 ? "Today's goal is complete! 🎉" : "\(remaining) XP to fill today’s ring."
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
    let onDifficultyChange: (PracticeDifficulty) -> Void
    let guidesBinding: Binding<Bool>?
    let onOpenProfile: (() -> Void)?

    private var difficultyBinding: Binding<PracticeDifficulty> {
        Binding(
            get: { difficulty },
            set: { onDifficultyChange($0) }
        )
    }

    var body: some View {
        Menu {
            Section {
                Text("XP today: \(today.xpEarned)/\(max(goal.dailyXP, 1))")
                Text("Weekly goal: \(goal.activeDaysPerWeek) days")
            }
            Section {
                Picker("Difficulty", selection: difficultyBinding) {
                    ForEach(PracticeDifficulty.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
            }
            if let guidesBinding {
                Section {
                    Toggle("Guides On", isOn: guidesBinding)
                }
            }
            if let onOpenProfile {
                Section {
                    Button("Open Profile", action: onOpenProfile)
                }
            }
        } label: {
            AvatarProgressButton(seed: seed, progress: progress)
                .accessibilityLabel("Open profile options")
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

private struct GoalTrackerCard: View {
    let contributions: [ContributionDay]
    let goal: PracticeGoal
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Tracker")
                .font(.headline)
                .foregroundStyle(Color(red: 0.3, green: 0.4, blue: 0.6))
            if contributions.isEmpty {
                EmptyTrackerView()
            } else {
                ContributionGrid(columns: weekColumns)
            }
            Text("Goal: \(goal.dailyXP) XP • \(goal.activeDaysPerWeek) days per week")
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.38, green: 0.47, blue: 0.65))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
        )
    }

    private var weekColumns: [[ContributionDay?]] {
        guard !contributions.isEmpty else { return [] }
        var columns: [[ContributionDay?]] = []
        var currentKey: DateComponents?
        var currentColumn = Array<ContributionDay?>(repeating: nil, count: 7)

        for day in contributions {
            let key = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: day.date)
            if currentKey == nil {
                currentKey = key
            } else if key != currentKey {
                columns.append(currentColumn)
                currentColumn = Array(repeating: nil, count: 7)
                currentKey = key
            }

            let weekday = calendar.component(.weekday, from: day.date)
            let index = (weekday + 6) % 7 // Monday-first ordering
            currentColumn[index] = day
        }

        columns.append(currentColumn)
        return columns
    }
}

private struct ContributionGrid: View {
    let columns: [[ContributionDay?]]
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        let day = week[index]
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(color(for: day))
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .accessibilityLabel(label(for: day))
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func color(for day: ContributionDay?) -> Color {
        guard let day else { return Color.white.opacity(0.15) }
        guard day.goalXP > 0 else { return Color(red: 0.9, green: 0.95, blue: 1.0) }
        let ratio = min(Double(day.xpEarned) / Double(day.goalXP), 1)
        switch ratio {
        case 0:
            return Color.white.opacity(0.25)
        case 0..<0.5:
            return Color(red: 0.74, green: 0.86, blue: 1.0)
        case 0..<1:
            return Color(red: 0.52, green: 0.72, blue: 1.0)
        default:
            return Color(red: 1.0, green: 0.8, blue: 0.4)
        }
    }

    private func label(for day: ContributionDay?) -> String {
        guard let day else { return "No practice recorded." }
        if day.goalXP == 0 { return "Goal paused on \(dayFormatter.string(from: day.date))." }
        if day.didHitGoal { return "Goal met on \(dayFormatter.string(from: day.date))." }
        return "\(day.xpEarned) of \(day.goalXP) XP on \(dayFormatter.string(from: day.date))."
    }
}

private struct EmptyTrackerView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(red: 0.94, green: 0.97, blue: 1.0))
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Text("Your practice days will appear here.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.33, green: 0.42, blue: 0.61))
                    Text("Earn XP to light up the calendar squares.")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.75))
                }
            )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PracticeDataStore())
    }
}
