import Foundation

/// Where rep data comes from. The UI only talks to `TrackingService`,
/// so each source can be swapped without touching any screen.
enum TrackingSource: String, Codable, CaseIterable, Identifiable {
    case simulated
    case csvReplay
    case airPods

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulated: "Demo · Simulated"
        case .csvReplay: "CSV Replay"
        case .airPods: "AirPods Pro"
        }
    }
}

/// Lifecycle of a tracking session.
enum TrackingStatus: Equatable {
    case idle
    case starting
    case recording
    case paused
    case stopped
    case failed(String)
}

/// A rep reported by a tracking source, before it is numbered and classified.
struct DetectedRep {
    /// Relative speed score, 0–100. Not a velocity in m/s.
    var speedScore: Double
    /// Movement duration in seconds.
    var duration: TimeInterval
    /// Seconds since tracking started, if the source knows it.
    var timestamp: TimeInterval?
}

enum TrackingEvent {
    case status(TrackingStatus)
    case rep(DetectedRep)
    case failure(String)
}

struct TrackingContext {
    var exercise: Exercise
    var weightKg: Double
    var targetReps: Int?
}

enum TrackingError: LocalizedError {
    case motionUnavailable
    case permissionDenied
    case noData

    var errorDescription: String? {
        switch self {
        case .motionUnavailable: "Headphone motion data is not available. Connect supported AirPods Pro."
        case .permissionDenied: "Motion & Fitness access is turned off for BarTrack in Settings."
        case .noData: "The file did not contain any usable motion samples."
        }
    }
}

/// Common interface for simulated, CSV-replay and real AirPods tracking.
@MainActor
protocol TrackingService: AnyObject {
    var source: TrackingSource { get }
    /// Called on the main actor for every status change and detected rep.
    var onEvent: (@MainActor (TrackingEvent) -> Void)? { get set }

    func start(context: TrackingContext) throws
    func pause()
    func resume()
    func stop()
}

enum TrackingServiceFactory {
    @MainActor
    static func make(for source: TrackingSource) -> any TrackingService {
        switch source {
        case .simulated:
            return SimulatedTrackingService()
        case .csvReplay:
            return CSVReplayTrackingService(samples: [])
        case .airPods:
            return AirPodsMotionTrackingService()
        }
    }
}
