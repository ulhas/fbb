import SwiftUI

struct LibraryView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundStyle(.byowTeal)
            Text("Movement Library")
                .font(.byow.title2)
                .foregroundStyle(.inkPrimary)
            Text("Coming in Phase 2")
                .font(.byow.caption)
                .foregroundStyle(.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.byowBackground)
    }
}
