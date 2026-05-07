# Live Activity — Xcode setup steps

The Swift sources for the Workout Live Activity have been written, but
several pieces of Xcode project state can only be configured safely from
inside Xcode. Walk through these once on this machine before running on
device.

## 1. Add new files to the **fbb** (iOS app) target

In Xcode → Project navigator, right-click the `fbb` group → **Add Files to "fbb"…**
and add (with target membership = `fbb` only, unless noted):

- `fbb/Features/Workout/LiveActivity/WorkoutActivityAttributes.swift` — **also** check `fbbWorkoutWidget` once that target exists (step 4).
- `fbb/Features/Workout/LiveActivity/WorkoutLiveActivityController.swift`
- `fbb/Features/Workout/LiveActivity/LiveActivityBridge.swift`
- `fbb/Features/Workout/LiveActivity/QuickLogService.swift`
- `fbb/Sync/LiveActivityRelayReceiver.swift`

## 2. Add new files to the **fbb-watch Watch App** target

- `fbb-watch Watch App/Sync/WatchActivityRelaySender.swift`

## 3. Add new files to the package (auto-detected — no Xcode action needed)

These live under `Packages/FBBWorkoutKit/Sources/FBBWorkoutKitCore` and SPM picks them up automatically:

- `Session/CursorDescriptors.swift`
- `Sync/WatchActivityRelay.swift`

(Already builds clean — verified with `swift build`.)

## 4. Create the Widget Extension target

**File → New → Target… → Widget Extension**

- Product Name: `fbbWorkoutWidget`
- Bundle Identifier: `com.functional-bodybuilding.fbb.workoutWidget`
- Include Live Activity: **ON**
- Include Configuration App Intent: **OFF**
- Embed in: `fbb`

After Xcode generates the target, **delete** its scaffold files (`fbbWorkoutWidget.swift`, `fbbWorkoutWidgetLiveActivity.swift`, etc.). Then add to the new target:

- `fbbWorkoutWidget/fbbWorkoutWidgetBundle.swift` (replaces the `@main` Xcode generated)
- `fbbWorkoutWidget/WorkoutLiveActivity.swift`
- `fbbWorkoutWidget/Views/WorkoutLockScreenView.swift`
- `fbbWorkoutWidget/Views/DynamicIslandRegions.swift`
- `fbbWorkoutWidget/Intents/PauseWorkoutIntent.swift`
- `fbbWorkoutWidget/Intents/LogSetIntent.swift`

Also add `WorkoutActivityAttributes.swift` (from step 1) to the extension's target membership — both targets share the type.

Then:

- **Target → Signing & Capabilities → +Capability → App Groups**
  Add `group.com.functional-bodybuilding.fbb` (matches the iOS + watch entitlements already in place).
- **Build Settings → Deployment** → set iOS deployment to **17.0** (LiveActivityIntent buttons require iOS 17).
- **Code Signing Entitlements**: point to `fbbWorkoutWidget/fbbWorkoutWidget.entitlements` (already on disk).
- **Info.plist**: leave Xcode's auto-generated; the `Info.plist` skeleton on disk under `fbbWorkoutWidget/` is provided as a reference and isn't consumed unless you wire `INFOPLIST_FILE` to it.
- The widget extension does **not** need to link `FBBWorkoutKitCore`. Keep it light — it depends only on `ActivityKit`, `WidgetKit`, `SwiftUI`, `AppIntents`.

## 5. Build settings already changed in pbxproj

`INFOPLIST_KEY_NSSupportsLiveActivities = YES` was added to both Debug and Release configs of the `fbb` target. No further action needed there.

## 6. Verify on a device or simulator

1. Run the iOS app on iPhone 15/16 Pro simulator (Dynamic Island) on iOS 17+.
2. Start a workout from the iPhone home → Lock the simulator (⌘L) → confirm the activity card appears with the elapsed timer ticking and current exercise visible.
3. Tap **Pause** on Lock Screen → timer freezes. Tap **Resume** → timer resumes.
4. Tap **Log Set** → returning to the app, the cursor has advanced and the prescribed reps were logged with the most-recent exercise weight.
5. Pair a watch simulator. Start a workout *from the watch*. Confirm the activity appears on the iPhone Lock Screen within a couple seconds (transferred via WatchConnectivity).
6. Watch's Smart Stack (watchOS 10+) auto-syndicates the iPhone activity — verify by swiping up on the watch home screen.
7. Toggle Settings → fbb → Live Activities OFF, re-run start: app silently no-ops, workout still functions.

## Open implementation decisions

- "Log Set" defaults: currently uses `repsMax ?? repsMin` and the most-recent weight logged for that exercise. Sanity-check against a few real prescriptions before shipping.
- iPhone-→-watch intent dispatch round-trip is wired (`WatchActivityRelay.intentDispatch`) but only takes effect when the watch app is reachable. If the user pauses from the iPhone Lock Screen while the watch app is backgrounded, the watch session won't receive it — the iPhone activity will visibly flip but the watch may briefly disagree until the next observation tick rebuilds the snapshot.
