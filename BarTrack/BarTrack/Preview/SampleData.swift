import Foundation
import SwiftData

/// Realistic sample workouts for SwiftUI previews and the
/// "Load sample workouts" button in Settings.
@MainActor
enum SampleData {
    /// In-memory store pre-filled with sample workouts, for previews.
    static let previewContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: WorkoutSession.self, SetEntry.self,
                configurations: configuration
            )
            insertSampleWorkouts(into: container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }()

    /// A single finished set, for result-screen previews.
    static var sampleSetResult: SetResult {
        var generator = SeededGenerator(seed: 42)
        return makeSet(
            exercise: .backSquat,
            weightKg: 120,
            setNumber: 1,
            reps: 6,
            startedAt: .now,
            generator: &generator
        )
    }

    /// Adds about five weeks of varied workouts ending today.
    static func insertSampleWorkouts(into context: ModelContext, referenceDate: Date = .now) {
        var generator = SeededGenerator(seed: UInt64(referenceDate.timeIntervalSince1970))
        let calendar = Calendar.current

        // (days ago, exercise, sets, reps per set)
        let plan: [(Int, Exercise, Int, Int)] = [
            (34, .backSquat, 4, 5), (33, .benchPress, 4, 6), (31, .deadlift, 3, 3),
            (29, .overheadPress, 3, 8), (27, .backSquat, 4, 5), (26, .barbellRow, 4, 8),
            (24, .benchPress, 4, 6), (22, .deadlift, 3, 3), (20, .backSquat, 5, 5),
            (19, .overheadPress, 3, 8), (17, .benchPress, 4, 5), (15, .barbellRow, 4, 8),
            (13, .backSquat, 4, 4), (12, .deadlift, 3, 3), (10, .benchPress, 4, 5),
            (8, .overheadPress, 4, 6), (6, .backSquat, 4, 3), (5, .barbellRow, 3, 10),
            (3, .benchPress, 3, 5), (1, .deadlift, 3, 2),
        ]

        for (daysAgo, exercise, setCount, repsPerSet) in plan {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate),
                  let date = calendar.date(bySettingHour: 17 + daysAgo % 3, minute: 15, second: 0, of: day)
            else { continue }

            // Weight climbs gradually over the block.
            let weeksIn = Double(35 - daysAgo) / 7
            let rawWeight = exercise.defaultWeightKg * (0.9 + weeksIn * 0.03)
            let weightKg = (rawWeight / 2.5).rounded() * 2.5

            var sets: [SetResult] = []
            var setStart = date
            for setNumber in 1...setCount {
                let result = makeSet(
                    exercise: exercise,
                    weightKg: weightKg,
                    setNumber: setNumber,
                    reps: repsPerSet,
                    startedAt: setStart,
                    generator: &generator
                )
                sets.append(result)
                setStart = setStart.addingTimeInterval(result.duration + 150)
            }
            try? WorkoutStore.save(sets: sets, date: date, in: context)
        }
    }

    static func makeSet<G: RandomNumberGenerator>(
        exercise: Exercise,
        weightKg: Double,
        setNumber: Int,
        reps repCount: Int,
        startedAt: Date,
        generator: inout G
    ) -> SetResult {
        // Later sets start a little slower.
        let model = RepSimulationModel(
            exercise: exercise,
            weightKg: weightKg * (1 + Double(setNumber - 1) * 0.03),
            expectedReps: repCount + 2,
            using: &generator
        )
        var reps: [RepRecord] = []
        var clock: TimeInterval = 2
        for number in 1...max(1, repCount) {
            let score = model.score(forRep: number, using: &generator)
            let duration = RepSimulationModel.duration(for: score, exercise: exercise)
            clock += duration * 2.2 + Double.random(in: 0.6...1.4, using: &generator)
            reps.append(RepRecord(
                number: number,
                speedScore: score,
                speedClass: SpeedClassifier.default.classify(score),
                duration: duration,
                timestamp: clock
            ))
        }
        return SetResult(
            setNumber: setNumber,
            exercise: exercise,
            weightKg: weightKg,
            targetReps: repCount,
            reps: reps,
            duration: clock + 2,
            startedAt: startedAt,
            source: .simulated
        )
    }
}
