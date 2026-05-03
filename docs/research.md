# Rebuilding FBB native: a strategic teardown

**Marcus Filly's Functional Bodybuilding app is a beloved program trapped in a 2.5-star white-label shell, and a native rebuild is both necessary and high-leverage.** The current iOS app sits at **2.5★ across 88 ratings** and Google Play at **2.7★** — yet the harshest reviewers still write "I love Marcus and the programming itself" and "Love the workouts, hate this app." The app is a hybrid web wrapper produced by **AppRabbit** (legal entity Iversen International, LLC), confirmed by the privacy-policy domain `app.apprabbit.com/privacyPolicy/fbb` baked into the App Store listing, the developer-of-record being Marcus's Director of Operations Cliff Kohut, and the auto-generated Android package ID `com.dllpl4533boop2h0bsk2sa.app`. Marcus's own status page openly acknowledges "**network issues leading to lag and errors saving data**" as the team's April 2026 top priority. A ground-up native rebuild — Swift/SwiftUI + Kotlin/Compose, offline-first SQLite via PowerSync, Sanity CMS, native Apple Watch and Wear OS, and a Hevy-grade set logger — would convert one of fitness's strongest programs into one of its strongest apps.

This report integrates user reviews, the team's own bug log, AppRabbit platform analysis, deep competitive benchmarking against Hevy, Strong, TrainHeroic, Fitbod, Future, Centr, Caroline Girvan, Caliber, MacroFactor, and a technical blueprint for the rebuild covering architecture, sync, video, programming primitives, Apple Watch, and modern AI features.

---

## What's actually shipping today

The current Functional Bodybuilding app launched in **late 2024 / early 2025** to replace the prior delivery on RPM Training's **Atom platform** (`trainatom.com`, a JavaScript SPA) and TrueCoach before that. The new branded app is built on **AppRabbit**, a white-label fitness-coaching app builder founded in 2019 (originally Gameplan Apps) by Matthew Iversen and Cory Swainston in Rexburg, Idaho. AppRabbit's CTO previously worked on mobile at SoFi; the platform produces dozens of similarly templated coach-branded apps including SUPRĀ Training (Ross Edgley), Strength Side, Vegan Proteins, Hypuro Fit, and many others — all sharing the same backend at `app.apprabbit.com` and the same telltale randomly-generated package IDs.

**The architecture is almost certainly Capacitor/Ionic hybrid** (~70% confidence), with React Native a possibility (~25%) and pure native essentially ruled out. The signals: a single shared codebase delivered as iOS + Android + web, multi-tenant template provisioning with random bundle IDs, Mac Catalyst and visionOS support inheriting automatically (a Capacitor tell), the Atom predecessor was already a JavaScript SPA, and the symptom pattern of user complaints — "step backward from the old web version," "feels unfinished," login fragmentation between web and app, video playback wiping local state — is the canonical signature of a webview-wrapped app. Backend-of-record is Cloudflare in front of `app.apprabbit.com`; payments via Stripe; storefront on Shopify at `functional-bodybuilding.com`; support via Intercom; bug intake via JotForm.

Version **2.131.893** in the user's screenshots sits one build ahead of the 2.130.867 listed as "in review" on the public status page on 4/3/26 — consistent with the team's stated cadence of "expect more frequent updates until performance is stable."

## The good, the bad, and the ugly

### What works (the good)

**Marcus's programming reputation is intact and possibly growing.** Even one-star reviewers explicitly carve out praise for the workouts: "The fitness programming is great. I did CrossFit for years but a recent job change... this is perfect. It has everything you need and great options and modifications for everything too." Garage Gym Reviews calls Persist "exceptional programming for folks looking to improve mobility and increase muscle mass at the same time." TikTok carries strong organic positive sentiment for Persist tracks like PUMP 40 — none of it about the app, all about the programming.

**The app's ambition is appreciated.** A representative 5-star reviewer: "I LOVE the app layout and the features/functions they've created for tracking." Users credit the FBB team for visibly shipping fixes weekly and running a public status page — rare transparency in the category. Some users do prefer the new app to bookmarking the old web page.

