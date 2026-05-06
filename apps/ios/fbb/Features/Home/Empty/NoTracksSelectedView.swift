import SwiftUI

struct NoTracksSelectedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.largeTitle)
                .foregroundStyle(.fbbTeal)

            Text("Pick a track to get started")
                .font(.fbb.title3)
                .foregroundStyle(.inkPrimary)

            Text("Choose from PUMP LIFT, PUMP CONDITION, PERFORM, or MINIMALIST. You can change tracks at any time.")
                .font(.fbb.body)
                .foregroundStyle(.inkSecondary)

            Button("Browse tracks") { }
                .buttonStyle(PrimaryGlassButtonStyle())
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
