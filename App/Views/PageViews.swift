import SwiftUI
import WebKit
import PDFKit

/// Reports how far through a piece you are (0 to 1), whether you've reached the end, and taps.
struct ReadingCallbacks {
    var progress: (Double) -> Void
    var tap: () -> Void
}

// MARK: Article text

struct ArticlePageView: UIViewRepresentable {
    let article: Article
    let piece: Piece
    let theme: PageTheme
    let font: PageFont
    let size: Double
    let callbacks: ReadingCallbacks

    func makeCoordinator() -> ScrollCoordinator { ScrollCoordinator(piece: piece, callbacks: callbacks) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.attach(to: view)
        view.allowsLinkPreview = false
        load(view, context: context)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.callbacks = callbacks
        view.backgroundColor = UIColor(theme.background)
        view.scrollView.backgroundColor = UIColor(theme.background)
        let signature = "\(theme.rawValue)-\(font.rawValue)-\(Int(size))"
        if context.coordinator.signature != signature {
            context.coordinator.rememberPosition()
            load(view, context: context)
        }
    }

    private func load(_ view: WKWebView, context: Context) {
        context.coordinator.signature = "\(theme.rawValue)-\(font.rawValue)-\(Int(size))"
        view.backgroundColor = UIColor(theme.background)
        view.scrollView.backgroundColor = UIColor(theme.background)
        let html = ReaderHTML.page(article: article, piece: piece, theme: theme, font: font, size: size)
        view.loadHTMLString(html, baseURL: piece.readingURL)
    }
}

// MARK: Original page (when the text couldn't be picked out)

struct OriginalPageView: UIViewRepresentable {
    let url: URL
    let piece: Piece
    let theme: PageTheme
    let callbacks: ReadingCallbacks

    func makeCoordinator() -> ScrollCoordinator { ScrollCoordinator(piece: piece, callbacks: callbacks, followsLinks: true) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let css = ReaderHTML.nightCSS.replacingOccurrences(of: "\n", with: " ")
        let js = "(function(){var s=document.createElement('style');s.textContent=\(PageReader.jsString(css));(document.head||document.documentElement).appendChild(s);})();"
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = PageReader.userAgent
        context.coordinator.attach(to: view)
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.callbacks = callbacks
    }
}

/// Shared plumbing for the two web views: dark background before anything loads, taps,
/// tracking and restoring your place, and opening links outside the reader.
final class ScrollCoordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
    let piece: Piece
    var callbacks: ReadingCallbacks
    var signature = ""
    private let followsLinks: Bool
    private weak var webView: WKWebView?
    private var observation: NSKeyValueObservation?
    private var restoreTo: Double
    private var restoring = true
    private var lastSaved = Date.distantPast

    init(piece: Piece, callbacks: ReadingCallbacks, followsLinks: Bool = false) {
        self.piece = piece
        self.callbacks = callbacks
        self.followsLinks = followsLinks
        self.restoreTo = MainActor.assumeIsolated { ReadingProgress.shared.position(piece) }
    }

    @MainActor
    func attach(to view: WKWebView) {
        webView = view
        view.navigationDelegate = self
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.indicatorStyle = .white
        view.scrollView.contentInsetAdjustmentBehavior = .never
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        observation = view.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            MainActor.assumeIsolated { self?.scrolled(scroll) }
        }
    }

    @MainActor
    func rememberPosition() {
        if let scroll = webView?.scrollView { restoreTo = Self.fraction(of: scroll) }
        restoring = true
    }

    @MainActor
    private func scrolled(_ scroll: UIScrollView) {
        guard !restoring else { return }
        let value = Self.fraction(of: scroll)
        callbacks.progress(value)
        if Date().timeIntervalSince(lastSaved) > 1 || value > 0.98 {
            lastSaved = Date()
            ReadingProgress.shared.setPosition(piece, value)
        }
    }

    private static func fraction(of scroll: UIScrollView) -> Double {
        let range = scroll.contentSize.height - scroll.bounds.height
        guard range > 4 else { return 1 }
        return min(max(Double(scroll.contentOffset.y / range), 0), 1)
    }

    @objc private func tapped() { callbacks.tap() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            let target = restoreTo
            // Give the page a moment to lay out before jumping back to your place.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak webView] in
                guard let self, let scroll = webView?.scrollView else { return }
                MainActor.assumeIsolated {
                    let range = scroll.contentSize.height - scroll.bounds.height
                    if target > 0.01, target < 0.99, range > 0 {
                        scroll.setContentOffset(CGPoint(x: 0, y: range * target), animated: false)
                    }
                    self.restoring = false
                    self.callbacks.progress(Self.fraction(of: scroll))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url {
            if followsLinks, action.targetFrame?.isMainFrame == true {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                MainActor.assumeIsolated { UIApplication.shared.open(url) }
            }
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: PDFs, in night colours

struct PDFPageView: UIViewRepresentable {
    let url: URL
    let piece: Piece
    let theme: PageTheme
    let callbacks: ReadingCallbacks

    func makeUIView(context: Context) -> NightPDFView {
        let view = NightPDFView(piece: piece)
        view.callbacks = callbacks
        view.load(url)
        view.tint(UIColor(theme.ink))
        return view
    }

    func updateUIView(_ view: NightPDFView, context: Context) {
        view.callbacks = callbacks
        view.tint(UIColor(theme.ink))
    }
}

/// A PDF with its colours flipped (light text on black) and warmed, for reading in the dark.
final class NightPDFView: UIView, UIGestureRecognizerDelegate {
    var callbacks: ReadingCallbacks?
    private let piece: Piece
    private let pdfView = PDFView()
    private let inverter = UIView()
    private let warmer = UIView()
    private var lastSaved = Date.distantPast

    init(piece: Piece) {
        self.piece = piece
        super.init(frame: .zero)
        backgroundColor = .black
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.pageShadowsEnabled = false
        pdfView.pageBreakMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        pdfView.backgroundColor = .white  // becomes black once flipped
        addSubview(pdfView)

        for overlay in [inverter, warmer] {
            overlay.isUserInteractionEnabled = false
            addSubview(overlay)
        }
        inverter.backgroundColor = .white
        inverter.layer.compositingFilter = "differenceBlendMode"
        warmer.layer.compositingFilter = "multiplyBlendMode"

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.delegate = self
        pdfView.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: pdfView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        pdfView.frame = bounds
        inverter.frame = bounds
        warmer.frame = bounds
    }

    func tint(_ color: UIColor) { warmer.backgroundColor = color }

    func load(_ url: URL) {
        guard let document = PDFDocument(url: url) else { return }
        pdfView.document = document
        let saved = MainActor.assumeIsolated { ReadingProgress.shared.position(piece) }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if saved > 0.01, document.pageCount > 1 {
                let index = min(document.pageCount - 1, Int((saved * Double(document.pageCount - 1)).rounded()))
                if let page = document.page(at: index) { self.pdfView.go(to: page) }
            }
            self.pageChanged()
        }
    }

    @objc private func pageChanged() {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return }
        let index = document.index(for: page)
        let value = document.pageCount <= 1 ? 1 : Double(index) / Double(document.pageCount - 1)
        callbacks?.progress(value)
        if Date().timeIntervalSince(lastSaved) > 1 || value >= 1 {
            lastSaved = Date()
            MainActor.assumeIsolated { ReadingProgress.shared.setPosition(piece, value) }
        }
    }

    @objc private func tapped() { callbacks?.tap() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// Keeps the hidden page reader inside the window so it keeps working.
struct PageReaderAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.isUserInteractionEnabled = false
        PageReader.shared.hostView = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}