**The track-quiz / equipment-profile / workshop ecosystem is a genuine differentiator.** No competitor matches the combination of structured year-long Persist tracks (PUMP LIFT, PUMP CONDITION, PERFORM, MINIMALIST, Hybrid Running) plus opt-in Workshops (PUMP 40, AEROBIC 40, CARDIO 30/30, FBB 101) plus a quiz-based onboarding plus a separate mobility library curated by Dr. Adam Fetter. TrainHeroic has the architecture but not the brand; Centr has the brand but a thinner program library; Hybrid Athletic has hybrid-running but not the hypertrophy depth.

### What annoys users (the bad)

**"Too many clicks to see the day."** The single most-cited UX complaint, captured perfectly by reviewer Mary Klem (9/3/2025): "I miss using the browser version, which was simple and easy to see your training day in one scroll. There are entirely too many clicks just to see the run down of each movement/section. Why are we trying to navigate inside individual movements right off the bat? I dread using the app each training session." This is webview-architecture taxation manifesting as UX.

**The built-in timer is "pathetically small and worthless on the screen."** A workout app whose timer is broken is structurally broken; this should be unfixable in the current codebase without rewriting the in-workout view.

**The history view is weak.** "There's no simple way to see past weights, which makes tracking progress unnecessarily hard." The team shipped a "History View" in February 2026 (2.126.805), but the deeper need — previous-set values overlaid on the current set during logging, à la Hevy and Strong — appears not to be addressed.

**Login fragmentation between web account and app account.** Multiple users describe needing to log in twice to reach all content, and a separate signup-flow nightmare for new subscribers ("Confirmation email was supposed to include temporary password, but was completely neglected after taking my credit card number").

**No Apple Watch app, no Wear OS app, no offline mode.** FBB tells users they will receive "a weekly PDF of training if you need to work out away from online access" — confirming the app does not gracefully handle gym basements, airplane mode, or flaky locker-room Wi-Fi. Apple Health integration was added Jan 22, 2026; Google Health Connect on Android arrived only in 2.128 on Mar 9, 2026 — table-stakes capabilities shipping years late.

**No leaderboards, no streaks UX, no social cheers, no per-track community.** TrainHeroic, SugarWOD, Ladder, and Peloton have all proven these are top retention drivers; FBB has only a Facebook group and an Atom-era community board.

### What's actually broken (the ugly)

The status page (functional-bodybuilding.com/pages/status) is unintentionally a damning artifact. It currently lists or recently listed:

- **"Bench press data loss — fix not available, log a new PR or new data going forward"** (12/13/25). For a strength app, telling users their bench history is gone is category-defining.
- **"Nutrition tracking bug with amounts — escalated to developers, gathering more data currently"** — grams miscalculating to wrong calorie totals.
- **Workout data loss when logging supersets** (fixed Sept 2025 in 2.109.719, again in 2.112.722).
- **Helper text in supersets/strength sections "causes an error when trying to save. Version is currently being rolled back"** (12/12/25).
- **Apple Health metrics not aggregating correctly** (fixed Feb 3, 2026).
- **Loss of warm-up set and rep counts in history** (fixed 1/9/26).
- **Workouts auto-completing only if exercises were done in order** (fixed 3/9/26).
- **"Network errors / lag saving data"** as the explicit current top priority (April 2026).

The single most damning user quote, from iOS reviewer Josh Witham (8/23/2025): "**Not fit for purpose. Regularly crashes... Actually worse than pen and paper.**" And from another: "**Playing a video completely wipes rep scheme, manual rep entry barely works, and workouts don't sync correctly across touch points.**" These are not surface bugs — they are the fingerprint of a hybrid framework where view-state lives in JavaScript memory that gets blown away by lifecycle events the wrapper doesn't handle. They will not be fully fixable inside AppRabbit's template.

## A complete inventory of what FBB does today

