import SwiftUI

/// Circular profile avatar used as a navigation entry point. Lives in the
/// trailing toolbar slot on Today (and any future surface that needs a
/// shortcut to ProfileView). Defaults to a tinted glyph when no image is set.
struct ProfileAvatarButton: View {
    var initials: String? = nil
    var imageName: String? = nil
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.fbbOrange, .fbbOrangeDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )

            if let imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if let initials, !initials.isEmpty {
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: 16) {
        ProfileAvatarButton()
        ProfileAvatarButton(initials: "UM")
        ProfileAvatarButton(initials: "AB", size: 44)
    }
    .padding()
    .background(Color.fbbBackground)
}
