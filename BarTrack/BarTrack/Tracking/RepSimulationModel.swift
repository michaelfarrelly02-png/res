import Foundation

/// Generates believable relative speed scores for simulated reps:
/// heavier loads start slower, and reps slow down with fatigue.
struct RepSimulationModel {
    let exercise: Exercise
    let weightKg: Double
    let expectedReps: Int
    let startScore: Double

    init<G: RandomNumberGenerator>(
        exercise: Exercise,
        weightKg: Double,
        expectedReps: Int,
        using generator: inout G
    ) {
        self.exercise = exercise
        self.weightKg = weightKg
        self.expectedReps = max(1, expectedReps)
        let intensity = min(1.25, weightKg / exercise.referenceWeightKg)
        let jitter = Double.random(in: -3...3, using: &generator)
        self.startScore = (95 - intensity * 24 + jitter).clamped(to: 50...96)
    }

    /// Score for rep `number` (1-based).
    func score<G: RandomNumberGenerator>(forRep number: Int, using generator: inout G) -> Double {
        let fatigue = Double(number - 1) / Double(expectedReps)
        let drop = fatigue * 30 + pow(fatigue, 2) * 10
        let noise = Double.random(in: -5...5, using: &generator)
        return (startScore - drop + noise).clamped(to: 8...99)
    }

    /// A score inside the band for a chosen speed class.
    static func score<G: RandomNumberGenerator>(in speedClass: SpeedClass, using generator: inout G) -> Double {
        let classifier = SpeedClassifier.default
        switch speedClass {
        case .fast:
            return Double.random(in: (classifier.fastLowerBound + 2)...96, using: &generator)
        case .medium:
            return Double.random(in: (classifier.slowUpperBound + 2)...(classifier.fastLowerBound - 2), using: &generator)
        case .slow:
            return Double.random(in: 18...(classifier.slowUpperBound - 2), using: &generator)
        }
    }

    /// Estimated mean velocity (m/s) that matches a speed score.
    static func meanVelocity(for score: Double, exercise: Exercise) -> Double {
        let range = exercise.simulatedVelocityRange
        return range.lowerBound + (range.upperBound - range.lowerBound) * score.clamped(to: 0...100) / 100
    }

    /// Peak velocity is typically 30–60% above the mean.
    static func peakVelocity<G: RandomNumberGenerator>(forMean mean: Double, using generator: inout G) -> Double {
        mean * Double.random(in: 1.3...1.6, using: &generator)
    }

    /// Bar travel in cm; occasionally a shorter (high) rep.
    static func rangeOfMotion<G: RandomNumberGenerator>(for exercise: Exercise, using generator: inout G) -> Double {
        let base = exercise.typicalRangeOfMotionCm
        if Double.random(in: 0...1, using: &generator) < 0.12 {
            return base * Double.random(in: 0.78...0.88, using: &generator)
        }
        return base * Double.random(in: 0.96...1.04, using: &generator)
    }

    /// A full simulated rep with estimated metrics.
    static func makeRep<G: RandomNumberGenerator>(score: Double, exercise: Exercise, using generator: inout G) -> DetectedRep {
        let mean = meanVelocity(for: score, exercise: exercise)
        let rom = rangeOfMotion(for: exercise, using: &generator)
        return DetectedRep(
            speedScore: score,
            duration: (rom / 100) / mean,
            timestamp: nil,
            meanVelocity: mean,
            peakVelocity: peakVelocity(forMean: mean, using: &generator),
            rangeOfMotionCm: rom
        )
    }

    /// Slower reps take longer.
    static func duration(for score: Double, exercise: Exercise) -> TimeInterval {
        exercise.baseConcentricDuration * (1.75 - score / 100)
    }
}

enum SimulationPace: String, CaseIterable, Identifiable {
    case relaxed, normal, quick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed: "Relaxed"
        case .normal: "Normal"
        case .quick: "Quick"
        }
    }

    /// Seconds between simulated reps.
    var interval: ClosedRange<Double> {
        switch self {
        case .relaxed: 2.6...3.4
        case .normal: 1.7...2.4
        case .quick: 0.9...1.3
        }
    }
}
