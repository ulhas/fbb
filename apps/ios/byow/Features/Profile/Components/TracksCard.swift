import SwiftUI

struct TracksCard: View {
    let selectedTrackCodes: [String]
    let onEdit: () -> Void

    private static let allTracks: [(code: String, name: String, family: TrackFamily)] = [
        ("pump_lift_4x",      "Pump Lift 4x",       .pumpLift),
        ("pump_condition_4x", "Pump Condition 4x",  .pumpCondition),
        ("perform_5x",        "Perform 5x",         .perform),
        ("minimalist_3x",     "Minimalist 3x",      .minimalist),
        ("hybrid_running_4x", "Hybrid Running 4x",  .hybridRunning),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My tracks")
                        .font(.byow.title3)
                        .foregroundStyle(Color.inkPrimary)
                    Text("\(selectedTrackCodes.count) of \(Self.allTracks.count) enrolled")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.byow.caption.weight(.semibold))
                        .foregroundStyle(Color.byowOrange)
                }
                .buttonStyle(.plain)
            }

            if selectedTrackCodes.isEmpty {
                Text("Tap Edit to enroll in your first track.")
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                    .elevation(.card)
            } else {
                VStack(spacing: 6) {
                    ForEach(selectedTrackInfo, id: \.code) { track in
                        TrackRow(name: track.name, family: track.family)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
                .elevation(.card)
            }
        }
    }

    private var selectedTrackInfo: [(code: String, name: String, family: TrackFamily)] {
        selectedTrackCodes.compactMap { code in
            Self.allTracks.first(where: { $0.code == code })
        }
    }
}

private struct TrackRow: View {
    let name: String
    let family: TrackFamily

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: familySymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.byowOrange)
                .frame(width: 32, height: 32)
                .background(Color.byowOrangeTint.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(family.displayLabel)
                    .font(.byow.label).tracking(0.8)
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.byowOrange)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var familySymbol: String {
        switch family {
        case .pumpLift:        return "dumbbell.fill"
        case .pumpCondition:   return "wind"
        case .perform:         return "flame.fill"
        case .minimalist:      return "circle.dashed"
        case .hybridRunning:   return "figure.run"
        case .workshop:        return "wrench.and.screwdriver.fill"
        case .onramp:          return "arrow.up.right"
        }
    }
}

// MARK: - Edit sheet

struct EditTracksSheet: View {
    let selectedCodes: [String]
    let onToggle: (String) -> Void
    let onDone: () -> Void

    private static let allTracks: [(code: String, name: String, family: TrackFamily, blurb: String)] = [
        ("pump_lift_4x",      "Pump Lift 4x",       .pumpLift,        "Strength + hypertrophy. 4 days a week."),
        ("pump_condition_4x", "Pump Condition 4x",  .pumpCondition,   "Conditioning-led strength. 4 days a week."),
        ("perform_5x",        "Perform 5x",         .perform,         "Max performance. 5 high-volume days."),
        ("minimalist_3x",     "Minimalist 3x",      .minimalist,      "3 days, full-body. For busy weeks."),
        ("hybrid_running_4x", "Hybrid Running 4x",  .hybridRunning,   "Run + lift. Built for hybrid athletes."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(Self.allTracks, id: \.code) { track in
                        TrackPickerRow(
                            track: track,
                            isSelected: selectedCodes.contains(track.code),
                            onToggle: { onToggle(track.code) }
                        )
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.byowBackground.ignoresSafeArea())
            .navigationTitle("My tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.byowOrange)
                }
            }
        }
    }
}

private struct TrackPickerRow: View {
    let track: (code: String, name: String, family: TrackFamily, blurb: String)
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                Image(systemName: familySymbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : Color.byowOrange)
                    .frame(width: 40, height: 40)
                    .background(
                        isSelected ? Color.byowOrange : Color.byowOrangeTint.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                    Text(track.blurb)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? Color.byowOrange : Color.inkMuted)
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCorner)
                    .strokeBorder(isSelected ? Color.byowOrange.opacity(0.5) : .clear, lineWidth: 1.4)
            )
            .elevation(.card)
        }
        .buttonStyle(.plain)
    }

    private var familySymbol: String {
        switch track.family {
        case .pumpLift:        return "dumbbell.fill"
        case .pumpCondition:   return "wind"
        case .perform:         return "flame.fill"
        case .minimalist:      return "circle.dashed"
        case .hybridRunning:   return "figure.run"
        case .workshop:        return "wrench.and.screwdriver.fill"
        case .onramp:          return "arrow.up.right"
        }
    }
}

#Preview {
    TracksCard(
        selectedTrackCodes: ["pump_lift_4x", "perform_5x"],
        onEdit: {}
    )
    .padding()
    .background(Color.byowBackground)
}
