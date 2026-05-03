# Engineering research for the FBB / Persist native rebuild PRD (Phase 1)

This report synthesizes seven parallel research streams to inform the Phase 1 PRD for a native iOS + Android rebuild of the Functional Bodybuilding (Persist) app. Highest-leverage findings up front: **AppRabbit's published terms create high migration risk for end-user workout history and Apple Developer-account ownership** (the iOS app is registered to "Cliff Kohut," not Iversen International or FBB); the platform appears to be **Flutter-based**, so this is a true rewrite, not a re-skin. **PowerSync Sync Streams (March 2026 beta)** replace legacy Sync Rules and are the right substrate for FBB's content/user/entitlement partitioning. **Bunny Stream beats Mux on cost by ~5×** at 50K MAU (~$1,250/mo vs ~$5,900/mo) while the native AVPlayer + Media3 ExoPlayer path makes player choice irrelevant. The current AppRabbit "playing a video wipes rep scheme" bug is a hybrid-framework state-loss pattern that vanishes when the video is presented as a SwiftUI `.fullScreenCover` / Compose `Dialog` rather than a navigation push, with the workout ViewModel hoisted to the navigation root. Phase 1 scope (logger + library + nutrition + charts + migration) is roughly **20–30 engineer-months of build + 5–9 of test/CI infrastructure** — best delivered by 2 iOS + 2 Android engineers with a designer.

---

## 1. AppRabbit / Iversen International data export reality

**The published Terms of Service are unfavorable for end-user data return.** AppRabbit's public ToS (apprabbit.com/termsofservice) confirms only that the brand owner retains rights to "uploaded content" — language that covers programs and videos the coach uploaded, but is **silent on user-generated workout history, set logs, PRs, body metrics, and chat archives**. §9 explicitly threatens "permanent account termination and **data deletion**" on chronic non-payment. There is no published export-format specification, no documented notice period for data return on termination, no public API documentation, and no developer portal discoverable via search. Pricing is gated behind a sales call (the public pricing page returns 404). A single Trustpilot review (Dec 2025) describes a coach being denied a contractually-promised $2,500 refund — a soft signal that AppRabbit may be slow to cooperate when relationships sour.

**The platform is almost certainly Flutter-built.** A LinkedIn job posting for "AppRabbit hiring Flutter Developer in United States" (jobs/view/4187020497) is dispositive. Cross-corroborated by: the 118.8 MB iOS bundle size (consistent with Flutter engine bundling); identical visual/UX signatures across ~35 AppRabbit-built apps in the "More by AppRabbit" Google Play developer page; cross-platform iOS/Android/web from one team; and the marketing claim of "build in 3-4 weeks." There is **no evidence of Capacitor/Ionic, React Native, or true native** under the hood. **Implication: the rebuild is not a re-skin — it is a full ground-up native build.**

**The Apple Developer-of-record problem is the most urgent migration risk.** The FBB iOS app is registered under "Cliff Kohut" as the individual Apple Developer — a common AppRabbit pattern where each white-label brand uses a separate Developer account. This means **the App Store listing, IAP product IDs, subscriber base, and reviews are tied to an account FBB likely does not control**. Apple's App Transfer process (developer.apple.com/help/app-store-connect/transfer-an-app/) preserves IAP continuity, ratings, and Bundle ID — but requires the source Account Holder to initiate. **If transfer is refused, FBB ships under a new Bundle ID and every existing subscriber must repurchase**, an entirely avoidable churn event. This is the single highest-priority blocker to identify before Phase 1 commits.

**Bug pattern in release notes confirms platform-level immaturity.** The iOS release notes since launch show repeated firefighting of basic primitives: *"Losing workout data when logging supersets"* (09/16/2025), *"Glitch when reordering sets"* (same), *"Two timers on timed unilateral movements"* (10/14/2025), *"Hotfix - Resolve intermittent network errors on home Wi-Fi"* (12/04/2025), *"Hotfix - Resolving workout logging errors"* (02/24/2026). Verbatim user reviews echo it: *"If you don't check off each completed set before you type in the next one, it messes up the order of your reps or weight. It did this multiple times. I dread using the app each training session."* Across all ~35 AppRabbit-built apps surveyed (Eubank Fitness 3.1★ despite a 3M+ social audience; SUPRĀ TRAINING by Ross Edgley; 30+ others), the rating cluster sits at 3.0–3.2★ — strong evidence the bugs are platform-level, not FBB-specific. **No documented coach migrations away from AppRabbit were found**, meaning FBB will be charting new ground on the export negotiation.

**Migration risk register:**

| Data class | Risk | Why |
|---|---|---|
| Program content (workouts authored by FBB) | **Low** | "Uploaded content" is owned by the brand owner per ToS; FBB likely has master copies in their authoring workflow regardless. |
| Movement Library and demo videos | **Medium** | Owned by FBB but stored on AppRabbit infrastructure; bulk download requires AppRabbit cooperation. |
| **End-user workout history / set logs / body metrics / PRs** | **High** | Not "uploaded content"; ToS silent on portability; no API; deletion threatened on non-payment. |
| Form-review videos and chat archives | **High** | No documented export. |
| **Apple/Google IAP continuity** | **High** | Tied to Cliff Kohut's Developer account. App Transfer required to preserve. |
| Stripe web subscriptions | **Medium** | Portable directly via Stripe if FBB is merchant of record (verify). |

**PRD action:** Pull AppRabbit's executed master agreement before scoping. Initiate App Transfer conversations as a parallel workstream to engineering. Plan a manual export workstream (browser-driven scraping of the admin dashboard, plus a pre-cutover prompt that asks each user to confirm/correct their PRs — turning a data-quality risk into a re-engagement moment).

## 2. PowerSync 2026 — the offline-first sync substrate

**PowerSync is the right tool, with three 2025–2026 changes that materially affect the PRD.** First, the **Swift SDK exited alpha at v1.0 in April 2025** and is now at 1.2+ with a Rust-based sync client; the Kotlin/Android SDK is at v1.11.2 (March 2026). Both are GA. Second, **Sync Streams (March 2026 beta)** replace legacy Sync Rules as the recommended way to control which data syncs, with on-demand subscription semantics and TTL caching that fit FBB's "user buys a track mid-session" pattern far better than preemptive bucket sync. Third, the SDK now ships **opt-in ORM bridges** (`PowerSyncGRDB` for Swift, `integration-room` and `integration-sqldelight` for Kotlin) but they remain **alpha-grade** as of May 2026 — not appropriate for a v1 production app.

**The recommended architecture for FBB:** native PowerSync SDKs per platform (no KMP module sharing for sync); **Sync Streams in edition 3 syntax** with three logical streams — `my_active_workout` (priority 1), `my_history` + `entitled_programs` (priority 2), and `movement_library_meta` + `mobility_flows` (priority 3); a **server-driven entitlements table** populated by RevenueCat webhooks (NOT JWT claims alone) so subscription upgrades stream new content to the device within seconds without a reload; **client-generated UUIDs on every set log** for idempotent retries; **last-write-wins per row + deletes-win** as the default conflict policy; and **`getCrudTransactions()`** (not `getCrudBatch()`) for upload so a workout session is atomic.

**Concrete Sync Streams shape (excerpt):**

```yaml
config:
  edition: 3
streams:
  my_sessions:
    auto_subscribe: true
    priority: 1
    queries:
      - SELECT * FROM workout_sessions WHERE user_id = auth.user_id()
      - SELECT * FROM set_logs WHERE session_id IN
          (SELECT id FROM workout_sessions WHERE user_id = auth.user_id())
  entitled_programs:
    auto_subscribe: true
    priority: 2
    with:
      my_tracks: SELECT track_code FROM entitlements
                 WHERE user_id = auth.user_id() AND active = true
    queries:
      - SELECT * FROM programs WHERE track_code IN my_tracks
      # ... mesocycles, blocks, microcycles, days, prescribed_exercises
  movement_library:
    auto_subscribe: true
    priority: 3
    query: SELECT * FROM movements WHERE active = true
```

**Three data-modeling decisions worth highlighting:**

