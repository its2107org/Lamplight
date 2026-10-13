import Foundation
import WidgetKit

/// The reading list as the app sees it: shown straight away from the copy on hand, then
/// refreshed from GitHub.
@MainActor
final class ReadingList: ObservableObject {
    static let shared = ReadingList()

    @Published private(set) var lineup: Lineup?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var checking = false

    private init() {
        lineup = LineupSource.local()
    }

    var tonight: Night? {
        if let forced = Demo.forcedNight { return lineup?.night(number: forced) }
        return lineup?.tonight()
    }
    var nextNight: Night? { lineup?.next() }

    /// Earlier nights with something left unread.
    var unfinished: [Night] {
        guard let lineup else { return [] }
        let progress = ReadingProgress.shared
        return lineup.past().filter { !progress.isComplete($0) }
    }

    func refresh() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        if let fresh = await LineupSource.fetch() {
            lineup = fresh
            WidgetCenter.shared.reloadAllTimelines()
        }
        lastChecked = Date()
        await Reminders.reschedule()
    }

    /// Tonight's and the next night's reading, downloaded ahead of bedtime.
    func prepareAhead() async {
        guard let lineup else { return }
        var nights: [Night] = []
        if let tonight { nights.append(tonight) }
        if let next = lineup.next() { nights.append(next) }
        await ContentStore.shared.prefetch(nights)
    }
}
