import SwiftUI

/// Generic placeholder view for tabs/views that will be implemented in later phases.
struct IOSPlaceholderView: View {
    let title: String
    let icon: String
    let phase: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: icon,
            description: Text("Coming in \(phase)")
        )
        .navigationTitle(title)
    }
}

#Preview("Placeholder") {
    NavigationStack {
        IOSPlaceholderView(title: "Reading Queue", icon: "book", phase: "Phase 2")
    }
}
