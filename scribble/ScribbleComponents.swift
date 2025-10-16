import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ScribbleDropdownField: View {
    let title: String
    let value: String
    let systemImage: String?
    let action: () -> Void

    init(title: String,
         value: String,
         systemImage: String? = "chevron.down",
         action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(ScribbleColors.secondary.opacity(0.75))
                    .tracking(0.6)

                HStack(spacing: 12) {
                    Text(value)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                        .lineLimit(1)

                    Spacer()

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ScribbleColors.accentDark.opacity(0.8))
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(ScribbleColors.accent.opacity(0.25))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                    .fill(ScribbleColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                    .stroke(ScribbleColors.inputBorder.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct ScribbleOptionSheet<Option: Identifiable & Hashable>: View {
    let title: String
    let message: String?
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    let subtitle: (Option) -> String?
    let icon: (Option) -> String?
    let tint: (Option) -> Color
    let onSelect: (Option) -> Void

    @Environment(\.dismiss) private var dismiss

    init(title: String,
         message: String? = nil,
         options: [Option],
         selection: Binding<Option>,
         label: @escaping (Option) -> String,
         subtitle: @escaping (Option) -> String? = { _ in nil },
         icon: @escaping (Option) -> String? = { _ in nil },
         tint: @escaping (Option) -> Color = { _ in ScribbleColors.accent },
         onSelect: @escaping (Option) -> Void = { _ in }) {
        self.title = title
        self.message = message
        self.options = options
        self._selection = selection
        self.label = label
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 56, height: 6)
                .padding(.top, 12)

            VStack(spacing: 10) {
                Text(title)
                    .font(ScribbleTypography.titleMedium())
                    .foregroundColor(ScribbleColors.primary)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(ScribbleTypography.bodyLarge())
                        .foregroundColor(ScribbleColors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(options) { option in
                        ScribbleSelectableOption(
                            title: label(option),
                            subtitle: subtitle(option),
                            systemName: icon(option),
                            tint: tint(option),
                            isSelected: option == selection
                        ) {
                            selection = option
                            onSelect(option)
#if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .background(
            ScribbleColors.cardBackground
                .ignoresSafeArea()
        )
    }
}

struct ScribbleSelectableOption: View {
    let title: String
    let subtitle: String?
    let systemName: String?
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    init(title: String,
         subtitle: String?,
         systemName: String?,
         tint: Color,
         isSelected: Bool,
         action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemName = systemName
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(ScribbleColors.primary.opacity(0.75))
                        .frame(width: 62, height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(tint.opacity(0.9))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(ScribbleColors.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ScribbleColors.accent)
                        .font(.system(size: 30, weight: .bold))
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusLarge, style: .continuous)
                    .fill(isSelected ? ScribbleColors.inputBackground : ScribbleColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusLarge, style: .continuous)
                    .stroke(isSelected ? ScribbleColors.accent : ScribbleColors.inputBorder.opacity(0.2), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08),
                    radius: isSelected ? 18 : 12,
                    x: 0,
                    y: isSelected ? 12 : 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct ScribbleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
#if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    configuration.label
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(ScribbleColors.primary)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(configuration.isOn ? ScribbleColors.accent : ScribbleColors.controlDisabled)
                    .frame(width: 70, height: 40)
                    .overlay(
                        Circle()
                            .fill(ScribbleColors.surface)
                            .frame(width: 36, height: 36)
                            .offset(x: configuration.isOn ? 14 : -14)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                    )
                    .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                    .fill(ScribbleColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ScribbleSpacing.cornerRadiusMedium, style: .continuous)
                    .stroke(ScribbleColors.inputBorder.opacity(0.4), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
