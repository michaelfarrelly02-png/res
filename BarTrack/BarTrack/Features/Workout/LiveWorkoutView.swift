import SwiftUI

/// Screen 3 — live performance dashboard for the current set.
struct LiveWorkoutView: View {
    let viewModel: LiveWorkoutViewModel
    let completedSets: Int
    var onFinish: () -> Void
    var onDiscard: () -> Void

    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue
    @AppStorage(AppStorageKey.simulationPace) private var paceRaw = SimulationPace.normal.rawValue
    @AppStorage(AppStorageKey.showEstimates) private var showEstimates = true
    @State private var showDiscardConfirmation = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }
    private var accentForLatest: Color { viewModel.latestRep?.speedClass.color ?? Theme.accent }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.cutoffReached {
                        cutoffBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    infoRow
                    repCounter
                        .padding(.vertical, 4)
                    latestRepCard
                    if viewModel.configuration.velocityLossLimit != nil {
                        speedDropCard
                    }
                    chartCard
                    if let simulator = viewModel.simulator {
                        DemoControlsCard(
                            simulator: simulator,
                            isEnabled: viewModel.isRecording,
                            onSimulate: { viewModel.simulateRep($0) },
                            onToggleAuto: { viewModel.toggleAutoSimulation() }
                        )
                    }
                    if let error = viewModel.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)

            if let seconds = viewModel.autoEndCountdown {
                autoEndBanner(seconds: seconds)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            controlBar
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.autoEndCountdown)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.cutoffReached)
        .onChange(of: viewModel.shouldAutoFinish) { _, shouldFinish in
            if shouldFinish { onFinish() }
        }
        .sensoryFeedback(.warning, trigger: viewModel.cutoffReached)
        .onAppear {
            viewModel.simulator?.pace = SimulationPace(rawValue: paceRaw) ?? .normal
            viewModel.start()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.reps.count)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive, action: onDiscard)
            Button("Keep Training", role: .cancel) {}
        } message: {
            if completedSets > 0 {
                Text("This set and \(completedSets) completed set\(completedSets == 1 ? "" : "s") will not be saved.")
            } else {
                Text("This set will not be saved.")
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "xmark", size: 38) {
                showDiscardConfirmation = true
            }
            .accessibilityLabel("Discard workout")

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.configuration.exercise.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("SET \(viewModel.setNumber)")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            RecordingIndicator(status: viewModel.status)
        }
    }

    // MARK: - Info row

    private var infoRow: some View {
        HStack(spacing: 10) {
            infoTile(title: "Weight", value: unit.number(fromKg: viewModel.configuration.weightKg), unit: unit.symbol)
            infoTile(title: "Set time", value: Format.clock(viewModel.elapsed), unit: nil, monospaced: true)
            infoTile(
                title: "Target",
                value: viewModel.configuration.targetReps.map { "\($0)" } ?? "—",
                unit: viewModel.configuration.targetReps == nil ? nil : "reps"
            )
        }
    }

    private func infoTile(title: String, value: String, unit: String?, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.metric(22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(monospaced ? .numericText() : .identity)
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    // MARK: - Rep counter

    private var repCounter: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: 14)

            Circle()
                .trim(from: 0, to: viewModel.targetProgress)
                .stroke(
                    AngularGradient(
                        colors: [accentForLatest.opacity(0.6), accentForLatest],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accentForLatest.opacity(0.5), radius: 12)

            VStack(spacing: -4) {
                Text("\(viewModel.reps.count)")
                    .font(.system(size: 112, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(viewModel.reps.count)))
                Text(counterCaption)
                    .font(.caption.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 236, height: 236)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: viewModel.reps.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.reps.count) reps")
    }

    private var counterCaption: String {
        if let target = viewModel.configuration.targetReps {
            return "OF \(target) REPS"
        }
        return viewModel.reps.count == 1 ? "REP" : "REPS"
    }

    // MARK: - Latest rep

    private var latestRepCard: some View {
        Card(highlight: viewModel.latestRep?.speedClass.color) {
            if let rep = viewModel.latestRep {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel("Rep \(rep.number) · relative speed")
                            HStack(spacing: 10) {
                                Image(systemName: rep.speedClass.symbol)
                                    .font(.title2.weight(.bold))
                                Text(rep.speedClass.label)
                                    .font(.metric(38, weight: .black))
                            }
                            .foregroundStyle(rep.speedClass.color)
                            .contentTransition(.interpolate)
                            if let zone = viewModel.configuration.speedZone {
                                HStack(spacing: 8) {
                                    ZoneStatusBadge(status: zone.status(for: rep.speedScore))
                                    Text("\(viewModel.inZoneCount)/\(viewModel.reps.count) in zone")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Format.score(rep.speedScore))
                                .font(.metric(38, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText(value: rep.speedScore))
                            Text("score / 100")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rep.id)
                    if showEstimates, let velocity = rep.meanVelocity {
                        Divider().overlay(Theme.border)
                        HStack(spacing: 8) {
                            MiniMetric(label: "Mean vel.", value: Format.velocity(velocity), unit: "m/s")
                            MiniMetric(label: "Peak vel.", value: rep.peakVelocity.map(Format.velocity) ?? "–", unit: "m/s")
                            MiniMetric(label: "Power", value: rep.power.map(Format.watts) ?? "–", unit: "W")
                            MiniMetric(label: "Depth", value: rep.rangeOfMotionCm.map(Format.centimetres) ?? "–", unit: "cm")
                        }
                        .overlay(alignment: .topTrailing) { EstimateTag().offset(y: -14) }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isPaused ? "Set paused" : "Waiting for first rep…")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if viewModel.isWaitingForFirstRep && !viewModel.isPaused {
                            Text("The set timer starts on your first rep.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        Text(viewModel.simulator != nil
                             ? "Use the Demo controls below to simulate reps."
                             : "Start lifting. Reps appear here automatically.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Speed drop

    private var cutoffBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title2.weight(.bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("STOP THE SET")
                    .font(.metric(22, weight: .black))
                Text("Speed dropped \(Int((viewModel.currentSpeedDrop ?? 0).rounded()))% from your best rep (limit \(Int(viewModel.configuration.velocityLossLimit ?? 0))%).")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.danger))
        .accessibilityElement(children: .combine)
    }

    private var speedDropCard: some View {
        let limit = viewModel.configuration.velocityLossLimit ?? 20
        let drop = viewModel.currentSpeedDrop ?? 0
        let fraction = min(1, drop / limit)
        let color = drop >= limit ? Theme.danger : (fraction >= 0.7 ? Theme.warning : Theme.accent)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("Speed drop from best rep")
                    Spacer()
                    Text("\(Int(drop.rounded()))%")
                        .font(.metric(22, weight: .heavy))
                        .foregroundStyle(color)
                        .contentTransition(.numericText(value: drop))
                    Text("/ \(Int(limit))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceRaised)
                        Capsule()
                            .fill(color.gradient)
                            .frame(width: geometry.size.width * fraction)
                    }
                }
                .frame(height: 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: drop)
            }
        }
    }

    private func autoEndBanner(seconds: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(Theme.accent)
            Text("Bar racked? Ending set in \(seconds)s")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: Double(seconds)))
            Spacer()
            Button("Keep going") { viewModel.keepGoing() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.vertical, 12)
        .background(Theme.surfaceRaised)
    }

    // MARK: - Chart

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                if let zone = viewModel.configuration.speedZone {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                        Text("Target zone \(zone.text)")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                }
                HStack {
                    SectionLabel("Speed score per rep")
                    Spacer()
                    SpeedLegend()
                }
                if viewModel.reps.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surfaceRaised.opacity(0.5))
                        .frame(height: 160)
                        .overlay(
                            Text("Completed reps will appear here")
                                .font(.footnote)
                                .foregroundStyle(Theme.textTertiary)
                        )
                } else {
                    RepSpeedChart(reps: viewModel.reps, height: 160, speedZone: viewModel.configuration.speedZone)
                }
                Text("Relative score (0–100), experimental — not m/s.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePause()
            } label: {
                Label(viewModel.isPaused ? "Resume" : "Pause",
                      systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.secondary)
            .disabled(!(viewModel.isRecording || viewModel.isPaused))

            Button(action: onFinish) {
                Label("Finish Set", systemImage: "flag.checkered")
            }
            .buttonStyle(.primary)
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

// MARK: - Recording indicator

private struct RecordingIndicator: View {
    let status: TrackingStatus
    @State private var pulse = false

    private var label: String {
        switch status {
        case .recording: "REC"
        case .paused: "PAUSED"
        case .starting: "STARTING"
        case .failed: "ERROR"
        case .idle, .stopped: "READY"
        }
    }

    private var color: Color {
        switch status {
        case .recording: Theme.recording
        case .paused: Theme.warning
        case .failed: Theme.danger
        default: Theme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(status == .recording && pulse ? 0.25 : 1)
                .animation(
                    status == .recording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
            Text(label)
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.12)))
        .onAppear { pulse = true }
        .accessibilityLabel("Status: \(label)")
    }
}

