import Foundation
import Security
import CryptoKit

/// Brings in reading from the Shelf app: the things Ian saved there (still unread), and the top
/// five For You picks. Anything he marks as read, deletes or dismisses in Shelf drops off here too.
///
/// Shelf keeps its list in Ian's private GitHub project. It hands Lamplight the key to read it
/// through iCloud Keychain, so there's nothing to type in.
@MainActor
final class ShelfLink: ObservableObject {
    static let shared = ShelfLink()

    static let picksURL = URL(string: "https://raw.githubusercontent.com/its2107org/Shelf/main/feed/recommendations.json")!
    static let queueURL = URL(string: "https://api.github.com/repos/its2107org/shelf-feedback/contents/queue.json")!
    static let topPicks = 5

    @Published private(set) var saved: [Piece] = []
    @Published private(set) var picks: [Piece] = []
    @Published private(set) var isConnected = false
    @Published private(set) var lastSynced: Date?
    private var done: Set<String> = []

    private static let cacheKey = "shelfCache"
    private static let manualKeyService = "lamplight.shelf"

    private struct Cache: Codable {
        var saved: [Item]
        var picks: [Item]
        var done: [String]
        var at: Date
    }

    struct Item: Codable {
        var url: String
        var title: String
        var site: String?
        var minutes: Int?
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            apply(saved: cache.saved, picks: cache.picks, done: Set(cache.done))
            lastSynced = cache.at
        }
        isConnected = Self.key() != nil
    }

    /// Saves and picks still to read tonight.
    var visibleSaved: [Piece] { saved.filter { !ReadingProgress.shared.isDone($0) } }
    var visiblePicks: [Piece] { picks.filter { !ReadingProgress.shared.isDone($0) } }
    var extras: [Piece] { visibleSaved + visiblePicks }

    func refresh() async {
        let key = Self.key()
        isConnected = key != nil
        async let feed = Self.fetchPicks()
        async let queue = Self.fetchQueue(key: key)
        let (pickItems, queueResult) = await (feed, queue)

        var savedItems = cachedSaved
        var doneURLs = done
        if let queueResult {
            savedItems = queueResult.saved
            doneURLs = queueResult.done
        }
        let freshPicks = pickItems ?? cachedPicks
        apply(saved: savedItems, picks: freshPicks, done: doneURLs)
        lastSynced = Date()
        let cache = Cache(saved: savedItems, picks: freshPicks, done: Array(doneURLs), at: Date())
        if let data = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(data, forKey: Self.cacheKey) }
    }

    /// For when iCloud Keychain isn't on: the same key Shelf uses, pasted once.
    func connect(manualKey: String) async -> Bool {
        let trimmed = manualKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, await Self.fetchQueue(key: trimmed) != nil else { return false }
        Self.storeManualKey(trimmed)
        await refresh()
        return true
    }

    // MARK: Internals

    private var cachedSaved: [Item] = []
    private var cachedPicks: [Item] = []

    private func apply(saved savedItems: [Item], picks pickItems: [Item], done doneURLs: Set<String>) {
        cachedSaved = savedItems
        cachedPicks = pickItems
        done = doneURLs
        let normalisedDone = Set(doneURLs.map(Self.normalise))
        saved = savedItems
            .filter { !normalisedDone.contains(Self.normalise($0.url)) }
            .map { Self.piece($0, kind: .saved) }
        let savedLinks = Set(savedItems.map { Self.normalise($0.url) })
        picks = Array(pickItems
            .filter { !normalisedDone.contains(Self.normalise($0.url)) && !savedLinks.contains(Self.normalise($0.url)) }
            .prefix(Self.topPicks))
            .map { Self.piece($0, kind: .pick) }
    }

    private static func piece(_ item: Item, kind: PieceKind) -> Piece {
        let digest = SHA256.hash(data: Data(normalise(item.url).utf8)).map { String(format: "%02x", $0) }.joined()
        return Piece(title: item.title, by: item.site, link: item.url, minutes: item.minutes, kind: kind, key: "shelf-\(digest.prefix(16))")
    }

    /// Links compared without tracking bits, "www." or a trailing slash.
    static func normalise(_ link: String) -> String {
        guard var parts = URLComponents(string: link) else { return link }
        parts.query = nil
        parts.fragment = nil
        parts.scheme = "https"
        if let host = parts.host, host.hasPrefix("www.") { parts.host = String(host.dropFirst(4)) }
        var text = parts.string ?? link
        while text.hasSuffix("/") { text.removeLast() }
        return text.lowercased()
    }

    // MARK: Downloads

    private struct Feed: Decodable {
        struct Entry: Decodable {
            var url: String
            var title: String
            var source: String?
            var minutes: Int?
            var addedAt: String?

            private enum CodingKeys: String, CodingKey { case url, title, source, minutes, addedAt }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                url = try c.decode(String.self, forKey: .url)
                title = (try? c.decode(String.self, forKey: .title)) ?? "Untitled"
                source = try? c.decodeIfPresent(String.self, forKey: .source)
                addedAt = try? c.decodeIfPresent(String.self, forKey: .addedAt)
                if let number = try? c.decodeIfPresent(Int.self, forKey: .minutes) {
                    minutes = number
                } else if let text = try? c.decodeIfPresent(String.self, forKey: .minutes) {
                    minutes = Int(text)
                }
            }
        }
        var items: [Entry]
    }

    /// The latest For You run, best first.
    private static func fetchPicks() async -> [Item]? {
        var request = URLRequest(url: picksURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(Feed.self, from: data) else { return nil }
        let latest = feed.items.compactMap(\.addedAt).max()
        let newest = feed.items.filter { latest == nil || $0.addedAt == latest }
        return newest.map { Item(url: $0.url, title: $0.title, site: $0.source, minutes: $0.minutes) }
    }

    private struct Queue: Decodable {
        struct Entry: Decodable {
            var url: String
            var title: String?
            var site: String?
            var minutes: Int?
        }
        var saved: [Entry]?
        var done: [String]?
    }

    private static func fetchQueue(key: String?) async -> (saved: [Item], done: Set<String>)? {
        guard let key else { return nil }
        var request = URLRequest(url: queueURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let queue = try? JSONDecoder().decode(Queue.self, from: data) else { return nil }
        let items = (queue.saved ?? []).map { Item(url: $0.url, title: $0.title ?? $0.url, site: $0.site, minutes: $0.minutes) }
        return (items, Set(queue.done ?? []))
    }

    // MARK: The key

    /// Shelf's key, synced from the iPhone by iCloud Keychain, or one pasted in Settings.
    static func key() -> String? {
        var queries: [[String: Any]] = []
        var synced: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "shelf.feedback.sync",
            kSecAttrAccount as String: "key",
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = shelfGroup { synced[kSecAttrAccessGroup as String] = group }
        queries.append(synced)
        queries.append([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: manualKeyService,
            kSecAttrAccount as String: "key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ])
        for query in queries {
            var result: AnyObject?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
               let data = result as? Data, let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private static var shelfGroup: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "ShelfKeychainGroup") as? String
        guard let value, !value.hasPrefix("."), !value.contains("$(") else { return nil }
        return value
    }

    private static func storeManualKey(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: manualKeyService,
            kSecAttrAccount as String: "key"
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
