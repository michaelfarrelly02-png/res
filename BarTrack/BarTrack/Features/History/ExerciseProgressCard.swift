import SwiftUI
import Charts

/// Progress over time for one exercise: speed score, top weight or reps.
struct ExerciseProgressCard: View {
    let exercise: Exercise
    /// Sessions for this exercise, any order.
    let sessions: [WorkoutSession]
    let unit: WeightUnit

    @State private var metric: Metric = .speed

    enum Metric: String, CaseIterable, Identifiable {
        case speed = "Speed"
        case weight = "Weight"
        case reps = "Reps"
        var id: String { rawValue }
    }

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var points: [Point] {
        sessions
            .sorted { $0.date < $1.date }
            .compactMap { session -> Point? in
                switch metric {
                case .speed:
                    return session.averageScore.map { Point(date: session.date, value: $0) }
                case .weight:
                    return Point(date: session.date, value: unit.fromKg(session.topWeightKg))
                case .reps:
                    return Point(date: session.date, value: Double(session.totalReps))
                }
            }
    }

    private var valueLabel: String {
        switch metric {
        case .speed: "Avg speed score"
        case .weight: "Top weight (\(unit.symbol))"
        case .reps: "Total reps"
        }
    }

    private func formatted(_ value: Double) -> String {
        switch metric {
        case .speed: Format.score(value)
        case .weight: WeightUnit.formatNumber(value)
        case .reps: "\(Int(value))"
        }
    }

    var body: some View {
        let data = points
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel("\(exercise.displayName) progress")
                        Text("\(sessions.count) workouts")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: exercise.symbol)
                        .foregroundStyle(Theme.accent)
                }

                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if data.count >= 1 {
                    summary(data)
                    chart(data)
                        .frame(height: 180)
                } else {
                    Text("No data for this metric yet.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }

                if metric == .speed {
                    Text("Speed scores are relative and experimental — compare trends, not exact values.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut, value: metric)
    }

    private func summary(_ data: [Point]) -> some View {
        let latest = data.last?.value ?? 0
        let best = data.map(\.value).max() ?? 0
        let first = data.first?.value ?? 0
        let change = first > 0 ? (latest - first) / first * 100 : 0
        return HStack(spacing: 0) {
            summaryItem(label: "Latest", value: formatted(latest), color: Theme.textPrimary)
            summaryItem(label: "Best", value: formatted(best), color: Theme.accent)
            summaryItem(
                label: "Change",
                value: data.count > 1 ? Format.signedPercent(change) : "–",
                color: change >= 0 ? Theme.fast : Theme.slow
            )
        }
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.metric(22, weight: .heavy))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chart(_ data: [Point]) -> some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value(valueLabel, point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(
                colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            ))

            LineMark(
                x: .value("Date", point.date),
                y: .value(valueLabel, point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Theme.accent)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

            PointMark(
                x: .value("Date", point.date),
                y: .value(valueLabel, point.value)
            )
            .foregroundStyle(metric == .speed ? SpeedClassifier.default.classify(point.value).color : Theme.accent)
            .symbolSize(50)
        }
        .chartYScale(domain: yDomain(data))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
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
    }

    private func yDomain(_ data: [Point]) -> ClosedRange<Double> {
        if metric == .speed { return 0...100 }
        let values = data.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.25, high * 0.05, 1)
        return max(0, low - padding)...(high + padding)
    }
}
