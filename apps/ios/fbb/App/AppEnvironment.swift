import Foundation
import Observation

/// Lightweight DI container. Holds the long-lived dependencies that the
/// ViewModels and Views depend on. Mounted once at app launch in `fbbApp`.
@Observable
@MainActor
final class AppEnvironment {
    let api: APIClient
    let entitlements: EntitlementsStore
    let clock: any DateProvider

    init(
        api: APIClient = APIClient(),
        entitlements: EntitlementsStore? = nil,
        clock: any DateProvider = SystemDateProvider()
    ) {
        self.api = api
        self.entitlements = entitlements ?? EntitlementsStore()
        self.clock = clock
    }
}
