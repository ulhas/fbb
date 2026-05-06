import SwiftUI

/// Elevation scale. Mirrors Material's z-stack but tuned for iOS Liquid
/// Glass surfaces. Use one of these — never an ad-hoc shadow value.
enum Elevation {
    case flat       // base surface, no shadow (lists, large backgrounds)
    case card       // standard card lift
    case raised     // hero surfaces (Today workout card, primary CTA)
    case floating   // sheets, popovers, FAB-style controls

    fileprivate var radius: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 8
        case .raised: return 18
        case .floating: return 28
        }
    }

    fileprivate var y: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 2
        case .raised: return 6
        case .floating: return 12
        }
    }

    fileprivate var opacity: Double {
        switch self {
        case .flat: return 0
        case .card: return 0.08
        case .raised: return 0.12
        case .floating: return 0.18
        }
    }
}

extension View {
    /// Apply a calibrated, theme-aware shadow. Watch / Widget callers should
    /// prefer `.flat` and rely on tint contrast instead.
    func elevation(_ level: Elevation) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, x: 0, y: level.y)
    }
}
