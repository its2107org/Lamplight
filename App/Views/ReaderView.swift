import SwiftUI

/// The night's reading, one piece after another, full screen and as dim as you like.
struct ReaderView: View {
    let night: Night
    @State private var index: Int
    @State private var progress: Double = 0
    @State private var chrome = true
    @State private var chromeShownAt: Double = 0
    @State private var showAppearance = false
    @State private var showGoodnight = false
    @State private var reloads = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: ReaderSettings
    @EnvironmentObject private var readingProgress: ReadingProgress

    init(night: Night, start: PieceKind?) {
        self.night = night
        let first = start.flatMap { kind in night.pieces.firstIndex { $0.kind == kind } }
            ?? night.pieces.firstIndex { !ReadingProgress.shared.isDone($0) }
            ?? 0
        _index = State(initialValue: first)
    }

    private var piece: Piece { night.pieces[index] }
    private var isLast: Bool { index == night.pieces.count - 1 }
    private var atEnd: Bool { progress > 0.97 }
    private var theme: PageTheme { settings.theme }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if night.pieces.isEmpty {
                Text("Nothing to read tonight.").foregroundStyle(theme.muted)
            } else if showGoodnight {
                GoodnightView(night: night) { dismiss() }
                    .transition(.opacity)
            } else {
                PieceReader(piece: piece, callbacks: ReadingCallbacks(
                    progress: { value in
                        progress = value
                        if chrome, abs(value - chromeShownAt) > 0.015 { withAnimation(.easeOut(duration: 0.3)) { chrome = false } }
                    },
                    tap: { toggleChrome() }
                ))
                .id("\(piece.id)-\(reloads)")
                .ignoresSafeArea()
                .transition(.opacity)

                VStack(spacing: 0) {
                    ProgressLine(value: progress, color: theme.accent)
                    if chrome { topBar.transition(.move(edge: .top).combined(with: .opacity)) }
                    Spacer()
                    if chrome || atEnd { bottomBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
                }
            }

            // Extra dimming, beyond the screen's own lowest brightness.
            Color.black.opacity(settings.dimmer).ignoresSafeArea().allowsHitTesting(false)
        }
        .statusBarHidden(!chrome || showGoodnight)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: index)
        .animation(.easeInOut(duration: 0.25), value: atEnd)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = settings.keepAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $showAppearance) {
            AppearancePanel()
                .presentationDetents([.medium])
                .presentationBackground(Palette.surface)
        }
    }

    private func toggleChrome() {
        chromeShownAt = progress
        withAnimation(.easeOut(duration: 0.25)) { chrome.toggle() }
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(spacing: 14) {
            CircleButton(symbol: "xmark", label: "Close") { dismiss() }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Text("\(index + 1) of \(night.pieces.count) · \(piece.kind.label)".uppercased())
                    .font(.label(11)).tracking(1.4).foregroundStyle(theme.accent)
                Text(piece.title).font(.lamp(15)).foregroundStyle(theme.ink).lineLimit(1)
            }
            Spacer(minLength: 8)
            Menu {
                Section("Tonight") {
                    ForEach(Array(night.pieces.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            progress = 0
                            index = offset
                        } label: {
                            Label("\(item.kind.label): \(item.title)", systemImage: readingProgress.isDone(item) ? "checkmark.circle.fill" : item.kind.symbol)
                        }
                    }
                }
                Section {
                    Button {
                        readingProgress.toggle(piece)
                    } label: {
                        Label(readingProgress.isDone(piece) ? "Mark as Unread" : "Mark as Read", systemImage: "checkmark.circle")
                    }
                    Button {
                        ContentStore.shared.refresh(piece)
                        progress = 0
                        reloads += 1
                    } label: {
                        Label("Download Again", systemImage: "arrow.clockwise")
                    }
                    if let url = piece.url {
                        Link(destination: url) { Label("Open Original Page", systemImage: "safari") }
                    }
                }
            } label: {
                CircleIcon(symbol: "list.bullet")
            }
            .accessibilityLabel("Tonight's pieces")
            CircleButton(symbol: "textformat.size", label: "Appearance") { showAppearance = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [theme.background, theme.background.opacity(0.92), theme.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            Button(action: advance) {
                HStack(spacing: 10) {
                    if isLast {
                        Image(systemName: "moon.stars.fill")
                        Text("Finish tonight").font(.lamp(17, .semibold))
                    } else {
                        let next = night.pieces[index + 1]
                        Text(atEnd ? "Next" : "Skip to").font(.label(12)).tracking(1).textCase(.uppercase).opacity(0.75)
                        Text("\(next.kind.label): \(next.title)").font(.lamp(17, .semibold)).lineLimit(1)
                        Image(systemName: "arrow.right")
                    }
                }
                .foregroundStyle(atEnd ? Palette.background : theme.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Capsule().fill(atEnd ? theme.accent : theme.background.opacity(0.85)))
                .overlay(Capsule().strokeBorder(theme.accent.opacity(atEnd ? 0 : 0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 560)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    private func advance() {
        if atEnd { readingProgress.setDone(piece, true) }
        if isLast {
            readingProgress.setDone(piece, true)
            withAnimation(.easeInOut(duration: 0.6)) { showGoodnight = true }
        } else {
            progress = 0
            chrome = true
            chromeShownAt = 0
            index += 1
        }
    }
}

/// Loads one piece (from the iPad if it's been downloaded already) and shows it.
private struct PieceReader: View {
    let piece: Piece
    let callbacks: ReadingCallbacks
    @State private var content: ReadyContent?
    @EnvironmentObject private var settings: ReaderSettings

    var body: some View {
        Group {
            switch content {
            case nil:
                Preparing(title: piece.title, theme: settings.theme)
            case .article(let article):
                ArticlePageView(article: article, piece: piece, theme: settings.theme, font: settings.font, size: settings.textSize, callbacks: callbacks)
            case .pdf(let url):
                PDFPageView(url: url, piece: piece, theme: settings.theme, callbacks: callbacks)
                    .padding(.top, 60)
                    .background(Color.black)
            case .web(let url):
                OriginalPageView(url: url, piece: piece, theme: settings.theme, callbacks: callbacks)
                    .padding(.top, 60)
                    .background(Color.black)
            case .unavailable:
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz").font(.system(size: 34))
                    Text("This piece has no link yet.").font(.lamp(19))
                }
                .foregroundStyle(settings.theme.muted)
            }
        }
        .task(id: piece.id) {
            content = ContentStore.shared.cached(piece)
            if content == nil { content = await ContentStore.shared.content(for: piece) }
        }
    }
}

private struct Preparing: View {
    let title: String
    let theme: PageTheme
    @State private var glow = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.fill")
                .font(.system(size: 30))
                .foregroundStyle(theme.accent)
                .opacity(glow ? 0.95 : 0.35)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glow)
            Text("Getting “\(title)” ready")
                .font(.lamp(18))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .onAppear { glow = true }
    }
}

private struct ProgressLine: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Rectangle().fill(color.opacity(0.7))
                .frame(width: proxy.size.width * value)
                .animation(.linear(duration: 0.15), value: value)
        }
        .frame(height: 2)
    }
}

struct CircleIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Palette.raised.opacity(0.9)))
    }
}

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { CircleIcon(symbol: symbol) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}
