import SwiftUI
import BYOWDesignSystem
import BYOWWorkoutKitCore

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
        VStack(spacing: 0) {
            dateStepper(vm: vm)
            Divider()
            switch vm.state {
            case .idle, .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .empty(let reason):
                emptyState(reason: reason, vm: vm)

            case .failed(let message):
                failedState(message: message, vm: vm)

            case .loaded(let cells, _, _):
                loadedList(cells: cells)
            }
        }
    }

    private func dateStepper(vm: WatchHomeViewModel) -> some View {
        HStack(spacing: Spacing.xxs) {
            Button {
                vm.goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(vm.canGoPrevious ? Color.byowOrange : Color.inkMuted.opacity(0.5))
            .disabled(!vm.canGoPrevious)

            VStack(spacing: 0) {
                Text(currentDateLabel(vm: vm))
                    .font(.byow.watchTitle)
                    .foregroundStyle(Color.inkPrimary)
                if let date = vm.selectedDate {
                    Text(ISO8601.weekdayShort(date))
                        .font(.byow.label)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                vm.goToNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(vm.canGoNext ? Color.byowOrange : Color.inkMuted.opacity(0.5))
            .disabled(!vm.canGoNext)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.bottom, Spacing.xxs)
    }

    private func currentDateLabel(vm: WatchHomeViewModel) -> String {
        guard let selected = vm.selectedDate else { return "—" }
        return selected == ISO8601.todayString() ? "Today" : ISO8601.prettyDate(selected)
    }

    private func emptyState(reason: String, vm: WatchHomeViewModel) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "figure.run")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
            Text(reason)
                .font(.byow.body)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Button("Retry") {
                Task { await vm.load(force: true) }
            }
            .buttonStyle(.bordered)
            .tint(.byowOrange)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(message: String, vm: WatchHomeViewModel) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.semanticError)
            Text(message)
                .font(.byow.caption)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await vm.load(force: true) }
            }
            .buttonStyle(.bordered)
            .tint(.byowOrange)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func loadedList(cells: [TrainingWeekDayCellRow]) -> some View {
        List {
            // Resume in-progress card pinned on top when an active session exists.
            if env.store.hasRunningSession, let active = env.store.activeSession {
                Section {
                    Button {
                        path.append(WatchRoute.activeSession)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.byowOrange)
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resume")
                                    .font(.byow.watchTitle)
                                    .foregroundStyle(Color.inkPrimary)
                                Text(active.trackCode.replacingOccurrences(of: "_", with: " ").uppercased())
                                    .font(.byow.label)
                                    .foregroundStyle(Color.inkMuted)
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

            ForEach(cells) { cell in
                DayCellRow(cell: cell) {
                    let session = WorkoutSession(
                        day: cell.day,
                        trackCode: cell.track.trackCode,
                        weekStartsOn: cell.track.microcycle.startsOn,
                        scheduledOn: cell.day.scheduledOn,
                        trackDisplayName: cell.track.displayName
                    )
                    env.store.attach(session)
                    env.store.start()
                    path.append(WatchRoute.activeSession)
                }
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
        case .pumpLift, .perform:     return .byowOrange
        case .pumpCondition, .hybridRunning: return .byowTeal
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
                        .font(.byow.label)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(cell.day.displayName)
                    .font(.byow.watchTitle)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if isRestDay {
                    Text("Rest day")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(cell.day.totalExercises) exercises")
                            .font(.byow.caption)
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
