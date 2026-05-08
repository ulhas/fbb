import SwiftUI

/// Small toolbar chip indicating the user's nutrition + training data is
/// visible to their coach (human + AI). Tap opens the explainer sheet.
struct CoachVisibilityChip: View {
    var coachName: String? = "Sarah"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "eye.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.byowTeal)
                .frame(width: 30, height: 30)
                .background(Color.byowTealTint.opacity(0.6), in: Circle())
                .accessibilityLabel("Coach visibility settings")
                .accessibilityHint(coachName.map { "Visible to coach \($0)" } ?? "Coach view enabled")
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        CoachVisibilityChip(onTap: {})
        CoachVisibilityChip(coachName: nil, onTap: {})
    }
    .padding()
    .background(Color.byowBackground)
}
