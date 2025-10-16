import SwiftUI

struct ProfileCenterView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss

    private var today: ContributionDay {
        dataStore.todayContribution()
    }

    private var weeklySummary: (hits: Int, target: Int) {
        dataStore.weeklyGoalSummary()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    avatarCard
                    nameCard
                    difficultyCard
                    goalCard
                    preferencesCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.97, green: 0.99, blue: 1.0).ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }

    private var avatarCard: some View {
        VStack(spacing: 16) {
            DiceBearAvatar(seed: dataStore.profile.avatarSeed, size: 140)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)
            Button {
                shuffleAvatar()
            } label: {
                Label("Shuffle Avatar", systemImage: "shuffle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.86, blue: 0.4))
                    )
                    .foregroundStyle(Color(red: 0.29, green: 0.2, blue: 0.1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
        )
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Name")
                .font(.headline)
                .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))
            TextField("Explorer", text: nameBinding)
                .font(.title3.weight(.semibold))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
                )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 12)
        )
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Practice Difficulty")
                .font(.headline)
                .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))

            VStack(spacing: 12) {
                ForEach(PracticeDifficulty.allCases, id: \.self) { level in
                    DifficultyOptionTile(level: level,
                                         isSelected: dataStore.settings.difficulty == level,
                                         onSelect: {
                                             dataStore.updateDifficulty(level)
                                         })
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
        )
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("XP Goal")
                .font(.headline)
                .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))

            HStack(spacing: 24) {
                MiniGoalRing(name: dataStore.profile.displayName,
                             progress: dataStore.dailyProgressRatio(),
                             contribution: today)
                VStack(alignment: .leading, spacing: 8) {
                    Text(progressMessage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.39, blue: 0.6))
                    Text("This week: \(weeklySummary.hits) of \(weeklySummary.target) goal days")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.53, green: 0.61, blue: 0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                Stepper(value: dailyGoalBinding, in: 20...400, step: 10) {
                    Text("Daily XP target: \(dataStore.profile.goal.dailyXP) XP")
                        .font(.subheadline.weight(.semibold))
                }
                Stepper(value: activeDaysBinding, in: 1...7, step: 1) {
                    Text("Goal days each week: \(dataStore.profile.goal.activeDaysPerWeek)")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
        )
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.headline)
                .foregroundStyle(Color(red: 0.32, green: 0.42, blue: 0.61))

            Toggle(isOn: Binding(
                get: { dataStore.settings.hapticsEnabled },
                set: { dataStore.updateHapticsEnabled($0) }
            )) {
                Label("Haptic feedback", systemImage: "hand.tap.fill")
            }
            .tint(Color(red: 1.0, green: 0.75, blue: 0.3))

            Toggle(isOn: Binding(
                get: { dataStore.settings.isLeftHanded },
                set: { dataStore.updateLeftHanded($0) }
            )) {
                Label("Left-handed guides", systemImage: "hand.draw.fill")
            }
            .tint(Color(red: 0.39, green: 0.58, blue: 0.98))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        )
    }

    private var progressMessage: String {
        let remaining = max(dataStore.profile.goal.dailyXP - today.xpEarned, 0)
        if dataStore.profile.goal.dailyXP == 0 {
            return "Daily goals are paused."
        }
        if remaining == 0 {
            return "Today's goal met! 🎉"
        }
        return "\(remaining) XP to go today"
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { dataStore.profile.displayName },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                dataStore.updateDisplayName(trimmed.isEmpty ? "Explorer" : trimmed)
            }
        )
    }

    private var dailyGoalBinding: Binding<Int> {
        Binding(
            get: { dataStore.profile.goal.dailyXP },
            set: { newValue in
                var goal = dataStore.profile.goal
                goal.dailyXP = max(20, min(newValue, 400))
                dataStore.updateGoal(goal)
            }
        )
    }

    private var activeDaysBinding: Binding<Int> {
        Binding(
            get: { dataStore.profile.goal.activeDaysPerWeek },
            set: { newValue in
                var goal = dataStore.profile.goal
                goal.activeDaysPerWeek = max(1, min(newValue, 7))
                dataStore.updateGoal(goal)
            }
        )
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
}

private struct DiceBearAvatar: View {
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

private struct DifficultyOptionTile: View {
    let level: PracticeDifficulty
    let isSelected: Bool
    let onSelect: () -> Void

    private var title: String {
        level.title
    }

    private var subtitle: String {
        switch level {
        case .easy: return "Biggest stroke width and gentle guides."
        case .medium: return "Balanced stroke width with standard guides."
        case .hard: return "Slim stroke width and tighter accuracy."
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.white : Color(red: 0.36, green: 0.47, blue: 0.68))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(isSelected ? Color(red: 1.0, green: 0.75, blue: 0.3) : Color(red: 0.9, green: 0.95, blue: 1.0))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.47, green: 0.55, blue: 0.69))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.3))
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Color(red: 1.0, green: 0.95, blue: 0.83) : Color.white)
                    .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)
            )
            .foregroundStyle(Color(red: 0.28, green: 0.38, blue: 0.57))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch level {
        case .easy: return "tortoise.fill"
        case .medium: return "scribble.variable"
        case .hard: return "bolt.fill"
        }
    }
}

private struct MiniGoalRing: View {
    let name: String
    let progress: Double
    let contribution: ContributionDay

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
            Text(name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.34, green: 0.42, blue: 0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's progress \(contribution.xpEarned) out of \(contribution.goalXP) XP")
    }
}
