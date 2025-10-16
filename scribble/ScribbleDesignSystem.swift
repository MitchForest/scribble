import SwiftUI

enum ScribbleColors {
    static let backgroundTop = Color(red: 0.95, green: 0.98, blue: 1.0)
    static let backgroundBottom = Color(red: 0.86, green: 0.93, blue: 1.0)

    static let cardBackground = Color(red: 1.0, green: 0.99, blue: 0.95)
    static let surface = Color.white

    static let primaryText = Color(red: 0.22, green: 0.29, blue: 0.57)
    static let secondaryText = Color(red: 0.32, green: 0.43, blue: 0.67)
    static let mutedText = Color(red: 0.58, green: 0.64, blue: 0.78)

    // Legacy aliases used across views while the design system is being unified.
    static let primary = primaryText
    static let secondary = secondaryText
    static let muted = mutedText

    static let accent = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let accentSoft = Color(red: 1.0, green: 0.9, blue: 0.64)
    static let accentDark = Color(red: 0.35, green: 0.24, blue: 0.12)

    static let inputBackground = Color(red: 1.0, green: 0.95, blue: 0.84)
    static let inputBorder = Color(red: 1.0, green: 0.85, blue: 0.52)
    static let controlDisabled = Color(red: 0.89, green: 0.9, blue: 0.93)

    static let shadow = Color(red: 0.78, green: 0.6, blue: 0.3)
}

enum ScribbleSpacing {
    static let cardPadding: CGFloat = 28
    static let controlHeight: CGFloat = 64
    static let cornerRadiusLarge: CGFloat = 36
    static let cornerRadiusMedium: CGFloat = 26
    static let cornerRadiusSmall: CGFloat = 20
}

enum ScribbleTypography {
    static func titleLarge() -> Font {
        .system(size: 34, weight: .heavy, design: .rounded)
    }

    static func titleMedium() -> Font {
        .system(size: 28, weight: .heavy, design: .rounded)
    }

    static func bodyLarge() -> Font {
        .system(size: 20, weight: .medium, design: .rounded)
    }

    static func bodyMedium() -> Font {
        .system(size: 18, weight: .semibold, design: .rounded)
    }

    static func caption() -> Font {
        .system(size: 14, weight: .semibold, design: .rounded)
    }
}
