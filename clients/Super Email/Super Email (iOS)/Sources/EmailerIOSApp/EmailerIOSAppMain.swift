import SwiftUI
import EmailClientKit
#if os(iOS)
import BackgroundTasks
#endif

@main
struct EmailerIOSApp: App {
    @State private var appState = AppState()
    @State private var emailStore = EmailStore()
    @State private var recommendationStore = RecommendationStore()
    @State private var digestStore = DigestStore()
    @State private var coordinator: AppCoordinator?
    @Environment(\.scenePhase) private var scenePhase

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
                    #if os(iOS)
                    registerBackgroundTasks()
                    #endif
                }
        }
        #if os(iOS)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard let coordinator else { return }
            switch newPhase {
            case .background:
                coordinator.didEnterBackground()
                scheduleBackgroundRefresh()
            case .active:
                if oldPhase == .background || oldPhase == .inactive {
                    Task { @MainActor in
                        await coordinator.willEnterForeground()
                    }
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        #endif
    }

    #if os(iOS)
    // MARK: - Background Tasks

    private static let backgroundRefreshIdentifier = "com.cullenbmacdonald.emailer.refresh"

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(refreshTask)
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh scheduling failed -- not critical
        }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundRefresh()

        let fetchTask = Task { @MainActor in
            guard let coordinator else {
                task.setTaskCompleted(success: true)
                return
            }
            // Check for new digest data
            if let client = coordinator.apiClient {
                do {
                    let digest = try await client.fetchLatestDigest()
                    digestStore.setLatestDigest(digest)
                    await coordinator.cacheCurrentData()
                } catch {
                    // No new digest -- that's fine
                }
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            fetchTask.cancel()
        }
    }
    #endif
}