The current app comprises roughly twelve feature surfaces, drawn from the screenshots and the FBB website:

**Programs and tracks.** Persist subscription delivers four ongoing tracks — PUMP LIFT (3x/4x/5x), PUMP CONDITION (3x/4x/5x), PERFORM (5 days, athletic/Olympic/gymnastic), MINIMALIST (4 days, DBs + bench + pull-up bar). Plus FBB 101 (8-workout on-ramp), Hybrid Running, Workshops (2–12 wk specialty: PUMP 40, AEROBIC 40, CARDIO 30/30, etc.). Programs run on a **year-long architecture of four 12-week mesocycles, each made of two 6-week blocks, separated by a "Bridge Week" deload**. The Mar 22–Jun 20 window in the user's screenshot is exactly one such mesocycle. New users choose "Jump In Today" (current week of the rolling cycle) or "Start from Beginning" (week 1 of the latest block), and pick their equipment profile (Limited vs Varied).

**Movement Library and Mobility Library.** Demo video catalog plus separate mobility flows curated by Dr. Adam Fetter for active-recovery days.

**Track Quiz / Find Your Match.** Recommends a starting track based on goals, schedule, and equipment — a strong onboarding tool that competitors largely lack.

**Fitness Audit.** Self-scored baseline assessment (cited in the dashboard "Get your score" tile).

**Nutrition tracking.** Calorie target (2,922 in screenshots), protein/carbs/fat/fiber goals, meal logging with Recent/Saved/Search foods, recipes, "Save Meal" templates. Daily breakfast/lunch/dinner/snack structure.

**Habits tracker.** Get-started CTA implies a basic boolean-per-day habit system.

**Progress tracking.** Weight and steps charts, custom "Add Chart" capability, PRs, photos, calendar strip. Apple Health steps in/out (Jan 2026); Google Health Connect on Android (Mar 2026).

**Workshops, Coaching content, and the "Look Good Move Well" podcast** integrated via the dashboard.

**Settings.** Profile, account, language (English only), password, privacy policy, EULA, logout, version display.

What FBB **does not** have today: an Apple Watch app, a Wear OS app, offline workout logging, video pre-download, leaderboards, social feed/cheers, automated progressive overload, voice logging, AI form check, exercise-substitution intelligence (only a pre-set "alternates" list per movement), barcode food scanning, AI photo nutrition logging, adaptive macros, recovery-aware programming (HRV/sleep), Whoop/Oura/Garmin integration, Live Activities/Dynamic Island, App Intents/Siri Shortcuts, widgets, multi-language support, accessibility features beyond OS defaults.

## How FBB stacks up against the field

Modern fitness apps split into three archetypes, and FBB straddles all three uncomfortably:

| Dimension | FBB today | Hevy (logger king) | Strong (logger king v2) | TrainHeroic (coach king) | Centr (lifestyle king) | Future (premium 1:1) | Caroline Girvan CGX (video-led) | Fitbod (smart algo) | MacroFactor (nutrition king) |
|---|---|---|---|---|---|---|---|---|---|
| Set logger speed | Slow, multi-tap | One-tap, prev-overlay | One-tap, plate calc | Coach-prescribed | Video-led | Coach voice cues | Video follow-along | Auto-generated | n/a |
| Native vs hybrid | **AppRabbit hybrid** | RN | **Native Swift+Kotlin** | RN-ish hybrid | Native | Native | Hybrid | Native | Native |
| Apple Watch | **None** | Live sync, custom faces | Best-in-class standalone | None | Yes | Excellent (1-tap advance) | None | Yes | n/a |
| Offline workouts | **None** (PDF fallback) | Yes | **Best (offline-first)** | Limited | Limited | Limited | YouTube | Limited | Logging works offline |
| Auto progression | None | Hevy Trainer (paid) | Manual | Coach-driven | Manual | Coach-driven | Manual | **Best-in-class** | n/a |
| Substitution UX | Pre-listed alternates | Manual swap | Manual swap | Coach-dependent | Filter | Coach swaps | None | **Smart Replace algo** | n/a |
| Workout timers | Tiny built-in only | Auto rest timer | Best rest timer | **7 timers (EMOM/AMRAP/etc.)** | Built into video | Coach voice | Beep cues | Standard | n/a |
| Nutrition | Basic logging | None | None | None | Meal plans | General guidance | None | None | **Verified DB, barcode, AI photo, voice describe, adaptive macros** |
| Social/community | Facebook group | Strong: feed, leaderboards | None | Leaderboards per Team | Facebook group | Coach 1:1 | YouTube | None | None |
| Pricing | ~$29/mo | Free or $5.99/mo Pro | Free or $4.99/mo Pro | Athlete free + coach fees | $30/mo | $149–199/mo | ~$29/mo | ~$13/mo | ~$12/mo |
| App Store rating | **2.5★** | 4.9★ | 4.8★ | 4.5★ | 4.6★ | 4.8★ | 4.6★ | 4.6★ | 4.9★ |

