import SwiftUI
import SwiftData

@main
struct BarTrackApp: App {
    init() {
        AppearanceConfigurator.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutSession.self, SetEntry.self])
    }
}
