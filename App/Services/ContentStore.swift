import Foundation
import CryptoKit
import PDFKit

/// What the reader shows for a piece.
enum ReadyContent {
    case article(Article)
    case pdf(URL)
    /// The original page, shown with night colours, when the text couldn't be picked out.
    case web(URL)
    case unavailable
}

/// Downloads each night's reading ahead of time and keeps it on the iPad, so bedtime is
/// instant and works offline.
@MainActor
final class ContentStore: ObservableObject {
    static let shared = ContentStore()

    /// Reading time in minutes, once a piece has been downloaded (keyed by piece link).
    @Published private(set) var minutes: [String: Int]

    private var inFlight: [String: Task<ReadyContent, Never>] = [:]
    private let folder: URL
    private static let minutesKey = "minutesByLink"
    /// Pieces that only work as the original page are tried again after this long.
    private static let retryAfter: TimeInterval = 12 * 3600
    private static let wordsPerMinute = 230.0

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var dir = support.appendingPathComponent("Reading", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        folder = dir
        minutes = (UserDefaults.standard.dictionary(forKey: Self.minutesKey) as? [String: Int]) ?? [:]
    }

    // MARK: Reading time

    func estimatedMinutes(_ piece: Piece) -> Int {
        if let set = piece.minutes { return set }
        if let known = minutes[piece.link] {
            // Papers are for skimming: about 20 minutes is plenty.
            return piece.kind == .paper ? min(known, 25) : known
        }
        return piece.kind.typicalMinutes
    }

    func totalMinutes(_ night: Night) -> Int {
        night.pieces.reduce(0) { $0 + estimatedMinutes($1) }
    }

    func isReady(_ piece: Piece) -> Bool { cached(piece) != nil }

    // MARK: Content

    func content(for piece: Piece) async -> ReadyContent {
        if let ready = cached(piece) { return ready }
        guard let url = piece.readingURL else { return .unavailable }
        if let task = inFlight[piece.link] { return await task.value }
        let task = Task { await self.download(piece, from: url) }
        inFlight[piece.link] = task
        let result = await task.value
        inFlight[piece.link] = nil
        return result
    }

    /// Gets a night's pieces ready in the background.
    func prefetch(_ nights: [Night]) async {
        for night in nights {
            for piece in night.pieces where cached(piece) == nil {
                _ = await content(for: piece)
            }
        }
    }

    func cached(_ piece: Piece) -> ReadyContent? {
        let base = file(for: piece)
        let fm = FileManager.default
        if let data = try? Data(contentsOf: base.appendingPathExtension("json")),
           let article = try? JSONDecoder().decode(Article.self, from: data) {
            return .article(article)
        }
        let pdf = base.appendingPathExtension("pdf")
        if fm.fileExists(atPath: pdf.path) { return .pdf(pdf) }
        let marker = base.appendingPathExtension("web")
        if let attributes = try? fm.attributesOfItem(atPath: marker.path),
           let date = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < Self.retryAfter,
           let url = piece.readingURL {
            return .web(url)
        }
        return nil
    }

    /// Forgets the downloaded copy, so it's fetched fresh next time.
    func refresh(_ piece: Piece) {
        let base = file(for: piece)
        for ext in ["json", "pdf", "web"] {
            try? FileManager.default.removeItem(at: base.appendingPathExtension(ext))
        }
    }

    private func download(_ piece: Piece, from url: URL) async -> ReadyContent {
        let base = file(for: piece)
        let reader = PageReader.shared
        do {
            switch try await reader.read(url) {
            case .pdf(let data):
                return savePDF(data, piece: piece, base: base)
            case let .article(article, pdfLink):
                // A page that's only a summary of a paper: read the paper's PDF instead.
                if article.words < 250, let pdfLink, let data = try? await reader.downloadPDF(pdfLink) {
                    return savePDF(data, piece: piece, base: base)
                }
                let minimum = piece.kind == .poem ? 12 : 120
                guard article.words >= minimum, !article.html.isEmpty else { break }
                if let data = try? JSONEncoder().encode(article) {
                    try? data.write(to: base.appendingPathExtension("json"), options: .atomic)
                }
                remember(minutes: max(1, Int((Double(article.words) / Self.wordsPerMinute).rounded())), for: piece)
                return .article(article)
            }
        } catch {
            // Offline or the site said no: fall through to the original page.
        }
        FileManager.default.createFile(atPath: base.appendingPathExtension("web").path, contents: Data())
        return .web(url)
    }

    private func savePDF(_ data: Data, piece: Piece, base: URL) -> ReadyContent {
        let file = base.appendingPathExtension("pdf")
        try? data.write(to: file, options: .atomic)
        if let document = PDFDocument(data: data) {
            // Skimming a paper: about three minutes a page.
            remember(minutes: max(3, document.pageCount * 3), for: piece)
        }
        return .pdf(file)
    }

    private func remember(minutes value: Int, for piece: Piece) {
        minutes[piece.link] = value
        UserDefaults.standard.set(minutes, forKey: Self.minutesKey)
    }

    private func file(for piece: Piece) -> URL {
        let key = piece.readingURL?.absoluteString ?? piece.link
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(String(digest.prefix(24)))
    }
}