**The competitive read:** FBB is the only app that combines structured year-long coach-led programming with on-platform nutrition tracking and a mobility library. That positioning is genuinely defensible. But the execution layer — set logging, timers, watch, offline, social — is below every benchmark, and the gap is wide enough that users who try Persist's programming via the app churn back to "Atom was far better" or "Hevy + a coach PDF."

## The architecture decision: native, fully

**Recommendation: build two fully native codebases — Swift 6 + SwiftUI on iOS 17+, Kotlin 2.x + Jetpack Compose on Android — backed by a shared Node.js (or Go) API plus PostgreSQL.** Reject React Native and reject any further hybrid framework. The reasoning is specific to FBB:

The performance complaints in v1 come from JavaScript/webview cost on a video-heavy, network-dependent app, and the brand wound is now public. Doubling down on JS-bridge architecture (RN) would risk a repeat — and Hevy itself, the gold standard set logger, is regularly criticized in comparison reviews for "doesn't feel native on Android" precisely because it's RN, while Strong's native Kotlin codebase is the praised counter-example. SwiftUI is now mandatory for the iOS surfaces FBB most needs (Live Activities via ActivityKit, Home Screen widgets via WidgetKit, Apple Watch via WorkoutKit, App Intents/Siri Shortcuts, Dynamic Island) — none of these have UIKit equivalents. Compose for Wear OS is the only modern path on Android wearables. And FBB's planned Apple Watch + Wear OS surface is itself a competitive imperative.

If the engineering team is small (one to two engineers across both platforms), a credible alternative is **Kotlin Multiplatform Mobile (KMM/KMP)** for the data, sync, and programming-engine layers, with native SwiftUI + Compose UI on top — used in production by McDonald's, Cash App, Netflix Prodicle, Forbes, Philips, Duolingo, Careem. That keeps the complex periodization/RPE/substitution logic in one codebase but preserves native UX.

For local data, use **GRDB on iOS** and **Room (or SQLDelight if KMP) on Android** over SQLite. These give type-safe SQL, reactive observation (Flow/Combine), and SQLCipher encryption. Avoid Realm — MongoDB removed Atlas Device Sync in September 2025, which deletes the only reason to choose it. Avoid Core Data — opaque to migrate to a custom sync engine.

For sync, pick **PowerSync**. It is the most mature mobile-native local-first sync engine in 2026, with first-class Swift and Kotlin SDKs, bidirectional sync via Sync Rules over PostgreSQL, and a model that maps cleanly to FBB's domain (one bucket per program subscription, one per user history, one read-only bucket for the shared movement library). ElectricSQL is Postgres-read-only and you'd rebuild the write path; Replicache/Zero are web-only; Triplit and Convex don't have production-grade native mobile coverage; Firestore charges painfully on read-heavy access patterns; CRDTs (Y.js, Automerge) are overkill for single-author workout logs. Only **Couchbase Lite + Capella App Services** is a credible alternative — heavier ops, but bundles peer-to-peer sync and vector search if the team wants edge-AI movement search out of the box.

