import SwiftUI

struct MacroConsistencyCard: View {
    let consistency: MacroConsistency

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Consistency")
                        .font(.byow.title3)
                        .foregroundStyle(Color.inkPrimary)
                    Text("Days hit · last \(consistency.total) days")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                streakBadge
            }

            HStack(spacing: Spacing.sm) {
                MacroBadge(
                    label: "Protein",
                    hits: consistency.proteinHits,
                    total: consistency.total,
                    tint: .byowOrange
                )
                MacroBadge(
                    label: "Carbs",
                    hits: consistency.carbsHits,
                    total: consistency.total,
                    tint: .byowTeal
                )
                MacroBadge(
                    label: "Fat",
                    hits: consistency.fatHits,
                    total: consistency.total,
                    tint: .inkSecondary
                )
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.byowOrange)
            Text("\(consistency.bestStreak)d streak")
                .font(.byow.caption.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, Spacing.xs)
        .background(Color.byowOrangeTint.opacity(0.55), in: Capsule())
    }
}

private struct MacroBadge: View {
    let label: String
    let hits: Int
    let total: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                MacroRing(progress: Double(hits) / max(Double(total), 1), lineWidth: 6, tint: tint)
                    .frame(width: 56, height: 56)
                Text("\(hits)/\(total)")
                    .font(.byow.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.inkPrimary)
            }
            Text(label.uppercased())
                .font(.byow.label)
                .tracking(1.0)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MacroConsistencyCard(consistency: MacroConsistency(proteinHits: 5, carbsHits: 4, fatHits: 6, total: 7, bestStreak: 9))
        .padding()
        .background(Color.byowBackground)
}
