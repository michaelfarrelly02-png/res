import Foundation

/// Replays motion samples from a CSV file (for example a recording made with
/// the Python prototype) through the same rep detector the AirPods use.
///
/// Not yet exposed in the UI. Expected columns (names are matched loosely):
/// `timestamp, accX, accY, accZ` and optionally `rotX, rotY, rotZ, pitch`.
@MainActor
final class CSVReplayTrackingService: TrackingService {
    let source: TrackingSource = .csvReplay
    var onEvent: (@MainActor (TrackingEvent) -> Void)?

    /// 1 = real time, 4 = four times faster.
    var playbackSpeed: Double = 1

    private let samples: [MotionSample]
    private var detector = RepDetector()
    private var replayTask: Task<Void, Never>?
    private var isPaused = false

    init(samples: [MotionSample]) {
        self.samples = samples
    }

    convenience init(csvText: String) {
        self.init(samples: Self.parse(csvText))
    }

    func start(context: TrackingContext) throws {
        guard !samples.isEmpty else { throw TrackingError.noData }
        detector = RepDetector()
        isPaused = false
        onEvent?(.status(.recording))

        replayTask = Task { [weak self] in
            guard let self else { return }
            var previous: TimeInterval?
            for sample in self.samples {
                if Task.isCancelled { return }
                if let previous {
                    let wait = max(0, sample.timestamp - previous) / max(self.playbackSpeed, 0.1)
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                while self.isPaused && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                previous = sample.timestamp
                if let rep = self.detector.process(sample) {
                    self.onEvent?(.rep(rep))
                }
            }
            self.onEvent?(.status(.stopped))
        }
    }

    func pause() {
        isPaused = true
        onEvent?(.status(.paused))
    }

    func resume() {
        isPaused = false
        onEvent?(.status(.recording))
    }

    func stop() {
        replayTask?.cancel()
        replayTask = nil
        onEvent?(.status(.stopped))
    }

    // MARK: - Parsing

    static func parse(_ text: String) -> [MotionSample] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return [] }

        let header = headerLine
            .split(separator: ",")
            .map { $0.lowercased().filter { $0.isLetter || $0.isNumber } }

        func column(_ names: [String]) -> Int? {
            header.firstIndex { names.contains($0) }
        }

        guard
            let t = column(["timestamp", "time", "t", "seconds"]),
            let ax = column(["accx", "ax", "useraccelerationx", "useraccx", "accelerationx"]),
            let ay = column(["accy", "ay", "useraccelerationy", "useraccy", "accelerationy"]),
            let az = column(["accz", "az", "useraccelerationz", "useraccz", "accelerationz"])
        else { return [] }

        let rx = column(["rotx", "gx", "rotationratex", "gyrox"])
        let ry = column(["roty", "gy", "rotationratey", "gyroy"])
        let rz = column(["rotz", "gz", "rotationratez", "gyroz"])
        let pitch = column(["pitch"])

        var result: [MotionSample] = []
        var firstTime: Double?
        for line in lines.dropFirst() {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { Double($0.trimmingCharacters(in: .whitespaces)) }
            func value(_ index: Int?) -> Double? {
                guard let index, index < fields.count else { return nil }
                return fields[index]
            }
            guard let time = value(t), let x = value(ax), let y = value(ay), let z = value(az) else { continue }
            let start = firstTime ?? time
            firstTime = start
            result.append(MotionSample(
                timestamp: time - start,
                userAcceleration: SIMD3(x, y, z),
                rotationRate: SIMD3(value(rx) ?? 0, value(ry) ?? 0, value(rz) ?? 0),
                pitch: value(pitch)
            ))
        }
        return result
    }
}
