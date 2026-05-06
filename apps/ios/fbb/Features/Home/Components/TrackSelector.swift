import SwiftUI

struct TrackSelector: View {
    let tracks: [TrainingWeekTrackIndexRow]
    let selectedTrackCode: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    ForEach(tracks) { track in
                        TrackChip(
                            track: track,
                            isSelected: track.trackCode == selectedTrackCode,
                            onTap: { onSelect(track.trackCode) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.xxs)
        }
    }
}