For content management, use **Sanity** as the headless CMS. Workout programs are deeply nested structured content (program → mesocycle → microcycle → day → block → exercise → prescribed sets/reps/RPE/tempo) — exactly Sanity's GROQ/Portable Text sweet spot. The Movement Library is a flat collection with rich relations (substitutions, equipment tags, video references). FBB's content team will live in Sanity Studio daily, and Studio's real-time multiplayer editing supports a coaching team working on next quarter's mesocycle in parallel. Webhook content writes to Postgres mirror tables that PowerSync delivers to clients, so end-users get content updates inside their offline-first SQLite without bespoke sync code.

For video, use **Bunny Stream** (cheapest at scale, sufficient SDK coverage) or **Mux** (best DX and Mux Data QoE analytics) for HLS adaptive streaming. Many B2C fitness apps land on Mux for the developer experience and migrate to Bunny when monthly delivery costs cross ~$10K. On the client, use **`AVAssetDownloadURLSession` + `AVAssetDownloadTask` on iOS** (background-capable, persists `.movpkg` bundles) and **AndroidX Media3 `DownloadManager`** on Android. The download UX should mirror Netflix: per-program "Download all 47 demos (1.2 GB)?" plus per-session just-in-time prefetch the night before via `BGAppRefreshTask` / WorkManager when on Wi-Fi and charging, plus a Settings → Manage Downloads with per-program disk usage and LRU eviction.

For auth and payments, use **Sign in with Apple + Google Sign-In + email magic link**, with **RevenueCat** managing subscription receipts across both stores. This also fixes the v1 "login twice between web and app" complaint by making the auth surface single and federated.

## The workout execution flow, in detail

This is the highest-leverage rebuild surface. FBB's programming language is unusually rich — it includes tempo notation (e.g., 30X1: 3-second eccentric, 0 pause, X-explosive concentric, 1-second pause), per-set RPE prescriptions, percent-of-1RM blocks, AMRAP, EMOM and E2MOM/E3MOM, supersets, contrast pairs, pre-fatigue pairs, drop sets, back-off AMRAPs, Olympic lifting complexes (e.g., "1 hang power snatch + 2 hang snatch + 1 OHS"), unilateral L/R ordering with separate rest, time-cap For Time, custom intervals like "Every 7 min × 5 sets, ABCDE in varying order," and per-side cooldown stretches. **No competitor's logger handles all of these gracefully.** TrainHeroic is closest with its seven dedicated workout timers (Rest, Stopwatch, AMRAP, For Time, Tabata, Custom Interval, EMOM); Hevy is the speed king for standard sets but lacks the timer modes; Strong is the offline king but lacks RPE-prescribed AMRAP back-off; Fitbod is the substitution king but lacks RPE altogether.

The rebuilt session should be a **single-scroll, block-aware logger** — not a multi-tap drill-in. The information architecture borrows the best from each benchmark:

When the user taps Start Workout, a 15–30 second voice-recorded coach note from Marcus plays (Future pattern), followed by a TrainHeroic-style 5-question readiness survey (Sleep / Energy / Soreness / Mood / Stress, skippable, feeds into the coach dashboard for compliance). The session view then opens as a single scroll with all blocks visible — Warmup, Pre-Fatigue, Strength Intensity, Strength Balance, Conditioning, Cooldown — current block expanded, others collapsed but tappable.

Each set row borrows from Hevy and Strong: previous-session values overlaid to the left ("Prev: 135×8 RPE 8"), a tappable weight field that opens a plate calculator, a reps field, an RPE picker chip, a tempo chip displaying "30X1" with a tap-to-explain modal and an optional metronome that clicks at the prescribed cadence through earbuds. The checkmark auto-starts the rest timer at the prescribed duration, with ±15s chips, a Live Activity / Dynamic Island display, and an Apple Watch haptic at T-10s and T-0.

