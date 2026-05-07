import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}
