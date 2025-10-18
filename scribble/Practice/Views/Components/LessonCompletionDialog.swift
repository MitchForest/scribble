import SwiftUI

struct LessonCompletionDialog: View {
    let lessonTitle: String
    let hasNextLesson: Bool
    let onNext: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ScribbleColors.accentSoft.opacity(0.45))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(ScribbleColors.accent)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(ScribbleColors.accentDark)
                        )
                }

                Text("Lesson complete!")
                    .font(ScribbleTypography.titleMedium())
                    .foregroundColor(ScribbleColors.primary)

                Text("Ready for the next challenge?")
                    .font(ScribbleTypography.bodyMedium())
                    .foregroundColor(ScribbleColors.secondary.opacity(0.85))
            }

            VStack(spacing: 6) {
                Text("Up next")
                    .font(ScribbleTypography.caption())
                    .foregroundColor(ScribbleColors.secondary.opacity(0.7))

                Text(lessonTitle)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(ScribbleColors.primary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 18) {
                Button(action: onExit) {
                    Text("Exit Lesson")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                                .fill(ScribbleColors.accentSoft.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Text(nextButtonLabel)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                                .fill(ScribbleColors.accent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 420)
        .padding(.horizontal, 32)
        .padding(.vertical, 34)
        .background(
            RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusLarge, style: .continuous)
                .fill(ScribbleColors.cardBackground)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 28, x: 0, y: 20)
    }

    private var nextButtonLabel: String {
        hasNextLesson ? "Next Lesson" : "Replay Lesson"
    }
}
