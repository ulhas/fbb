import SwiftUI

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
