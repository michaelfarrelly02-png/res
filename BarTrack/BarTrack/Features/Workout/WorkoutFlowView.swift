import SwiftUI
import SwiftData

/// Full-screen container that switches between Live tracking and Results.
struct WorkoutFlowView: View {
    let controller: WorkoutFlowController

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var showSavedBanner = false
    @State private var saveError: String?

    var body: some View {
        ZStack {
            AppBackground()

            switch controller.phase {
            case .live(let viewModel):
                LiveWorkoutView(
                    viewModel: viewModel,
                    completedSets: controller.completedSets.count,
                    onFinish: { withAnimation(.easeInOut(duration: 0.35)) { controller.finishCurrentSet() } },
                    onDiscard: discard
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))

            case .results(let result):
                SetResultsView(
                    controller: controller,
                    result: result,
                    onSave: save,
                    onNextSet: { withAnimation(.easeInOut(duration: 0.35)) { controller.startNextSet() } },
                    onDiscard: discard
                )
                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            }

            if showSavedBanner {
                SavedOverlay()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .alert("Could not save workout", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func save() {
        do {
            try controller.save(in: modelContext)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showSavedBanner = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                router.selectedTab = .home
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func discard() {
        controller.discard()
        dismiss()
    }
}

private struct SavedOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Workout saved")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.borderStrong, lineWidth: 1)
        )
    }
}
