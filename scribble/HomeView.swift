import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @State private var path = NavigationPath()
    @State private var activeDialog: QuickDialog?
    @State private var dialogInitialTab: ProfileQuickActionsDialog.Tab = .today

    private let contributionWindow = 84
    private let units = PracticeLessonLibrary.units

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
            withAnimation(.easeInOut(duration: 0.25)) {
                dialogInitialTab = .streak
                activeDialog = .profile
            }
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
                ScrollView {
                    VStack(spacing: 32) {
                        header
                        unitSelection
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .practiceLesson(let lessonID):
                    if let lesson = PracticeLessonLibrary.lesson(for: lessonID) {
                        LessonPracticeView(lesson: lesson)
                            .environmentObject(dataStore)
                    } else {
                        Text("Lesson unavailable")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay {
            if let dialog = activeDialog {
                DialogOverlay {
                    dialogView(for: dialog)
                } onDismiss: {
                    closeDialog()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeDialog)
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
                                  onOpen: {
                                      withAnimation(.easeInOut(duration: 0.25)) {
                                          dialogInitialTab = .today
                                          activeDialog = .profile
                                      }
                                  })
            }
        }
        .accessibilityElement(children: .combine)
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

    private var unitSelection: some View {
        LazyVGrid(columns: unitColumns, spacing: 28) {
            ForEach(unitSummaries, id: \.unit.id) { summary in
                UnitCard(unit: summary.unit,
                         status: summary.status) {
                    guard let nextLesson = summary.status.nextLesson else { return }
                    path.append(HomeRoute.practiceLesson(nextLesson.id))
                }
            }
        }
    }

    private var unitColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 340, maximum: 420), spacing: 28, alignment: .top)]
    }

    private var unitSummaries: [(unit: PracticeUnit, status: UnitStatus)] {
        units.map { unit in
            let status = unitStatus(for: unit)
            return (unit, status)
        }
    }

    private func unitStatus(for unit: PracticeUnit) -> UnitStatus {
        let orderedLessons = unit.lessons.sorted { $0.order < $1.order }
        var completedSets = 0
        var nextLesson: PracticeLesson?

        for lesson in orderedLessons {
            let progress = dataStore.lessonProgress(for: lesson)
            if progress.completed >= progress.total {
                completedSets += 1
            } else if nextLesson == nil {
                nextLesson = lesson
            }
        }

        if nextLesson == nil {
            nextLesson = orderedLessons.last
        }

        return UnitStatus(completedSets: completedSets,
                          totalSets: orderedLessons.count,
                          nextLesson: nextLesson)
    }

    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.25)) {
            activeDialog = nil
        }
    }

    @ViewBuilder
    private func dialogView(for _: QuickDialog) -> some View {
        ProfileQuickActionsDialog(initialTab: dialogInitialTab,
                                  onClose: { closeDialog() })
            .environmentObject(dataStore)
    }

}

private enum HomeRoute: Hashable {
    case practiceLesson(PracticeLesson.ID)
}

private struct UnitStatus {
    let completedSets: Int
    let totalSets: Int
    let nextLesson: PracticeLesson?

    var remainingSets: Int {
        max(totalSets - completedSets, 0)
    }

    var completionRatio: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    var isComplete: Bool {
        remainingSets == 0
    }
}

private struct UnitCard: View {
    let unit: PracticeUnit
    let status: UnitStatus
    let onSelect: () -> Void

    private var setCountText: String {
        let label = status.totalSets == 1 ? "set" : "sets"
        return "\(status.totalSets) \(label)"
    }

    private var remainingText: String {
        guard status.remainingSets > 0 else {
            return "All sets complete"
        }
        let label = status.remainingSets == 1 ? "set left" : "sets left"
        return "\(status.remainingSets) \(label)"
    }

    private var progressDescription: String {
        let label = status.totalSets == 1 ? "set" : "sets"
        return "\(min(status.completedSets, status.totalSets)) of \(status.totalSets) \(label) complete"
    }

    private var nextDescription: String {
        guard status.remainingSets > 0, let next = status.nextLesson else {
            return "Jump back into your favorite set to keep the streak alive."
        }
        return "Up next: \(next.title)"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(unit.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.24, green: 0.33, blue: 0.57))
                    Text(unit.description)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.45, green: 0.54,  blue: 0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    UnitInfoChip(icon: "square.grid.2x2.fill",
                                 text: setCountText)
                    UnitInfoChip(icon: status.isComplete ? "sparkles" : "flag.checkered",
                                 text: remainingText,
                                 accent: status.isComplete ? Color(red: 0.33, green: 0.56, blue: 0.91) : Color(red: 1.0, green: 0.72, blue: 0.32))
                }

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: status.completionRatio)
                        .tint(Color(red: 0.98, green: 0.58, blue: 0.25))
                    Text(progressDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(red: 0.48, green: 0.57, blue: 0.74))
                }

                Text(nextDescription)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.26, green: 0.36, blue: 0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct UnitInfoChip: View {
    let icon: String
    let text: String
    var accent: Color = Color(red: 0.52, green: 0.62, blue: 0.84)

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.24))
        )
    }
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
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            AvatarProgressButton(seed: seed, progress: progress)
                .accessibilityLabel("Open profile options")
        }
        .buttonStyle(.plain)
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PracticeDataStore())
    }
}
