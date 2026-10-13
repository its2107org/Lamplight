import Foundation
import UIKit

/// Launch options used by the automatic build check to take screenshots and test every link.
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-LamplightDemo") }

    /// Pretend a given night is tonight (for screenshots).
    static var forcedNight: Int? {
        let value = UserDefaults.standard.integer(forKey: "LamplightDemoNight")
        return value > 0 ? value : nil
    }

    @MainActor
    static func prepare() {
        guard isOn else { return }
        let args = ProcessInfo.processInfo.arguments
        let list = ReadingList.shared
        guard let night = list.tonight else { return }
        if args.contains("-LamplightDemoComplete") {
            ReadingProgress.shared.completeForDemo(night)
        } else {
            ReadingProgress.shared.seedForDemo(night)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            MainActor.assumeIsolated {
                let router = Router.shared
                if args.contains("-LamplightDemoReader") {
                    router.read(night, from: .essay)
                } else if args.contains("-LamplightDemoPDF") {
                    router.read(night, from: .paper)
                } else if args.contains("-LamplightDemoPlan") {
                    router.showPlan = true
                } else if args.contains("-LamplightDemoSettings") {
                    router.showSettings = true
                }
            }
        }
    }
}

/// Tries every link on the reading list and writes what happened to selftest.json.
enum SelfTest {
    @MainActor
    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-LamplightSelfTest"),
              let lineup = ReadingList.shared.lineup else { return }
        let store = ContentStore.shared
        var results: [[String: Any]] = []
        for night in lineup.nights {
            for piece in night.pieces {
                store.refresh(piece)
                let started = Date()
                let content = await store.content(for: piece)
                var row: [String: Any] = [
                    "night": night.number,
                    "kind": piece.kind.rawValue,
                    "title": piece.title,
                    "link": piece.link,
                    "seconds": Int(Date().timeIntervalSince(started))
                ]
                switch content {
                case .article(let article):
                    row["result"] = "text"
                    row["words"] = article.words
                    row["start"] = String(article.html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .split(whereSeparator: \.isWhitespace).prefix(30).joined(separator: " "))
                case .pdf:
                    row["result"] = "pdf"
                    row["minutes"] = store.estimatedMinutes(piece)
                case .web:
                    row["result"] = "original page"
                case .unavailable:
                    row["result"] = "no link"
                }
                results.append(row)
            }
        }
        let summary: [String: Any] = [
            "pieces": results.count,
            "text": results.filter { $0["result"] as? String == "text" }.count,
            "pdf": results.filter { $0["result"] as? String == "pdf" }.count,
            "originalPage": results.filter { $0["result"] as? String == "original page" }.count,
            "results": results
        ]
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: docs.appendingPathComponent("selftest.json"))
        }
    }
}
