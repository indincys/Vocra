import AppKit
import SwiftUI
import VocraCore
import WebKit

struct MarkdownWebView: NSViewRepresentable {
  let markdown: String

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.setValue(false, forKey: "drawsBackground")
    webView.underPageBackgroundColor = .clear
    webView.allowsBackForwardNavigationGestures = false
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    let html = MarkdownHTMLRenderer().renderDocument(markdown)
    guard html != context.coordinator.lastHTML else { return }
    context.coordinator.lastHTML = html
    webView.loadHTMLString(html, baseURL: nil)
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var lastHTML = ""

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
        return
      }

      decisionHandler(.allow)
    }
  }
}
