import SwiftUI
import Observation

/// Drives one set on the Live Workout screen. It listens to a
/// `TrackingService`, numbers and classifies reps, and runs the set timer.
@Observable
@MainActor
final class LiveWorkoutViewModel: Identifiable {
    let id = UUID()
    let configuration: SetConfiguration
    let setNumber: Int

    private(set) var reps: [RepRecord] = []
    private(set) var status: TrackingStatus = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var startedAt = Date()
    private(set) var lastError: String?

    private let service: any TrackingService
    private let classifier: SpeedClassifier

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var accumulated: TimeInterval = 0

    init(
        configuration: SetConfiguration,
        setNumber: Int,
        service: (any TrackingService)? = nil,
        classifier: SpeedClassifier = .default
    ) {
        self.configuration = configuration
        self.setNumber = setNumber
        self.service = service ?? TrackingServiceFactory.make(for: configuration.source)
        self.classifier = classifier
    }

    // MARK: Derived state

    var simulator: SimulatedTrackingService? { service as? SimulatedTrackingService }
    var latestRep: RepRecord? { reps.last }
    var isPaused: Bool { status == .paused }
    var isRecording: Bool { status == .recording }
    var analytics: SetAnalytics { SetAnalytics(reps: reps) }

    var inZoneCount: Int {
        guard let zone = configuration.speedZone else { return 0 }
        return analytics.inZoneCount(zone)
    }

    var targetProgress: Double {
        guard let target = configuration.targetReps, target > 0 else {
            return reps.isEmpty ? 0 : 1
        }
        return min(1, Double(reps.count) / Double(target))
    }

    // MARK: Actions

    func start() {
        guard status == .idle else { return }
        service.onEvent = { [weak self] event in
            self?.handle(event)
        }
        do {
            try service.start(context: TrackingContext(
                exercise: configuration.exercise,
                weightKg: configuration.weightKg,
                targetReps: configuration.targetReps
            ))
            startedAt = Date()
            segmentStart = Date()
            startTimer()
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func togglePause() {
        if isPaused {
            service.resume()
            segmentStart = Date()
        } else if isRecording {
            accumulated = currentElapsed()
            segmentStart = nil
            service.pause()
        }
        elapsed = currentElapsed()
    }

    func simulateRep(_ speedClass: SpeedClass?) {
        simulator?.simulateRep(forcing: speedClass)
    }

    func toggleAutoSimulation() {
        guard let simulator else { return }
        if simulator.isAutoSimulating {
            simulator.stopAutoSimulation()
        } else {
            simulator.startAutoSimulation()
        }
    }

    /// Stops tracking and returns the finished set.
    func finish() -> SetResult {
        elapsed = currentElapsed()
        tearDown()
        return SetResult(
            setNumber: setNumber,
            exercise: configuration.exercise,
            weightKg: configuration.weightKg,
            targetReps: configuration.targetReps,
            reps: reps,
            duration: elapsed,
            startedAt: startedAt,
            source: configuration.source,
            speedZone: configuration.speedZone
        )
    }

    /// Stops tracking without producing a result.
    func cancel() {
        tearDown()
    }

    // MARK: Private

    private func handle(_ event: TrackingEvent) {
        switch event {
        case .status(let newStatus):
            status = newStatus
        case .failure(let message):
            lastError = message
        case .rep(let detected):
            let rep = RepRecord(
                number: reps.count + 1,
                speedScore: detected.speedScore,
                speedClass: classifier.classify(detected.speedScore),
                duration: detected.duration,
                timestamp: detected.timestamp ?? currentElapsed()
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                reps.append(rep)
            }
        }
    }

    private func tearDown() {
        timerTask?.cancel()
        timerTask = nil
        service.stop()
        service.onEvent = nil
    }

    private func currentElapsed() -> TimeInterval {
        accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self else { return }
                self.elapsed = self.currentElapsed()
            }
        }
    }
}
