import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @Environment(\.dismiss) private var dismiss

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
            Form {
                Section("Input") {
                    Picker("Letter size", selection: strokeSizeBinding) {
                        ForEach(StrokeSizePreference.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Letter size")

                    Text(dataStore.settings.strokeSize.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Drawing input", selection: inputPreferenceBinding) {
                        ForEach(InputPreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Drawing input preference")

                    Toggle("Left-handed mode", isOn: leftHandBinding)
                        .accessibilityLabel("Left-handed mode")
                        .accessibilityHint("Mirrors practice overlays and repositions buttons for left-handed writers.")
                }

                Section("Feedback") {
                    Toggle("Enable haptics", isOn: hapticsBinding)
                        .accessibilityLabel("Enable haptic feedback")
                        .accessibilityHint("Turn off if vibrations are distracting.")
                }

                Section("About") {
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .accessibilityLabel("App version")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
