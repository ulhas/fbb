import SwiftUI

/// Lightweight section header used across Stats cards.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.byow.title3)
                    .foregroundStyle(Color.inkPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 2)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader(title: "Tracks", subtitle: "Per-track volume · last 8 weeks")
        SectionHeader(title: "Movement balance")
    }
    .padding()
    .background(Color.byowBackground)
}
