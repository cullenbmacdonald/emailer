import SwiftUI
import EmailClientKit

@main
struct EmailerIOSApp: App {
    @State private var appState = AppState()
    @State private var emailStore = EmailStore()
    @State private var recommendationStore = RecommendationStore()
    @State private var digestStore = DigestStore()
    @State private var coordinator: AppCoordinator?

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environment(appState)
                .environment(emailStore)
                .environment(recommendationStore)
                .environment(digestStore)
                .task {
                    let coord = AppCoordinator(
                        appState: appState,
                        emailStore: emailStore,
                        recommendationStore: recommendationStore,
                        digestStore: digestStore
                    )
                    coordinator = coord
                    coord.start()
                }
        }
    }
}
