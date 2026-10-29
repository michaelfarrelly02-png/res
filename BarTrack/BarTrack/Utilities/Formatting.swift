import Foundation

enum Format {
    /// "1:05" style clock.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "0.82s"
    static func seconds(_ interval: TimeInterval) -> String {
        String(format: "%.2fs", interval)
    }

    /// Relative speed score as a whole number.
    static func score(_ score: Double) -> String {
        "\(Int(score.rounded()))"
    }

    static func optionalScore(_ score: Double?) -> String {
        score.map(Self.score) ?? "–"
    }

    /// "+12%" / "−8%"
    static func signedPercent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "−\(abs(rounded))%" }
        return "0%"
    }
}

extension String {
    /// "yesterday" → "Yesterday", without capitalising every word.
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Small deterministic random generator so sample data and previews
/// look the same every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
