import SwiftUI

@main
struct fbbApp: App {
    @State private var api = APIClient()
    @State private var entitlements = EntitlementsStore()

    var body: some Scene {
        WindowGroup {
            RootView(api: api, entitlements: entitlements)
                .environment(entitlements)
        }
    }
}