Demo videos pin in a top-right floating mini-player (Apple Fitness+ pattern) that does **not** lose log state when expanded or closed — the explicit fix to v1's "playing a video wipes rep scheme" disaster. Hevy's Smart Superset Scrolling auto-jumps from set 1 of A to set 1 of B on check-off, with the rest timer firing only after the round closes.

**The blocks need mode switches**, because a session can move through six different timer paradigms in one workout. Standard sets render as set rows. Supersets render as grouped cards with smart scroll. EMOM blocks ("Every 90s × 8 sets") swap in a top-pinned EMOM clock with a per-minute log button. AMRAP blocks render an AMRAP countdown with a "+ Round" tally and optional rep counter. For Time blocks render a stopwatch plus a checklist of the rep scheme (21-15-9). Custom intervals like "Every 7 min × 5 sets, ABCDE varying" render a Custom Interval timer with a movement-order matrix. Olympic complexes log as a single set with one load and one quality slider. Cooldown stretches use a side-flip timer that haptics on switch L→R.

Substitution should be **Fitbod-grade**: long-press an exercise → "Show alternatives" → modal lists alternates filtered by three chips (Same equipment / Limited equipment / Bodyweight), each annotated with why it matches (same primary muscle, same plane, same joint pattern), with a "remember this swap for the rest of the cycle" option. The exercise database is keyed by a movement taxonomy graph: every movement tagged by primary muscle, secondary muscle, equipment, plane, joint pattern; substitution is a vector-distance query on that graph filtered by the user's equipment profile. PUMP LIFT machine alternatives surface automatically; MINIMALIST swaps surface when the user toggles a "Travel mode" profile.

The Apple Watch app should run **standalone** with `HKWorkoutSession` and `HKLiveWorkoutBuilder` so users in a locker-room or class can leave the phone behind. The Watch shows current block, set X of Y, target weight and reps, rest timer; the digital crown scrolls sets, tap checks, long-press advances exercise. HR streams back to the iPhone for the post-workout summary. Voice memos for set notes work hands-free. WorkoutKit can also schedule the next session into the native Workout app for a one-tap start. Live Activities and Dynamic Island carry the rest-timer countdown for users who keep the phone nearby.

The post-workout summary surfaces total volume, time, RPE average, time-in-zone, automatically detected PRs (Caliber-style shareable card), a "How did this feel?" slider feeding the autoregulation engine, and a one-tap form-review video upload for the day's primary lift. The coach dashboard sees compliance, readiness, RPE trends, and form-video submissions in a single view.

**Progressive overload should be a suggestion, never an imposition.** FBB's philosophy values athlete autoregulation — the rebuild preserves that by surfacing per-set load suggestions ("Last RPE 7 at 135 × 8 → try 140 × 8 today") that the user accepts or overrides. For percent-based Olympic blocks, the app prompts for a current 1RM and computes target loads automatically. For AMRAP back-offs ("Set 3: -5–10% from Set 2 AMRAP"), the app pre-fills a -7.5% default. **Bridge Week deload detection** is FBB-unique: the app knows the periodization calendar and proactively surfaces the deload week with a coach note ("This is a bridge week — dial intensity to ~70% RPE") and adjusts load suggestions accordingly.

## The performance and offline rebuild, end-to-end

The performance and offline complaints are not a UI polish problem — they are an architectural one. The fix has four layers.

**Layer 1: native runtime.** Swift/SwiftUI and Kotlin/Compose eliminate the JS-bridge cost that webview-wrapped apps pay on every state transition. Tap-to-log latency drops from a webview's typical 150–400ms to native's sub-100ms; the "video wipes rep scheme" bug becomes structurally impossible because view state lives in proper SwiftUI `@State` / Compose `MutableState` lifecycles that the OS doesn't blow away on backgrounded media playback.

**Layer 2: offline-first local DB.** Every user mutation — every checked set, every weight entered, every RPE picked, every note saved — writes to local SQLite immediately and reads from local SQLite immediately. The UI is reactive on the local DB. Network state is irrelevant to the in-workout experience. This is how Strong achieves its category-leading reliability and why it remains a top recommendation despite a thinner feature set than Hevy.

