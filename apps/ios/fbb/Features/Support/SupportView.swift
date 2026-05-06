import SwiftUI

struct SupportView: View {
    var body: some View {
        ComingSoonScaffold(
            symbol: "sparkles",
            title: "AI Coach",
            subtitle: "Ask questions about your programming, get smart swaps, and read your week back like a coach is in the room — powered by your live training data.",
            accent: .fbbTeal
        )
    }
}

#Preview { SupportView() }
