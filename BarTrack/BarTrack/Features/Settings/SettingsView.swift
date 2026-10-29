import SwiftUI
import SwiftData

/// Screen 6 — preferences, tracking, data and app info.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [WorkoutSession]

    @AppStorage(AppStorageKey.userName) private var userName = ""
    @AppStorage(AppStorageKey.weightUnit) private var unitRaw = WeightUnit.kg.rawValue
    @AppStorage(AppStorageKey.accentTheme) private var accentRaw = AccentTheme.teal.rawValue
    @AppStorage(AppStorageKey.backgroundStyle) private var backgroundRaw = BackgroundStyle.navy.rawValue
    @AppStorage(AppStorageKey.demoMode) private var demoMode = true
    @AppStorage(AppStorageKey.simulationPace) private var paceRaw = SimulationPace.normal.rawValue
    @AppStorage(AppStorageKey.showEstimates) private var showEstimates = true

    @State private var confirmDeleteAll = false
    @State private var showMeasurementInfo = false
    @State private var toastMessage: String?

    private var connection: MotionConnectionState { .current(demoMode: demoMode) }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                unitsSection
                appearanceSection
                trackingSection
                measurementsSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accent))
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .confirmationDialog("Delete all workouts?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete \(sessions.count) Workouts", role: .destructive, action: deleteAll)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your saved workout history from this iPhone.")
            }
            .sheet(isPresented: $showMeasurementInfo) {
                MeasurementInfoSheet()
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
                TextField("Your name", text: $userName)
                    .textContentType(.givenName)
                    .foregroundStyle(Theme.textPrimary)
            }
        } header: {
            SectionLabel("Profile")
        }
        .listRowBackground(Theme.surface)
    }

    private var unitsSection: some View {
        Section {
            Picker("Weight unit", selection: $unitRaw) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            SectionLabel("Units")
        } footer: {
            Text("Weights are stored in kilograms and converted for display.")
        }
        .listRowBackground(Theme.surface)
    }

    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent colour")
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 14) {
                    ForEach(AccentTheme.allCases) { theme in
                        Button {
                            withAnimation { accentRaw = theme.rawValue }
                        } label: {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: accentRaw == theme.rawValue ? 3 : 0)
                                )
                                .overlay {
                                    if accentRaw == theme.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(Theme.onAccent)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.displayName)
                        .accessibilityAddTraits(accentRaw == theme.rawValue ? .isSelected : [])
                    }
                }
                Text(AccentTheme(rawValue: accentRaw)?.displayName ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 4)

            Picker("Background", selection: $backgroundRaw) {
                ForEach(BackgroundStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
        } header: {
            SectionLabel("Theme")
        } footer: {
            Text("Speed colours stay fixed: teal = fast, blue = medium, orange = slow.")
        }
        .listRowBackground(Theme.surface)
    }

    private var trackingSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "airpodspro")
                    .font(.title2)
                    .foregroundStyle(connection.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.title)
                        .foregroundStyle(Theme.textPrimary)
                    Text(connection.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                StatusPill(state: connection)
            }
            .padding(.vertical, 4)

            Toggle(isOn: $demoMode.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Mode")
                        .foregroundStyle(Theme.textPrimary)
                    Text("Simulate reps without AirPods or a barbell.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .tint(Theme.accent)

            if demoMode {
                Picker("Auto-simulation pace", selection: $paceRaw) {
                    ForEach(SimulationPace.allCases) { pace in
                        Text(pace.displayName).tag(pace.rawValue)
                    }
                }
            }

            LabeledContent("Real AirPods tracking") {
                Text("Coming soon")
                    .foregroundStyle(Theme.warning)
            }
        } header: {
            SectionLabel("AirPods & tracking")
        } footer: {
            Text("A Bluetooth connection alone does not mean motion data is streaming. BarTrack will only show “Streaming” once motion samples are actually received from the AirPod on the bar.")
        }
        .listRowBackground(Theme.surface)
    }

    private var measurementsSection: some View {
        Section {
            ExperimentalNotice()
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            Toggle(isOn: $showEstimates) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show estimated velocity & depth")
                        .foregroundStyle(Theme.textPrimary)
                    Text("m/s, power (W) and range of motion (cm), marked EST. until validated.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .tint(Theme.accent)
            Button {
                showMeasurementInfo = true
            } label: {
                Label("How speed is measured", systemImage: "info.circle")
                    .foregroundStyle(Theme.accent)
            }
        } header: {
            SectionLabel("Experimental measurements")
        }
        .listRowBackground(Theme.surface)
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Saved workouts", value: "\(sessions.count)")
            Button {
                SampleData.insertSampleWorkouts(into: modelContext)
                showToast("Sample workouts added")
            } label: {
                Label("Load sample workouts", systemImage: "tray.and.arrow.down.fill")
                    .foregroundStyle(Theme.accent)
            }
            Button(role: .destructive) {
                confirmDeleteAll = true
            } label: {
                Label("Delete all workouts", systemImage: "trash")
                    .foregroundStyle(Theme.danger)
            }
            .disabled(sessions.isEmpty)
        } header: {
            SectionLabel("Data")
        } footer: {
            Text("Workouts are stored only on this iPhone.")
        }
        .listRowBackground(Theme.surface)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App version", value: appVersion)
            LabeledContent("Tracking engine", value: demoMode ? "Simulated" : "Not active")
            LabeledContent("Motion algorithm", value: "Prototype v0.6.1 (not yet integrated)")
        } header: {
            SectionLabel("About BarTrack")
        } footer: {
            Text("BarTrack prototype · Built with SwiftUI, Swift Charts and SwiftData.")
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: - Actions

    private func deleteAll() {
        for session in sessions {
            modelContext.delete(session)
        }
        try? modelContext.save()
        showToast("All workouts deleted")
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { toastMessage = nil }
        }
    }
}

private struct MeasurementInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoBlock(
                        icon: "speedometer",
                        title: "Relative speed score",
                        text: "Each rep gets a score from 0 to 100 that compares how quickly the bar moved. It is useful for spotting trends within a set and between workouts, but it is not a velocity in metres per second."
                    )
                    infoBlock(
                        icon: "hare.fill",
                        title: "Slow · Medium · Fast",
                        text: "Scores of 70 and above are labelled Fast, 45–69 Medium and below 45 Slow. These thresholds are tentative and will be tuned as the algorithm is validated."
                    )
                    infoBlock(
                        icon: "flask.fill",
                        title: "Still experimental",
                        text: "The motion algorithms (prototype v0.6.1) have shown encouraging results in controlled tests but are not independently validated. Some slow-movement detections rely on AirPod orientation changes rather than direct bar displacement."
                    )
                    infoBlock(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Estimated velocity & depth",
                        text: "Mean velocity (m/s), peak velocity, power (W) and range of motion (cm) are shown as estimates (EST.). In Demo Mode they are simulated. With AirPods they will come from the motion algorithm, and they are not yet validated against a reference device such as a linear position transducer. You can hide them in Settings."
                    )
                }
                .padding(Theme.Spacing.screen)
            }
            .appBackground()
            .navigationTitle("About measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func infoBlock(icon: String, title: String, text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}
