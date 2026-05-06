import SwiftUI

/// Wraps a list of rows with optional title + card chrome. Callers are
/// responsible for inserting `RowDivider()` between rows when wanted —
/// that's a small explicit cost in exchange for staying off the private
/// `_VariadicView` API.
struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.fbb.title3)
                        .foregroundStyle(Color.inkPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.fbb.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .padding(.horizontal, 2)
            }

            VStack(spacing: 0) { content() }
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                .elevation(.card)
        }
    }
}

/// Hairline divider tuned to sit between two `PreferenceRow`s — leaves the
/// leading icon column untouched so the divider lines up with row text.
struct RowDivider: View {
    var body: some View {
        Divider()
            .background(Color.fbbDivider)
            .padding(.leading, 56)
    }
}

#Preview {
    VStack(spacing: 24) {
        SettingsCard(title: "Account") {
            PreferenceRow(symbol: "envelope.fill", title: "Email", subtitle: "alex@fbb.training") {}
            RowDivider()
            PreferenceRow(symbol: "lock.fill", title: "Change password") {}
        }
        SettingsCard(title: "Notifications", subtitle: "Choose what reaches your phone") {
            PreferenceRow(symbol: "bell.fill", symbolTint: .fbbTeal, title: "Workout reminders") {
                Toggle("", isOn: .constant(true)).labelsHidden().tint(.fbbOrange)
            }
            RowDivider()
            PreferenceRow(symbol: "trophy.fill", symbolTint: .fbbOrange, title: "PR celebrations") {
                Toggle("", isOn: .constant(true)).labelsHidden().tint(.fbbOrange)
            }
        }
    }
    .padding()
    .background(Color.fbbBackground)
}
