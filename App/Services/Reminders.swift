import Foundation
import UserNotifications

/// A gentle nudge on reading nights: "Tonight: How do you know? · Philosophy".
enum Reminders {
    private static let prefix = "windDown-"

    /// Asks permission the first time. Returns whether reminders can be shown.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }

    @MainActor
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let settings = ReaderSettings.shared
        guard settings.reminderOn, let lineup = ReadingList.shared.lineup else { return }
        let calendar = Calendar.current
        let now = Date()
        let upcoming = lineup.nights.compactMap { night -> (Night, Date)? in
            guard let fire = calendar.date(bySettingHour: settings.reminderMinutes / 60, minute: settings.reminderMinutes % 60, second: 0, of: night.day),
                  fire > now else { return nil }
            return (night, fire)
        }
        for (night, fire) in upcoming.prefix(20) {
            let content = UNMutableNotificationContent()
            content.title = "Tonight: \(night.headline)"
            let minutes = ContentStore.shared.totalMinutes(night)
            var body = night.field.map { "\($0). " } ?? ""
            body += "Five pieces, about \(minutes) minutes. Time to wind down."
            content.body = body
            content.sound = nil
            content.userInfo = ["night": night.number]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(night.number)", content: content, trigger: trigger))
        }
    }
}
