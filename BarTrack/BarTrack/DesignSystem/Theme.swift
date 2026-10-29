import SwiftUI

// MARK: - Stored preference keys

enum AppStorageKey {
    static let weightUnit = "weightUnit"
    static let accentTheme = "accentTheme"
    static let backgroundStyle = "backgroundStyle"
    static let demoMode = "demoMode"
    static let userName = "userName"
    static let lastExercise = "lastExercise"
    static let simulationPace = "simulationPace"
}

// MARK: - Theme options

enum AccentTheme: String, CaseIterable, Identifiable {
    case teal, cyan, mint, lime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teal: "Electric Teal"
        case .cyan: "Ice Cyan"
        case .mint: "Mint"
        case .lime: "Volt"
        }
    }

    var color: Color {
        switch self {
        case .teal: Color(red: 0.00, green: 0.90, blue: 0.80)
        case .cyan: Color(red: 0.20, green: 0.80, blue: 1.00)
        case .mint: Color(red: 0.35, green: 0.95, blue: 0.65)
        case .lime: Color(red: 0.80, green: 1.00, blue: 0.25)
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case navy, black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .navy: "Deep Navy"
        case .black: "True Black"
        }
    }

    var baseColor: Color {
        switch self {
        case .navy: Color(red: 0.027, green: 0.043, blue: 0.082)
        case .black: Color(red: 0.0, green: 0.0, blue: 0.0)
        }
    }

    var surfaceColor: Color {
        switch self {
        case .navy: Color(red: 0.063, green: 0.090, blue: 0.145)
        case .black: Color(red: 0.067, green: 0.071, blue: 0.082)
        }
    }
}

// MARK: - Theme tokens

enum Theme {
    static var accentTheme: AccentTheme {
        AccentTheme(rawValue: UserDefaults.standard.string(forKey: AppStorageKey.accentTheme) ?? "") ?? .teal
    }

    static var backgroundStyle: BackgroundStyle {
        BackgroundStyle(rawValue: UserDefaults.standard.string(forKey: AppStorageKey.backgroundStyle) ?? "") ?? .navy
    }

    // Brand
    static var accent: Color { accentTheme.color }
    static let onAccent = Color(red: 0.02, green: 0.06, blue: 0.08)

    // Surfaces
    static var background: Color { backgroundStyle.baseColor }
    static var surface: Color { backgroundStyle.surfaceColor }
    static let surfaceRaised = Color(red: 0.10, green: 0.135, blue: 0.20)
    static let tabBarBackground = Color(red: 0.035, green: 0.055, blue: 0.10)
    static let border = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.16)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.64)
    static let textTertiary = Color(white: 0.44)

    // Speed classes (fixed so their meaning never changes with the theme)
    static let fast = Color(red: 0.00, green: 0.90, blue: 0.80)
    static let medium = Color(red: 0.36, green: 0.55, blue: 1.00)
    static let slow = Color(red: 1.00, green: 0.45, blue: 0.24)

    // Status
    static let recording = Color(red: 1.00, green: 0.27, blue: 0.33)
    static let warning = Color(red: 1.00, green: 0.75, blue: 0.25)
    static let danger = Color(red: 1.00, green: 0.33, blue: 0.36)

    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 16
        static let chip: CGFloat = 12
    }

    enum Spacing {
        static let screen: CGFloat = 16
        static let section: CGFloat = 20
    }
}

extension Font {
    /// Large, rounded numerals used for performance metrics.
    static func metric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
