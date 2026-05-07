import SwiftUI
import FBBDesignSystem
import FBBWorkoutKitCore

struct WatchHomeView: View {
    @Environment(WatchAppEnvironment.self) private var env
    @Binding var path: NavigationPath
    @State private var vm: WatchHomeViewModel?

    var body: some View {
        Group {
            if let vm {
                content(for: vm)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if vm == nil {
                vm = WatchHomeViewModel(api: env.api)
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(for vm: WatchHomeViewModel) -> some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            emptyState

        case .failed(let message):
            failedState(message: message, vm: vm)

        case .loaded(let cells):
            loadedList(cells: cells)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "figure.run")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
            Text("No workout today")
                .font(.fbb.body)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func failedState(message: String, vm: WatchHomeViewModel) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.semanticError)
            Text(message)
                .font(.fbb.caption)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await vm.load(force: true) }
            }
            .buttonStyle(.bordered)
            .tint(.fbbOrange)
        }
        .padding()
    }

    @ViewBuilder
    private func loadedList(cells: [TrainingWeekDayCellRow]) -> some View {
        List {
            // Resume in-progress card pinned on top when an active session exists.
            if env.session.hasActiveSession {
                Section {
                    Button {
                        path.append(WatchRoute.activeSession)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.fbbOrange)
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resume")
                                    .font(.fbb.watchTitle)
                                    .foregroundStyle(Color.inkPrimary)
                                if let trackCode = env.session.trackCode {
                                    Text(trackCode.replacingOccurrences(of: "_", with: " ").uppercased())
                                        .font(.fbb.label)
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.inkMuted)
                        }
                        .padding(.vertical, Spacing.xxs)
                    }
                    .listRowBackground(
                        Color.surfaceCard
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                }
            }

            Section {
                ForEach(cells) { cell in
                    DayCellRow(cell: cell) {
                        env.session.start(day: cell.day, trackCode: cell.track.trackCode)
                        path.append(WatchRoute.activeSession)
                    }
                }
            } header: {
                Text("Today")
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .listStyle(.carousel)
    }
}

private struct DayCellRow: View {
    let cell: TrainingWeekDayCellRow
    let onStart: () -> Void

    private var familyIcon: String {
        switch cell.track.family {
        case .pumpLift:        return "dumbbell.fill"
        case .pumpCondition:   return "wind"
        case .perform:         return "flame.fill"
        case .minimalist:      return "circle.dashed"
        case .hybridRunning:   return "figure.run"
        case .workshop:        return "wrench.and.screwdriver.fill"
        case .onramp:          return "arrow.up.right"
        }
    }

    private var familyTint: Color {
        switch cell.track.family {
        case .pumpLift, .perform:     return .fbbOrange
        case .pumpCondition, .hybridRunning: return .fbbTeal
        default:                      return .inkSecondary
        }
    }

    private var isRestDay: Bool {
        cell.day.kind == .rest
    }

    var body: some View {
        Button {
            if !isRestDay {
                onStart()
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: familyIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(familyTint)
                        .frame(width: 22, height: 22)
                        .background(familyTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                    Text(cell.track.displayName)
                        .font(.fbb.label)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(cell.day.displayName)
                    .font(.fbb.watchTitle)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if isRestDay {
                    Text("Rest day")
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(cell.day.totalExercises) exercises")
                            .font(.fbb.caption)
                    }
                    .foregroundStyle(Color.inkMuted)
                }
            }
            .padding(.vertical, Spacing.xxs)
        }
        .disabled(isRestDay)
        .buttonStyle(.pressedScale)
        .listRowBackground(
            Color.surfaceCard
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )
    }
}

enum WatchRoute: Hashable {
    case activeSession
    case summary
}
