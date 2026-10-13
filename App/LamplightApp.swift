import SwiftUI
import BackgroundTasks

@main
struct LamplightApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var list = ReadingList.shared
    @StateObject private var progress = ReadingProgress.shared
    @StateObject private var store = ContentStore.shared
    @StateObject private var settings = ReaderSettings.shared
    @StateObject private var router = Router.shared
    @StateObject private var shelf = ShelfLink.shared

    nonisolated private static let refreshTaskID = (Bundle.main.bundleIdentifier ?? "lamplight") + ".refresh"

    init() {
        Demo.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(list)
                .environmentObject(progress)
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(router)
                .environmentObject(shelf)
                .preferredColorScheme(.dark)
                .onOpenURL { router.handle($0) }
                .task { await SelfTest.runIfRequested() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await list.refresh()
                    await shelf.refresh()
                    await list.prepareAhead()
                }
            case .background:
                Self.scheduleRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            Self.scheduleRefresh()
            await ReadingList.shared.refresh()
            await ShelfLink.shared.refresh()
            await ReadingList.shared.prepareAhead()
        }
    }

    /// Checks for new nights and downloads the reading during the day, ready for bedtime.
    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
