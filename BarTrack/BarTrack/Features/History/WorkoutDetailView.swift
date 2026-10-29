import SwiftUI
import SwiftData
import Charts

/// Detailed view of one saved workout.
struct WorkoutDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue
    @State private var confirmDelete = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metrics
                if session.orderedSets.count > 1 {
                    setTrendCard
                }
                ForEach(session.orderedSets) { entry in
                    SetDetailCard(entry: entry, unit: unit)
                }
                ExperimentalNotice()
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle(session.exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete workout")
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) {
                let session = session
                let context = modelContext
                dismiss()
                // Delete after the pop animation so this screen never shows a deleted object.
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    context.delete(session)
                    try? context.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: session.exercise.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent))
            VStack(alignment: .leading, spacing: 4) {
                Text(session.exercise.displayName)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(session.date.formatted(date: .complete, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(session.source.displayName.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 8)
    }

    private var metrics: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            MetricTile(title: "Sets", value: "\(session.sets.count)", icon: "square.stack.3d.up.fill")
            MetricTile(title: "Reps", value: "\(session.totalReps)", icon: "number")
            MetricTile(title: "Top weight", value: unit.number(fromKg: session.topWeightKg), unit: unit.symbol, icon: "scalemass.fill")
            MetricTile(
                title: "Avg speed",
                value: Format.optionalScore(session.averageScore),
                unit: "/100",
                valueColor: session.averageScore.map { SpeedClassifier.default.classify($0).color } ?? Theme.textPrimary,
                icon: "speedometer"
            )
        }
    }

    private struct SetPoint: Identifiable {
        let setNumber: Int
        let score: Double
        var id: Int { setNumber }
    }

    private var setTrendCard: some View {
        let points = session.orderedSets.compactMap { entry -> SetPoint? in
            guard let score = entry.analytics.averageScore else { return nil }
            return SetPoint(setNumber: entry.setNumber, score: score)
        }
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Average speed by set")
                Chart(points) { point in
                    LineMark(
                        x: .value("Set", "Set \(point.setNumber)"),
                        y: .value("Avg speed", point.score)
                    )
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Set", "Set \(point.setNumber)"),
                        y: .value("Avg speed", point.score)
                    )
                    .foregroundStyle(SpeedClassifier.default.classify(point.score).color)
                    .symbolSize(80)
                    .annotation(position: .top) {
                        Text(Format.score(point.score))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Theme.border)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 150)
            }
        }
    }
}

/// One saved set with its interactive rep chart.
private struct SetDetailCard: View {
    let entry: SetEntry
    let unit: WeightUnit
    @State private var selectedRep: Int?
    @AppStorage(AppStorageKey.showEstimates) private var showEstimates = true

    private var repsText: String {
        guard let target = entry.targetReps else { return "\(entry.repCount)" }
        return "\(entry.repCount)/\(target)"
    }

    var body: some View {
        let reps = entry.reps
        let analytics = SetAnalytics(reps: reps)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Set \(entry.setNumber)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(unit.format(kg: entry.weightKg))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(Format.clock(entry.duration))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 16) {
                    stat("Reps", repsText)
                    stat("Avg", Format.optionalScore(analytics.averageScore))
                    stat("Best", analytics.fastest.map { Format.score($0.speedScore) } ?? "–")
                    if let zone = entry.speedZone {
                        stat("In zone", "\(analytics.inZoneCount(zone))/\(reps.count)")
                    } else {
                        stat("Early→Late", analytics.earlyToLateChange.map(Format.signedPercent) ?? "–")
                    }
                }

                if showEstimates && analytics.hasVelocityEstimates {
                    HStack(spacing: 16) {
                        stat("Mean m/s", analytics.averageMeanVelocity.map(Format.velocity) ?? "–")
                        stat("Peak m/s", analytics.bestPeakVelocity.map(Format.velocity) ?? "–")
                        stat("Power W", analytics.averagePower.map(Format.watts) ?? "–")
                        stat("Depth cm", analytics.averageRangeOfMotion.map(Format.centimetres) ?? "–")
                    }
                    .overlay(alignment: .topTrailing) { EstimateTag() }
                }

                if let limit = entry.velocityLossLimit {
                    let drop = analytics.velocityLoss ?? 0
                    Label("Speed drop \(Int(drop.rounded()))% (limit \(Int(limit))%)", systemImage: drop >= limit ? "hand.raised.fill" : "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(drop >= limit ? Theme.danger : Theme.fast)
                }

                if let zone = entry.speedZone {
                    Label("Target zone \(zone.text)", systemImage: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }

                RepSpeedChart(reps: reps, height: 140, speedZone: entry.speedZone, isInteractive: true, selectedRep: $selectedRep)

                if let number = selectedRep, let rep = reps.first(where: { $0.number == number }) {
                    RepDetailRow(rep: rep, firstScore: reps.first?.speedScore) {
                        withAnimation { selectedRep = nil }
                    }
                }

                FlowChips(reps: reps)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.metric(17, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

/// Small rep-number chips coloured by speed class.
private struct FlowChips: View {
    let reps: [RepRecord]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(reps) { rep in
                Text("\(rep.number)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(rep.speedClass.color)
                    .frame(width: 36, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(rep.speedClass.color.opacity(0.14)))
                    .accessibilityLabel("Rep \(rep.number), \(rep.speedClass.label)")
            }
        }
    }
}

#Preview {
    let container = SampleData.previewContainer
    let session = try? container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
    return NavigationStack {
        if let session {
            WorkoutDetailView(session: session)
        }
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
