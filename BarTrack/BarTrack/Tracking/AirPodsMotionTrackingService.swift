import Foundation
import CoreMotion

/// Real AirPods Pro tracking via `CMHeadphoneMotionManager` (Phase 2).
///
/// Prepared but NOT used by the UI yet. When enabled it:
/// 1. checks headphone motion is available and permitted,
/// 2. treats a Bluetooth connection only as `.connectedNoMotion`,
/// 3. reports `.streaming` only once motion samples actually arrive,
/// 4. feeds samples through `RepDetector` and emits detected reps.
///
/// Requires `NSMotionUsageDescription` (already set in the build settings)
/// and a physical iPhone with supported AirPods — it cannot run in the Simulator.
@MainActor
final class AirPodsMotionTrackingService: NSObject, TrackingService {
    let source: TrackingSource = .airPods
    var onEvent: (@MainActor (TrackingEvent) -> Void)?

    private(set) var connectionState: MotionConnectionState = .notConnected
    var onConnectionChange: (@MainActor (MotionConnectionState) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private var detector = RepDetector()
    private var firstTimestamp: TimeInterval?
    private var isPaused = false

    var isMotionAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(context: TrackingContext) throws {
        guard manager.isDeviceMotionAvailable else { throw TrackingError.motionUnavailable }
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            throw TrackingError.permissionDenied
        default:
            break
        }

        detector = RepDetector()
        firstTimestamp = nil
        isPaused = false
        manager.delegate = self
        onEvent?(.status(.starting))

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            MainActor.assumeIsolated {
                self?.handle(motion: motion, error: error)
            }
        }
    }

    func pause() {
        isPaused = true
        onEvent?(.status(.paused))
    }

    func resume() {
        isPaused = false
        onEvent?(.status(.recording))
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        if connectionState == .streaming {
            updateConnection(.connectedNoMotion)
        }
        onEvent?(.status(.stopped))
    }

    private func handle(motion: CMDeviceMotion?, error: Error?) {
        if let error {
            onEvent?(.failure(error.localizedDescription))
            return
        }
        guard let motion else { return }

        // Only now do we know data is really flowing.
        if connectionState != .streaming {
            updateConnection(.streaming)
            onEvent?(.status(.recording))
        }
        guard !isPaused else { return }

        let start = firstTimestamp ?? motion.timestamp
        firstTimestamp = start

        let sample = MotionSample(
            timestamp: motion.timestamp - start,
            userAcceleration: SIMD3(motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
            rotationRate: SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z),
            pitch: motion.attitude.pitch
        )
        if let rep = detector.process(sample) {
            onEvent?(.rep(rep))
        }
    }

    private func updateConnection(_ state: MotionConnectionState) {
        guard state != connectionState else { return }
        connectionState = state
        onConnectionChange?(state)
    }
}

extension AirPodsMotionTrackingService: CMHeadphoneMotionManagerDelegate {
    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            // Connected is not the same as streaming.
            guard let self, self.connectionState != .streaming else { return }
            self.updateConnection(.connectedNoMotion)
        }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            self?.updateConnection(.notConnected)
        }
    }
}
