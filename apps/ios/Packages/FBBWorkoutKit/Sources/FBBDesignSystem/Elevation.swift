import SwiftUI

/// Elevation scale. Mirrors Material's z-stack but tuned for iOS Liquid
/// Glass surfaces. Use one of these — never an ad-hoc shadow value.
public enum Elevation {
    case flat
    case card
    case raised
    case floating

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

public extension View {
    func elevation(_ level: Elevation) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, x: 0, y: level.y)
    }
}
