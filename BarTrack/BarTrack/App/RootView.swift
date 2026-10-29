import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()
    @AppStorage(AppStorageKey.accentTheme) private var accentRaw = AccentTheme.teal.rawValue
    @AppStorage(AppStorageKey.backgroundStyle) private var backgroundRaw = BackgroundStyle.navy.rawValue

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            WorkoutSetupView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(AppTab.workout)

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        // Rebuild the views when the theme changes so every Theme colour refreshes.
        .id("\(accentRaw)-\(backgroundRaw)")
        .environment(router)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .modelContainer(SampleData.previewContainer)
}
