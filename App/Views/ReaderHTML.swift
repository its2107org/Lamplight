import Foundation

/// Builds the page the reader shows: the article text set in warm, low-light type.
enum ReaderHTML {
    static func page(article: Article, piece: Piece, theme: PageTheme, font: PageFont, size: Double) -> String {
        let c = theme.css
        let byline = piece.by ?? article.byline
        let isPoem = piece.kind == .poem
        return """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
        :root { color-scheme: dark; }
        html { background: \(c.bg); -webkit-text-size-adjust: none; }
        body { margin: 0; padding: 88px 32px 200px; color: \(c.ink); background: \(c.bg);
               font-family: \(font.css); font-size: \(Int(size))px; line-height: \(isPoem ? "1.7" : "1.62");
               -webkit-font-smoothing: antialiased; hanging-punctuation: first; }
        article { max-width: \(isPoem ? "30em" : "36em"); margin: 0 auto; }
        header { margin-bottom: 2.4em; }
        .kind { font: 600 12px -apple-system, sans-serif; letter-spacing: .16em; text-transform: uppercase; color: \(c.accent); }
        h1.title { font-family: ui-serif, Georgia, serif; font-weight: 500; font-size: 1.9em; line-height: 1.15;
                   margin: .35em 0 .25em; text-wrap: balance; }
        .by { color: \(c.muted); font-style: italic; }
        .note { color: \(c.muted); font-size: .85em; margin-top: .8em; }
        .rule { width: 48px; height: 1px; background: \(c.accent); opacity: .5; margin-top: 1.8em; }
        p, li { margin: 0 0 1em; }
        \(isPoem ? "p { margin-bottom: 1.3em; } .content { white-space: normal; }" : "p { text-wrap: pretty; }")
        a { color: inherit; text-decoration-color: \(c.accent); text-underline-offset: 3px; }
        h1, h2, h3, h4, h5 { font-family: ui-serif, Georgia, serif; font-weight: 600; line-height: 1.25; margin: 1.8em 0 .6em; }
        .content h1 { font-size: 1.4em; } h2 { font-size: 1.25em; } h3 { font-size: 1.1em; }
        img, video, svg { max-width: 100%; height: auto; border-radius: 6px; filter: brightness(.62) sepia(.35); }
        figure { margin: 1.6em 0; } figcaption { color: \(c.muted); font-size: .8em; margin-top: .5em; }
        blockquote { margin: 1.2em 0; padding-left: 1.1em; border-left: 2px solid \(c.accent); color: \(c.muted); }
        table { display: block; overflow-x: auto; border-collapse: collapse; font-size: .82em; }
        td, th { border-bottom: 1px solid \(c.muted)33; padding: .35em .6em; text-align: left; }
        pre, code { font-family: ui-monospace, Menlo, monospace; font-size: .82em; white-space: pre-wrap; }
        hr { border: none; height: 1px; background: \(c.muted)44; margin: 2em 0; }
        sup { line-height: 0; }
        .end { text-align: center; color: \(c.accent); opacity: .7; margin-top: 3em; font-size: 1.4em; }
        ::selection { background: \(c.accent)55; }
        </style></head>
        <body><article>
        <header>
          <div class="kind">\(escape(piece.kind.label))</div>
          <h1 class="title">\(escape(piece.title))</h1>
          \(byline.map { "<div class=\"by\">\(escape($0))</div>" } ?? "")
          \(piece.note.map { "<div class=\"note\">\(escape($0))</div>" } ?? "")
          <div class="rule"></div>
        </header>
        <div class="content">\(article.html)</div>
        <div class="end">&#x263E;</div>
        </article></body></html>
        """
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Turns any ordinary web page into warm night colours.
    static let nightCSS = """
    html { filter: invert(0.9) hue-rotate(180deg) sepia(0.3) !important; background: #fff !important; }
    img, video, picture, canvas, iframe, svg image, [style*="background-image"] { filter: invert(1) hue-rotate(180deg) brightness(.75) !important; }
    """
}
