import Foundation
import UIKit
import WebKit

/// Clean article text pulled out of a web page.
struct Article: Codable, Hashable {
    var title: String
    var byline: String?
    var html: String
    var words: Int
}

/// Downloads a link and turns it into something calm to read: either clean article text
/// (using Readability, the engine behind Firefox's Reader View) or a PDF.
@MainActor
final class PageReader: NSObject {
    static let shared = PageReader()

    enum Result {
        case article(Article, pdfLink: URL?)
        case pdf(Data)
    }

    enum Failure: Error { case badResponse, notReadable, timedOut }

    static let userAgent = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept": "text/html,application/xhtml+xml,application/pdf;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-GB,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }()

    private lazy var scripts: String = {
        ["Readability", "LamplightExtract"].compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }.joined(separator: "\n;\n")
    }()

    private var webView: WKWebView?
    /// A view in the window to keep the hidden web view in, so WebKit doesn't pause it.
    weak var hostView: UIView?
    private var ruleList: WKContentRuleList?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var loadGeneration = 0
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func read(_ url: URL) async throws -> Result {
        let (data, response) = try await download(url)
        if Self.isPDF(data, response) { return .pdf(data) }
        let html = Self.decode(data, encodingName: response.textEncodingName)
        let json = try await runInPage(html: html, baseURL: response.url ?? url,
                                       expression: "lamplightExtract(document, \(Self.jsString((response.url ?? url).absoluteString)))")
        struct Raw: Decodable { var title: String; var byline: String?; var html: String; var words: Int; var pdf: String? }
        let raw = try JSONDecoder().decode(Raw.self, from: Data(json.utf8))
        let article = Article(title: raw.title, byline: raw.byline, html: raw.html, words: raw.words)
        return .article(article, pdfLink: raw.pdf.flatMap(URL.init(string:)))
    }

    func downloadPDF(_ url: URL) async throws -> Data {
        let (data, response) = try await download(url)
        guard Self.isPDF(data, response) else { throw Failure.notReadable }
        return data
    }

    private func download(_ url: URL) async throws -> (Data, URLResponse) {
        // Sign-ins made on an original page (say, a newspaper) count here too.
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        for cookie in cookies { HTTPCookieStorage.shared.setCookie(cookie) }
        // Plain "http" links: try the secure version first.
        if url.scheme == "http", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.scheme = "https"
            if let secure = parts.url, let result = try? await session.data(from: secure),
               let http = result.1 as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                return result
            }
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else { throw Failure.badResponse }
        return (data, response)
    }

    private static func isPDF(_ data: Data, _ response: URLResponse) -> Bool {
        if response.mimeType?.lowercased() == "application/pdf" { return true }
        return data.prefix(5).elementsEqual("%PDF-".utf8)
    }

    // MARK: Hidden web view

    private func runInPage(html: String, baseURL: URL, expression: String) async throws -> String {
        await acquire()
        defer { release() }
        let webView = try await makeWebViewIfNeeded()
        loadGeneration += 1
        let generation = loadGeneration
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.loadContinuation = continuation
                webView.loadHTMLString(html, baseURL: baseURL)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    guard let self, self.loadGeneration == generation else { return }
                    self.finishLoad(Failure.timedOut)
                }
            }
        } catch {
            discardWebView()
            throw error
        }
        let result = try await webView.evaluateJavaScript(scripts + "\n;\n" + expression)
        guard let json = result as? String else { throw Failure.notReadable }
        return json
    }

    private func makeWebViewIfNeeded() async throws -> WKWebView {
        if let webView { return webView }
        if ruleList == nil {
            // Nothing from the page is downloaded or run: only its text is wanted.
            let rules = """
            [{"trigger":{"url-filter":".*","resource-type":["image","style-sheet","script","font","media","raw","svg-document","popup","fetch","websocket","other","ping"]},"action":{"type":"block"}}]
            """
            ruleList = try? await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "LamplightBlockAll", encodedContentRuleList: rules)
        }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.suppressesIncrementalRendering = true
        if let ruleList { config.userContentController.add(ruleList) }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000), configuration: config)
        view.navigationDelegate = self
        view.isUserInteractionEnabled = false
        if let host = hostView {
            view.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
            view.alpha = 0.01
            host.addSubview(view)
        }
        webView = view
        return view
    }

    private func discardWebView() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
    }

    private func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    fileprivate func finishLoad(_ error: Error?) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }

    // MARK: Helpers

    static func jsString(_ value: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [value])) ?? Data("[\"\"]".utf8)
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }

    static func decode(_ data: Data, encodingName: String?) -> String {
        if let name = encodingName {
            let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cf != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

extension PageReader: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finishLoad(nil) }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finishLoad(error) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finishLoad(error) }
    }

    nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only the page itself: no frames, pop-ups or redirects elsewhere.
        let allow = MainActor.assumeIsolated { navigationAction.targetFrame?.isMainFrame == true && navigationAction.navigationType == .other }
        decisionHandler(allow ? .allow : .cancel)
    }
}
