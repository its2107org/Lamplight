import AppIntents
import Foundation

// Note: descriptions here must not use company or device trademarks (the App Store rejects them).

struct OpenTonightIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tonight's Reading"
    static var description = IntentDescription("Opens tonight's reading where you left off.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.readTonight()
        return .result()
    }
}

struct WhatsTonightIntent: AppIntent {
    static var title: LocalizedStringResource = "What's Tonight's Reading"
    static var description = IntentDescription("Tells you tonight's theme and how long the reading will take.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let list = ReadingList.shared
        guard let night = list.tonight else {
            if let next = list.nextNight {
                return .result(dialog: "No reading tonight. The next night is \(GoodnightView.dayName(next.day)): \(next.headline).")
            }
            return .result(dialog: "There's nothing on the reading list yet.")
        }
        let left = night.pieces.filter { !ReadingProgress.shared.isDone($0) }
        if left.isEmpty { return .result(dialog: "You've finished tonight's reading. Goodnight.") }
        let minutes = left.reduce(0) { $0 + ContentStore.shared.estimatedMinutes($1) }
        return .result(dialog: "Tonight: \(night.headline). \(left.count) pieces left, about \(minutes) minutes.")
    }
}

struct LamplightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTonightIntent(),
            phrases: [
                "Open tonight's reading in \(.applicationName)",
                "Start reading in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Tonight's Reading",
            systemImageName: "moon.stars"
        )
        AppShortcut(
            intent: WhatsTonightIntent(),
            phrases: [
                "What's tonight's reading in \(.applicationName)",
                "What's in \(.applicationName) tonight"
            ],
            shortTitle: "What's Tonight",
            systemImageName: "book"
        )
    }
}
