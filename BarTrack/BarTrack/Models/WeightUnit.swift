import Foundation

/// Weights are always stored in kilograms; this only affects display and input.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb

    var id: String { rawValue }

    static let poundsPerKilogram = 2.2046226218

    var symbol: String { rawValue }

    var displayName: String {
        switch self {
        case .kg: "Kilograms"
        case .lb: "Pounds"
        }
    }

    /// Increment used by the +/− weight buttons.
    var step: Double {
        switch self {
        case .kg: 2.5
        case .lb: 5
        }
    }

    func fromKg(_ kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lb: kg * Self.poundsPerKilogram
        }
    }

    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lb: value / Self.poundsPerKilogram
        }
    }

    /// Number only, e.g. "102.5".
    func number(fromKg kg: Double) -> String {
        Self.formatNumber(fromKg(kg))
    }

    /// Number with unit, e.g. "102.5 kg".
    func format(kg: Double) -> String {
        "\(number(fromKg: kg)) \(symbol)"
    }

    static func formatNumber(_ value: Double) -> String {
        // Round to 0.1 to hide floating-point noise from unit conversion.
        let rounded = (value * 10).rounded() / 10
        return rounded.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    static func parse(_ text: String) -> Double? {
        let normalised = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value.isFinite else { return nil }
        return value
    }
}
