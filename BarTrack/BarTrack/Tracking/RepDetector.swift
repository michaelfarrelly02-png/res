import Foundation

/// One motion sample, in the same shape as Core Motion's `CMDeviceMotion`
/// and the CSV files recorded by the Python prototype.
struct MotionSample {
    /// Seconds since the first sample.
    var timestamp: TimeInterval
    /// User acceleration (gravity removed), in g.
    var userAcceleration: SIMD3<Double>
    /// Rotation rate, in rad/s.
    var rotationRate: SIMD3<Double>
    /// Attitude pitch in radians, if available.
    var pitch: Double?
}

/// Placeholder rep detector for motion samples.
///
/// This is a deliberately simple threshold detector so the AirPods and CSV
/// pipelines are complete end to end. It is where the Python prototype
/// (v0.6.1) logic — rep counting, pattern matching and Slow/Medium/Fast
/// classification — should be ported in Phase 2. Its output is a relative
/// score, not a velocity.
struct RepDetector {
    struct Configuration {
        /// Smoothed acceleration (g) that starts a movement.
        var startThreshold = 0.12
        /// Smoothed acceleration (g) under which the bar counts as still.
        var endThreshold = 0.05
        /// How long the bar must stay still to end a movement.
        var stillTime: TimeInterval = 0.15
        var minRepDuration: TimeInterval = 0.25
        var maxRepDuration: TimeInterval = 4.0
        /// Minimum gap between reps.
        var minGap: TimeInterval = 0.35
        /// Exponential smoothing factor (0–1).
        var smoothing = 0.25
        /// Integrated acceleration (roughly m/s) that maps to a score of 100.
        var referencePeak = 2.5
    }

    var configuration = Configuration()

    private var smoothed = 0.0
    private var inMovement = false
    private var movementStart: TimeInterval = 0
    private var lastTimestamp: TimeInterval?
    private var intensity = 0.0
    private var peakIntensity = 0.0
    private var stillSince: TimeInterval?
    private var lastRepEnd: TimeInterval = -.greatestFiniteMagnitude

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Feed samples in time order. Returns a rep when one finishes.
    mutating func process(_ sample: MotionSample) -> DetectedRep? {
        let a = sample.userAcceleration
        let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
        smoothed += configuration.smoothing * (magnitude - smoothed)

        let dt = lastTimestamp.map { max(0, sample.timestamp - $0) } ?? 0
        lastTimestamp = sample.timestamp

        if !inMovement {
            if smoothed > configuration.startThreshold,
               sample.timestamp - lastRepEnd > configuration.minGap {
                inMovement = true
                movementStart = sample.timestamp
                intensity = 0
                peakIntensity = 0
                stillSince = nil
            }
            return nil
        }

        // Integrated acceleration magnitude: a rough "how fast did it move" proxy.
        intensity += smoothed * 9.81 * dt
        peakIntensity = max(peakIntensity, intensity)

        let duration = sample.timestamp - movementStart
        if duration > configuration.maxRepDuration {
            reset(at: sample.timestamp)
            return nil
        }

        if smoothed < configuration.endThreshold {
            if stillSince == nil { stillSince = sample.timestamp }
            if let stillSince, sample.timestamp - stillSince >= configuration.stillTime {
                let repDuration = stillSince - movementStart
                let peak = peakIntensity
                reset(at: sample.timestamp)
                guard repDuration >= configuration.minRepDuration else { return nil }
                let score = (peak / configuration.referencePeak * 100).clamped(to: 0...100)
                return DetectedRep(speedScore: score, duration: repDuration, timestamp: sample.timestamp)
            }
        } else {
            stillSince = nil
        }
        return nil
    }

    private mutating func reset(at time: TimeInterval) {
        inMovement = false
        lastRepEnd = time
        stillSince = nil
        intensity = 0
        peakIntensity = 0
    }
}