**Layer 3: PowerSync + outbox.** Mutations are queued to a sync outbox with client-generated UUID v7 idempotency keys. The PowerSync upload queue drains in order with exponential backoff when the network returns. Server-side mutators are idempotent; replay-safe. Last-touched-wins is acceptable for single-author workout logs (no need for CRDT machinery). When the user opens the iPad later in the day, PowerSync down-syncs the in-progress workout and they resume seamlessly.

**Layer 4: video pre-fetch and storage management.** Default behavior is HLS adaptive streaming with a rolling 256 MB cache of the last-played demos. When a user enrolls in a new program, an opt-in dialog offers "Download all 47 demo videos (1.2 GB)?" The night before each scheduled session, `BGAppRefreshTask` (iOS) and WorkManager (Android) prefetch the next session's demos at the user's preferred quality if on Wi-Fi and charging. A Settings → Manage Downloads pane surfaces per-program disk usage, "Wi-Fi only," "Auto-delete after 30 days unused," and a manual quality picker (480p/720p/1080p). LRU eviction by last-played timestamp triggers when device storage drops below threshold.

The combined effect: a user can drive to a basement gym with no signal, complete a 75-minute PUMP CONDITION session with full demo videos, log every set with sub-100ms latency, and have everything sync silently when they walk back into Wi-Fi range. That's the bar Strong set in 2018 and FBB has not yet met.

## Modern features to build on the new foundation

A native rebuild unlocks a backlog of high-leverage features that are physically impossible (or shipped years late) on the AppRabbit platform. Ranked by user value × implementation cost:

**Highest leverage, low cost.** Live Activities and Dynamic Island for active workouts (the rest timer should be glanceable without unlocking the phone). Home Screen widgets for "Today's workout" and current streak. App Intents and Siri Shortcuts so users can say "Hey Siri, start FBB workout." A proper plate/dumbbell/kettlebell loading visualizer. Two-way HealthKit and Health Connect integration so FBB workouts contribute to Apple Activity Rings and pull HRV/sleep/resting HR for autoregulation hints. Better push notifications — streak-saving nudges and scheduled-workout reminders, not generic daily blasts.

