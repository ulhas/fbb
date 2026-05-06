import Foundation
import Observation

/// Lightweight DI container. Holds the long-lived dependencies that the
/// ViewModels and Views depend on. Mounted once at app launch in `fbbApp`.
@Observable
@MainActor
final class AppEnvironment {
    let api: APIClient
    let userStore: UserStore
    let clock: any DateProvider

    init(
        api: APIClient = APIClient(),
        userStore: UserStore? = nil,
        clock: any DateProvider = SystemDateProvider()
    ) {
        self.api = api
        self.userStore = userStore ?? UserStore(api: api)
        self.clock = clock
    }
}
