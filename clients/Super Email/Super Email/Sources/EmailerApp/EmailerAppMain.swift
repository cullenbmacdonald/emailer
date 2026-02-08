import SwiftUI
import EmailClientKit

@main
struct EmailerApp: App {
    @State private var appState = AppState()
    @State private var emailStore = EmailStore()
    @State private var recommendationStore = RecommendationStore()
    @State private var digestStore = DigestStore()
    @State private var focusCoordinator = FocusCoordinator()
    @State private var coordinator: AppCoordinator?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(emailStore)
                .environment(recommendationStore)
                .environment(digestStore)
                .environment(focusCoordinator)
                .onAppear {
                    if coordinator == nil {
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
        .defaultSize(width: 1200, height: 800)
        #if os(macOS)
        .commands {
            AppCommands(appState: appState, focusCoordinator: focusCoordinator)
        }
        #endif
    }
}
