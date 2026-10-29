import SwiftUI
import SwiftData
import Charts

/// Screen 1 — dashboard shown when the app opens.
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @AppStorage(AppStorageKey.demoMode) private var demoMode = true
    @AppStorage(AppStorageKey.userName) private var userName = ""
    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }
    private var connection: MotionConnectionState { .current(demoMode: demoMode) }

    private var recentSessions: [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return sessions.filter { $0.date >= cutoff }
    }

    private var averageRecentScore: Double? {
        let scores = recentSessions.compactMap(\.averageScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    header
                    welcome
                    startWorkoutButton
                    connectionCard
                    statsRow
                    lastWorkoutSection
                    ActivityChartCard(sessions: sessions)
                    quickLinks
                    ExperimentalNotice()
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(session: session)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            BarTrackLogo()
            Spacer()
            Button {
                router.selectedTab = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Track every rep. Train with intent.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var startWorkoutButton: some View {
        Button {
            router.selectedTab = .workout
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("START WORKOUT")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(0.5)
                    Text(demoMode ? "Demo Mode · simulated reps" : "Choose exercise & weight")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.75)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .black))
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Theme.onAccent.opacity(0.14)))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.accent, Theme.accent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(alignment: .bottomTrailing) {
                BarbellGlyph(color: Theme.onAccent.opacity(0.08))
                    .scaleEffect(4)
                    .offset(x: -110, y: -18)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.35), radius: 20, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Start workout")
    }

    private var connectionCard: some View {
        Button {
            router.selectedTab = .settings
        } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(connection.color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(connection.color.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connection.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(connection.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    StatusPill(state: connection)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "Workouts",
                value: "\(recentSessions.count)",
                caption: "Last 30 days",
                icon: "calendar"
            )
            MetricTile(
                title: "Avg speed",
                value: Format.optionalScore(averageRecentScore),
                unit: "/100",
                caption: "Relative score, 30 days",
                valueColor: averageRecentScore.map { SpeedClassifier.default.classify($0).color } ?? Theme.textPrimary,
                icon: "speedometer"
            )
        }
    }

    @ViewBuilder
    private var lastWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Last workout")
            if let last = sessions.first {
                NavigationLink(value: last) {
                    LastWorkoutCard(session: last, unit: unit)
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                EmptyStateView(
                    icon: "figure.strengthtraining.traditional",
                    title: "No workouts yet",
                    message: "Start your first set in Demo Mode, or load sample workouts from Settings."
                )
            }
        }
    }

    private var quickLinks: some View {
        HStack(spacing: 12) {
            QuickLinkCard(title: "History", subtitle: "\(sessions.count) workouts", icon: "chart.bar.xaxis") {
                router.selectedTab = .history
            }
            QuickLinkCard(title: "Settings", subtitle: demoMode ? "Demo Mode on" : "Demo Mode off", icon: "slider.horizontal.3") {
                router.selectedTab = .settings
            }
        }
    }
}

// MARK: - Last workout card

private struct LastWorkoutCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: session.exercise.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.exercise.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(session.date.formatted(.relative(presentation: .named)).capitalizedFirstLetter)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: 0) {
                    stat(value: unit.number(fromKg: session.topWeightKg), label: "Top \(unit.symbol)")
                    divider
                    stat(value: "\(session.sets.count)", label: "Sets")
                    divider
                    stat(value: "\(session.totalReps)", label: "Reps")
                    divider
                    stat(
                        value: Format.optionalScore(session.averageScore),
                        label: "Avg speed",
                        color: session.averageScore.map { SpeedClassifier.default.classify($0).color }
                    )
                }
                RepSpeedChart(reps: session.allReps, height: 70, showThresholds: false, showAxes: false)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(width: 1, height: 30)
    }

    private func stat(value: String, label: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.metric(20, weight: .heavy))
                .foregroundStyle(color ?? Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity chart

struct ActivityChartCard: View {
    let sessions: [WorkoutSession]
    @State private var metric: Metric = .reps

    enum Metric: String, CaseIterable, Identifiable {
        case reps = "Reps"
        case speed = "Speed"
        var id: String { rawValue }
    }

    struct Day: Identifiable {
        let date: Date
        let reps: Int
        let averageScore: Double?
        var id: Date { date }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<14).reversed().compactMap { offset -> Day? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let reps = daySessions.flatMap(\.allReps)
            let average = reps.isEmpty ? nil : reps.map(\.speedScore).reduce(0, +) / Double(reps.count)
            return Day(date: day, reps: reps.count, averageScore: average)
        }
    }

    var body: some View {
        let data = days
        let hasData = data.contains { $0.reps > 0 }
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel("Training activity")
                        Text("Last 14 days")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Picker("Metric", selection: $metric) {
                        ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                if hasData {
                    chart(data)
                        .frame(height: 150)
                        .animation(.easeInOut, value: metric)
                } else {
                    Text("Complete a workout to see your activity here.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                }
            }
        }
    }

    @ViewBuilder
    private func chart(_ data: [Day]) -> some View {
        switch metric {
        case .reps:
            Chart(data) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Reps", day.reps)
                )
                .foregroundStyle(Theme.accent.gradient)
                .cornerRadius(4)
            }
            .chartXAxis { dayAxis }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
        case .speed:
            Chart(data.filter { $0.averageScore != nil }) { day in
                LineMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Avg speed", day.averageScore ?? 0)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                PointMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Avg speed", day.averageScore ?? 0)
                )
                .foregroundStyle(SpeedClassifier.default.classify(day.averageScore ?? 0).color)
                .symbolSize(60)
            }
            .chartXScale(domain: (data.first?.date ?? .now)...(data.last?.date ?? .now))
            .chartYScale(domain: 0...100)
            .chartXAxis { dayAxis }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Quick link

private struct QuickLinkCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}
