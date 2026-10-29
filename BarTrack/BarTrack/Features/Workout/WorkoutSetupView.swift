import SwiftUI
import SwiftData

/// Screen 2 — configure exercise, weight and target, then start a set.
struct WorkoutSetupView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKey.demoMode) private var demoMode = true
    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue
    @AppStorage(AppStorageKey.lastExercise) private var lastExerciseRaw = Exercise.backSquat.rawValue
    @AppStorage(AppStorageKey.zoneEnabled) private var zoneEnabled = false
    @AppStorage(AppStorageKey.zoneLower) private var zoneLower = 60.0
    @AppStorage(AppStorageKey.zoneUpper) private var zoneUpper = 80.0

    @State private var exercise: Exercise = .backSquat
    @State private var weightText = ""
    @State private var weightEdited = false
    @State private var useTargetReps = true
    @State private var targetReps = 5
    @State private var activeFlow: WorkoutFlowController?
    @State private var didLoadDefaults = false
    @State private var showAirPodsInfo = false
    @State private var comingSoonExercise: Exercise?
    @FocusState private var weightFocused: Bool

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }
    private var connection: MotionConnectionState { .current(demoMode: demoMode) }

    private var weightValue: Double? {
        guard let value = WeightUnit.parse(weightText), value > 0, value < 2000 else { return nil }
        return value
    }

    private var canStart: Bool { demoMode && weightValue != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    exerciseSection
                    weightSection
                    targetSection
                    speedZoneSection
                    trackingSection
                    startSection
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StatusPill(state: connection)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadDefaults)
            .onChange(of: exercise) { _, newExercise in
                if !weightEdited {
                    weightText = unit.number(fromKg: newExercise.defaultWeightKg)
                }
            }
            .onChange(of: unitRaw) { oldRaw, _ in
                // Convert the typed weight when the unit changes in Settings.
                let oldUnit = WeightUnit(rawValue: oldRaw) ?? .kg
                if let value = weightValue {
                    weightText = unit.number(fromKg: oldUnit.toKg(value))
                }
            }
            .fullScreenCover(item: $activeFlow) { flow in
                WorkoutFlowView(controller: flow)
                    .environment(router)
                    .modelContext(modelContext)
            }
            .alert(
                "\(comingSoonExercise?.displayName ?? "This lift") is coming soon",
                isPresented: Binding(
                    get: { comingSoonExercise != nil },
                    set: { if !$0 { comingSoonExercise = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("BarTrack currently supports the Back Squat only. More lifts will be added once tracking has been tested on them.")
            }
            .alert("AirPods tracking is coming soon", isPresented: $showAirPodsInfo) {
                Button("Use Demo Mode") { demoMode = true }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Real motion tracking with an AirPod attached to the bar is still experimental and will be added in a future version. Demo Mode lets you try the full workout flow with simulated reps.")
            }
        }
    }

    // MARK: - Sections

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Exercise")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Exercise.allCases) { item in
                    ExerciseOptionCard(exercise: item, isSelected: item == exercise) {
                        if item.isAvailable {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                exercise = item
                            }
                        } else {
                            comingSoonExercise = item
                        }
                    }
                }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Bar weight")
            Card {
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($weightFocused)
                            .font(.metric(54, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .onChange(of: weightText) { _, _ in
                                if weightFocused { weightEdited = true }
                            }
                        Text(unit.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        CircleIconButton(systemName: "minus") { adjustWeight(by: -unit.step) }
                        Spacer()
                        ForEach(quickAdjustments, id: \.self) { delta in
                            Button {
                                adjustWeight(by: delta)
                            } label: {
                                Text("+\(WeightUnit.formatNumber(delta))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                        Spacer()
                        CircleIconButton(systemName: "plus") { adjustWeight(by: unit.step) }
                    }

                    if weightValue == nil {
                        Text("Enter the total weight on the bar.")
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                    }
                }
            }
        }
    }

    private var quickAdjustments: [Double] {
        unit == .kg ? [5, 10, 20] : [10, 25, 45]
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Target reps")
            Card {
                VStack(spacing: 12) {
                    Toggle(isOn: $useTargetReps.animation()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a rep target")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Optional. Shows progress during the set.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.accent)

                    if useTargetReps {
                        HStack {
                            CircleIconButton(systemName: "minus") {
                                targetReps = max(1, targetReps - 1)
                            }
                            Spacer()
                            VStack(spacing: 0) {
                                Text("\(targetReps)")
                                    .font(.metric(44, weight: .heavy))
                                    .foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText(value: Double(targetReps)))
                                    .animation(.snappy, value: targetReps)
                                Text("REPS")
                                    .font(.caption2.weight(.bold))
                                    .tracking(1.2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            CircleIconButton(systemName: "plus") {
                                targetReps = min(30, targetReps + 1)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private var currentZone: SpeedZone { SpeedZone(lower: zoneLower, upper: zoneUpper) }

    private var speedZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Target speed zone")
            Card {
                VStack(spacing: 14) {
                    Toggle(isOn: $zoneEnabled.animation()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aim for a speed range")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Each rep is marked in zone, too slow or too fast.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.accent)

                    if zoneEnabled {
                        VStack(spacing: 14) {
                            HStack(spacing: 8) {
                                ForEach(SpeedZone.Preset.allCases) { preset in
                                    let isSelected = SpeedZone.Preset.matching(currentZone) == preset
                                    Button {
                                        if let zone = preset.zone {
                                            withAnimation(.snappy) {
                                                zoneLower = zone.lower
                                                zoneUpper = zone.upper
                                            }
                                        }
                                    } label: {
                                        Text(preset.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(maxWidth: .infinity, minHeight: 34)
                                            .background(Capsule().fill(isSelected ? Theme.accent : Theme.surfaceRaised))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }

                            SpeedZoneBar(zone: currentZone)

                            HStack(spacing: 12) {
                                zoneStepper(title: "Low", value: zoneLower) { delta in
                                    zoneLower = (zoneLower + delta).clamped(to: 0...(zoneUpper - 5))
                                }
                                zoneStepper(title: "High", value: zoneUpper) { delta in
                                    zoneUpper = (zoneUpper + delta).clamped(to: (zoneLower + 5)...100)
                                }
                            }

                            Text("Uses the relative speed score (0–100), not m/s.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func zoneStepper(title: String, value: Double, change: @escaping (Double) -> Void) -> some View {
        HStack {
            CircleIconButton(systemName: "minus", size: 34) { withAnimation(.snappy) { change(-5) } }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(Format.score(value))
                    .font(.metric(26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: value))
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            CircleIconButton(systemName: "plus", size: 34) { withAnimation(.snappy) { change(5) } }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceRaised.opacity(0.6)))
    }

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Tracking mode")
            HStack(spacing: 10) {
                TrackingModeCard(
                    title: "Demo Mode",
                    subtitle: "Simulated reps",
                    icon: "wand.and.stars",
                    isSelected: demoMode,
                    badge: nil
                ) {
                    withAnimation { demoMode = true }
                }
                TrackingModeCard(
                    title: "AirPods Pro",
                    subtitle: "Motion sensors",
                    icon: "airpodspro",
                    isSelected: !demoMode,
                    badge: "SOON"
                ) {
                    showAirPodsInfo = true
                }
            }
            HStack(spacing: 10) {
                Image(systemName: connection.symbol)
                    .foregroundStyle(connection.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(connection.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var startSection: some View {
        VStack(spacing: 12) {
            Button(action: startSet) {
                Label("Start Set", systemImage: "play.fill")
                    .font(.title3.weight(.heavy))
            }
            .buttonStyle(PrimaryButtonStyle(height: 62))
            .disabled(!canStart)

            if !demoMode {
                Button("Turn on Demo Mode") {
                    withAnimation { demoMode = true }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func loadDefaults() {
        guard !didLoadDefaults else { return }
        didLoadDefaults = true
        let saved = Exercise(rawValue: lastExerciseRaw) ?? .backSquat
        exercise = saved.isAvailable ? saved : .backSquat
        weightText = unit.number(fromKg: exercise.defaultWeightKg)
    }

    private func adjustWeight(by delta: Double) {
        let current = weightValue ?? 0
        weightText = WeightUnit.formatNumber(max(0, current + delta))
        weightEdited = true
    }

    private func startSet() {
        guard let weightValue, demoMode else { return }
        weightFocused = false
        lastExerciseRaw = exercise.rawValue
        let configuration = SetConfiguration(
            exercise: exercise,
            weightKg: unit.toKg(weightValue),
            targetReps: useTargetReps ? targetReps : nil,
            source: .simulated,
            speedZone: zoneEnabled ? currentZone : nil
        )
        activeFlow = WorkoutFlowController(configuration: configuration)
    }
}

// MARK: - Option cards

private struct ExerciseOptionCard: View {
    let exercise: Exercise
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: exercise.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.onAccent : (exercise.isAvailable ? Theme.accent : Theme.textTertiary))
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Theme.accent : (exercise.isAvailable ? Theme.accent.opacity(0.12) : Theme.surfaceRaised))
                        )
                    Spacer(minLength: 0)
                    if !exercise.isAvailable {
                        Text("SOON")
                            .font(.caption2.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.warning.opacity(0.14)))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(exercise.focus)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.08) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(exercise.isAvailable ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(exercise.isAvailable ? "" : "Coming soon")
    }
}

private struct TrackingModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.warning.opacity(0.14)))
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    WorkoutSetupView()
        .environment(AppRouter())
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}
