import SwiftUI

struct TrackChip: View {
    let track: TrainingWeekTrackIndexRow
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Text(track.displayName)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(isSelected ? .white : .inkPrimary)
                if isBridge {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white : Color.semanticWarning)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .glassEffect(
            isSelected
                ? .regular.tint(.fbbOrange).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var isBridge: Bool { track.microcycle.kind == .bridgeWeek }

    private var a11yLabel: String {
        var parts: [String] = [track.displayName]
        if isSelected { parts.append("selected") }
        if isBridge   { parts.append("bridge week") }
        return parts.joined(separator: ", ")
    }
}
