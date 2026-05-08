import SwiftUI

struct LogoutFooter: View {
    let appInfo: AppInfo
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Button(action: onLogout) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("Sign out")
                        .font(.byow.bodyBold)
                    Spacer()
                }
                .foregroundStyle(Color.semanticError)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardCorner)
                        .strokeBorder(Color.semanticError.opacity(0.25), lineWidth: 1)
                )
                .elevation(.card)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign out")

            Text("BYOW Persist · \(appInfo.version) (\(appInfo.buildNumber)) · \(appInfo.environment)")
                .font(.byow.label).tracking(0.8)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    LogoutFooter(
        appInfo: ProfileMockData.appInfo,
        onLogout: {}
    )
    .padding()
    .background(Color.byowBackground)
}
