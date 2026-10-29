import Foundation

/// One completed repetition.
///
/// `speedScore` is a unitless, relative 0–100 score. It is NOT a validated
/// velocity in m/s. Validated metrics (mean concentric velocity, peak velocity)
/// will be added as separate fields once the algorithm has been validated.
struct RepRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var number: Int
    var speedScore: Double
    var speedClass: SpeedClass
    /// Detected movement duration in seconds.
    var duration: TimeInterval
    /// Seconds since the start of the set.
    var timestamp: TimeInterval

    // Estimated physical metrics. EXPERIMENTAL: not yet validated against a
    // reference device, so the UI always labels them as estimates.
    /// Estimated mean concentric velocity, m/s.
    var meanVelocity: Double? = nil
    /// Estimated peak concentric velocity, m/s.
    var peakVelocity: Double? = nil
    /// Estimated mean concentric power, watts.
    var power: Double? = nil
    /// Estimated bar travel (range of motion), cm.
    var rangeOfMotionCm: Double? = nil
}

/// The relative speed-score range the lifter is aiming for (e.g. 60–80).
struct SpeedZone: Codable, Hashable {
    var lower: Double
    var upper: Double

    enum Status {
        case below, inZone, above

        var label: String {
            switch self {
            case .below: "TOO SLOW"
            case .inZone: "IN ZONE"
            case .above: "TOO FAST"
            }
        }
    }

    func status(for score: Double) -> Status {
        if score < lower { return .below }
        if score > upper { return .above }
        return .inZone
    }

    func contains(_ score: Double) -> Bool { status(for: score) == .inZone }

    var text: String { "\(Int(lower))–\(Int(upper))" }

    /// Ready-made zones. Scores are relative, so these are starting points.
    enum Preset: String, CaseIterable, Identifiable {
        case speed, power, strength, custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .speed: "Speed"
            case .power: "Power"
            case .strength: "Strength"
            case .custom: "Custom"
            }
        }

        var zone: SpeedZone? {
            switch self {
            case .speed: SpeedZone(lower: 75, upper: 95)
            case .power: SpeedZone(lower: 60, upper: 80)
            case .strength: SpeedZone(lower: 40, upper: 60)
            case .custom: nil
            }
        }

        static func matching(_ zone: SpeedZone) -> Preset {
            allCases.first { $0.zone == zone } ?? .custom
        }
    }
}

/// Settings chosen on the Start Workout screen.
struct SetConfiguration: Hashable {
    var exercise: Exercise
    var weightKg: Double
    var targetReps: Int?
    var source: TrackingSource
    var speedZone: SpeedZone? = nil
    /// Stop the set when speed drops this many percent below the best rep.
    var velocityLossLimit: Double? = nil
    /// Start the timer on the first rep and end the set after a pause.
    var autoDetect: Bool = false
    /// Seconds without a rep before the set ends itself (when `autoDetect`).
    var autoEndAfter: TimeInterval = 8
}

/// A finished set before it is saved to storage.
struct SetResult: Identifiable, Hashable {
    let id = UUID()
    var setNumber: Int
    var exercise: Exercise
    var weightKg: Double
    var targetReps: Int?
    var reps: [RepRecord]
    var duration: TimeInterval
    var startedAt: Date
    var source: TrackingSource
    var speedZone: SpeedZone? = nil
    var velocityLossLimit: Double? = nil
    /// When the set finished, for the rest timer.
    var endedAt: Date = Date()

    var analytics: SetAnalytics { SetAnalytics(reps: reps) }
}

/// Summary statistics derived from a list of reps.
struct SetAnalytics {
    let reps: [RepRecord]

    var count: Int { reps.count }

    var averageScore: Double? {
        guard !reps.isEmpty else { return nil }
        return reps.map(\.speedScore).reduce(0, +) / Double(reps.count)
    }

    var averageClass: SpeedClass? {
        averageScore.map { SpeedClassifier.default.classify($0) }
    }

