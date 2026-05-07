import SwiftUI
import WatchKit
import FBBDesignSystem

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
        let session = env.session
        ScrollView {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.fbbOrange)
                    .padding(.top, Spacing.xs)

                Text("Done!")
                    .font(.fbb.watchTitle)
                    .foregroundStyle(Color.inkPrimary)

                statsGrid(
                    elapsed: session.elapsedSeconds,
                    volume: session.totalVolumeKg,
                    sets: session.setLogs.count
                )

                weightToggle

                Button {
                    save()
                } label: {
                    switch saveState {
                    case .saving:
                        ProgressView()
                            .tint(.white)
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
    private func statsGrid(elapsed: Int, volume: Double, sets: Int) -> some View {
        let cellHeight: CGFloat = 50
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                statTile(label: "TIME", value: formatElapsed(elapsed), height: cellHeight)
                statTile(label: "SETS", value: "\(sets)", height: cellHeight)
            }
            statTile(
                label: env.session.weightUnit == .kg ? "VOLUME (KG)" : "VOLUME (LB)",
                value: formatVolume(volume),
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

    private var weightToggle: some View {
        HStack(spacing: Spacing.xxs) {
            unitChip("kg", isSelected: env.session.weightUnit == .kg) { env.session.weightUnit = .kg }
            unitChip("lb", isSelected: env.session.weightUnit == .lb) { env.session.weightUnit = .lb }
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

    private func save() {
        guard let payload = env.session.makePayload() else {
            saveState = .failed("Nothing to save.")
            return
        }
        saveState = .saving
        Task {
            do {
                _ = try await env.api.postWorkoutSession(payload)
                saveState = .saved
                WKInterfaceDevice.current().play(.success)
                try? await Task.sleep(nanoseconds: 800_000_000)
                env.session.reset()
                // Pop back to Home
                path = NavigationPath()
            } catch {
                saveState = .failed(error.localizedDescription)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatVolume(_ kg: Double) -> String {
        let value = env.session.weightUnit == .kg ? kg : kg * 2.20462
        if value < 10 { return String(format: "%.1f", value) }
        return "\(Int(value.rounded()))"
    }
}
