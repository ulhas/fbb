import SwiftUI

struct LibraryView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundStyle(.fbbTeal)
            Text("Movement Library")
                .font(.fbb.title2)
                .foregroundStyle(.inkPrimary)
            Text("Coming in Phase 2")
                .font(.fbb.caption)
                .foregroundStyle(.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fbbBackground)
    }
}
