import SwiftUI

struct RootView: View {
    private let api: APIClient
    private let userStore: UserStore
    private let workoutStore: WorkoutStore
    @State private var homeVM: HomeViewModel
    @State private var todayPath = NavigationPath()
    @State private var selection: AppTab = .today
    @State private var showEndConfirm = false

    init(api: APIClient, userStore: UserStore, workoutStore: WorkoutStore) {
        self.api = api
        self.userStore = userStore
        self.workoutStore = workoutStore
        _homeVM = State(
            wrappedValue: HomeViewModel(
                api: api,
                userStore: userStore
            )
        )
    }

    enum AppTab: Hashable {
        case community, stats, today, nutrition, aiCoach
    }

    var body: some View {
        baseTabs
            .modifier(WorkoutAccessoryModifier(
                workoutStore: workoutStore,
                onTapAccessory: surfaceActiveWorkout,
                onEndWorkout: { showEndConfirm = true }
            ))
            .confirmationDialog(
                "End workout?",
                isPresented: $showEndConfirm,
                titleVisibility: .visible
            ) {
                Button("End workout", role: .destructive) {
                    workoutStore.end()
                    surfaceActiveWorkout()
                }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("You'll see your summary and can add notes before saving.")
            }
    }

    private var baseTabs: some View {
        TabView(selection: $selection) {
            Tab("Community", systemImage: "person.3.fill", value: AppTab.community) {
                NavigationStack {
                    CommunityView()
                        .navigationTitle("Community")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Stats", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.stats) {
                NavigationStack {
                    StatsView(userStore: userStore)
                        .navigationTitle("Stats")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Today", systemImage: "flame.fill", value: AppTab.today) {
                NavigationStack(path: $todayPath) {
                    HomeView(vm: homeVM)
                        .navigationDestination(for: NavRoute.self) { route in
                            switch route {
                            case .week(let weekStartsOn):
                                WeekDetailView(weekStartsOn: weekStartsOn, api: api)
                            case let .workout(trackCode, week, day):
                                WorkoutDetailView(
                                    trackCode: trackCode,
                                    weekStartsOn: week,
                                    scheduledOn: day,
                                    api: api,
                                    workoutStore: workoutStore
                                )
                            case .profile:
                                ProfileView(api: api, userStore: userStore)
                                    .navigationTitle("Profile")
                                    .navigationBarTitleDisplayMode(.inline)
                            }
                        }
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(value: NavRoute.profile) {
                                    ProfileAvatarButton()
                                }
                                .accessibilityLabel("Open profile")
                                .accessibilityHint("Account, tracks, and settings")
                            }
                        }
                }
            }

            Tab("Nutrition", systemImage: "fork.knife", value: AppTab.nutrition) {
                NavigationStack {
                    NutritionView()
                        .navigationTitle("Nutrition")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("AI Coach", systemImage: "sparkles", value: AppTab.aiCoach) {
                NavigationStack {
                    SupportView()
                        .navigationTitle("AI Coach")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.fbbOrange)
    }

    private func surfaceActiveWorkout() {
        guard let route = workoutStore.activeRoute else { return }
        selection = .today
        todayPath = NavigationPath([route])
    }
}

/// Conditionally attaches `tabViewBottomAccessory` and the related
/// `tabBarMinimizeBehavior` only while a workout is in flight.
///
/// Returning `EmptyView` from the accessory closure still reserves
/// space — applying the modifier itself conditionally is the only way
/// to truly hide it. The minimize behavior is also kept under the same
/// condition so that scrolling inside Today / Stats / etc. *outside* a
/// workout doesn't randomly collapse the tab bar.
private struct WorkoutAccessoryModifier: ViewModifier {
    let workoutStore: WorkoutStore
    let onTapAccessory: () -> Void
    let onEndWorkout: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if workoutStore.hasRunningSession,
           let session = workoutStore.activeSession {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    WorkoutMiniPlayer(
                        session: session,
                        onTap: onTapAccessory,
                        onEnd: onEndWorkout
                    )
                }
        } else {
            content
        }
    }
}
