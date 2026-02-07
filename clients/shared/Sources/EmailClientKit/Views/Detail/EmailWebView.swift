import SwiftUI
import WebKit

#if os(macOS)

/// A sandboxed WKWebView for rendering email HTML on macOS.
/// JavaScript is disabled, external images blocked, dark mode CSS injected.
public struct EmailWebView: NSViewRepresentable {
    public let htmlBody: String
    public let textBody: String?

    public init(htmlBody: String, textBody: String? = nil) {
        self.htmlBody = htmlBody
        self.textBody = textBody
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()

        // Block external resources via user content controller
        let cspScript = WKUserScript(
            source: """
            var meta = document.createElement('meta');
            meta.httpEquiv = 'Content-Security-Policy';
            meta.content = "default-src 'none'; style-src 'unsafe-inline'; img-src data: cid:;";
            document.head.appendChild(meta);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        // Note: JS is disabled, so CSP meta tag is set via HTML wrapper instead.
        _ = cspScript

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        let content = wrappedHTML()
        webView.loadHTMLString(content, baseURL: nil)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Wraps the email body in a full HTML document with dark mode CSS and CSP.
    private func wrappedHTML() -> String {
        let body: String
        if !htmlBody.isEmpty {
            body = htmlBody
        } else if let text = textBody, !text.isEmpty {
            let escaped = text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            body = "<pre style=\"font-family: ui-monospace, monospace; white-space: pre-wrap; word-wrap: break-word;\">\(escaped)</pre>"
        } else {
            body = "<p style=\"color: gray;\">No content available.</p>"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data: cid:;">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    margin: 16px;
                    padding: 0;
                    color: #1a1a1a;
                    background: transparent;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e5e5e5;
                    }
                    a { color: #60a5fa; }
                    blockquote {
                        border-left-color: #4a4a4a !important;
                        color: #999 !important;
                    }
                }
                img { max-width: 100%; height: auto; }
                a { color: #3b82f6; }
                blockquote {
                    margin: 8px 0;
                    padding: 0 12px;
                    border-left: 3px solid #d1d5db;
                    color: #6b7280;
                }
                .quoted-text {
                    display: none;
                }
                .quoted-text.expanded {
                    display: block;
                }
                .show-quoted-toggle {
                    display: inline-block;
                    margin: 8px 0;
                    padding: 4px 8px;
                    font-size: 12px;
                    color: #6b7280;
                    background: #f3f4f6;
                    border: 1px solid #d1d5db;
                    border-radius: 4px;
                    cursor: pointer;
                }
                @media (prefers-color-scheme: dark) {
                    .show-quoted-toggle {
                        background: #374151;
                        border-color: #4b5563;
                        color: #9ca3af;
                    }
                }
                pre {
                    user-select: text;
                    -webkit-user-select: text;
                }
            </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WKNavigationDelegate {
        /// Open links in the system browser instead of within the web view.
        @MainActor
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

#elseif os(iOS)

/// A sandboxed WKWebView for rendering email HTML on iOS.
public struct EmailWebView: UIViewRepresentable {
    public let htmlBody: String
    public let textBody: String?

    public init(htmlBody: String, textBody: String? = nil) {
        self.htmlBody = htmlBody
        self.textBody = textBody
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        let content = wrappedHTML()
        webView.loadHTMLString(content, baseURL: nil)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func wrappedHTML() -> String {
        let body: String
        if !htmlBody.isEmpty {
            body = htmlBody
        } else if let text = textBody, !text.isEmpty {
            let escaped = text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            body = "<pre style=\"font-family: ui-monospace, monospace; white-space: pre-wrap; word-wrap: break-word;\">\(escaped)</pre>"
        } else {
            body = "<p style=\"color: gray;\">No content available.</p>"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data: cid:;">
            <style>
                :root { color-scheme: light dark; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    margin: 16px;
                    padding: 0;
                    color: #1a1a1a;
                    background: transparent;
                    word-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e5e5e5; }
                    a { color: #60a5fa; }
                }
                img { max-width: 100%; height: auto; }
                a { color: #3b82f6; }
                pre { user-select: text; -webkit-user-select: text; }
            </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        @MainActor
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

#endif
