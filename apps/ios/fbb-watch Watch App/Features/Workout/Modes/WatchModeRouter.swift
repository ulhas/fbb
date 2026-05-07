import SwiftUI
import FBBDesignSystem
import FBBWorkoutKitCore

/// Picks the right Set page for whichever group the cursor sits in. The
/// engine's `activeBlock` tells us the prescription mode; we render the
/// matching specialised card. `.none` (straight_sets, rounds, free) falls
/// through to `WatchSetCard` — the user-paced "log reps + weight" flow.
struct WatchModeRouter: View {
    let session: WorkoutSession

    var body: some View {
        // Optional<ActiveBlock>'s .none collides with ActiveBlock.none(GroupId);
        // unwrap first so the inner switch is unambiguous.
        if let block = session.activeBlock {
            switch block {
            case .none:
                // straight_sets / rounds / free — user-paced.
                WatchSetCard(session: session)

            case .interval(let state):
                WatchEmomCard(session: session, state: state)

            case .capCountdown(let state):
                // amrap | for_time | density. Differ on whether reps or finish
                // matters; route on the prescription mode of the current group.
                let mode = CursorAdvance.currentGroup(session.cursor, in: session.day)?.prescriptionMode ?? "amrap"
                switch mode {
                case "for_time":
                    WatchForTimeCard(session: session, state: state)
                default:
                    // amrap, density, and any unexpected cap-style mode.
                    WatchAmrapCard(session: session, state: state)
                }

            case .tabata(let state):
                WatchTabataCard(session: session, state: state)

            case .pyramid(let state):
                WatchPyramidCard(session: session, state: state)

            case .stopwatch(let state):
                WatchStopwatchCard(session: session, state: state)
            }
        } else {
            // Brief moment between a group change and the engine rebuilding
            // the block — fall through to the user-paced card.
            WatchSetCard(session: session)
        }
    }
}
