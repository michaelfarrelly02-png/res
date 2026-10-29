import Foundation

enum Exercise: String, CaseIterable, Identifiable, Codable, Hashable {
    case backSquat
    case benchPress
    case deadlift
    case overheadPress
    case barbellRow

    var id: String { rawValue }

    /// Lifts that can be tracked right now. The others show as "Coming soon".
    static let available: [Exercise] = [.backSquat]

    var isAvailable: Bool { Self.available.contains(self) }

    var displayName: String {
        switch self {
        case .backSquat: "Back Squat"
        case .benchPress: "Bench Press"
        case .deadlift: "Deadlift"
        case .overheadPress: "Overhead Press"
        case .barbellRow: "Barbell Row"
        }
    }

    var shortName: String {
        switch self {
        case .backSquat: "Squat"
        case .benchPress: "Bench"
        case .deadlift: "Deadlift"
        case .overheadPress: "OHP"
        case .barbellRow: "Row"
        }
    }

    var symbol: String {
        switch self {
        case .backSquat: "figure.strengthtraining.functional"
        case .benchPress: "dumbbell.fill"
        case .deadlift: "figure.strengthtraining.traditional"
        case .overheadPress: "figure.arms.open"
        case .barbellRow: "figure.rower"
        }
    }

    var focus: String {
        switch self {
        case .backSquat: "Quads · Glutes"
        case .benchPress: "Chest · Triceps"
        case .deadlift: "Posterior chain"
        case .overheadPress: "Shoulders"
        case .barbellRow: "Upper back"
        }
    }

    /// Suggested starting weight for the setup screen.
    var defaultWeightKg: Double {
        switch self {
        case .backSquat: 100
        case .benchPress: 80
        case .deadlift: 140
        case .overheadPress: 50
        case .barbellRow: 70
        }
    }

    /// Rough "heavy" reference load used only by the simulator to make
    /// heavier sets produce slower simulated reps.
    var referenceWeightKg: Double {
        switch self {
        case .backSquat: 150
        case .benchPress: 110
        case .deadlift: 190
        case .overheadPress: 70
        case .barbellRow: 100
        }
    }

    /// Mean concentric velocity (m/s) from a grinding rep to a very fast one.
    /// Used only to simulate estimated velocities in Demo Mode.
    var simulatedVelocityRange: ClosedRange<Double> {
        switch self {
        case .backSquat: 0.25...1.30
        case .benchPress: 0.15...1.20
        case .deadlift: 0.20...1.20
        case .overheadPress: 0.20...1.20
        case .barbellRow: 0.40...1.40
        }
    }

    /// Typical bar travel for one rep, in centimetres (simulation only).
    var typicalRangeOfMotionCm: Double {
        switch self {
        case .backSquat: 60
        case .benchPress: 42
        case .deadlift: 55
        case .overheadPress: 55
        case .barbellRow: 38
        }
    }

    /// Typical concentric duration (seconds) for a moderately fast rep.
    var baseConcentricDuration: Double {
        switch self {
        case .backSquat: 0.9
        case .benchPress: 0.8
        case .deadlift: 1.0
        case .overheadPress: 0.85
        case .barbellRow: 0.6
        }
    }
}
