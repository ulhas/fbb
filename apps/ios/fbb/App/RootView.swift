import SwiftUI

struct RootView: View {
    private let api: APIClient
    private let entitlements: EntitlementsStore
    @State private var homeVM: HomeViewModel
    @State private var todayPath = NavigationPath()

    init(api: APIClient, entitlements: EntitlementsStore) {
        self.api = api
        self.entitlements = entitlements
        _homeVM = State(
            wrappedValue: HomeViewModel(
                api: api,
                entitlements: entitlements
            )
        )
    }

    var body: some View {
        TabView {
            Tab("Community", systemImage: "person.3.fill") {
                NavigationStack {
                    CommunityView()
                        .navigationTitle("Community")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Stats", systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack {
                    StatsView(entitlements: entitlements)
                        .navigationTitle("Stats")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("Today", systemImage: "flame.fill") {
                NavigationStack(path: $todayPath) {
                    HomeView(vm: homeVM)
                        .navigationDestination(for: NavRoute.self) { route in
                            switch route {
                            case .week(let weekStartsOn):
                                WeekDetailView(weekStartsOn: weekStartsOn, api: api)
                            case let .day(week, day):
                                DayDetailView(weekStartsOn: week, scheduledOn: day, api: api)
                            case .profile:
                                ProfileView(api: api, entitlements: entitlements)
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

            Tab("Nutrition", systemImage: "fork.knife") {
                NavigationStack {
                    NutritionView()
                        .navigationTitle("Nutrition")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("AI Coach", systemImage: "sparkles") {
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