// MARK: - Demo controls

private struct DemoControlsCard: View {
    let simulator: SimulatedTrackingService
    let isEnabled: Bool
    let onSimulate: (SpeedClass?) -> Void
    let onToggleAuto: () -> Void

    var body: some View {
        Card(highlight: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("DEMO MODE", systemImage: "wand.and.stars")
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("Simulated data")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Text("Add a rep")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    ForEach(SpeedClass.allCases) { speedClass in
                        SimulateButton(
                            title: speedClass.label,
                            icon: speedClass.symbol,
                            color: speedClass.color
                        ) {
                            onSimulate(speedClass)
                        }
                    }
                    SimulateButton(title: "AUTO", icon: "dice.fill", color: Theme.textPrimary) {
                        onSimulate(nil)
                    }
                }

                Button(action: onToggleAuto) {
                    Label(
                        simulator.isAutoSimulating ? "Stop Auto-Simulation" : "Auto-Simulate Set",
                        systemImage: simulator.isAutoSimulating ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .font(.subheadline.weight(.bold))
                }
                .buttonStyle(SecondaryButtonStyle(height: 46, foreground: simulator.isAutoSimulating ? Theme.warning : Theme.accent))

                Text("“AUTO” reps follow a fatigue model: heavier sets start slower and reps slow down as the set goes on.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct SimulateButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    LiveWorkoutView(
        viewModel: LiveWorkoutViewModel(
            configuration: SetConfiguration(exercise: .backSquat, weightKg: 120, targetReps: 5, source: .simulated),
            setNumber: 1
        ),
        completedSets: 0,
        onFinish: {},
        onDiscard: {}
    )
    .appBackground()
    .preferredColorScheme(.dark)
}
