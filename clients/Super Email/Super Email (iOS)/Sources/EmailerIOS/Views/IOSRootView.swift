import SwiftUI

/// The root view that selects between iPhone TabView and iPad NavigationSplitView.
/// Detection uses `UIDevice.current.userInterfaceIdiom` per the requirements.
public struct IOSRootView: View {
    @Environment(IOSAppState.self) private var appState

    public init() {}

    public var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadMainView()
        } else {
            MainTabView()
        }
        #else
        // macOS fallback for SPM builds — show TabView equivalent
        MainTabView()
        #endif
    }
}

#Preview("Root View") {
    IOSRootView()
        .environment(IOSAppState())
}
