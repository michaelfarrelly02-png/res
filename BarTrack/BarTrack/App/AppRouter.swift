import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, workout, history, settings
}

/// Shared navigation state, so any screen can switch tabs
/// (for example the Home "Start Workout" button).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
}
