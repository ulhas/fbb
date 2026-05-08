import SwiftUI

/// Live training surface. Sticky section headers (table-view style)
/// stay pinned at the top of the scroll viewport so the user always
/// knows what section they're in. The bottom playback bar moved to the
/// global TabView accessory — there is no in-screen footer here.
struct RunningView: View {
    let session: WorkoutSession
    let trackDisplayName: String
    let onEnd: () -> Void   // retained for parent compatibility; no longer rendered here

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: Spacing.lg,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    headerStrip
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                }

                ForEach(workoutSections) { section in
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(section.groups) { group in
                                GroupRunningCard(
                                    section: section,
                                    group: group,
                                    session: session
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.md)
                    } header: {
                        sectionHeader(section: section)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.byowBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(trackDisplayName)
        .animation(.snappy, value: session.cursor)
    }

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Spacing.xs) {
                Text(session.day.displayName)
                    .font(.byow.title2)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                    Text(SessionMath.formatElapsed(session.totalElapsedSeconds(now: ctx.date)))
                        .font(.byow.metric)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkPrimary)
                }
            }
            Text("Section \(currentSectionPosition) of \(workoutSections.count)")
                .font(.byow.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func sectionHeader(section: ParsedSection) -> some View {
        // Sticky pinned header. Solid background + bottom hairline so
        // scrolling content doesn't bleed through visually.
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(section.displayName.uppercased())
                .font(.byow.label).tracking(0.8)
                .foregroundStyle(Color.byowOrange)
            if let mins = section.targetDurationMax ?? section.targetDurationMin {
                Text("· \(mins) min")
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
            if isCompletedSection(section) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.byowTeal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            Color.byowBackground
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.inkMuted.opacity(0.15))
                        .frame(height: 1)
                }
        )
    }

    private var workoutSections: [ParsedSection] {
        session.day.sections.filter { $0.kind != "focus_note" && $0.kind != "lesson" }
    }

    private var currentSectionPosition: Int {
        let pos = workoutSections.firstIndex(where: { $0.position == session.cursor.sectionPosition }) ?? 0
        return pos + 1
    }

    private func isCompletedSection(_ section: ParsedSection) -> Bool {
        let allSets = section.groups.flatMap(\.exercises).flatMap(\.sets)
        guard !allSets.isEmpty else { return false }
        let logged = Set(
            session.setLog
                .filter { $0.outcome != .skipped }
                .map { $0.setId }
        )
        return section.groups.allSatisfy { group in
            group.exercises.allSatisfy { ex in
                ex.sets.allSatisfy { s in
                    logged.contains(SetId(
                        section: section.position,
                        group: group.position,
                        exercise: ex.position,
                        set: s.position
                    ))
                }
            }
        }
    }
}
