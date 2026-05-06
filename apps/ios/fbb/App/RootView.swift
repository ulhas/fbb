import SwiftUI

struct RootView: View {
    private let api: APIClient
    private let userStore: UserStore
    @State private var homeVM: HomeViewModel
    @State private var todayPath = NavigationPath()
    @State private var selection: AppTab = .today

    init(api: APIClient, userStore: UserStore) {
        self.api = api
        self.userStore = userStore
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
                            case let .day(week, day):
                                DayDetailView(weekStartsOn: week, scheduledOn: day, api: api)
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
}
