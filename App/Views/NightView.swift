import SwiftUI

/// One night's reading: the theme, what you'll learn, and the five pieces in bedtime order.
struct NightView: View {
    let night: Night
    var isTonight = false
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var progress: ReadingProgress
    @EnvironmentObject private var store: ContentStore
    @State private var showTip = false
    @State private var showSummary = false

    private var doneCount: Int { progress.doneCount(night) }
    private var complete: Bool { progress.isComplete(night) }
    private var minutesLeft: Int {
        night.pieces.filter { !progress.isDone($0) }.reduce(0) { $0 + store.estimatedMinutes($1) }
    }
    private var allDownloaded: Bool { night.pieces.allSatisfy(store.isReady) }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            header
            lesson
            status
            primaryButton
            pieces
            tip
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 60)
        .fullScreenCover(isPresented: $showSummary) {
            GoodnightView(night: night) { showSummary = false }
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.label(12)).tracking(1.8)
                .foregroundStyle(Palette.ember)
            Text(night.headline)
                .font(.lamp(46, .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let line = night.themeLine {
                Text(line)
                    .font(.lamp(19))
                    .foregroundStyle(Palette.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var eyebrow: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE d MMMM"
        let date = night.day == .distantPast ? night.dateLabel : formatter.string(from: night.day)
        return "\(isTonight ? "Tonight · " : "")Night \(night.number) · \(date)".uppercased()
    }

    @ViewBuilder
    private var lesson: some View {
        if night.field != nil || night.learn != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let field = night.field {
                        Text(field).font(.lamp(17, .semibold)).foregroundStyle(Palette.ink)
                    }
                    if let type = night.paperType {
                        Text(night.isNewResearch ? "New research" : type.capitalizingFirst)
                            .font(.label(10)).tracking(0.8).textCase(.uppercase)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Palette.ember.opacity(0.16)))
                            .foregroundStyle(Palette.glow)
                    }
                }
                if let learn = night.learn {
                    (Text("You'll learn: ").font(.lamp(18, .semibold)) + Text(learn).font(.lamp(18)))
                        .foregroundStyle(Palette.ink.opacity(0.92))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 16)
            .overlay(alignment: .leading) {
                Rectangle().fill(Palette.ember).frame(width: 2)
            }
        }
    }

    private var status: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(night.pieces) { piece in
                    Circle()
                        .fill(progress.isDone(piece) ? Palette.ember : Palette.line)
                        .frame(width: 8, height: 8)
                }
            }
            Text(statusText)
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
            Spacer()
            if allDownloaded {
                Label("Ready offline", systemImage: "arrow.down.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.faint)
            }
        }
    }

    private var statusText: String {
        if complete { return "All five read" }
        if doneCount == 0 { return "About \(minutesLeft) minutes" }
        return "\(doneCount) of \(night.pieces.count) read · about \(minutesLeft) min left"
    }

    @ViewBuilder
    private var primaryButton: some View {
        if complete {
            Button { showSummary = true } label: {
                Label("Night complete · see your summary", systemImage: "moon.stars.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LampButtonStyle(filled: false))
        } else {
            Button { router.read(night, from: nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.pages")
                    if doneCount == 0 {
                        Text(isTonight ? "Begin tonight's reading" : "Begin this night")
                    } else if let next = progress.nextPiece(in: night) {
                        Text("Continue with the \(next.kind.label.lowercased())")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LampButtonStyle(filled: true))
        }
    }

    private var pieces: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IN BEDTIME ORDER · DEMANDING FIRST, GENTLEST LAST")
                .font(.label(10)).tracking(1.4)
                .foregroundStyle(Palette.faint)
                .padding(.bottom, 10)
            ForEach(night.pieces) { piece in
                PieceRow(piece: piece, minutes: store.estimatedMinutes(piece), done: progress.isDone(piece),
                         toggle: { withAnimation(.easeOut(duration: 0.2)) { progress.toggle(piece) } },
                         open: { router.read(night, from: piece.kind) })
                if piece.id != night.pieces.last?.id {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
    }

    private var tip: some View {
        DisclosureGroup(isExpanded: $showTip) {
            Text("Read the summary at the top, the introduction and the conclusion, and look at the pictures and charts. Skip the maths and methods unless you're hooked, and skim anything that doesn't grab you.")
                .font(.lamp(16))
                .foregroundStyle(Palette.muted)
                .lineSpacing(3)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("How to read a paper in 20 minutes")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .tint(Palette.muted)
    }
}

private struct PieceRow: View {
    let piece: Piece
    let minutes: Int
    let done: Bool
    let toggle: () -> Void
    let open: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: toggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(done ? Palette.ember : Palette.faint)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark as unread" : "Mark as read")

            Button(action: open) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(piece.kind.label.uppercased(), systemImage: piece.kind.symbol)
                            .font(.label(10)).tracking(1.3)
                            .foregroundStyle(piece.kind == .paper ? Palette.glow : Palette.ember.opacity(0.85))
                        Text(piece.title)
                            .font(.lamp(21, .medium))
                            .foregroundStyle(done ? Palette.muted : Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let by = piece.by {
                            Text(by).font(.lamp(15).italic()).foregroundStyle(Palette.muted)
                        }
                        if let note = piece.note {
                            Text(note)
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.faint)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(minutes) min")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Palette.faint)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
    }
}

struct LampButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lamp(18, .semibold))
            .foregroundStyle(filled ? Palette.background : Palette.glow)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(LinearGradient(colors: [Palette.glow, Palette.ember], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.raised))
            )
            .overlay(Capsule().strokeBorder(Palette.ember.opacity(filled ? 0 : 0.35), lineWidth: 1))
            .shadow(color: filled ? Palette.ember.opacity(0.25) : .clear, radius: 18, y: 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension String {
    var capitalizingFirst: String { prefix(1).uppercased() + dropFirst() }
}
