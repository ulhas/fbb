import SwiftUI

/// Entry point for the per-track workout flow. One screen, three internal
/// phases (`preStart` / `running` / `summary`).
///
/// Session state is owned by the global `WorkoutStore` (not @State here)
/// so the timer and UI persist when the user switches tabs to peek at
/// Stats, Nutrition, etc. The TabView's `.tabViewBottomAccessory` shows
/// a mini-player whenever a session is running, even from other tabs.
struct WorkoutDetailView: View {
    let trackCode: String
    let weekStartsOn: String
    let scheduledOn: String
    let api: APIClient
    let workoutStore: WorkoutStore

    @State private var loadError: APIError?
    @State private var isLoading = false
    @State private var trackDisplayName: String = ""
    @State private var saveError: APIError?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let session = matchedSession {
                phaseBody(for: session)
            } else if let loadError {
                ErrorCard(
                    title: "Couldn't load workout",
                    message: loadError.errorDescription,
                    isRetryable: loadError.isRetryable,
                    retry: { Task { await load() } }
                )
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
            } else {
                loadingState
            }
        }
        .background(Color.byowBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active, let session = matchedSession {
                SessionPersistence.snapshot(session)
            }
        }
    }

    /// The store's active session — but only if it matches *this*
    /// workout (track + day). Otherwise we treat it as "no session
    /// loaded yet" and show a spinner / error. Prevents leaking another
    /// workout's session into this view.
    private var matchedSession: WorkoutSession? {
        guard let session = workoutStore.activeSession,
              session.trackCode == trackCode,
              session.scheduledOn == scheduledOn else {
            return nil
        }
        return session
    }

    @ViewBuilder
    private func phaseBody(for session: WorkoutSession) -> some View {
        switch session.phase {
        case .preStart:
            PreStartView(
                session: session,
                trackDisplayName: trackDisplayName,
                onStart: { startWorkout() }
            )
        case .running:
            RunningView(
                session: session,
                trackDisplayName: trackDisplayName,
                onEnd: { endWorkout() }
            )
        case .summary, .abandoned:
            SummaryView(
                session: session,
                trackDisplayName: trackDisplayName,
                isSaving: isSaving,
                saveError: saveError,
                onSave: { Task { await save(session: session) } }
            )
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBlock(width: 220, height: 28)
            SkeletonBlock(height: 120, corner: 16)
            SkeletonBlock(height: 220, corner: 16)
            SkeletonBlock(height: 220, corner: 16)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Actions

    private func load() async {
        // If the store already has a matching session, just bind the
        // display name. Don't recreate — that would clobber state.
        if let existing = matchedSession {
            await populateTrackName(fallback: existing.trackCode)
            return
        }
        // No matching session yet: fetch the day and create one.
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await api.day(weekStartsOn: weekStartsOn, scheduledOn: scheduledOn)
            guard let cell = detail.cells.first(where: { $0.track.trackCode == trackCode }) else {
                loadError = .notFound
                return
            }
            trackDisplayName = cell.track.displayName
            let session = WorkoutSession(
                day: cell.day,
                trackCode: trackCode,
                weekStartsOn: weekStartsOn,
                scheduledOn: scheduledOn,
                trackDisplayName: cell.track.displayName
            )
            workoutStore.attach(session)
            loadError = nil
        } catch let error as APIError {
            loadError = error
        } catch {
            loadError = .unknown(error.localizedDescription)
        }
    }

    private func populateTrackName(fallback: String) async {
        if !trackDisplayName.isEmpty { return }
        // Best-effort: try the cached day detail.
        do {
            let detail = try await api.day(weekStartsOn: weekStartsOn, scheduledOn: scheduledOn)
            if let cell = detail.cells.first(where: { $0.track.trackCode == trackCode }) {
                trackDisplayName = cell.track.displayName
                return
            }
        } catch {}
        trackDisplayName = fallback
    }

    private func startWorkout() {
        workoutStore.start()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endWorkout() {
        workoutStore.end()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func save(session: WorkoutSession) async {
        isSaving = true
        defer { isSaving = false }
        let result = await SessionSync.upload(session, api: api)
        switch result {
        case .synced:
            saveError = nil
            workoutStore.clear()
            dismiss()
        case .keptLocal(let error):
            saveError = error
        }
    }
}
