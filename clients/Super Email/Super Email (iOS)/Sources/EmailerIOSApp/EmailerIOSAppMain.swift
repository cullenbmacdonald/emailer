import SwiftUI
import EmailClientKit

@main
struct EmailerIOSApp: App {
    @State private var appState = IOSAppState()
    @State private var coordinator: IOSAppCoordinator?

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environment(appState)
                .task {
                    let coord = IOSAppCoordinator(appState: appState)
                    coordinator = coord
                    await coord.start()
                }
        }
    }
}
