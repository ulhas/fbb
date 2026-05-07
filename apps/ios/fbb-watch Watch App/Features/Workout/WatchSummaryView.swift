import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore
import FBBWorkoutKitNet

struct WatchSummaryView: View {
    @Environment(WatchAppEnvironment.self) private var env
    @Binding var path: NavigationPath
    @State private var saveState: SaveState = .idle

    enum SaveState {
        case idle
        case saving
        case saved
        case failed(String)
    }

    var body: some View {
        if let session = env.store.activeSession {
            content(session: session)
        } else {
            ContentUnavailableView(
                "No session",
                systemImage: "checkmark.seal",
                description: Text("Nothing to save.")
            )
            .onAppear {
                path = NavigationPath()
            }
        }
    }

    @ViewBuilder
    private func content(session: WorkoutSession) -> some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.fbbOrange)
                    .padding(.top, Spacing.xs)

                Text("Done!")
                    .font(.fbb.watchTitle)
                    .foregroundStyle(Color.inkPrimary)

                statsGrid(session: session)

                weightToggle(session: session)

                Button {
                    save(session: session)
                } label: {
                    switch saveState {
                    case .saving:
                        ProgressView().tint(.white)
                    case .saved:
                        Label("Saved", systemImage: "checkmark")
                    default:
                        Label("Save", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.fbbPrimary)
                .disabled({
                    switch saveState {
                    case .saving, .saved: return true
                    default: return false
                    }
                }())

                if case .failed(let message) = saveState {
                    Text(message)
                        .font(.fbb.caption)
                        .foregroundStyle(Color.semanticError)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Spacing.xs)
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func statsGrid(session: WorkoutSession) -> some View {
        let cellHeight: CGFloat = 50
        let elapsed = session.totalElapsedSeconds()
        let setCount = session.setLog.count
        let volumeKg = totalVolumeKg(setLog: session.setLog)

        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                statTile(label: "TIME", value: SessionMath.formatElapsed(elapsed), height: cellHeight)
                statTile(label: "SETS", value: "\(setCount)", height: cellHeight)
            }
            statTile(
                label: session.weightUnit == .kg ? "VOLUME (KG)" : "VOLUME (LB)",
                value: formatVolume(volumeKg, unit: session.weightUnit),
                height: cellHeight
            )
        }
    }

    private func statTile(label: String, value: String, height: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.fbb.watchMetric)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.fbb.label)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .background(Color.surfaceCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func weightToggle(session: WorkoutSession) -> some View {
        HStack(spacing: Spacing.xxs) {
            unitChip("kg", isSelected: session.weightUnit == .kg) { session.weightUnit = .kg }
            unitChip("lb", isSelected: session.weightUnit == .lb) { session.weightUnit = .lb }
        }
    }

    private func unitChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.fbb.caption.bold())
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, Spacing.sm)
                .background(isSelected ? Color.fbbOrange : Color.surfaceCard, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func save(session: WorkoutSession) {
        saveState = .saving
        Task {
            let result = await SessionSync.upload(session, api: env.api)
            switch result {
            case .synced:
                saveState = .saved
                WKInterfaceDevice.current().play(.success)
                try? await Task.sleep(nanoseconds: 800_000_000)
                env.store.clear()
                path = NavigationPath()
            case .keptLocal(let error):
                saveState = .failed("Saved locally — will retry. \(error.errorDescription ?? "")")
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func totalVolumeKg(setLog: [SetLogEntry]) -> Double {
        setLog.reduce(0) { acc, log in
            guard log.outcome == .completed,
                  let reps = log.actualReps,
                  let kg = log.actualWeightKg
            else { return acc }
            return acc + Double(reps) * kg
        }
    }

    private func formatVolume(_ kg: Double, unit: WeightUnit) -> String {
        let value = unit == .kg ? kg : kg * 2.20462
        if value < 10 { return String(format: "%.1f", value) }
        return "\(Int(value.rounded()))"
    }
}