    var fastest: RepRecord? { reps.max { $0.speedScore < $1.speedScore } }
    var slowest: RepRecord? { reps.min { $0.speedScore < $1.speedScore } }

    /// Size of the "early" and "late" groups: the first and last third of the set.
    private var groupSize: Int { max(1, reps.count / 3) }

    var earlyAverage: Double? {
        guard reps.count >= 2 else { return nil }
        let group = reps.prefix(groupSize)
        return group.map(\.speedScore).reduce(0, +) / Double(group.count)
    }

    var lateAverage: Double? {
        guard reps.count >= 2 else { return nil }
        let group = reps.suffix(groupSize)
        return group.map(\.speedScore).reduce(0, +) / Double(group.count)
    }

    /// Relative change from early to late reps, in percent (negative = slower).
    var earlyToLateChange: Double? {
        guard let early = earlyAverage, let late = lateAverage, early > 0 else { return nil }
        return (late - early) / early * 100
    }

    var earlyRepNumbers: ClosedRange<Int>? {
        guard reps.count >= 2 else { return nil }
        return 1...groupSize
    }

    var lateRepNumbers: ClosedRange<Int>? {
        guard reps.count >= 2 else { return nil }
        return (reps.count - groupSize + 1)...reps.count
    }

    func count(of speedClass: SpeedClass) -> Int {
        reps.filter { $0.speedClass == speedClass }.count
    }

    func inZoneCount(_ zone: SpeedZone) -> Int {
        reps.filter { zone.contains($0.speedScore) }.count
    }

    // MARK: Speed drop (velocity loss)

    var bestScore: Double? { reps.map(\.speedScore).max() }

    /// How far the latest rep is below the fastest rep, in percent.
    var velocityLoss: Double? {
        guard reps.count >= 2, let last = reps.last else { return nil }
        return loss(at: last)
    }

    /// Drop of `rep` below the fastest rep up to and including it, in percent.
    func loss(at rep: RepRecord) -> Double {
        let best = reps.prefix { $0.number <= rep.number }.map(\.speedScore).max() ?? rep.speedScore
        guard best > 0 else { return 0 }
        return max(0, (best - rep.speedScore) / best * 100)
    }

    /// The first rep whose speed drop reached `limit` percent.
    func firstRepPastLimit(_ limit: Double) -> RepRecord? {
        reps.first { loss(at: $0) >= limit }
    }

    // MARK: Estimated velocity & power (experimental)

    private func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var averageMeanVelocity: Double? { mean(reps.compactMap(\.meanVelocity)) }
    var bestMeanVelocity: Double? { reps.compactMap(\.meanVelocity).max() }
    var bestPeakVelocity: Double? { reps.compactMap(\.peakVelocity).max() }
    var averagePower: Double? { mean(reps.compactMap(\.power)) }
    var bestPower: Double? { reps.compactMap(\.power).max() }
    var hasVelocityEstimates: Bool { reps.contains { $0.meanVelocity != nil } }

    // MARK: Range of motion (experimental)

    var averageRangeOfMotion: Double? { mean(reps.compactMap(\.rangeOfMotionCm)) }

    /// Typical rep depth: the median range of motion.
    var medianRangeOfMotion: Double? {
        let values = reps.compactMap(\.rangeOfMotionCm).sorted()
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
    }

    /// Standard deviation of range of motion, in cm. Lower = more consistent.
    var rangeOfMotionSpread: Double? {
        let values = reps.compactMap(\.rangeOfMotionCm)
        guard values.count >= 2, let average = mean(values) else { return nil }
        let variance = values.map { ($0 - average) * ($0 - average) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }

    /// Reps that travelled noticeably less than usual (possible short or high reps).
    func shortReps(threshold: Double = 0.9) -> [RepRecord] {
        guard reps.count >= 3, let median = medianRangeOfMotion else { return [] }
        return reps.filter { ($0.rangeOfMotionCm ?? median) < median * threshold }
    }
}
