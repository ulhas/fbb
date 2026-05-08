import SwiftUI

/// Between-set rest countdown. Slides in from the bottom edge above the
/// session footer. Tap-to-skip via the chevron handle, +15s via the
/// little plus button.
struct RestOverlay: View {
    let rest: RestState
    let onSkip: () -> Void
    let onAdd15: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let remaining = rest.remainingSeconds(now: ctx.date)
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.byow.label).tracking(0.6)
                        .foregroundStyle(remaining < 0 ? .red : Color.byowTeal)
                    Text(SessionMath.formatCountdown(remaining))
                        .font(.byow.metricLarge)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button(action: onAdd15) {
                    Text("+15")
                        .font(.byow.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.byow.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.byowTeal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .background(
                Color.black.opacity(0.92)
                    .background(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCorner)
                    .strokeBorder(Color.byowTeal.opacity(0.4), lineWidth: 1)
            )
        }
    }
}
