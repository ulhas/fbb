import SwiftUI

struct MacroHeroCard: View {
    let target: MacroTarget
    let logged: MacroTotals
    let coachLine: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Calorie ring + center stack
            ZStack {
                MacroRing(
                    progress: caloriesProgress,
                    lineWidth: 14,
                    tint: caloriesTint
                )
                .frame(width: 180, height: 180)

                VStack(spacing: 2) {
                    Text(remainingLabel.uppercased())
                        .font(.fbb.label)
                        .tracking(1.2)
                        .foregroundStyle(Color.inkSecondary)

                    Text(remainingValue)
                        .font(.fbb.metricHero)
                        .foregroundStyle(remainingTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("of \(formatted(target.kcal)) kcal")
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.top, Spacing.sm)

            // Macro mini-rings
            HStack(spacing: Spacing.lg) {
                MiniMacro(
                    label: "Protein",
                    logged: logged.proteinG,
                    target: target.proteinG,
                    tint: .fbbOrange,
                    isPriority: true
                )
                MiniMacro(
                    label: "Carbs",
                    logged: logged.carbsG,
                    target: target.carbsG,
                    tint: .fbbTeal
                )
                MiniMacro(
                    label: "Fat",
                    logged: logged.fatG,
                    target: target.fatG,
                    tint: .inkSecondary
                )
            }
            .padding(.horizontal, Spacing.md)

            // Coach context strip
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.fbbTeal)
                Text(coachLine)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fbbTealTint.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.fbbOrangeTint.opacity(0.32),
                        Color.fbbTealTint.opacity(0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [Color.surfaceCard.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
        )
        .elevation(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(remainingValue) \(remainingLabel) of \(target.kcal) kcal. Protein \(logged.proteinG) of \(target.proteinG) grams. Carbs \(logged.carbsG) of \(target.carbsG) grams. Fat \(logged.fatG) of \(target.fatG) grams. \(coachLine)")
    }

    // MARK: Calories logic

    private var caloriesProgress: Double {
        Double(logged.kcal) / max(Double(target.kcal), 1)
    }

    private var caloriesTint: Color {
        if logged.kcal > target.kcal { return .semanticWarning }
        if Double(logged.kcal) > Double(target.kcal) * 0.95 { return .semanticSuccess }
        return .fbbOrange
    }

    private var remainingValue: String {
        let diff = target.kcal - logged.kcal
        if diff < 0 { return formatted(-diff) }
        return formatted(diff)
    }

    private var remainingLabel: String {
        target.kcal - logged.kcal < 0 ? "Over by" : "Remaining"
    }

    private var remainingTint: Color {
        target.kcal - logged.kcal < 0 ? .semanticWarning : .inkPrimary
    }

    private func formatted(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - Mini macro ring

private struct MiniMacro: View {
    let label: String
    let logged: Int
    let target: Int
    let tint: Color
    var isPriority: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                MacroRing(
                    progress: Double(logged) / max(Double(target), 1),
                    lineWidth: isPriority ? 7 : 5,
                    tint: tint
                )
                .frame(width: 60, height: 60)
                Text("\(logged)")
                    .font(.fbb.metric)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            VStack(spacing: 0) {
                Text(label.uppercased())
                    .font(.fbb.label)
                    .tracking(1.0)
                    .foregroundStyle(Color.inkSecondary)
                Text("of \(target)g")
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkMuted)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MacroHeroCard(
        target: MacroTarget(kcal: 2_450, proteinG: 180, carbsG: 280, fatG: 78),
        logged: MacroTotals(kcal: 1_638, proteinG: 121, carbsG: 165, fatG: 51),
        coachLine: "Lower strength day · push protein to 200 g and front-load carbs pre-workout."
    )
    .padding()
    .background(Color.fbbBackground)
}
