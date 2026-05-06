import Foundation
import Observation

/// Owns the user's selected track codes (a stub for real entitlements).
///
/// In Phase 1 this is a UserDefaults-backed list. In Phase 2 it will be
/// driven by RevenueCat webhooks → backend `entitlements` table → PowerSync.
@Observable
@MainActor
final class EntitlementsStore {
    private static let key = "fbb.selectedTrackCodes.v1"

    var selectedTrackCodes: [String] {
        didSet {
            UserDefaults.standard.set(selectedTrackCodes, forKey: Self.key)
        }
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        // Dev-default seeds a single track so a fresh install has something to show.
        // Real onboarding / track-picker is Phase 2.
        self.selectedTrackCodes = stored.isEmpty ? ["pump_lift_4x"] : stored
    }

    func toggle(_ code: String) {
        if selectedTrackCodes.contains(code) {
            selectedTrackCodes.removeAll { $0 == code }
        } else {
            selectedTrackCodes.append(code)
        }
    }

    func has(_ code: String) -> Bool {
        selectedTrackCodes.contains(code)
    }
}