**High leverage, medium cost.** Apple Watch and Wear OS standalone apps. Per-track leaderboards and streaks (Ladder + Peloton Club model). RPE-aware progressive overload suggestions. Equipment-aware Smart Replace substitution. Per-track community feeds with cheers/comments (SugarWOD's fist-bump pattern). Auto-detected PRs with shareable cards. e1RM (Epley/Brzycki) tracking per lift. Caliber-style Strength Score and Strength Balance composite metrics — naturally aligned with FBB's "strength balance" programming philosophy.

**High leverage, high cost — but worth it.** **AI form check** with on-device pose estimation: MediaPipe Pose Landmarker on Android (33 landmarks, ~30 FPS on iPhone 12+) and Apple Vision's `VNDetectHumanBodyPose3DRequest` on iOS 17+, scoped to 8–12 hero movements (squat, deadlift, bench, push-up, pull-up, KB swing) with rep-count, tempo, and ROM estimation — but explicitly framed as cues, not corrections, to avoid liability. **Voice logging** via WhisperKit on iOS (Argmax, runs Whisper Large V3 Turbo on-device) and whisper.cpp on Android: hold-to-talk → "135 by 8 at RPE 8" → parsed into structured `SetLog`. **Adaptive nutrition** with a verified food database, barcode scanner, AI photo logging, and a MacroFactor-style algorithm that adjusts macros weekly based on weight trend — naturally aligned with Marcus's "quality protein, quantity protein" brand voice.

**Recovery integration as a category-defining differentiator.** None of FBB's direct coach-led competitors (TrainHeroic, Centr, Ladder, Caliber) integrate Whoop/Oura/Garmin meaningfully. WHOOP 5.0 exposes a strain-target API ("today should be ~12 strain given your recovery") that maps cleanly onto FBB's RPE prescriptions: an athlete with low HRV gets a softer set of load suggestions, with a coach-voice rationale. This is a wide-open lane.

**Coaching and creator-economy infrastructure.** TrainHeroic's library architecture (write a session once, reuse forever) is the operational model FBB's coaching team needs as Persist scales to more tracks. Form Reviews — already an FBB feature — should become a first-class video-upload + coach-reply surface, comparable to Caliber and TrueCoach.

## A phased rebuild plan

A pragmatic 18-month rollout with clear "no-regret" early wins:

**Phase 1 (months 0–4): Native shell + workout logger parity.** Ship native iOS and Android with the new set logger, single-scroll session view, rest timer, plate calculator, supersets, RPE picker, tempo chips, and offline-first SQLite + PowerSync sync of workouts. Movement Library video streaming with basic caching. Auth via Sign in with Apple + Google + email; RevenueCat subscriptions; one-time migration of existing user history from AppRabbit. **Goal: hit Strong-level reliability and Hevy-level logger speed; close out the 2.5★ App Store narrative.**

**Phase 2 (months 4–8): Apple Watch + Live Activities + content polish.** Standalone Apple Watch + Wear OS apps. Live Activities/Dynamic Island. App Intents/Siri Shortcuts. Widgets. HealthKit/Health Connect two-way. Bridge Week deload detection. EMOM/AMRAP/For Time/Custom Interval timers. Pre-workout readiness survey. Sanity CMS migration of programs and Movement Library. **Goal: leapfrog TrainHeroic and Centr on watch UX and OS-native polish.**

**Phase 3 (months 8–14): Smart programming + community.** RPE-aware progressive overload suggestions. Equipment-aware Smart Replace. Per-track leaderboards, streaks, cheers, post-workout share cards. Coach Form Review video upload + reply. Caliber-style Strength Score. Recovery integration with Whoop/Oura/Apple HRV/sleep feeding into autoregulation hints. Tempo metronome. **Goal: become the most opinionated programmed-strength app on the market.**

**Phase 4 (months 14–18): AI features.** On-device voice logging via WhisperKit / whisper.cpp. Pose-based rep counter and tempo/ROM cues for 8–12 hero movements. AI photo nutrition logging and adaptive macros (MacroFactor pattern). LLM-generated next-workout briefer pulling from coach note + last session's RPE. Optional AI movement search via embeddings. **Goal: own the "AI-assisted coach-led training" positioning that no incumbent currently holds.**

## Bottom line

The Functional Bodybuilding programming is a category-leading product fronted by an app that actively undermines it. The current 2.5-star rating and the team's own status-page acknowledgment that "**network issues leading to lag and errors saving data**" are the dominant priority confirm that this is not a polish problem — it is an architectural one rooted in the AppRabbit hybrid platform. A clean native rebuild in Swift/SwiftUI + Kotlin/Compose, backed by PowerSync over local SQLite, Sanity-managed content, and Bunny/Mux video, can deliver Hevy-grade logger speed, Strong-grade offline reliability, TrainHeroic-grade timer breadth, Apple Fitness+ grade video pinning, Future-grade Apple Watch UX, and Fitbod-grade substitution intelligence. Layered with Live Activities, App Intents, native Wear OS, on-device voice logging, MediaPipe form check, and a MacroFactor-style adaptive nutrition rebuild, FBB v2 has a credible path to becoming the only app in the category that combines world-class programming, world-class execution UX, and category-defining recovery integration. The eighteen-month roadmap above is aggressive but each phase ships independent, user-visible value — and the first phase alone fixes the brand wound.

The opportunity is unusually clear: a beloved program, a public bug list, a documented architectural ceiling, and a competitive set whose execution layer is highly reverse-engineerable. The rebuild is not just a technical exercise; it is the difference between "great program, bad app" and a category-defining product.