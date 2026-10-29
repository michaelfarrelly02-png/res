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
}

/// Settings chosen on the Start Workout screen.
struct SetConfiguration: Hashable {
    var exercise: Exercise
    var weightKg: Double
    var targetReps: Int?
    var source: TrackingSource
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
}
