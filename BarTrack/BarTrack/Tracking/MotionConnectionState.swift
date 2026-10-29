import Foundation

/// Connection state shown in the UI.
///
/// "Connected" and "streaming" are deliberately different states: AirPods
/// being connected over Bluetooth does not prove that motion samples are
/// arriving. Only `.streaming` means data is flowing.
enum MotionConnectionState: Equatable {
    case simulated
    case notConnected
    case connectedNoMotion
    case streaming

    /// For this prototype, the status comes only from Demo Mode.
    /// A future version will read it from `AirPodsMotionTrackingService`.
    static func current(demoMode: Bool) -> MotionConnectionState {
        demoMode ? .simulated : .notConnected
    }

    var shortTitle: String {
        switch self {
        case .simulated: "Demo Mode"
        case .notConnected: "Not connected"
        case .connectedNoMotion: "No motion data"
        case .streaming: "Streaming"
        }
    }

    var title: String {
        switch self {
        case .simulated: "Simulated AirPods"
        case .notConnected: "AirPods not connected"
        case .connectedNoMotion: "Connected · waiting for motion"
        case .streaming: "Motion data streaming"
        }
    }

    var detail: String {
        switch self {
        case .simulated:
            "Demo Mode generates realistic simulated reps. No hardware needed."
        case .notConnected:
            "Live AirPods tracking arrives in a future version. Turn on Demo Mode to try the app."
        case .connectedNoMotion:
            "AirPods are connected, but no motion samples are arriving yet."
        case .streaming:
            "Motion samples are arriving from the AirPod on the bar."
        }
    }
}
