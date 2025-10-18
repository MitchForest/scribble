import SwiftUI
import PencilKit
import Foundation

func practiceDebugLog(_ message: @autoclosure () -> String,
                              function: StaticString = #function) {
    print("[Practice] \(function): \(message())")
}


struct LessonPracticeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var activeDialog: QuickDialog?
    @State private var dialogInitialTab: ProfileQuickActionsDialog.Tab = .today
    @State private var currentIndex: Int
    @State private var boardKey = UUID()
    @State private var boardDirection: BoardTransitionDirection = .forward
    @State private var clearToken = 0
    @State private var lessonCompletionVisible = false

    private let lessons: [PracticeLesson]

    init(lesson: PracticeLesson) {
        let unit = PracticeLessonLibrary.unit(for: lesson.unitId)
        let ordered = unit?.lessons.sorted(by: { $0.order < $1.order }) ?? [lesson]
        self.lessons = ordered
        let startIndex = ordered.firstIndex(where: { $0.id == lesson.id }) ?? 0
        _currentIndex = State(initialValue: startIndex)
    }

    private enum BoardTransitionDirection {
        case forward
        case backward
    }

    private var currentLesson: PracticeLesson {
        lessons[currentIndex]
    }

    private var nextLessonIndex: Int {
        guard !lessons.isEmpty else { return 0 }
        return (currentIndex + 1) % lessons.count
    }

    private var nextLessonDisplayTitle: String {
        if lessons.indices.contains(nextLessonIndex) && lessons.count > 1 {
            return lessons[nextLessonIndex].title
        } else {
            return currentLesson.title
        }
    }

    private var hasMultipleLessons: Bool {
        lessons.count > 1
    }

    private var canNavigateBackward: Bool {
        currentIndex > 0
    }

    private var canNavigateForward: Bool {
        guard lessons.count > 0 else { return false }
        return currentIndex < lessons.count - 1
    }

    private var boardTransition: AnyTransition {
        switch boardDirection {
        case .forward:
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity))
        case .backward:
            return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var streak: Int {
        dataStore.currentStreak()
    }

    var body: some View {
        ZStack {
            PracticeBackground()
            VStack(alignment: .leading, spacing: 24) {
                header
                lessonBoard
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            ZStack {
                if lessonCompletionVisible {
                    DialogOverlay {
                        LessonCompletionDialog(lessonTitle: nextLessonDisplayTitle,
                                               hasNextLesson: hasMultipleLessons,
                                               onNext: {
                                                   withAnimation(.easeInOut(duration: 0.25)) {
                                                       lessonCompletionVisible = false
                                                   }
                                                   DispatchQueue.main.async {
                                                       advanceToNextLesson()
                                                   }
                                               },
                                               onExit: {
                                                   withAnimation(.easeInOut(duration: 0.25)) {
                                                       lessonCompletionVisible = false
                                                   }
                                                   DispatchQueue.main.async {
                                                       dismiss()
                                                   }
                                               })
                    } onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            lessonCompletionVisible = false
                        }
                    }
                } else if let dialog = activeDialog {
                    DialogOverlay {
                        dialogView(for: dialog)
                    } onDismiss: {
                        closeDialog()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeDialog)
        .animation(.easeInOut(duration: 0.25), value: lessonCompletionVisible)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Scribble")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.24, green: 0.33, blue: 0.57))
            }
            Spacer()
            LessonNavigationDock(canGoBackward: canNavigateBackward,
                                 canGoForward: canNavigateForward,
                                 onBackward: navigateToPreviousLesson,
                                 onClear: clearCurrentLessonProgress,
                                 onForward: navigateToNextLesson)
            Spacer(minLength: 16)
            HStack(spacing: 16) {
                StreakBadge(streak: streak) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dialogInitialTab = .streak
                        activeDialog = .profile
                    }
                }
                ProfileMenuButton(seed: dataStore.profile.avatarSeed,
                                  progress: dataStore.dailyProgressRatio(),
                                  onOpen: {
                                      withAnimation(.easeInOut(duration: 0.25)) {
                                          dialogInitialTab = .today
                                          activeDialog = .profile
                                      }
                                  })
            }
        }
    }

    private var lessonBoard: some View {
        ZStack {
            PracticeBoardView(lesson: currentLesson,
                                settings: dataStore.settings,
                                allowFingerInput: dataStore.settings.inputPreference.allowsFingerInput,
                                clearTrigger: clearToken,
                                onLetterAward: { award in
                                    recordLetterXP(for: award)
                                },
                                onProgressChanged: { completed, total in
                                    dataStore.updateLessonProgress(for: currentLesson,
                                                                   completedLetters: completed,
                                                                   totalLetters: total)
                                },
                                onLessonComplete: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        activeDialog = nil
                                        lessonCompletionVisible = true
                                    }
                                })
            .id(boardKey)
            .transition(boardTransition)
        }
        .animation(.easeInOut(duration: lessonBoardTransitionDuration), value: boardKey)
    }

    private func navigateToLesson(at index: Int,
                                  direction: BoardTransitionDirection,
                                  animated: Bool = true) {
        guard lessons.indices.contains(index) else { return }
        boardDirection = direction
        let updates = {
            currentIndex = index
            boardKey = UUID()
        }
        if animated {
            withAnimation(.easeInOut(duration: lessonBoardTransitionDuration)) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func navigateToPreviousLesson() {
        guard canNavigateBackward else { return }
        navigateToLesson(at: currentIndex - 1, direction: .backward)
    }

    private func navigateToNextLesson() {
        guard canNavigateForward else { return }
        navigateToLesson(at: currentIndex + 1, direction: .forward)
    }

    private func clearCurrentLessonProgress() {
        guard !lessons.isEmpty else { return }
        dataStore.resetLessonProgress(for: currentLesson)
        clearToken &+= 1
    }

    private func advanceToNextLesson() {
        guard !lessons.isEmpty else { return }
        navigateToLesson(at: nextLessonIndex, direction: .forward)
    }

    private func recordLetterXP(for letter: LetterTimelineItem) {
        guard let letterId = letter.letterId else { return }
        let multiplier: Double
        switch dataStore.settings.difficulty {
        case .beginner: multiplier = 1.4
        case .intermediate: multiplier = 1.0
        case .expert: multiplier = 0.8
        }
        let baseSeconds = 5
        let adjusted = Int(Double(baseSeconds) * multiplier)
        dataStore.addWritingSeconds(max(adjusted, 1),
                                    category: .practiceLine,
                                    letterId: letterId)
    }

    private func closeDialog() {
        withAnimation(.easeInOut(duration: 0.25)) {
            activeDialog = nil
        }
    }

    @ViewBuilder
    private func dialogView(for _: QuickDialog) -> some View {
        ProfileQuickActionsDialog(initialTab: dialogInitialTab,
                                  onClose: { closeDialog() },
                                  onExitLesson: {
                                      dismiss()
                                  })
            .environmentObject(dataStore)
    }
}

private struct StreakBadge: View {
    let streak: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.25))
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.4).opacity(0.35), radius: 8, x: 0, y: 6)
                Text("\(streak)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
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
    }
}

private struct LessonNavigationDock: View {
    let canGoBackward: Bool
    let canGoForward: Bool
    let onBackward: () -> Void
    let onClear: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            controlButton(systemName: "chevron.left",
                          accessibilityLabel: "Previous lesson",
                          isEnabled: canGoBackward,
                          tint: ScribbleColors.primary,
                          action: onBackward)

            controlButton(systemName: "eraser",
                          accessibilityLabel: "Clear current practice",
                          tint: ScribbleColors.accentDark,
                          background: ScribbleColors.accent.opacity(0.18),
                          action: onClear)

            controlButton(systemName: "chevron.right",
                          accessibilityLabel: "Next lesson",
                          isEnabled: canGoForward,
                          tint: ScribbleColors.primary,
                          action: onForward)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private func controlButton(systemName: String,
                               accessibilityLabel: String,
                               isEnabled: Bool = true,
                               tint: Color,
                               background: Color = Color.white.opacity(0.95),
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint.opacity(isEnabled ? 1.0 : 0.45))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(isEnabled ? background : ScribbleColors.controlDisabled.opacity(0.85))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isEnabled ? 0.65 : 0.45), lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.55)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
