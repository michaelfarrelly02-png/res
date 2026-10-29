import SwiftUI

/// Screen 4 — summary of the set that was just completed.
struct SetResultsView: View {
    @Bindable var controller: WorkoutFlowController
    let result: SetResult
    var onSave: () -> Void
    var onNextSet: () -> Void
    var onDiscard: () -> Void

    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue
    @State private var selectedRep: Int?
    @State private var showDiscardConfirmation = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }
    private var analytics: SetAnalytics { result.analytics }

    private var selectedRepRecord: RepRecord? {
        guard let selectedRep else { return nil }
        return result.reps.first(where: { $0.number == selectedRep })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if result.reps.isEmpty {
                        EmptyStateView(
                            icon: "exclamationmark.circle",
                            title: "No reps recorded",
                            message: "This set has no reps, so it won't be saved. Start another set or discard the workout."
                        )
                    } else {
                        metricsGrid
                        chartCard
                        extremesRow
                        comparisonCard
                        repBreakdown
                    }
                    if controller.completedSets.count > 1 {
                        sessionSummary
                    }
                    nextSetCard
                    ExperimentalNotice()
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            actionBar
        }
        .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive, action: onDiscard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All sets from this workout will be lost.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("SET \(result.setNumber) COMPLETE")
                        .tracking(1.4)
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.accent)

                Text(result.exercise.displayName)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text(unit.format(kg: result.weightKg))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            CircleIconButton(systemName: "xmark", size: 38) {
                showDiscardConfirmation = true
            }
            .accessibilityLabel("Discard workout")
        }
        .padding(.top, 8)
    }

    // MARK: - Metrics

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            MetricTile(
                title: "Reps",
                value: "\(analytics.count)",
                unit: result.targetReps.map { "/ \($0)" },
                caption: targetCaption,
                icon: "number"
            )
            MetricTile(
                title: "Set time",
                value: Format.clock(result.duration),
                caption: "Including rest within the set",
                icon: "timer"
            )
            MetricTile(
                title: "Avg speed",
                value: Format.optionalScore(analytics.averageScore),
                unit: "/100",
                caption: analytics.averageClass.map { "Mostly \($0.label.lowercased())" },
                valueColor: analytics.averageClass?.color ?? Theme.textPrimary,
                icon: "speedometer"
            )
            MetricTile(
                title: "Early → Late",
                value: analytics.earlyToLateChange.map(Format.signedPercent) ?? "–",
                caption: "Change in speed score",
                valueColor: changeColor,
                icon: "chart.line.downtrend.xyaxis"
            )
        }
    }

    private var targetCaption: String? {
        guard let target = result.targetReps else { return "No target set" }
        if analytics.count >= target { return "Target reached" }
        return "\(target - analytics.count) short of target"
    }

    private var changeColor: Color {
        guard let change = analytics.earlyToLateChange else { return Theme.textPrimary }
        if change <= -20 { return Theme.slow }
        if change <= -8 { return Theme.medium }
        return Theme.fast
    }

    // MARK: - Chart

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel("Rep-by-rep speed")
                    Spacer()
                    SpeedLegend()
                }
                RepSpeedChart(
                    reps: result.reps,
                    height: 200,
                    isInteractive: true,
                    selectedRep: $selectedRep
                )
                if let rep = selectedRepRecord {
                    RepDetailRow(rep: rep, firstScore: result.reps.first?.speedScore) {
                        withAnimation { selectedRep = nil }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Label("Tap a bar to see that rep", systemImage: "hand.tap")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Extremes

    private var extremesRow: some View {
        HStack(spacing: 10) {
            if let fastest = analytics.fastest {
                extremeTile(title: "Fastest", rep: fastest, icon: "bolt.fill")
            }
            if let slowest = analytics.slowest {
                extremeTile(title: "Slowest", rep: slowest, icon: "tortoise.fill")
            }
        }
    }

    private func extremeTile(title: String, rep: RepRecord, icon: String) -> some View {
        Button {
            withAnimation { selectedRep = rep.number }
        } label: {
            Card(highlight: rep.speedClass.color) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(rep.speedClass.color)
                        SectionLabel(title)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Rep \(rep.number)")
                            .font(.metric(24, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                        SpeedBadge(speedClass: rep.speedClass)
                    }
                    Text("Score \(Format.score(rep.speedScore)) · \(Format.seconds(rep.duration))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Early vs late

    private var comparisonCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Early vs late reps")
                if let early = analytics.earlyAverage,
                   let late = analytics.lateAverage,
                   let earlyRange = analytics.earlyRepNumbers,
                   let lateRange = analytics.lateRepNumbers {
                    comparisonBar(label: "Early (\(rangeText(earlyRange)))", score: early)
                    comparisonBar(label: "Late (\(rangeText(lateRange)))", score: late)
                    Text(comparisonSummary(early: early, late: late))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Complete at least 2 reps to compare early and late reps.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func rangeText(_ range: ClosedRange<Int>) -> String {
        range.lowerBound == range.upperBound ? "rep \(range.lowerBound)" : "reps \(range.lowerBound)–\(range.upperBound)"
    }

    private func comparisonBar(label: String, score: Double) -> some View {
        let speedClass = SpeedClassifier.default.classify(score)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Format.score(score))
                    .font(.metric(18, weight: .heavy))
                    .foregroundStyle(speedClass.color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceRaised)
                    Capsule()
                        .fill(speedClass.color.gradient)
                        .frame(width: geometry.size.width * min(1, score / 100))
                }
            }
            .frame(height: 10)
        }
    }

    private func comparisonSummary(early: Double, late: Double) -> String {
        let change = (late - early) / max(early, 1) * 100
        if change <= -3 {
            return "Speed score dropped \(Format.signedPercent(change).dropFirst()) from early to late reps — a sign of fatigue building during the set."
        }
        if change >= 3 {
            return "Speed score rose \(Format.signedPercent(change).dropFirst()) from early to late reps."
        }
        return "Speed held steady from early to late reps."
    }

    // MARK: - Rep list

    private var repBreakdown: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel("Rep breakdown")
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(SpeedClass.allCases.reversed()) { speedClass in
                            let count = analytics.count(of: speedClass)
                            if count > 0 {
                                Text("\(count) \(speedClass.label)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(speedClass.color)
                            }
                        }
                    }
                }
                ForEach(result.reps) { rep in
                    Button {
                        withAnimation { selectedRep = (selectedRep == rep.number) ? nil : rep.number }
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(rep.number)")
                                .font(.metric(16, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Theme.surfaceRaised))
                            VStack(alignment: .leading, spacing: 2) {
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(rep.speedClass.color.opacity(0.85))
                                        .frame(width: geometry.size.width * min(1, rep.speedScore / 100))
                                }
                                .frame(height: 6)
                                Text("\(Format.seconds(rep.duration)) · at \(Format.clock(rep.timestamp))")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Text(Format.score(rep.speedScore))
                                .font(.metric(16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 30, alignment: .trailing)
                            SpeedBadge(speedClass: rep.speedClass)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedRep == rep.number ? Theme.accent.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Session summary

    private var sessionSummary: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("This workout so far")
                ForEach(controller.completedSets) { item in
                    HStack {
                        Text("Set \(item.setNumber)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(unit.format(kg: item.weightKg))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(item.reps.count) reps")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Text(Format.optionalScore(item.analytics.averageScore))
                            .font(.metric(16, weight: .heavy))
                            .foregroundStyle(item.analytics.averageClass?.color ?? Theme.textTertiary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Next set

    private var nextSetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Next set weight")
                HStack {
                    CircleIconButton(systemName: "minus", size: 40) {
                        let value = max(0, unit.fromKg(controller.weightKg) - unit.step)
                        controller.weightKg = unit.toKg(value)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(unit.number(fromKg: controller.weightKg))
                            .font(.metric(30, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText(value: controller.weightKg))
                        Text(unit.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .animation(.snappy, value: controller.weightKg)
                    Spacer()
                    CircleIconButton(systemName: "plus", size: 40) {
                        controller.weightKg = unit.toKg(unit.fromKg(controller.weightKg) + unit.step)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: onNextSet) {
                Label("Another Set", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.secondary)

            Button(action: onSave) {
                Label("Save Workout", systemImage: "square.and.arrow.down.fill")
            }
            .buttonStyle(.primary)
            .disabled(!controller.canSave)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Theme.tabBarBackground
                .opacity(0.92)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
        )
    }
}

/// Detail line for a selected rep.
struct RepDetailRow: View {
    let rep: RepRecord
    let firstScore: Double?
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Rep \(rep.number)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    SpeedBadge(speedClass: rep.speedClass)
                }
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(Format.score(rep.speedScore))
                .font(.metric(30, weight: .heavy))
                .foregroundStyle(rep.speedClass.color)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear selection")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceRaised))
    }

    private var detailText: String {
        var parts = ["Duration \(Format.seconds(rep.duration))", "at \(Format.clock(rep.timestamp))"]
        if let firstScore, rep.number > 1, firstScore > 0 {
            parts.append("\(Format.signedPercent((rep.speedScore - firstScore) / firstScore * 100)) vs rep 1")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let controller = WorkoutFlowController(configuration: SetConfiguration(
        exercise: .backSquat, weightKg: 120, targetReps: 6, source: .simulated
    ))
    return SetResultsView(
        controller: controller,
        result: SampleData.sampleSetResult,
        onSave: {},
        onNextSet: {},
        onDiscard: {}
    )
    .appBackground()
    .preferredColorScheme(.dark)
}
