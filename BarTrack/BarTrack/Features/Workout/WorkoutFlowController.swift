import SwiftUI
import SwiftData
import Observation

/// Owns one workout from the first set until it is saved or discarded:
/// Live set → Results → (another set → Results …) → Save.
@Observable
@MainActor
final class WorkoutFlowController: Identifiable {
    enum Phase {
        case live(LiveWorkoutViewModel)
        case results(SetResult)
    }

    let id = UUID()
    let exercise: Exercise
    let source: TrackingSource
    let startedAt = Date()

    /// Weight and target for the next set; editable on the Results screen.
    var weightKg: Double
    var targetReps: Int?
    var speedZone: SpeedZone?
    let velocityLossLimit: Double?
    let autoDetect: Bool
    let autoEndAfter: TimeInterval

    private(set) var completedSets: [SetResult] = []
    private(set) var phase: Phase

    init(configuration: SetConfiguration) {
        exercise = configuration.exercise
        source = configuration.source
        weightKg = configuration.weightKg
        targetReps = configuration.targetReps
        speedZone = configuration.speedZone
        velocityLossLimit = configuration.velocityLossLimit
        autoDetect = configuration.autoDetect
        autoEndAfter = configuration.autoEndAfter
        phase = .live(LiveWorkoutViewModel(configuration: configuration, setNumber: 1))
    }

    var phaseKey: String {
        switch phase {
        case .live(let viewModel): "live-\(viewModel.id)"
        case .results(let result): "results-\(result.id)"
        }
    }

    var totalReps: Int { completedSets.reduce(0) { $0 + $1.reps.count } }
    var canSave: Bool { totalReps > 0 }

    func finishCurrentSet() {
        guard case .live(let viewModel) = phase else { return }
        let result = viewModel.finish()
        completedSets.append(result)
        phase = .results(result)
    }

    func startNextSet() {
        let configuration = SetConfiguration(
            exercise: exercise,
            weightKg: weightKg,
            targetReps: targetReps,
            source: source,
            speedZone: speedZone,
            velocityLossLimit: velocityLossLimit,
            autoDetect: autoDetect,
            autoEndAfter: autoEndAfter
        )
        phase = .live(LiveWorkoutViewModel(configuration: configuration, setNumber: completedSets.count + 1))
    }

    func discard() {
        if case .live(let viewModel) = phase {
            viewModel.cancel()
        }
        completedSets.removeAll()
    }

    /// Saves every set with at least one rep.
    func save(in context: ModelContext) throws {
        var setsWithReps = completedSets.filter { !$0.reps.isEmpty }
        for index in setsWithReps.indices {
            setsWithReps[index].setNumber = index + 1
        }
        try WorkoutStore.save(sets: setsWithReps, date: startedAt, in: context)
    }
}
