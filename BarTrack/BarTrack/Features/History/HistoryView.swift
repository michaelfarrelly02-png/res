import SwiftUI
import SwiftData
import Charts

/// Screen 5 — saved workouts, filters and progress charts.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue

    @State private var filter: Exercise?

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    private var filteredSessions: [WorkoutSession] {
        guard let filter else { return sessions }
        return sessions.filter { $0.exercise == filter }
    }

    private struct MonthGroup: Identifiable {
        let id: String
        let title: String
        var sessions: [WorkoutSession]
    }

    private var monthGroups: [MonthGroup] {
        var groups: [MonthGroup] = []
        for session in filteredSessions {
            let components = Calendar.current.dateComponents([.year, .month], from: session.date)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            if let index = groups.firstIndex(where: { $0.id == key }) {
                groups[index].sessions.append(session)
            } else {
                let title = session.date.formatted(.dateTime.month(.wide).year())
                groups.append(MonthGroup(id: key, title: title, sessions: [session]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    filterBar

                    if sessions.isEmpty {
                        emptyState
                    } else if let filter {
                        ExerciseProgressCard(exercise: filter, sessions: filteredSessions, unit: unit)
                    } else {
                        HistoryOverviewCard(sessions: sessions)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                ForEach(monthGroups) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            ZStack {
                                NavigationLink(value: session) { EmptyView() }
                                    .opacity(0)
                                HistoryRow(session: session, unit: unit)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        SectionLabel(group.title)
                            .padding(.leading, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(session: session)
            }
            .animation(.easeInOut, value: filter)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filter == nil) { filter = nil }
                ForEach(Exercise.allCases) { exercise in
                    FilterChip(title: exercise.shortName, isSelected: filter == exercise) {
                        filter = exercise
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: "No history yet",
                message: "Saved workouts appear here. Complete a set and tap Save Workout, or load sample data in Settings."
            )
            Button {
                router.selectedTab = .workout
            } label: {
                Label("Start a Workout", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, 16)
    }

    private func delete(_ session: WorkoutSession) {
        withAnimation {
            modelContext.delete(session)
            try? modelContext.save()
        }
    }
}

// MARK: - Components

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Theme.accent : Theme.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct HistoryRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        Card(padding: 14) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(session.date.formatted(.dateTime.day()))
                        .font(.metric(22, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: session.exercise.symbol)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                        Text(session.exercise.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("\(unit.format(kg: session.topWeightKg)) · \(session.sets.count) sets · \(session.totalReps) reps")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.optionalScore(session.averageScore))
                        .font(.metric(22, weight: .heavy))
                        .foregroundStyle(session.averageScore.map { SpeedClassifier.default.classify($0).color } ?? Theme.textTertiary)
                    Text("AVG SPEED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

/// Totals and weekly volume across all exercises.
private struct HistoryOverviewCard: View {
    let sessions: [WorkoutSession]

    private struct WeekVolume: Identifiable {
        let weekStart: Date
        let exercise: Exercise
        let reps: Int
        var id: String { "\(weekStart.timeIntervalSince1970)-\(exercise.rawValue)" }
    }

    private var weeks: [WeekVolume] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .weekOfYear, value: -8, to: .now) ?? .distantPast
        var totals: [String: WeekVolume] = [:]
        for session in sessions where session.date >= cutoff {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start else { continue }
            let key = "\(week.timeIntervalSince1970)-\(session.exerciseRaw)"
            let existing = totals[key]?.reps ?? 0
            totals[key] = WeekVolume(weekStart: week, exercise: session.exercise, reps: existing + session.totalReps)
        }
        return totals.values.sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    total(value: "\(sessions.count)", label: "Workouts")
                    total(value: "\(sessions.reduce(0) { $0 + $1.sets.count })", label: "Sets")
                    total(value: "\(sessions.reduce(0) { $0 + $1.totalReps })", label: "Reps")
                }
                SectionLabel("Weekly reps by exercise")
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Reps", week.reps)
                    )
                    .foregroundStyle(by: .value("Exercise", week.exercise.shortName))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(
                    domain: Exercise.allCases.map(\.shortName),
                    range: ExerciseColors.all
                )
                .chartLegend(position: .bottom, spacing: 10)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.border)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 180)
                Text("Select an exercise above to see its progress over time.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func total(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.metric(26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Fixed colours to tell exercises apart in charts (unrelated to speed classes).
enum ExerciseColors {
    static let all: [Color] = [
        Color(red: 0.00, green: 0.85, blue: 0.78),
        Color(red: 0.45, green: 0.55, blue: 1.00),
        Color(red: 0.75, green: 0.45, blue: 1.00),
        Color(red: 1.00, green: 0.75, blue: 0.30),
        Color(red: 1.00, green: 0.45, blue: 0.65),
    ]
}

#Preview {
    HistoryView()
        .environment(AppRouter())
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}
