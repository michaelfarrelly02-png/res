import SwiftUI

/// Tentative relative speed label for a rep.
enum SpeedClass: String, Codable, CaseIterable, Identifiable, Hashable {
    case slow, medium, fast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slow: "SLOW"
        case .medium: "MEDIUM"
        case .fast: "FAST"
        }
    }

    var color: Color {
        switch self {
        case .slow: Theme.slow
        case .medium: Theme.medium
        case .fast: Theme.fast
        }
    }

    var symbol: String {
        switch self {
        case .slow: "tortoise.fill"
        case .medium: "speedometer"
        case .fast: "hare.fill"
        }
    }
}

/// Turns a relative speed score (0–100) into a Slow / Medium / Fast label.
/// Kept separate so thresholds can be tuned once the real algorithm is ported.
struct SpeedClassifier {
    var slowUpperBound: Double = 45
    var fastLowerBound: Double = 70

    static let `default` = SpeedClassifier()

    func classify(_ score: Double) -> SpeedClass {
        if score >= fastLowerBound { return .fast }
        if score < slowUpperBound { return .slow }
        return .medium
    }
}
