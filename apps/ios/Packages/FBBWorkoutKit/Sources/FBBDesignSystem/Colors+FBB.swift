import SwiftUI

// On iOS the colors live in the SPM bundle's asset catalog and resolve
// light/dark via the system trait. On watchOS the SPM bundle's appearance
// trait isn't propagating cleanly (a known SwiftUI/SPM quirk on
// watchOS 11+), so the universal/light variant kept winning even with
// `.preferredColorScheme(.dark)` set on the root. Watch UI is always
// dark, so we hardcode the dark hex values there and keep iOS on the
// asset catalog. Same names + same values everywhere — design parity
// preserved.

#if os(watchOS)

private extension Color {
    /// Convenience initializer for hex byte values. (`Color(red:green:blue:)`
    /// expects 0–1 doubles.)
    static func srgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }
}

public extension Color {
    static let fbbOrange       = Color.srgb(0xEE, 0x4B, 0x0F)
    static let fbbOrangeDark   = Color.srgb(0xC5, 0x3D, 0x0C)
    static let fbbOrangeTint   = Color.srgb(0xFD, 0xE9, 0xE0)
    static let fbbTeal         = Color.srgb(0x7E, 0xBF, 0xC7)
    static let fbbTealDark     = Color.srgb(0x5C, 0x9C, 0xA4)
    static let fbbTealTint     = Color.srgb(0xD1, 0xE5, 0xE9)
    static let fbbStop         = Color.srgb(0xEF, 0x44, 0x4D) // dark variant
    static let fbbBackground   = Color.srgb(0x0B, 0x12, 0x20) // dark variant
    static let fbbDivider      = Color.srgb(0x33, 0x41, 0x55) // dark variant

    static let surfaceCard     = Color.srgb(0x11, 0x18, 0x27) // dark variant

    static let inkPrimary      = Color.srgb(0xF1, 0xF5, 0xF9) // dark variant
    static let inkSecondary    = Color.srgb(0xCB, 0xD5, 0xE1) // dark variant
    static let inkMuted        = Color.srgb(0x94, 0xA3, 0xB8) // dark variant

    static let semanticError   = Color.srgb(0xEF, 0x44, 0x44) // dark variant
    static let semanticSuccess = Color.srgb(0x34, 0xC7, 0x7D) // dark variant
    static let semanticWarning = Color.srgb(0xF5, 0x9E, 0x0B) // dark variant
}

#else

public extension Color {
    static let fbbOrange       = Color("FBBOrange",       bundle: .module)
    static let fbbOrangeDark   = Color("FBBOrangeDark",   bundle: .module)
    static let fbbOrangeTint   = Color("FBBOrangeTint",   bundle: .module)
    static let fbbTeal         = Color("FBBTeal",         bundle: .module)
    static let fbbTealDark     = Color("FBBTealDark",     bundle: .module)
    static let fbbTealTint     = Color("FBBTealTint",     bundle: .module)
    static let fbbStop         = Color("FBBStop",         bundle: .module)
    static let fbbBackground   = Color("FBBBackground",   bundle: .module)
    static let fbbDivider      = Color("FBBDivider",      bundle: .module)

    static let surfaceCard     = Color("SurfaceCard",     bundle: .module)

    static let inkPrimary      = Color("InkPrimary",      bundle: .module)
    static let inkSecondary    = Color("InkSecondary",    bundle: .module)
    static let inkMuted        = Color("InkMuted",        bundle: .module)

    static let semanticError   = Color("SemanticError",   bundle: .module)
    static let semanticSuccess = Color("SemanticSuccess", bundle: .module)
    static let semanticWarning = Color("SemanticWarning", bundle: .module)
}

#endif

// Mirror the brand palette onto ShapeStyle so `.foregroundStyle(.fbbOrange)`,
// `.fill(.surfaceCard)`, etc. work — same dot-syntax that Xcode's auto-
// generated asset symbols used to provide on the iOS app's catalog.
public extension ShapeStyle where Self == Color {
    static var fbbOrange:       Color { .fbbOrange }
    static var fbbOrangeDark:   Color { .fbbOrangeDark }
    static var fbbOrangeTint:   Color { .fbbOrangeTint }
    static var fbbTeal:         Color { .fbbTeal }
    static var fbbTealDark:     Color { .fbbTealDark }
    static var fbbTealTint:     Color { .fbbTealTint }
    static var fbbStop:         Color { .fbbStop }
    static var fbbBackground:   Color { .fbbBackground }
    static var fbbDivider:      Color { .fbbDivider }

    static var surfaceCard:     Color { .surfaceCard }

    static var inkPrimary:      Color { .inkPrimary }
    static var inkSecondary:    Color { .inkSecondary }
    static var inkMuted:        Color { .inkMuted }

    static var semanticError:   Color { .semanticError }
    static var semanticSuccess: Color { .semanticSuccess }
    static var semanticWarning: Color { .semanticWarning }
}
