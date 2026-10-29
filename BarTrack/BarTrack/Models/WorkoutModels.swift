import Foundation
import SwiftData

/// A saved workout: one exercise and one or more sets.
@Model
final class WorkoutSession {
    var uuid: UUID
    var date: Date
    var exerciseRaw: String
    var sourceRaw: String
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session)
    var sets: [SetEntry] = []

    init(date: Date, exercise: Exercise, source: TrackingSource) {
        self.uuid = UUID()
        self.date = date
        self.exerciseRaw = exercise.rawValue
        self.sourceRaw = source.rawValue
    }

    var exercise: Exercise { Exercise(rawValue: exerciseRaw) ?? .backSquat }
    var source: TrackingSource { TrackingSource(rawValue: sourceRaw) ?? .simulated }

    var orderedSets: [SetEntry] { sets.sorted { $0.setNumber < $1.setNumber } }
    var allReps: [RepRecord] { orderedSets.flatMap(\.reps) }
    var totalReps: Int { sets.reduce(0) { $0 + $1.repCount } }
    var topWeightKg: Double { sets.map(\.weightKg).max() ?? 0 }
    var totalDuration: TimeInterval { sets.reduce(0) { $0 + $1.duration } }

    var averageScore: Double? {
        let reps = allReps
        guard !reps.isEmpty else { return nil }
        return reps.map(\.speedScore).reduce(0, +) / Double(reps.count)
    }
}

/// One set inside a saved workout. Reps are stored as JSON for simplicity
/// and so the rep format can grow (e.g. validated m/s fields) without
/// needing extra SwiftData models.
@Model
final class SetEntry {
    var setNumber: Int
    var weightKg: Double
    var targetReps: Int?
    var duration: TimeInterval
    var startedAt: Date
    var repCount: Int
    var repsData: Data
    /// Target speed zone, if one was set (optional so older saves still load).
    var zoneLower: Double?
    var zoneUpper: Double?
    var session: WorkoutSession?

    init(result: SetResult) {
        self.setNumber = result.setNumber
        self.weightKg = result.weightKg
        self.targetReps = result.targetReps
        self.duration = result.duration
        self.startedAt = result.startedAt
        self.repCount = result.reps.count
        self.repsData = (try? JSONEncoder().encode(result.reps)) ?? Data()
        self.zoneLower = result.speedZone?.lower
        self.zoneUpper = result.speedZone?.upper
    }

    var speedZone: SpeedZone? {
        guard let zoneLower, let zoneUpper else { return nil }
        return SpeedZone(lower: zoneLower, upper: zoneUpper)
    }

    var reps: [RepRecord] {
        (try? JSONDecoder().decode([RepRecord].self, from: repsData)) ?? []
    }

    var analytics: SetAnalytics { SetAnalytics(reps: reps) }
}

enum WorkoutStore {
    /// Saves completed sets as one workout session.
    @discardableResult
    static func save(sets: [SetResult], date: Date = .now, in context: ModelContext) throws -> WorkoutSession? {
        guard let first = sets.first else { return nil }
        let session = WorkoutSession(date: date, exercise: first.exercise, source: first.source)
        context.insert(session)
        for result in sets {
            let entry = SetEntry(result: result)
            context.insert(entry)
            entry.session = session
        }
        try context.save()
        return session
    }
}
