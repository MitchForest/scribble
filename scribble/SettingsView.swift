import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var showInputPreferenceSheet = false

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settings.hapticsEnabled },
            set: { dataStore.updateHapticsEnabled($0) }
        )
    }

    private var leftHandBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settings.isLeftHanded },
            set: { dataStore.updateLeftHanded($0) }
        )
    }

    private var inputPreferenceBinding: Binding<InputPreference> {
        Binding(
            get: { dataStore.settings.inputPreference },
            set: { dataStore.updateInputPreference($0) }
        )
    }

    private var strokeSizeBinding: Binding<StrokeSizePreference> {
        Binding(
            get: { dataStore.settings.strokeSize },
            set: { dataStore.updateStrokeSize($0) }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [ScribbleColors.backgroundTop, ScribbleColors.backgroundBottom],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        settingsCard(title: "Writing setup") {
                            VStack(spacing: 16) {
                                ForEach(StrokeSizePreference.allCases) { size in
                                    ScribbleSelectableOption(
                                        title: size.title,
                                        subtitle: size.description,
                                        systemName: strokeIcon(for: size),
                                        tint: strokeTint(for: size),
                                        isSelected: strokeSizeBinding.wrappedValue == size
                                    ) {
                                        strokeSizeBinding.wrappedValue = size
                                    }
                                }

                                ScribbleDropdownField(
                                    title: "Drawing input",
                                    value: inputPreferenceBinding.wrappedValue.title,
                                    systemImage: "slider.horizontal.3"
                                ) {
                                    showInputPreferenceSheet = true
                                }

                                Toggle(isOn: leftHandBinding) {
                                    Text("Left-handed mode")
                                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                                        .foregroundColor(ScribbleColors.primary)
                                }
                                .toggleStyle(ScribbleToggleStyle())
                                .accessibilityHint("Mirrors practice overlays and repositions buttons for left-handed writers.")
                            }
                        }

                        settingsCard(title: "Feedback") {
                            Toggle(isOn: hapticsBinding) {
                                Text("Play gentle haptics")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(ScribbleColors.primary)
                            }
                            .toggleStyle(ScribbleToggleStyle())
                            .accessibilityHint("Turn off if vibrations are distracting.")
                        }

                        settingsCard(title: "About Scribble") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Version")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(ScribbleColors.secondary.opacity(0.8))
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(ScribbleColors.primary)
                            }
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ScribbleColors.secondary)
                }
            }
            .sheet(isPresented: $showInputPreferenceSheet) {
                ScribbleOptionSheet(
                    title: "Choose your drawing tools",
                    message: "Pick the input that feels good for your hand today.",
                    options: InputPreference.allCases,
                    selection: inputPreferenceBinding,
                    label: { $0.title },
                    subtitle: { inputPreferenceSubtitle(for: $0) },
                    icon: { inputPreferenceIcon(for: $0) },
                    tint: { _ in ScribbleColors.accent }
                )
            }
        }
    }

    private func settingsCard<Content: View>(title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(ScribbleColors.primary)

            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ScribbleColors.cardBackground)
        )
        .shadow(color: ScribbleColors.shadow.opacity(0.2), radius: 22, x: 0, y: 14)
    }

    private func strokeIcon(for preference: StrokeSizePreference) -> String {
        switch preference {
        case .large: return "textformat.size.larger"
        case .standard: return "textformat.size"
        case .compact: return "textformat.size.smaller"
        }
    }

    private func strokeTint(for preference: StrokeSizePreference) -> Color {
        switch preference {
        case .large: return Color(red: 0.95, green: 0.82, blue: 0.98)
        case .standard: return Color(red: 0.78, green: 0.92, blue: 0.88)
        case .compact: return Color(red: 0.86, green: 0.92, blue: 1.0)
        }
    }

    private func inputPreferenceSubtitle(for preference: InputPreference) -> String {
        switch preference {
        case .pencilOnly:
            return "Best for precise strokes and pencil pressure."
        case .fingerAndPencil:
            return "Great when sharing an iPad or practicing without Pencil."
        }
    }

    private func inputPreferenceIcon(for preference: InputPreference) -> String {
        switch preference {
        case .pencilOnly:
            return "pencil.tip"
        case .fingerAndPencil:
            return "hand.draw"
        }
    }
}
