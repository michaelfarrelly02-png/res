import Foundation
import Observation

/// Demo Mode tracking source. Reps are created manually (buttons) or
/// automatically on a timer, so the whole app can be used without hardware.
@Observable
@MainActor
final class SimulatedTrackingService: TrackingService {
    let source: TrackingSource = .simulated

    @ObservationIgnored
    var onEvent: (@MainActor (TrackingEvent) -> Void)?

    private(set) var isAutoSimulating = false
    var pace: SimulationPace = .normal

    /// Stop auto-simulation after this many reps when no target is set.
    var autoRepLimit = 12

    @ObservationIgnored private var model: RepSimulationModel?
    @ObservationIgnored private var context: TrackingContext?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private var autoTask: Task<Void, Never>?
    @ObservationIgnored private var repCount = 0
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var isPaused = false

    func start(context: TrackingContext) throws {
        self.context = context
        model = RepSimulationModel(
            exercise: context.exercise,
            weightKg: context.weightKg,
            expectedReps: context.targetReps ?? 8,
            using: &generator
        )
        repCount = 0
        isRunning = true
        isPaused = false
        onEvent?(.status(.recording))
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        onEvent?(.status(.paused))
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        onEvent?(.status(.recording))
    }

    func stop() {
        stopAutoSimulation()
        guard isRunning else { return }
        isRunning = false
        onEvent?(.status(.stopped))
    }

    /// Emits one rep. Pass a speed class to force it, or nil for the fatigue model.
    func simulateRep(forcing speedClass: SpeedClass? = nil) {
        guard isRunning, !isPaused, let model, let context else { return }
        repCount += 1
        let score: Double
        if let speedClass {
            score = RepSimulationModel.score(in: speedClass, using: &generator)
        } else {
            score = model.score(forRep: repCount, using: &generator)
        }
        onEvent?(.rep(RepSimulationModel.makeRep(score: score, exercise: context.exercise, using: &generator)))
    }

    func startAutoSimulation() {
        guard isRunning, autoTask == nil else { return }
        isAutoSimulating = true
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.pace.interval ?? SimulationPace.normal.interval
                let delay = Double.random(in: interval)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                if self.isPaused { continue }
                let limit = self.context?.targetReps ?? self.autoRepLimit
                if self.repCount >= limit {
                    self.stopAutoSimulation()
                    return
                }
                self.simulateRep()
                if self.repCount >= limit {
                    self.stopAutoSimulation()
                    return
                }
            }
        }
    }

    func stopAutoSimulation() {
        autoTask?.cancel()
        autoTask = nil
        isAutoSimulating = false
    }
}
