import SwiftUI

/// Generic settings row primitive. Composes icon + label + (value | toggle |
/// chevron). Used by Account / Body / Notifications / Privacy / About cards.
struct PreferenceRow<Trailing: View>: View {
    let symbol: String
    let symbolTint: Color
    let title: String
    let subtitle: String?
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    init(
        symbol: String,
        symbolTint: Color = .byowOrange,
        title: String,
        subtitle: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.trailing = trailing
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(symbolTint)
                .frame(width: 28, height: 28)
                .background(symbolTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.byow.body)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            trailing()

            if onTap != nil && Trailing.self == EmptyView.self {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Convenience trailing builders

struct PreferenceValue: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.byow.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(1)
    }
}

#Preview {
    VStack(spacing: 0) {
        PreferenceRow(symbol: "envelope.fill", title: "Email", subtitle: "alex@byow.training") {} trailing: { PreferenceValue(text: "Edit") }
        Divider()
        PreferenceRow(symbol: "lock.fill", title: "Change password", subtitle: "Last changed 12 days ago") {}
        Divider()
        PreferenceRow(symbol: "bell.fill", symbolTint: .byowTeal, title: "Workout reminders") {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .tint(.byowOrange)
        }
    }
    .background(Color.surfaceCard)
    .cardStyle(padded: false)
    .padding()
    .background(Color.byowBackground)
}
