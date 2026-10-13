import Foundation

/// The five kinds of reading in a night.
enum PieceKind: String, CaseIterable, Identifiable, Codable {
    case paper, ai, essay, story, poem

    var id: String { rawValue }

    /// Most demanding first, gentlest last, so the night winds down towards sleep.
    static let bedtimeOrder: [PieceKind] = [.paper, .ai, .essay, .story, .poem]

    var label: String {
        switch self {
        case .paper: return "Paper"
        case .ai: return "AI now"
        case .essay: return "Essay"
        case .story: return "Story"
        case .poem: return "Poem"
        }
    }

    var symbol: String {
        switch self {
        case .paper: return "doc.text"
        case .ai: return "sparkles"
        case .essay: return "text.quote"
        case .story: return "book"
        case .poem: return "leaf"
        }
    }

    /// A sensible guess before the piece has been downloaded.
    var typicalMinutes: Int {
        switch self {
        case .paper: return 20
        case .ai: return 10
        case .essay: return 12
        case .story: return 15
        case .poem: return 3
        }
    }
}

/// One thing to read.
struct Piece: Identifiable, Hashable, Decodable {
    var title: String
    var by: String?
    var link: String
    var note: String?
    var readLink: String?
    var minutes: Int?

    var kind: PieceKind = .paper
    var nightNumber: Int = 0

    var id: String { "\(nightNumber)-\(kind.rawValue)" }
    var url: URL? { Self.makeURL(link) }
    /// The copy that reads best (a direct PDF, say), when the reading list gives one.
    var readingURL: URL? { readLink.flatMap(Self.makeURL) ?? url }

    private enum CodingKeys: String, CodingKey {
        case title, by, url, note, readUrl, minutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled"
        by = try? c.decodeIfPresent(String.self, forKey: .by)
        link = (try? c.decodeIfPresent(String.self, forKey: .url)) ?? ""
        note = try? c.decodeIfPresent(String.self, forKey: .note)
        readLink = try? c.decodeIfPresent(String.self, forKey: .readUrl)
        minutes = try? c.decodeIfPresent(Int.self, forKey: .minutes)
    }

    private static func makeURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed) ?? trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap(URL.init(string:))
    }
}

/// One evening's reading.
struct Night: Identifiable, Hashable, Decodable {
    var number: Int
    var dateLabel: String
    var isoDate: String?
    var theme: String?
    var themeLine: String?
    var field: String?
    var paperType: String?
    var learn: String?
    var pieces: [Piece]
    /// The calendar day this night is for (worked out once the whole file is read).
    var day: Date = .distantPast

    var id: Int { number }

    private enum CodingKeys: String, CodingKey {
        case night, date, isoDate, theme, themeLine, field, paperType, learn, items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let number = (try? c.decode(Int.self, forKey: .night)) ?? 0
        self.number = number
        dateLabel = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        isoDate = try? c.decodeIfPresent(String.self, forKey: .isoDate)
        theme = try? c.decodeIfPresent(String.self, forKey: .theme)
        themeLine = try? c.decodeIfPresent(String.self, forKey: .themeLine)
        field = try? c.decodeIfPresent(String.self, forKey: .field)
        paperType = try? c.decodeIfPresent(String.self, forKey: .paperType)
        learn = try? c.decodeIfPresent(String.self, forKey: .learn)
        let items = (try? c.decode([String: Piece].self, forKey: .items)) ?? [:]
        pieces = PieceKind.bedtimeOrder.compactMap { kind in
            guard var piece = items[kind.rawValue] else { return nil }
            piece.kind = kind
            piece.nightNumber = number
            return piece
        }
    }

    var isNewResearch: Bool { paperType?.lowercased().contains("new") == true }

    /// A short heading: the theme if there is one, otherwise the field.
    var headline: String { theme ?? field ?? "Night \(number)" }

    func piece(_ kind: PieceKind) -> Piece? { pieces.first { $0.kind == kind } }
}

/// The whole reading list.
struct Lineup: Decodable {
    var title: String
    var start: String?
    var nights: [Night]

    private enum CodingKeys: String, CodingKey {
        case challenge, start, nights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .challenge)) ?? "Bradbury Nights"
        start = try? c.decodeIfPresent(String.self, forKey: .start)
        nights = (try? c.decode([Night].self, forKey: .nights)) ?? []
        resolveDays()
    }

    static func decode(_ data: Data) -> Lineup? {
        guard let lineup = try? JSONDecoder().decode(Lineup.self, from: data), !lineup.nights.isEmpty else { return nil }
        return lineup
    }

    private mutating func resolveDays() {
        let calendar = Calendar.current
        let iso = DateFormatter()
        iso.calendar = calendar
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        let startDate = start.flatMap { iso.date(from: $0) } ?? Date()
        let startYear = calendar.component(.year, from: startDate)

        let label = DateFormatter()
        label.calendar = calendar
        label.locale = Locale(identifier: "en_GB")
        label.dateFormat = "EEE d MMM yyyy"
        label.isLenient = true

        var previous = calendar.startOfDay(for: startDate)
        for index in nights.indices {
            var night = nights[index]
            if let text = night.isoDate, let date = iso.date(from: text) {
                night.day = calendar.startOfDay(for: date)
            } else if var date = label.date(from: "\(night.dateLabel) \(startYear)") {
                // Lists that run over New Year: never step backwards in time.
                while date < calendar.date(byAdding: .day, value: -1, to: previous)! {
                    date = calendar.date(byAdding: .year, value: 1, to: date)!
                }
                night.day = calendar.startOfDay(for: date)
            } else {
                night.day = calendar.date(byAdding: .day, value: index, to: previous) ?? previous
            }
            previous = night.day
            nights[index] = night
        }
        nights.sort { $0.day < $1.day }
    }

    // MARK: Finding tonight

    /// Before 4am still counts as the previous evening.
    static func readingDay(for date: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: date.addingTimeInterval(-4 * 3600))
    }

    func tonight(at date: Date = Date()) -> Night? {
        let day = Self.readingDay(for: date)
        return nights.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func next(after date: Date = Date()) -> Night? {
        let day = Self.readingDay(for: date)
        return nights.first { $0.day > day }
    }

    func past(before date: Date = Date()) -> [Night] {
        let day = Self.readingDay(for: date)
        return nights.filter { $0.day < day }
    }

    func night(number: Int) -> Night? { nights.first { $0.number == number } }
}

/// Where the reading list comes from: GitHub first (the reading-list thread keeps it up to date),
/// then the last copy downloaded, then the copy built into the app.
enum LineupSource {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/its2107org/Lamplight/main/content/nights.json")!

    private static var cacheFile: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("nights.json")
    }

    static func bundled() -> Lineup? {
        guard let url = Bundle.main.url(forResource: "nights", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return Lineup.decode(data)
    }

    static func cached() -> Lineup? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        return Lineup.decode(data)
    }

    /// The best copy on hand without going online.
    static func local() -> Lineup? {
        switch (cached(), bundled()) {
        case let (cached?, bundled?): return bundled.nights.count > cached.nights.count ? bundled : cached
        case let (cached?, nil): return cached
        case let (nil, bundled): return bundled
        }
    }

    static func fetch() async -> Lineup? {
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let lineup = Lineup.decode(data) else { return nil }
        try? data.write(to: cacheFile, options: .atomic)
        return lineup
    }
}
