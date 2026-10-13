// Picks the readable text out of a web page for Lamplight's night-time reader.
// Runs in a hidden web view (the page's own scripts are off) after Readability.js has loaded.
// Returns a JSON string: { title, byline, html, words, pdf }.

function lamplightMeta(doc, names) {
  var metas = doc.getElementsByTagName("meta");
  for (var n = 0; n < names.length; n++) {
    for (var i = 0; i < metas.length; i++) {
      var key = metas[i].getAttribute("property") || metas[i].getAttribute("name");
      if (key && key.toLowerCase() === names[n]) {
        var c = metas[i].getAttribute("content");
        if (c) return c.trim();
      }
    }
  }
  return null;
}

function lamplightAbsolute(link, base) {
  if (!link) return null;
  try { return new URL(link, base).href; } catch (e) { return null; }
}

function lamplightExtract(doc, url) {
  var pdf = lamplightAbsolute(lamplightMeta(doc, ["citation_pdf_url"]), url);
  var fallbackTitle = lamplightMeta(doc, ["og:title", "twitter:title", "citation_title"]) || doc.title || "";
  var result = null;
  try {
    result = new Readability(doc.cloneNode(true), { charThreshold: 120, keepClasses: false }).parse();
  } catch (e) {
    result = null;
  }
  var html = result && result.content ? result.content : "";
  var text = result && result.textContent ? result.textContent : "";
  var words = text.split(/\s+/).filter(function (w) { return w.length > 0; }).length;
  return JSON.stringify({
    title: (result && result.title) || fallbackTitle,
    byline: (result && result.byline) || null,
    html: html,
    words: words,
    pdf: pdf
  });
}
