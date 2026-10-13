import SwiftUI

/// "From your Shelf": things saved in Shelf and the top For You picks, below the night's reading.
struct ShelfSection: View {
    @EnvironmentObject private var shelf: ShelfLink
    @EnvironmentObject private var progress: ReadingProgress
    @EnvironmentObject private var store: ContentStore
    @EnvironmentObject private var router: Router

    var body: some View {
        let saved = shelf.visibleSaved
        let picks = shelf.visiblePicks
        VStack(alignment: .leading, spacing: 26) {
            if !saved.isEmpty {
                group(title: "FROM YOUR SHELF", pieces: saved)
            } else if !shelf.isConnected {
                Text("Things you save in Shelf will appear here once Shelf on your iPhone has its next update.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.faint)
            }
            if !picks.isEmpty {
                group(title: "TOP \(picks.count) FOR YOU", pieces: picks)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 60)
    }

    private func group(title: String, pieces: [Piece]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.label(10)).tracking(1.4)
                .foregroundStyle(Palette.faint)
                .padding(.bottom, 4)
            ForEach(pieces) { piece in
                HStack(alignment: .top, spacing: 16) {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { progress.toggle(piece) }
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(Palette.faint)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark as read")

                    Button {
                        let all = shelf.extras
                        router.read(Night(extras: all, title: "From your Shelf"), from: nil, piece: piece)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(piece.title)
                                    .font(.lamp(18, .medium))
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let by = piece.by {
                                    Text(by).font(.lamp(14).italic()).foregroundStyle(Palette.muted)
                                }
                            }
                            Spacer(minLength: 8)
                            Text("\(store.estimatedMinutes(piece)) min")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(Palette.faint)
                                .padding(.top, 2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .transition(.opacity)
                if piece.id != pieces.last?.id {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
    }
}
