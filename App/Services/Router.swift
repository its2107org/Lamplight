import Foundation

/// Which night is open in the reader, if any.
struct ReaderRequest: Identifiable, Equatable {
    let night: Night
    let start: PieceKind?
    var id: String { "\(night.number)-\(start?.rawValue ?? "next")" }

    static func == (a: ReaderRequest, b: ReaderRequest) -> Bool { a.id == b.id }
}

@MainActor
final class Router: ObservableObject {
    static let shared = Router()

    @Published var reading: ReaderRequest?
    @Published var showSettings = false
    @Published var showPlan = false

    func read(_ night: Night, from start: PieceKind?) {
        reading = ReaderRequest(night: night, start: start)
    }

    /// Opens tonight's reading where you left off (or the next night, on nights off).
    func readTonight() {
        let list = ReadingList.shared
        guard let night = list.tonight ?? list.unfinished.last ?? list.nextNight else { return }
        read(night, from: nil)
    }

    /// lamplight://tonight opens the reader. Anything else just opens the app.
    func handle(_ url: URL) {
        guard url.scheme == "lamplight" else { return }
        switch url.host {
        case "tonight", "read": readTonight()
        case "plan": showPlan = true
        default: break
        }
    }
}
