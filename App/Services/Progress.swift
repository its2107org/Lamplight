import Foundation

/// What's been read, and where each piece was left off. Kept on the iPad.
@MainActor
final class ReadingProgress: ObservableObject {
    static let shared = ReadingProgress()

    @Published private(set) var done: Set<String>
    private var positions: [String: Double]

    private static let doneKey = "donePieces"
    private static let positionsKey = "readingPositions"

    private init() {
        done = Set(UserDefaults.standard.stringArray(forKey: Self.doneKey) ?? [])
        positions = (UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: Double]) ?? [:]
    }

    func isDone(_ piece: Piece) -> Bool { done.contains(piece.id) }

    func setDone(_ piece: Piece, _ value: Bool) {
        if value { done.insert(piece.id) } else { done.remove(piece.id) }
        UserDefaults.standard.set(Array(done), forKey: Self.doneKey)
    }

    func toggle(_ piece: Piece) { setDone(piece, !isDone(piece)) }

    func doneCount(_ night: Night) -> Int { night.pieces.filter(isDone).count }

    func isComplete(_ night: Night) -> Bool { !night.pieces.isEmpty && night.pieces.allSatisfy(isDone) }

    /// The first piece not yet read, in bedtime order.
    func nextPiece(in night: Night) -> Piece? { night.pieces.first { !isDone($0) } }

    func completedNights(in lineup: Lineup) -> Int { lineup.nights.filter(isComplete).count }

    // MARK: Place in each piece (0 = top, 1 = end)

    func position(_ piece: Piece) -> Double { positions[piece.id] ?? 0 }

    func setPosition(_ piece: Piece, _ value: Double) {
        positions[piece.id] = min(max(value, 0), 1)
        UserDefaults.standard.set(positions, forKey: Self.positionsKey)
    }

    // MARK: Screenshots

    func seedForDemo(_ night: Night) {
        done = Set(night.pieces.prefix(2).map(\.id))
    }

    func completeForDemo(_ night: Night) {
        done = Set(night.pieces.map(\.id))
    }
}
