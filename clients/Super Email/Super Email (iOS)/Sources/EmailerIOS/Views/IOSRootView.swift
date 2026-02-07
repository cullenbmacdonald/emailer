import SwiftUI
import EmailClientKit

/// The root view that selects between iPhone TabView and iPad NavigationSplitView.
/// Detection uses `UIDevice.current.userInterfaceIdiom` per the requirements.
public struct IOSRootView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadMainView()
        } else {
            MainTabView()
        }
        #else
        // macOS fallback for SPM builds -- show TabView equivalent
        Text("iOS Root View")
        #endif
    }
}
