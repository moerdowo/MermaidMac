import SwiftUI
import WebKit

enum PreviewStatus: Equatable {
    case loading
    case ok(width: Double, height: Double)
    case error(String)
    case empty
}

final class PreviewController: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    @Published var status: PreviewStatus = .loading
    @Published var zoomScale: Double = 1

    weak var webView: WKWebView?
    private var isReady = false
    private var pending: (code: String, theme: String, bg: String)?

    func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "bridge")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.setValue(false, forKey: "drawsBackground") // transparent
        if let url = Bundle.main.url(forResource: "preview", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        self.webView = wv
        return wv
    }

    // MARK: - Render

    func render(code: String, theme: String, background: String) {
        guard isReady else {
            pending = (code, theme, background)
            return
        }
        let js = "window.renderDiagram(\(jsString(code)), \(jsString(theme)), \(jsString(background)));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func jsString(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s]),
           let str = String(data: data, encoding: .utf8) {
            // strips the surrounding [ ]
            return String(str.dropFirst().dropLast())
        }
        return "\"\""
    }

    // MARK: - Zoom

    func zoomIn() { webView?.evaluateJavaScript("window.zoomIn()") }
    func zoomOut() { webView?.evaluateJavaScript("window.zoomOut()") }
    func resetZoom() { webView?.evaluateJavaScript("window.resetZoom()") }
    func fitToWindow() { webView?.evaluateJavaScript("window.fitToWindow()") }
    func setZoom(_ s: Double) { webView?.evaluateJavaScript("window.setZoom(\(s))") }

    // MARK: - Export

    func exportSVG(completion: @escaping (String?) -> Void) {
        webView?.evaluateJavaScript("window.getSVG()") { result, _ in
            completion(result as? String)
        }
    }

    func exportPNG(scale: Double, completion: @escaping (Data?) -> Void) {
        webView?.callAsyncJavaScript(
            "return await window.getPNG(s);",
            arguments: ["s": scale],
            in: nil,
            in: .page
        ) { result in
            switch result {
            case .success(let value):
                if let dataURL = value as? String,
                   let comma = dataURL.range(of: ","),
                   let data = Data(base64Encoded: String(dataURL[comma.upperBound...])) {
                    completion(data)
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // ready signal comes from JS; nothing to do here
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            isReady = true
            if let p = pending {
                pending = nil
                render(code: p.code, theme: p.theme, background: p.bg)
            }
        case "rendered":
            let w = body["width"] as? Double ?? 0
            let h = body["height"] as? Double ?? 0
            status = .ok(width: w, height: h)
        case "error":
            status = .error(body["message"] as? String ?? "Unknown error")
        case "empty":
            status = .empty
        case "zoom":
            if let s = body["scale"] as? Double { zoomScale = s }
        default:
            break
        }
    }
}

struct MermaidWebView: NSViewRepresentable {
    let controller: PreviewController

    func makeNSView(context: Context) -> WKWebView {
        controller.makeWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