- **Row-per-set, not JSONB blob.** PowerSync's JSON-view system makes ~200-row sessions cheap (~60 KB hosted per session) and field-level diffs send ~50 bytes upstream when a user edits one rep count. JSONB blobs collapse to whole-blob LWW conflict resolution and break SQL aggregations needed for PR detection and volume charts.
- **PRs are stored, not derived.** A Postgres trigger on `set_logs` insert maintains a `prs` table. Computing on-device means PR rules can't evolve without an app-store review cycle; computing server-side means PR semantics are a deploy.
- **Bridge Week is a column on `days`, not a client-side computation.** Bake `kind: 'standard' | 'deload' | 'bridge_week'` at content-publish time in Postgres. The math (4 mesocycles × two 6-week blocks + bridge week ≈ 52 weeks) is FBB-confirmed via their own deload-week blog post.

**Two known footguns to ticket on day one.** First, **PowerSync DBs cannot be opened from iOS App Extensions** (Widgets, Live Activities, App Intents) — a confirmed open issue (#126) flagged by the FitWoody team in production. Workaround: dump a Codable JSON snapshot to the App Group on every meaningful update. This is fine for Phase 1 (no Watch/Live Activities) but constrains Phase 2. Second, the **backend write API must apply writes synchronously to Postgres** — no SQS-then-worker pattern in front, or the write checkpoint resolves before data lands and the user sees their just-saved set "disappear" briefly. Custom Write Checkpoints exist for async backends but require Team plan.

**Cost at 50K MAU with ~30 concurrent syncing users sits comfortably on the $49/month Pro plan.** Estimated ~6 GB synced/month and ~1.8 GB hosted, both well under Pro caps. Upgrade to Team ($599/mo) only if HIPAA, VPC peering, or SOC2 reports for B2B partners become requirements. The closest production analog is **FitWoody (consumer iOS health/fitness, Swift + Supabase + PowerSync)** — same platform, same domain, in production. Marco's blog (marcoapp.io/blog/offline-first-landscape) candidly documents an evaluation across WatermelonDB, Triplit, InstantDB, Replicache, Zero, and ElectricSQL before settling on PowerSync, and is the most useful prior art on what doesn't work. Zero is web/React focused; ElectricSQL pivoted to read-path-only in 2024; Replicache is open-source but lacks native mobile SDKs and SQLite. **No alternative matches PowerSync's combination of bidirectional sync, native iOS+Android SDKs, Postgres-source-of-truth, and Sync Streams' on-demand semantics.**

## 3. Local DB — GRDB on iOS, Room on Android, schemas duplicated

**Recommendation: GRDB.swift 7.10+ on iOS + Room 2.8.x on Android, with PowerSync's standard (default) integration — NOT the alpha ORM bridges.** Schemas are duplicated between platforms (~15–25 tables; the duplication cost is small) and SQLDelight/KMP is deferred to a 2027 carve-out.

**Rationale.** GRDB 7 is the gold-standard SQLite library on iOS, with full Swift 6 / strict concurrency support, structured-concurrency cancellation that rolls back transactions cleanly, and a SwiftUI-native `@Query` property wrapper via the GRDBQuery package that pairs `ValueObservation.tracking { ... }` with declarative views. Room 2.8 is universally adopted on Android, has KMP support (a 2027 option), and the modern Flow-based DAO pattern is the unanimous 2026 best practice over LiveData/RxJava. PowerSync's GA path — where PowerSync owns the SQLite instance and the app queries via `powersync.execute()` / `watch()` — is well-tested, while the GRDB and Room *bridges* (which let your ORM and PowerSync share a connection) are alpha. Don't ship critical persistence on alpha bridges in v1.

**Skip SQLCipher in Phase 1.** Without HIPAA/PHI scope, **iOS FileProtection (`NSFileProtectionComplete`) and Android's default disk encryption are sufficient**, with zero performance cost and no SPM/CocoaPods build complications. SQLCipher costs 2–3.5× on bulk writes (Swift Forums benchmark: 500K row inserts go from ~10s to ~35s on iPad Pro Gen 1) and the SPM story for GRDB+SQLCipher is unsolved upstream. Revisit only if compliance scope changes.

**Reactive query patterns to ship in v1.** "Last 90 days workout history grouped by week" is a simple `strftime('%Y-%W', logged_at)` GROUP BY wrapped in `ValueObservation` (iOS) or returned as `Flow<List<WeekSummary>>` (Android). PR detection uses the Epley formula `MAX(weight_kg * (1 + reps/30.0))` over a join with `reps BETWEEN 1 AND 12`. Movement Library search uses **FTS5** — first-class on GRDB via `db.create(virtualTable: "movement_fts", using: FTS5())`, and PowerSync's bundled SQLite is FTS5-enabled per their changelog. Bridge Week detection is a single `SELECT (CAST((julianday('now') - julianday(started_at)) / 7 AS INT) + 1) AS current_week` against a `program_block` table — `isBridgeWeek = current_week == weeks_total`.

## 4. Workout logger UX — best-in-class patterns 2026

The logger is the single most-used surface in the app and the place AppRabbit fails worst. The right model is **Hevy's set-row clarity** plus **TrainHeroic's seven-mode timer** plus **Peloton/Future's pinned video**, with a few first-of-class decisions on Olympic complexes and unilateral L/R rest.

**Set-row layout: a tabular `SET # | PREV (line below) | Weight | Reps | RPE | ✓` row.** Hevy's PREVIOUS-as-column works on iPad but eats horizontal space on a 6.1" iPhone; FBB should render it as a small grey line under the row ("Last: 200lb × 5 @ RPE 8"). **Auto-save on blur, plus an explicit checkmark to mark "complete"** (which strikes through the row, triggers the rest timer, and creates a clean "set_completed" event for the outbox queue). Auto-advance focus to the next incomplete set's weight field within the same exercise; auto-scroll between exercises **only inside grouped supersets** (Hevy's "Smart Superset Scrolling" off-by-default is too cautious for FBB programs that explicitly group A1/A2). **RPE input as segmented stepper buttons** (6 / 6.5 / 7 / 7.5 / 8 / 8.5 / 9 / 9.5 / 10) defaulting to "—"; sliders are imprecise mid-set and freeform numerics produce typos. **Tempo as a monospaced inline pill** ("⏱ 30X1") under the exercise name with an info-icon tooltip explaining FBB's specific convention (3s eccentric • 0 hold bottom • X explosive concentric • 1 hold top — confirmed via FBB's own help center). The convention is not universal (N1 puts pause-after-eccentric in position 2; OPEX uses it for isometric-bottom), so the tooltip is essential.

**Three first-of-class decisions where no competitor handles FBB's needs:**

- **Olympic complexes (e.g., "1 hang power snatch + 2 hang snatch + 1 OHS").** Render as **one row per complex execution**, with the complex descriptor in the exercise label and `weight × "complex completed"` as the unit. The complex *is* the unit of progression — coaches care that the athlete hit "165# × 1 complex" four times, not 4 individual snatch logs. None of Hevy, Strong, TrainHeroic, Boostcamp, FitNotes, Caliber, Liftin, or Stacked handle this natively. Optional expansion to per-component reps for failed complexes.
- **Unilateral L/R with separate rest.** **Two stacked rows per set** (L row, R row), each independently checkmarked with its own rest timer. Single-row L/R toggles lose the parallel history; two-column rows are cramped on narrow phones. Stacked rows match how lifters actually log unilaterals on paper.
- **AMRAP back-off prefill.** When a coach prescribes "3×5 @ 80%, then 1×AMRAP at 70%," the back-off row prefills as **70% of the just-completed working set's weight** (more relevant than 1RM percent), shown as a greyed placeholder ("140 suggested") tappable to accept and always editable.

**Skipped vs failed sets.** **Long-press the checkmark to reveal a 3-option menu** — Complete / Failed (counts as attempt) / Skipped (don't count). Failed = red strike + ⚠ icon; Skipped = greyed dashed border. RPE-10-with-zero-reps as an implicit "failed" signal is too ambiguous for charts and PR detection.

**Timer modes — adopt TrainHeroic's seven-mode set verbatim, but render with bigger tap targets:** Rest, Stopwatch, AMRAP, For Time, Tabata, Custom Interval, EMOM. EMOM renders a big minute countdown plus minute counter with an audible top-of-minute beep; reps are decoupled from the timer (logging happens between minutes; failure to finish reps is purely visual). AMRAP shows time remaining plus a **big tap-to-increment "Round" button** (typing a number is too slow when chalked-up); partial reps logged on stop. For Time inverts to a count-up stopwatch with a "Done" button; time cap stops the timer with a tone and remainder logs as "Cap+". Tabata is the standard 20s/10s × 8 preset with color-coded Work/Rest labels and a 3-2-1 audible countdown. Custom Interval covers E2MOM, E3MOM, and per-side stretches with rest. **Rest timer auto-starts on checkmark**, surfaces in a sticky bottom bar, and as an iOS Live Activity / Android persistent notification (Hevy's pattern) — Live Activity is Phase 2 but the protocol design must accommodate it from v1.

**Video pinning is the architectural fix for the AppRabbit "wipes rep scheme" bug.** On iOS, present demo videos via **`.fullScreenCover`** (parent view stays mounted, `@State`/`@StateObject` survives) — never via a `NavigationLink` push. Hold the `AVPlayer` in a `@StateObject` so the player survives parent re-renders (this is the single most common SwiftUI-AVKit footgun, documented at copyprogramming.com/howto/swiftui-how-to-properly-present-avplayerviewcontroller-modally; almost certainly the root of the AppRabbit bug). Use `AVPictureInPictureController` with `canStartPictureInPictureAutomaticallyFromInline = true` for the "watch demo while logging" pattern. On Android, present videos as a `Dialog` or `ModalBottomSheet` Composable rooted at the same `NavBackStackEntry` as the logger — never a new destination — and **hoist the workout `ViewModel` to the navigation-graph root** so child Composable lifecycle never destroys workout state. This invariant ("the in-flight workout is owned by a single ViewModel rooted at the app shell; no screen owns workout state in its own local scope") is the single most important architectural rule in the PRD.

## 5. Sanity CMS schema for deeply nested fitness programming

**Sanity beats Contentful, Strapi, Hygraph, Storyblok, and Payload** for FBB's pattern of schema-as-TypeScript, deep nesting, character-level real-time multi-edit, and GROQ-projected webhooks. Sanity has no public deeply-nested fitness reference customer (Tata Neu's multi-brand platform is the closest analog), so this is greenfield — but the architecture is sound and a 2-sprint validation prototype before locking the data model is enough de-risking.

**Entity granularity.** **Documents** for things with identity, references, or independent lifecycle — Program, Mesocycle, Block, Microcycle, Day, Movement, MobilityFlow, SubstitutionRule. **Inline objects** for things owned 1:1 by a parent and never referenced — Section ("A: Strength") and PrescribedExercise. The breakpoint rule: if there will be >50 of an entity, or it appears in any `references()` graph, it's a document. At maturity ~50 programs × 4 mesos × 2 blocks × 6 micros × ~3 days ≈ **7,200 day documents**, well within Sanity's free-tier limits.

**Reference + override pattern for prescribed exercises.** Each PrescribedExercise stores a `movement` reference plus sibling override fields for `tempo`, `sets`, `reps`, `percent1RM`, `restSeconds`, `rpe`, `coachCue`. Empty overrides fall back to library defaults at query time. A `substitutionRules[]` array of references to first-class `SubstitutionRule` documents (with `condition` enum: `no_barbell`, `shoulder_limit`, `travel`, etc., and a `priority` for ranking) handles the substitution graph that AppRabbit's late-2025 "swap any exercise" feature added but did not normalize.

**Custom Studio inputs for tempo and RPE.** Build two ~1-day React components: a **TempoInput** with four single-character fields (`eccentric` / `pauseBottom` / `concentric` / `pauseTop`, validating `[0-9X]`, with X meaning "explosive" and an FBB-specific A meaning "assisted concentric" seen in tempos like `40A0` for Nordic Hamstring Curl Negatives) plus a live-summary "Tempo: 3 · 0 · X · 1" pill; and an **RpeInput** with a single value or optional min/max range plus a coach-note string. Both dispatch atomic `set`/`unset` patches so they participate cleanly in real-time multiplayer (two coaches can edit different fields of the same PrescribedExercise simultaneously). Coach authoring becomes ~5× faster than free-text.

**Real-time multiplayer is GA in 2026 with character-level sync** — operational-transformation–style mutation log, not Yjs/Automerge CRDTs, with presence indicators, in-line cursor presence in Portable Text (shipped 2024), Comments + Tasks (GA 2024-2025), and Content Releases (Spring 2025) for atomic publishing of an entire mesocycle's worth of changes. For a coach team, give each coach distinct mesocycle ownership via Sanity's 2025-added field-level RBAC.

**Webhook → Postgres mirror pattern.** GROQ-powered Document Webhooks (preferred over Transaction webhooks), one per type, projecting a denormalized JSON shape. Verify with `@sanity/webhook` `isValidSignature()`; dedupe with `sanity-idempotency-key` header in a `webhook_log` table; upsert with `ON CONFLICT (id) DO UPDATE WHERE rev IS DISTINCT FROM EXCLUDED.rev` to skip stale arrivals. **GROQ webhook projections do not support sub-queries** — to denormalize movement names into `prescribed_exercises` rows, store `movementId` from `movement._ref` and resolve at query time in the client via SQLite views. Schema-drift discipline: **schema (`defineType`), Postgres migration, webhook GROQ projection, and PowerSync Sync Stream YAML all live in a monorepo and ship in a single PR**. Old client versions tolerate added fields (PowerSync silently ignores unknown fields), so additive changes are safe to roll; renames or type changes require a deprecation window with both old + new fields populated.

**Localization-ready schema for Phase 1 English-only.** Use **document-level internationalization** (`@sanity/document-internationalization`) for narrative content (Program, Mesocycle, Block, Microcycle, Day, MobilityFlow) where a Spanish program is effectively its own document, and **field-level internationalization** (`sanity-plugin-internationalized-array`) for Movement (canonical English `name`, localized `cuesPortable`). Phase 1 just sets `language: 'en'` everywhere; Phase 2 turns on the language selector. **Sanity Agent Actions** (Spring 2025) can AI-translate documents in bulk.

**Video reference pattern: a polyglot `externalVideo` object** storing either Bunny `(libraryId, videoGuid)` or Mux `playbackId` behind a `provider` discriminator, with shared `durationSeconds`, `aspectRatio`, and Sanity-hosted `posterImage`. Never embed playback URLs in Sanity — build them at runtime. Sanity's image CDN is used only for posters/thumbnails; per their own blog, they explicitly do not provide a video pipeline.

## 6. Video infrastructure — Bunny Stream + Mux Data analytics

**Choose Bunny Stream for delivery + storage; instrument with Mux Data SDKs for analytics; defer iOS DRM to Phase 2.** This hybrid saves ~$56K/year vs Mux Video at FBB's scale while preserving best-in-class native-player QoS observability.

**Cost comparison at 50K MAU.** Assumptions: 200 demo videos × 60s + 100 workshop videos × 30 min = 3,200 source minutes; ~30 MB/min encoded (multi-rendition HLS); per-user ~5 GB/month delivered (450 MB demos + 4.5 GB workshops); 250 TB/month total egress; pre-cache 7 days on Wi-Fi.

| Line item | Bunny Stream | Mux Video |
|---|---|---|
| Encoding | Free (default) | Free (basic input) |
| Storage (multi-region) | ~$2.40/mo (96 GB × ~$0.01/GB × 2-3 regions) | ~$5/mo (with cold-storage discount) |
| Delivery | **~$1,250/mo** (Volume Network, $0.005/GB × 250,000 GB) | ~$5,920/mo (7.4M billable min × $0.0008/min) |
| Player + analytics | Free (Bunny Player) | Free (Mux Player + Mux Data) |
| **Total** | **~$1,250/mo** | ~$5,900/mo list, ~$4,200 negotiated |

Bunny is ~5× cheaper at scale and the gap widens linearly with MAU growth. Player-agnostic HLS is genuinely fine for native — both AVPlayer and Media3 ExoPlayer are mature HLS clients, and Bunny's HLS URLs feed them directly. **Bunny released native iOS and Android SDKs in 2025** (`bunny-stream-ios` SwiftPM, `bunny-stream-android` Maven), but FBB doesn't need them — the `api` module wrapping Bunny's REST API is useful, but the player layer should remain in raw native code.

**Where Bunny falls short and Mux Data fills the gap.** Bunny offers no first-party AVPlayer/ExoPlayer analytics SDK — to get rebuffer rate, startup time, and per-movement completion rate you'd manually instrument `AVPlayerItemNewAccessLogEntry` notifications and ExoPlayer's `AnalyticsListener` (~1 sprint). **Mux Data SDKs work with any HLS source, including Bunny's**: `MUXSDKStats.monitorAVPlayerViewController(...)` is a one-line attach on iOS, `exoPlayer.monitorWithMuxData(...)` is a one-line attach on Android (Media3-compatible). Mux Data is free at FBB's view volume. Custom dimensions (10 free `customN` slots) make `programId`, `mesocycleId`, `dayId`, `movementId`, `userTier` first-class filters in the dashboard — "completion rate per movement" becomes a built-in chart.

**Native HLS playback patterns.**

- **iOS (AVAssetDownloadURLSession + .movpkg, 2025 best practice).** Use `AVAssetDownloadConfiguration` (iOS 15+) — preferred over the older `makeAssetDownloadTask(asset:assetTitle:options:)`. Configure with a background `URLSessionConfiguration` so downloads continue when the app is backgrounded; reattach via the same identifier on relaunch. Persist the returned `.movpkg` URL relative to the sandbox (the OS may move it on app updates). `NSURLIsExcludedFromBackupKey` is automatic. **Critical gotcha** (WWDC 2016 Session 503 @33:15): if you spec a single high bitrate via `AVAssetDownloadTaskMinimumRequiredMediaBitrateKey`, AVFoundation downloads only that rendition and offline playback may fail when no fallback exists — download both highest and lowest renditions. Combine with `BGProcessingTaskRequest` for "download next 7 days overnight while charging."
- **Android (Media3 ExoPlayer + DownloadManager + DownloadService).** `DownloadManager` with `StandaloneDatabaseProvider` + `SimpleCache` + `NoOpCacheEvictor` (never auto-evict downloads); `DownloadHelper.forMediaItem()` to prepare the request; foreground service of type `dataSync` with progress notification. **Track-selection gotcha** (Media3 issue #670 on `androidx/media`): `DownloadHelper.clearTrackSelections()` followed by selecting a single 720p track produces a download that won't play offline — keep at least one track selection per renderer. `WorkManagerScheduler` is the 2026-preferred restart scheduler. `targetSdk 35+` is required for new releases as of 2025.

**Phase 2 triggers to revisit Mux:** live workout streaming (Mux Live is best-in-class), iOS DRM mandate, content team ingest volume 10× projection, or "just-in-time encoding" becoming material.

## 7. RevenueCat 2026 + migration runbook

**Adopt RevenueCat Pro plan as the entitlement source of truth across iOS, Android, and Stripe.** SDKs: `purchases-ios` v5.x (StoreKit 2 default, iOS 13+, Swift 6 toolchain, RevenueCatUI for paywalls + Customer Center) and `purchases-android` v8/v9.x (BillingClient 7+, minSdk 21, first-class Compose). **Pricing at FBB's ~$2M ARR**: $2M ÷ 12 = ~$166K MTR; the free tier ends at $2,500 MTR, so Pro at 1% of MTR ≈ **~$1,667/month** (~$20K/year — well within build-vs-buy band where RC pays for itself).

**Entitlements model: multi-attach.** One `persist` entitlement granted by Persist subscription products, plus one entitlement per workshop (`workshop_pump40`, `workshop_aerobic40`, …) — each workshop entitlement has both the workshop's standalone product **and** the Persist subscription products attached. This encodes "Persist unlocks all current and future workshops" while allowing à-la-carte workshop purchases to remain lifetime after Persist cancellation. Single-entitlement models can't represent that. RevenueCat Paywalls v2 (GA WWDC 2025, Figma export added Nov 2025) renders the paywall surfaces; one `default` Persist offering plus per-workshop offerings, A/B tested via Experiments.

**Customer Center is optional, not Apple-mandatory, but cuts churn.** SwiftUI `CustomerCenterView` (RevenueCatUI 5.14+) on iOS and Compose `CustomerCenter` on Android handle cancel-with-promo-offer, refund request, change plan, restore, missing purchases, and contact support out of the box. Configure cancel-flow promo offers in the dashboard.

**Webhook architecture (the critical glue to PowerSync).** `/webhooks/revenuecat` endpoint verifies the configurable Authorization-header bearer secret, writes raw payload to a durable `webhook_events` inbox (unique on `event.id`), returns 200 within 60s. Background worker derives `(user_id, track_code, active, expires_at)` from `INITIAL_PURCHASE` / `RENEWAL` / `CANCELLATION` / `EXPIRATION` / `BILLING_ISSUE` / `SUBSCRIPTION_PAUSED` events and upserts the `entitlements` table — which PowerSync Sync Streams (§2) then push to the device in seconds. A daily reconciliation job calls `GET /v1/subscribers/{app_user_id}` to backfill any missed events (RC retries 5× with exponential backoff at 5/10/20/40/80 minutes, then stops — there is no built-in dead-letter).

**Migration from old AppRabbit subscriptions to new native + RevenueCat — staged runbook:**

- **T–60 (foundation):** Create RC project; upload Apple In-App Purchase `.p8` Key + App-Specific Shared Secret + ASC API Key; configure App Store Server Notifications v2 → RC URL on prod *and* sandbox; same for Google Real-Time Developer Notifications via Pub/Sub; install RevenueCat App from Stripe Marketplace; **enable "Track new purchases from server-to-server notifications" before launch** so renewals on the *old* app version are ingested into RC even before any user installs the new app.
- **T–45 (App Transfer):** Cliff Kohut (current Account Holder) initiates Apple App Transfer to FBB's new ASC team — **mandatory pre-conditions: ungroup any Sign in with Apple grouping; generate app-specific shared secret; ensure no IAP product ID conflicts in recipient account.** Plan that users will be forced to re-login once after the post-transfer update (keychain migration breaks). Equivalent Google Play app transfer.
- **T–30 (historical backfill):** Server-side import — POST full base64-encoded Apple receipts and Google purchase tokens to `POST /v1/receipts` with the canonical FBB user_id. **Apple constraint**: must be the *full* receipt, not `latest_receipt_info`. **Google constraint**: tokens expired >60 days cannot be imported. **Bulk imports do NOT trigger webhooks**, so use REST API rather than CSV.
- **T–14 (beta):** Ship via TestFlight / Play internal track; verify existing entitlement carries over without "Restore Purchases" tap. RC SDK auto-detects on-device transactions on first launch.
- **T–0 (cutover):** Submit new native app under same Bundle ID / package name; force-update banner on old AppRabbit app.
- **T+30:** Daily reconciliation: compare RC subscriber count vs. AppRabbit's last known vs. Stripe's active count. Any delta >1% triggers investigation. Sunset old AppRabbit version.

**Subscription expiry mid-workout — the graceful UX.** RevenueCat caches `CustomerInfo` for **3 days when offline**. Check entitlement only at workout start, not on every set save. Cache `workout.entitlementVerified = true` for the workout duration. If `customerInfoUpdateListener` fires mid-workout indicating revocation, **defer enforcement until workout completion** — show a non-blocking banner ("Your subscription expired — you'll need to renew before your next workout") but allow the in-flight session to finish and sync. Configure 14-day grace period at the product level for billing-issue users.

## 8. Auth — Sign in with Apple + Google + email magic link

**Recommended provider stack:** **Supabase Auth for magic links + email/OTP** (cheapest at scale, asymmetric JWTs work directly with PowerSync's JWKS verification, open-source escape hatch), with **native `ASAuthorizationController`** for Sign in with Apple on iOS and **Credential Manager API** for Google Sign-In on Android (the modern replacement for the deprecated `GoogleSignInClient`; supports passwords, federated Google, and passkeys). On iOS, Google federation goes through `GoogleSignIn-iOS` (Apple doesn't allow federated identity through `ASAuthorizationController`).

**Provider cost comparison at FBB scale (50K MAU):**

| Provider | Free tier | At 50K MAU | Native SDKs | Notes |
|---|---|---|---|---|
| **Supabase Auth** | 50K MAU | **~$25/mo** (Pro plan, 100K MAU included) | Mature iOS/Android | Recommended primary |
| Firebase Auth | 50K MAU | $0 (under cap) | Mature | Migration tax: Dynamic Links retired Aug 2025 — magic links now via Universal Links/App Links + Firebase Hosting. SDK ≥ Android v23.2.0 / iOS v11.8.0 required |
| Stytch | 10K MAU | ~$400/mo (Consumer, $0.01/MAU) | Strong native | Pricing turbulence post-Twilio acquisition Oct 2025 |
| Clerk | 10K MAU | ~$825/mo | React-first; native iOS/Kotlin SDKs thinner | Better fit for RN apps |
| Auth0 | 7.5–25K MAU | ~$1K–3K/mo | Mature | Most expensive post-Okta |
| Self-built (Postmark + custom JWT) | $15–30/mo email cost | ~$30/mo | DIY | 4–6 weeks engineering; max control |

**Fallback if Supabase Postgres dependency is unwanted:** self-build with Postmark for email (excellent Sign in with Apple private-relay support documented at postmarkapp.com/support/article/1283) plus a small Node/Go service issuing JWTs. ~4 weeks engineering, $20/mo Postmark.

**Sign in with Apple — three things the PRD must build day one.** (1) **Token revocation on account deletion** is mandatory per Apple's June 2022 mandate (TN3194) — implement `POST https://appleid.apple.com/auth/revoke` and store the user's Apple `refresh_token` server-side at signup. If you forgot to store it, prompt re-auth at deletion time to obtain a fresh `authorization_code`. (2) **Hide My Email relay deliverability** requires DNS work *before* first SiwA user signs up: register your transactional domain (e.g., `mg.functionalbodybuilding.com`) in Apple Developer Console → Sign in with Apple for Email Communication; publish SPF, configure DKIM with `d=functionalbodybuilding.com` matching the From address, configure custom Return-Path so envelope sender is your domain (not your ESP's), publish DMARC `p=quarantine` minimum. (3) **Ungroup the Sign in with Apple Service ID before Apple App Transfer** (pre-condition; see §7).

**Account linking pattern for existing Shopify customers.** First-launch flow: user enters email → backend lookup either finds an existing FBB user (send magic link to that email), finds a Shopify customer but no FBB user (send magic link to verify; on click, create FBB user record linking Shopify customer ID + RevenueCat customer ID), or creates a new signup. After verification, optionally prompt to "also link Sign in with Apple / Google" silently. An `identities (user_id, provider, provider_subject, email)` table with primary key `(provider, provider_subject)` handles idempotent multi-method linking. **Recovery when user lost Hide My Email access**: the Apple `sub` claim is stable, so re-signing in with Apple still works on the same device; only the relay email is broken, and the user just updates email-on-file.

**Backend session model: short-lived RS256 JWT access token + opaque rotating refresh token.** Access token: 5–15 min lifetime (10 min recommended), signed asymmetrically, JWKS at `https://auth.functionalbodybuilding.com/.well-known/jwks.json` so PowerSync can verify directly. Refresh token: opaque, 30–60-day lifetime, **single-use rotation with reuse detection** (presenting refresh token N after N+1 was issued = treat as breach, invalidate the entire token family). **Token storage**: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock` (allows background refresh); Android EncryptedSharedPreferences backed by Android Keystore. **Claims**: only identity (`iss`, `sub`, `aud`, `iat`, `exp`, `jti`) — **no entitlements in the JWT** (revocation latency would be unacceptable; entitlements live in Postgres and stream to clients via PowerSync).

**PowerSync `fetchCredentials()` implementation** caches the JWT in memory while `exp - now > 5 min`; otherwise calls `POST /auth/refresh` with the stored refresh token, persists the new (access, refresh) pair, returns the fresh access JWT. PowerSync rejects tokens older than 60 minutes (`exp - iat ≤ 3600`).

## 9. HealthKit + Health Connect — Phase 1 patterns

**iOS uses `HKWorkoutBuilder` (no session) for Phase 1 strength workouts** because `HKWorkoutSession` is intended for live tracking on Apple Watch / Live Activity surfaces (out of scope until Phase 2). `HKWorkoutBuilder` works on iPhone/iPad for "log a workout that already happened" and is the right model for FBB's post-workout summary save. The activity-type recommendation: `.functionalStrengthTraining` for Persist programming (Apple's docs explicitly cover "primarily with free weights and body weight"), `.traditionalStrengthTraining` for Olympic blocks, `.crossTraining` or `.highIntensityIntervalTraining` for conditioning days. Tag each FBB program template at the CMS level with a default; expose a per-session override picker (8–10 options) in the post-workout summary screen.

**Workout Effort Score (iOS 18+)** is a 1–10 RPE that contributes to Apple's native Training Load chart in the Fitness app. FBB already collects RPE — write it as a related effort-score sample via `HKQuery.predicateForWorkoutEffortSamplesRelated(workout:activity:)`, gated `if #available(iOS 18.0, *)`. **This is a meaningful FBB differentiator**: FBB-logged sessions appear in Apple's Training Load alongside Watch-recorded workouts.

**HealthKit reads use `HKAnchoredObjectQuery` (incremental)** for Steps, HRV, Resting HR, Body Weight, persisting `HKQueryAnchor` in PowerSync local metadata. Subscribe via `HKObserverQuery` + `enableBackgroundDelivery(.hourly)` for steps and `.daily` for weight. HealthKit returns success even if the user declined reads (privacy-preserving) — the UI must check actual data presence, not the auth result. Apple's protection rules: Class "Protected Unless Open" with a 10-minute access window after device lock.

**`HKWorkoutActivity` for sub-activities is NOT the right model for FBB's warm-up/main/cool-down structure.** Apple Developer Forums thread #737323 confirms sub-activities of *different* activity types are only allowed within multi-sport parents (`.swimBikeRun`, `.transition`). For FBB, store program structure in your own DB and write a single `HKWorkout` to HealthKit.

**Android Health Connect 1.1.x is the production target** (1.2.0-alpha04 is current alpha as of April 2026). Health Connect is part of the Android system on Android 14+; on 13 and below it's a Play-Store app. Min SDK 26 to call the API. Use `EXERCISE_TYPE_STRENGTH_TRAINING` for FBB sessions. **There is no native background-delivery equivalent to HealthKit's `HKObserverQuery`** — schedule a 30-minute `WorkManager` periodic job that uses the changes-token API (`client.getChanges(token)`) and persists the token between runs. For Android 15+ users who grant `READ_HEALTH_DATA_IN_BACKGROUND`, the same WorkManager job runs while the app is backgrounded.

**Permission UX: just-in-time, never onboarding-blast.** Apple has rejected apps for over-broad authorization (Guideline 5.1.1). Use SwiftUI's `.healthDataAccessRequest(...)` modifier inside the screen that needs the data, gated by a state trigger; pair every system sheet with explanatory copy *before* it ("Show your daily step count alongside your workouts so you can see total activity," not "FBB needs access to step count data"). On Android, implement the rationale activity (`android.intent.action.VIEW_PERMISSION_USAGE`) which Health Connect opens when the user taps "Privacy policy." On denial: show a small "Connect Apple Health" CTA in the empty-state of the affected chart, never block app navigation.

**Data deletion on uninstall:** HealthKit data persists in Apple Health (uninstalling FBB doesn't delete it); Health Connect data persists in the Health Connect system store on Android. Permissions reset on re-grant (re-grant resets the 30-day historical-read window on Health Connect).

## 10. Charts — Swift Charts on iOS, Vico on Android

**iOS: Apple Swift Charts** (built-in since iOS 16, current iOS 18). `LineMark + AreaMark` with Catmull-Rom interpolation for body-weight trends, `BarMark` with `foregroundStyle(by: .value(...))` for stacked weekly volume, `SectorMark` (iOS 17+) for muscle-group distribution. `chartXSelection(value:)` for tap-to-detail tooltips, `chartScrollableAxes(.horizontal)` + `chartXVisibleDomain(length:)` for scrollable timelines. **Performance budget: ~500 marks per chart before jank**. For FBB's 5-year body-weight series at daily resolution (1,825 points), implement on-device LTTB downsampling — bucket to weekly average (~260 points) when the visible domain ≥ 6 months, raw daily when ≤ 30 days. Implement via a SQLite view aggregating by `strftime('%Y-%W', ts)`.

**Android: Vico 2.2.0+** (`com.patrykandpatrick.vico:compose-m3`). Active maintenance with 2025 releases, KMP-capable, Material 3 theming, Apache 2.0. **Avoid MPAndroidChart** (last release June 2019) and **YCharts** (slowing). Vico uses a `CartesianChartModelProducer` + `CartesianChartHost` composable pattern; cartesian primitives (line, column, stacked column, area) are stable, pie added in 2.2.0 is experimental.

**Custom-chart "Add Chart" feature.** Schema is identical on both platforms (PowerSync-friendly):

```sql
CREATE TABLE user_chart (
    id TEXT PRIMARY KEY, user_id TEXT, title TEXT,
    chart_type TEXT CHECK(chart_type IN ('line','bar','stacked_bar','pie','area')),
    x_source TEXT,    -- 'date_day' | 'date_week' | 'date_month'
    y_source TEXT,    -- 'workout_set' | 'body_weight' | 'steps' | 'macro'
    y_field  TEXT,    -- 'weight_kg' | 'reps' | 'volume_load' | 'protein_g'
    aggregation TEXT CHECK(aggregation IN
                  ('max','min','sum','avg','count','one_rm_epley')),
    filter_json TEXT, date_range TEXT DEFAULT 'last_90d',
    created_at INTEGER, updated_at INTEGER
);
```

Aggregations execute in <50ms on 5-year-of-data SQLite given indexes on `(user_id, exercise_id, performed_at)`. PowerSync's `watch()` Flow/Combine streams re-execute on set-log completion; debounce 250ms to coalesce rapid set-log events (a barbell complex can fire 5 sets in 30s). Pre-shipped templates for day-1 value: body-weight trend, weekly training volume, steps, big-three 1RMs, pull-up reps, calories vs goal.

## 11. Nutrition — Open Food Facts primary, Nutritionix fallback

**Recommended stack: Open Food Facts (primary) + Nutritionix (paid fallback) + USDA (seed library).** Estimated nutrition-API cost at 50K MAU: **~$2–3.5K/month** (Nutritionix Enterprise tier required at this volume; OFF and USDA are $0).

**Open Food Facts** (~4M products, ODbL license, free) is the default barcode lookup and free-text search provider, with strong EU coverage. ODbL requires attribution and share-alike on derivative *databases* — reading-and-displaying records on demand without persisting a derivative DB is the safe path. Include a "Powered by Open Food Facts" attribution in the food-search empty state and About screen.

**Nutritionix** (~1.9M items, 92% UPC match rate, NLP free-text parsing) is the paid fallback for barcodes not in OFF and the natural-language parser for free-text logs ("I ate a chicken Caesar wrap from Sweetgreen"). This fixes FBB's US restaurant coverage gap. Pricing: no free tier (removed 2024 due to abuse); Starter ~$299/mo; Enterprise from $1,850/mo; >100K MAU is custom — confirm with sales before PRD finalization.

**USDA FoodData Central** (~400K items, public domain, no rate limits) seeds a ~150-item universal-foods JSON shipped with the app (chicken breast, ground beef 80/20, white rice cooked, oats, eggs, broccoli, almonds, etc.) keyed on `fdc_id` for provenance. Loaded into local `food` table on first launch — makes day-1 logging instant.

**Barcode scanning.** **iOS: `AVCaptureMetadataOutput` for the live-preview loop** (lowest overhead, 30+ fps, restrict symbologies to `.ean13, .ean8, .upce, .upca, .code128`), with **iOS 18's Vision `DetectBarcodesRequest`** (Swift 6 async API) as a still-frame fallback when live capture can't lock. **Android: ML Kit bundled `barcode-scanning:17.3.0`** (model in app, ~2.4 MB, offline) — not the GMS-delivered variant, to avoid Play Services dependency conflicts. CameraX 1.4.x + ML Kit + `MlKitAnalyzer` is the canonical Compose stack. Decode-to-UI <150ms typical; full barcode → nutrition card visible <800ms including network.

**Recipe + nutrition schema with Phase 4 AI-photo room reserved:**

```sql
CREATE TABLE food_log_entry (
    id TEXT PRIMARY KEY, user_id TEXT, consumed_at INTEGER,
    meal TEXT, food_id TEXT, food_source TEXT, recipe_id TEXT,
    servings REAL,
    calories REAL, protein_g REAL, carb_g REAL, fat_g REAL,
    source TEXT CHECK(source IN ('manual','barcode','recipe','ai_photo')),
    photo_id TEXT  -- nullable; populated only by Phase 4 AI photo logging
);
```

Macro totals are denormalized into `food_log_entry` on insert for fast daily aggregation; recompute on edit. Daily target rings (Apple Fitness style: triple-ring for Calories outer, Protein middle, Carbs/Fat split inner) implemented as a custom `Canvas`/`Shape` view in SwiftUI and `Canvas` `drawArc` in Compose — Swift Charts `SectorMark` is sized for pie, not rings. Quick-add recents from the last 30 days surface as a horizontal chip strip above search.

## 12. Engineering scope and team shape

**Phase 1 envelope: ~20–30 engineer-months of build + ~5–9 engineer-months of test/CI infrastructure = ~25–40 engineer-months total.** Decomposition (rough ranges): logger with all timer modes 4–6 EM; Movement Library 2–3 EM; workout history + charts 2–3 EM; nutrition logging 3–5 EM (depending on food DB licensing decision); PowerSync integration + schema + connector 2–3 EM; migration tooling 2–3 EM (could be 6 EM if AppRabbit data is hostile); auth + paywall + onboarding 1.5–2 EM; Bridge Week / program engine 1–2 EM; app-wide polish + accessibility + App Store + beta 2–3 EM.

**Industry benchmarks corroborate.** Hevy's founders (Guillem Ros + Desmond McNamee, both ex-8fit) launched their MVP ~6 months in as a two-person team writing native Swift + Kotlin separately. They reached 2M downloads in 4 years and $2M ARR with a 9-person team — engineering ~half of that. The Strong app is solo-developer and notably slower on bug-fix cadence post-MVP, illustrating the ceiling of solo dev on a maturing product.

**Recommended team shape: 4 engineers (2 iOS + 2 Android), 1 designer, 0.5 PM, with QA ramp from beta.** No KMP in v1 — duplicate native code for the timer/state-machine and program math (each <2K LOC per platform). Plan a **post-launch KMP carve-out** for shared logger state machine + e1RM/program math in v1.5; Touchlab's guidance is unanimous that retrofitting KMP into existing native codebases is well-trodden, while introducing it during a v1 build adds tooling complexity that slows shipping. **Reject Compose Multiplatform UI** for v1 — Compose for iOS went stable May 2025 (CMP 1.8.0) and works, but FBB's brand-premium positioning rewards native feel; iOS users can spot cross-platform UI smell.

**Test strategy: ~5–9 EM of foundational infrastructure.** Unit + DAO tests with fixtures (1–2 EM); snapshot tests via `swift-snapshot-testing` and Compose Preview Screenshot Testing (Google's 2026 default; use Roborazzi only for flows requiring taps/scrolls; avoid Paparazzi for Compose-heavy UIs) (1–2 EM); PowerSync integration test harness using `PowerSyncDatabase.inMemory` for isolated DAO tests plus Testcontainers spinning up Postgres + a self-hosted PowerSync container for two-device convergence tests (1.5–2 EM); E2E smoke suite in **Maestro** (YAML-based, single suite covers both platforms, dominant 2026 choice; reserve XCUITest/Espresso only for deep-platform-specific flows) (1–2 EM); CI on **GitHub Actions with macOS-15 runners** (default for indie/small-team mobile shops in 2026; reserve Bitrise/Codemagic only if non-engineers trigger builds) (0.5–1 EM).

## 13. FBB content audit and migration scope

**Persist tracks confirmed (4 active, sometimes marketed as 5):** PUMP LIFT (3x/4x/5x weekly variants), PUMP CONDITION (3x/4x/5x), PERFORM (5x, only track with Olympic lifting), MINIMALIST (4x, travel-friendly DBs). PILLARS appears in older marketing as a 4-day/60-min track but is absent from the current FAQ — likely deprecated or renamed to MINIMALIST. **"Hybrid Running" track was not confirmed as a discrete Persist track** as of May 2026; what exists is users layering running on top of PUMP LIFT plus an FBB blog post on running + strength. Verify with stakeholders.

**Year-long architecture confirmed verbatim** from FBB's own deload-week blog: *"After every two 6-week training cycles in Persist, we have a Bridge week to deload before the next training block starts."* Math: (6+6+1) × 4 = 52 weeks. Pre-deload weeks ramp into "the over reaching state" then dial back to Week 1 of the next cycle.

**Workshops confirmed:** PUMP 40 (8-week, 4 sessions/wk, 40-min, ~32 lifting workouts), AEROBIC 40 (8-week, ~32 cardio workouts), CARDIO 30/30 (30-min aerobic), FBB 101 (8 onboarding workouts in-app + a separate 8-video legacy course with 45-page workbook), OLY BUILDING (6-week Olympic, July 2024+), Bodyweight workshop (~50 bodyweight workouts), Pancake Challenge (3+ editions × 30 daily mobility videos = 90+ videos by Adam Fetter). Confirmed bonus-ebook bundle: 94 extra workouts.

**Tempo notation convention confirmed verbatim** from FBB's `/blogs/articles/workout-tempo`: 4-digit `eccentric – pause-bottom – concentric – pause-top`, with **X = "explosive"** and FBB-specific **A = "assisted concentric"** (seen in Nordic Hamstring Curl Negatives `40A0`). Confirmed examples in real FBB programming: Back Squat 30X1 (most common), Strict Pull Up 31X1, DB Bench Press 31X0, Goblet Squat 4020, Skull Crusher 20X0, Chainsaw Row 20X2. Variations seen: 30X1, 31X1, 30X0, 20X0, 20X1, 21X1, 21X0, 2110, 31X0, 12X1, 11X1, 1010, 20X2, 4020, 40A0.

**RPE convention confirmed: 1–10 scale, with occasional RIR parenthetical** ("6/7 out of 10 RPE (3-4 reps left in the tank)"). Concrete examples: *"Set 1: 12 reps @ 20X1 – RPE 7 / Set 2: 10 reps @ 20X1 – RPE 7 / Set 3: 8 reps @ 20X1 – RPE 7 / Set 4: Subtract 10-15% of the weight from Set 3 and perform a max rep set @ 20X0 – RPE 10 (form failure)."* Percent-of-1RM is **deliberately rare** in FBB programming: *"You may be used to working off percentages... but the truth is that we're not robots, and 85% on one day will feel like 110% on the next."* It appears mostly in Olympic peaking blocks ("75-80% of your maximal loads").

**Programming primitives confirmed in real FBB programs (verbatim examples available):** A1/A2 supersets with separate rest, EMOM (alternating-movement and 3-movement-rotation forms), Every-90sec / Every-75sec / Every-3:30 / Every-3min intervals, AMRAP rep ladders (`12min AMRAP 2-4-6-8-10-12-14`), Olympic complexes (`1 Hang Power Snatch + 2 Hang Snatch + 1 Snatch x 6 Sets`), unilateral notation (`6-8/side`, `6-8/arm`, `6-8/leg`, alternating descending Right/Left), For Time with descending rep schemes, drop sets via "subtract 10-15%" instructions, contrast pairs (heavy lift + plyo/cardio), Continuous Movement (no rest, no score), gendered cal targets on conditioning machines (`14/12 Cals`), inline equipment alternates ("use jump stretch band as needed"), and the late-2025 in-app "swap any exercise" feature confirming substitution as a structured primitive going forward.

**Migration scope estimate (confidence varies):**
- ~10 active track configurations (4 tracks × frequency variants)
- ≥8 workshops + 94 confirmed bonus-ebook workouts + ~50 bodyweight + ~30+ pancake + accumulated weekly cycles since 2017 = **~2,000–4,000+ unique daily workouts** (needs DB query)
- **Movement Library: ~400–800 unique demos estimated** (NOT publicly confirmed — recommend pulling from FBB CMS directly)
- **Mobility Library: ~150–300 videos estimated** (NOT publicly confirmed)
- ~200 weekly delivery PDFs/year × multi-year history = several hundred PDF artifacts
- Coach Tip videos: 10–20 per cycle × 4+ years = 200+

## 14. Edge cases and FBB failure modes

**The "playing a video wipes rep scheme" bug is fixed by hoisting workout state and presenting video as a modal overlay, not a navigation push** (full architectural rationale in §4 above). The correct invariant — *"The in-flight workout document is owned by a single ViewModel rooted at the app shell. Every screen reads/writes through it. No screen owns workout state in its own local scope."* — must be a non-negotiable rule in the PRD.

**Network-error save patterns** are PowerSync-native: every local SQLite write is intercepted into the persistent FIFO `ps_crud` upload queue, durable across app restarts and crashes, drained when connectivity returns via your `uploadData()` callback with automatic retry/backoff. Idempotency comes from client-generated UUID v7 row IDs upserted server-side via `INSERT ... ON CONFLICT (id) DO UPDATE`. Conflict resolution defaults to last-write-wins per row with deletes-win.

**Backgrounded app during long workout — different patterns per platform.** **iOS**: never rely on `Timer.scheduledTimer` running in background; compute elapsed time on demand via `Date.now - workout.startedAt` whenever the view re-renders (timer is purely for UI tick). For audio rest-timer cues while backgrounded, the modern (2025+) Apple-blessed pattern is **scheduled local notifications** (`UNUserNotificationCenter`) at the rest-timer's expiry time — the app does not need to be alive — *not* the older "play silent audio to keep alive" trick which is rejected by App Review. Live Activities (`ActivityKit` with `ProgressView(timerInterval:)`) are the modern lock-screen + Dynamic Island surface, but Phase 2. **Android**: use a **Foreground Service of type `FOREGROUND_SERVICE_TYPE_HEALTH`** (introduced for fitness in Android 14, requires `FOREGROUND_SERVICE_HEALTH` permission) — `health` does NOT have the timeout cap that `dataSync` and `mediaProcessing` got in Android 15+. Use `AlarmManager.setExactAndAllowWhileIdle(...)` for the precise expiry alarm (fires even in Doze), backed up by a high-priority notification. **Persist `workout.startedAt` and every set commit to local SQLite synchronously on the user-action thread.** Do not depend on a long-running timer. Logger must survive 90 minutes of phone backgrounding because *the state is on disk, not in memory*.

**Mid-workout subscription expiry — graceful degradation pattern.** Check entitlement at workout-start only, never on every set save. Cache `workout.entitlementVerified = true` for the workout duration. If the RevenueCat `customerInfoUpdateListener` fires mid-workout indicating revocation, **defer enforcement until workout completion** — show a non-blocking banner ("Your subscription expired — renew before your next workout") but allow the in-flight session to finish and sync. RevenueCat caches `CustomerInfo` for **3 days when offline**, so users with flaky connections aren't kicked out. Configure 14-day grace period at the product level for billing-issue users.

**Mid-workout time-zone change.** Schema:

```sql
workouts (
  id uuid pk, user_id uuid,
  started_at timestamptz NOT NULL,    -- UTC
  started_at_tz text NOT NULL,         -- IANA tz id at start, e.g. 'America/New_York'
  completed_at timestamptz,
  completed_at_tz text,
  duration_seconds int generated...    -- (completed - started)
)
```

Display in the user's *current* device timezone on later reads (matches mental model "I trained on Tuesday at 6pm"). Show originating TZ as a small subtitle on the workout detail screen. Duration is `completed_at - started_at` (a TimeInterval, immune to TZ).

**iCloud / Google multi-device behavior — enforce single-active-workout per user at the server.** A unique partial index `CREATE UNIQUE INDEX active_workout ON workouts (user_id) WHERE status = 'in_progress'`. The "Start Workout" mutation INSERTs `status='in_progress'`; if another device tries, the unique-index violation surfaces in PowerSync's `uploadData()` callback as a 409, which the UI renders as: *"You have an active workout on another device. Resume here, or finish there first."* with a "Take over" button updating `last_active_device_id` and abandoning the other session. **Far simpler than CRDT-merging two parallel set logs** and reflects athlete reality: one human, one workout at a time.

**Crash mid-workout recovery.** Persist on every `✓` set save (not at workout end) — the local SQLite write is ground truth. PowerSync's `ps_crud` queue makes this durable across app crashes and OS kills. On app launch, if a workout exists with `status='in_progress'` and `last_set_at < 4 hours ago`, show a top-of-screen banner: *"Resume your in-progress workout? Started 23 minutes ago • 12 sets logged"* with [Resume] [Discard]. After 4 hours of inactivity, auto-mark `status='abandoned'` server-side (still preserves data; surfaces in history with an "abandoned" tag). The UI must never block reentering the app or force a decision — banner-only.

## 15. Privacy, GDPR/CCPA, and App Store compliance

**HealthKit's special rules apply only to data sourced from HealthKit, not to FBB's own logged data.** App Store Review Guideline 5.1.3 prohibits using HealthKit data for advertising or third-party data mining; HealthKit data must not be stored in iCloud (5.1.3 ii). Critically, workouts/sets/RPE/body-weight that the user types into FBB are **FBB-owned data, governed by FBB's own privacy policy and Privacy Label, NOT by 5.1.3** — until and unless FBB writes them to HealthKit. The moment `HKHealthStore.save(workout)` runs, that workout becomes *also* HealthKit data, but FBB's original copy in its own DB remains FBB's data. Practical implication: **mark all HealthKit-sourced fields with a `source` flag and exclude them from any analytics extract that leaves the device**. Health Connect carries equivalent rules per Google Play health-permissions policy.

**DPIA is required before EEA/UK launch.** GDPR Article 35 mandates a DPIA for large-scale processing of special-category data including health data; FBB at 50K MAU + coach-review pipeline + HRV/body-composition imports is squarely in scope. The DPIA must cover: form-review video uploads (special category, possible child athletes — implement age gate, no under-16 in EEA without guardian consent per Article 8); coach-views-athlete cross-user data flows (athlete must affirmatively connect; revocable; audit log of coach views); HRV/RHR import for readiness (just-in-time consent, on-device computation, no HK-sourced fields in third-party analytics); marketing analytics (strip all HK-sourced and special-category fields, pseudonymize user_id); form-review video → external-coach freelancer (DPA with each non-employee coach, sub-processor obligations documented in Article 30 records). Use the UK ICO DPIA template or CNIL PIA tool; review every 12 months and on material processing changes.

**In-app account deletion is mandatory** (Apple Guideline 5.1.1(v) since June 2022; Google Play parity since May 2024). Implementation cascade: server soft-deletes (mark `users.deleted_at`, schedule 30-day hard-delete); hard-delete cascades across `workouts`, `workout_set`, `body_metric`, `food_log_entry`, `recipe`, `chart`, `coach_athlete_link`, `messages`, `media`; client calls `powersync.disconnectAndClear()` then drops the SQLite file, clears `URLCache`, image caches, `UserDefaults` keys; **revoke the Sign in with Apple `refresh_token` via `POST appleid.apple.com/auth/revoke`**; delete athlete-uploaded form-review videos via Bunny's `DELETE /library/{libraryId}/videos/{videoId}`; call RevenueCat `DELETE /v1/subscribers/{app_user_id}`. Document that users must cancel platform-managed subscriptions via Apple ID Settings / Play Account UI (apps cannot cancel them on the user's behalf).

**DSAR export** (GDPR Articles 15 + 20): in-app "Export my data" button → server generates a signed-URL ZIP containing JSON+CSV per table (workouts, sets, body_metrics, food_log, charts, messages) plus original media files. Email the link to the verified email; URL expires in 7 days. Target SLA <72 hours (GDPR ceiling is 30 days).

**App Store Privacy Nutrition Label declarations** for FBB: Health & Fitness (linked, not for tracking, used for App Functionality + Analytics on FBB-DB only + Product Personalization), Contact Info (email, linked, App Functionality), User Content (photos, form-review videos, messages — linked, App Functionality), Identifiers (linked, App Functionality + Analytics), Usage Data (linked, Analytics + Personalization), Diagnostics (not linked, App Functionality), Purchases (linked, App Functionality). **Do not declare "Used for Tracking" / present an ATT prompt** unless FBB actually links to third-party advertising IDs. **The privacy manifest (`PrivacyInfo.xcprivacy`) is mandatory since May 2024** and must list required-reason API usage and any tracking domains. Google Play Data Safety section parallels these declarations.

**PRD §15 compliance checklist** (must ship on day one): privacy policy URL hosted and linked; in-app "Delete my account" ≤ 3 taps from root with 30-day soft-delete; in-app "Export my data" DSAR button; SiwA REST token revocation in deletion flow; PowerSync `disconnectAndClear()` + cache wipe on logout/deletion; Bunny + RC subscriber deletion on hard-delete; `PrivacyInfo.xcprivacy` shipped with iOS; App Store Privacy Nutrition Label completed; Google Play Data Safety completed; Health Connect rationale activity declared in `AndroidManifest.xml`; all HealthKit / Health Connect requests just-in-time; `source` flag on body-metric and activity records; HealthKit data NOT stored in iCloud; DPIA completed before EEA launch and reviewed annually; coach DPA template; Article 30 records maintained; DPO appointed (required given large-scale special-category processing, Article 37(1)(c)); coach-view audit log; default retention policies (form-review videos auto-delete 30 days post-review unless saved); age gate at signup; no HealthKit data used for advertising.

---

## Decision summary

| Layer | Decision | Rationale |
|---|---|---|
| **Migration risk** | Pull AppRabbit master agreement; initiate Apple App Transfer with Cliff Kohut as parallel workstream | Highest-risk blocker; without it, every existing subscriber must repurchase |
| **Sync substrate** | PowerSync Pro ($49/mo); Sync Streams edition 3; row-per-set; LWW + UUID idempotency; `getCrudTransactions()` for atomic uploads | GA, native SDKs, server-authoritative, Postgres-source, only viable competitor |
| **Local DB** | GRDB 7 on iOS, Room 2.8 on Android, schemas duplicated, FileProtection (no SQLCipher) | Mature; alpha PowerSync ORM bridges deferred; SQLCipher unneeded without HIPAA |
| **CMS** | Sanity with custom Tempo/RPE Studio inputs; document-level + field-level i18n; GROQ webhook → Postgres mirror → PowerSync | Schema-as-TS, character-level multiplayer, only credible alternative is Payload |
| **Video** | Bunny Stream delivery + storage; Mux Data SDKs for analytics; AVPlayer + Media3 ExoPlayer native | ~$56K/yr savings vs Mux; Mux Data fills analytics gap; no DRM in Phase 1 |
| **Subscriptions** | RevenueCat Pro (~$1,667/mo at $2M ARR); multi-attach entitlements (workshops survive Persist cancellation); webhook → Postgres → PowerSync | Industry standard; multi-attach matches business rule |
| **Auth** | Supabase Auth for magic links; native ASAuthorizationController + Credential Manager; RS256 JWT 10-min + opaque rotating refresh; entitlements NEVER in JWT | Cheapest at scale; PowerSync JWKS-compatible; revocation latency demands DB-driven entitlements |
| **Health** | `HKWorkoutBuilder` (no session) + `.functionalStrengthTraining` default; iOS 18 Workout Effort Score for RPE; Health Connect 1.1.x with WorkManager polling | Phase 1 doesn't need live session; Effort Score is a real differentiator |
| **Charts** | Swift Charts (iOS) + Vico 2.2 (Android); identical SQL aggregation engine; LTTB downsampling >500 pts | Native, zero-deps on iOS; Vico actively maintained, Material 3, KMP-capable |
| **Nutrition** | Open Food Facts primary + Nutritionix paid fallback + USDA seed; AVFoundation (iOS) + ML Kit bundled (Android) for barcodes | ~$2-3.5K/mo at 50K MAU; broadest coverage; Phase 4 photo-AI room reserved in schema |
| **Logger UX** | Tabular set rows with line-below "Last:"; segmented RPE buttons; tempo pill with tooltip; long-press for skipped/failed; Hevy-style superset auto-scroll on by default for groups; Olympic-complex one-row pattern; stacked unilateral L/R rows; AMRAP back-off prefill at 70% of last set | Differentiated where competitors fail; Hevy-grade where they don't |
| **Video pinning** | iOS `.fullScreenCover` + `AVPlayer` in `@StateObject`; Android `Dialog`/`ModalBottomSheet` + ViewModel hoisted to nav-graph root | Fixes the AppRabbit "wipes rep scheme" bug class architecturally |
| **Background** | Persist on every `✓`; iOS local notifications for rest-timer expiry (no silent-audio trick); Android FOREGROUND_SERVICE_TYPE_HEALTH + AlarmManager exact alarm | Survives 90-min backgrounding by design; disk is ground truth |
| **Multi-device** | Server-enforced single-active-workout via unique partial index; "Take over" prompt | Avoids CRDT merge complexity; matches user mental model |
| **Privacy** | DPIA before EEA launch; in-app delete + DSAR export; SiwA token revocation; HealthKit-sourced fields excluded from analytics; no iCloud storage of HK data | Apple/Google mandates + GDPR Article 35 compliance |
| **Team** | 2 iOS + 2 Android engineers, 1 designer, 0.5 PM, QA from beta; no KMP in v1; no Compose Multiplatform UI | Hevy parallel; KMP is a v1.5 carve-out for state machine + math |
| **Test stack** | GitHub Actions macOS-15; PowerSync `inMemory` + Testcontainers for sync convergence; Maestro for E2E; Compose Preview Screenshot Testing | Lean and dominant in 2026 |
| **Scope envelope** | ~25–40 engineer-months total for Phase 1 (build + test infra) | Bottom-up matches Hevy's 6-mo MVP + 12-mo polish trajectory |