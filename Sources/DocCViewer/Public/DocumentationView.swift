//
//  DocumentationView.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import DocCViewerCore
import OSLog
import SwiftUI
import WebKit

public struct DocumentationView {
    public class Coordinator: NSObject, WKNavigationDelegate {
        let viewer: DocumentationViewer
        var view: WKWebView?

        @MainActor
        init(viewer: DocumentationViewer) {
            self.viewer = viewer
        }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .cancel
            }

            guard url.scheme == "doc" else {
                try? viewer.bridge.emit(.openURL, value: url)
                return .cancel
            }

            return .allow
        }
//
//        @MainActor
//        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//            if let url = navigationAction.request.url {
//                print("HELLO ZRL")
//                if url.scheme == TopicURL.scheme {
//                    decisionHandler(.allow)
//                } else {
//                    print("emitted call url \(url)")
//                    decisionHandler(.cancel)
//                }
//            } else {
//                decisionHandler(.allow)
//            }
//        }
    }

    let viewer: DocumentationViewer

    public init(viewer: DocumentationViewer) {
        self.viewer = viewer
    }

    @MainActor
    public func makeCoordinator() -> Coordinator {
        Coordinator(viewer: viewer)
    }

    @MainActor
    func makeView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Configure URL Handler
        config.setURLSchemeHandler(viewer.schemaHandler, forURLScheme: "doc")
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Configure Communication
        let contentController = WKUserContentController()
        let communicationBackend = WebKitBackend(delegate: context.coordinator.viewer.bridge)
        contentController.add(communicationBackend, name: "bridge")
        config.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.view = view
        context.coordinator.viewer.bridge.backend = communicationBackend
        view.navigationDelegate = context.coordinator

        // Connect Communication & register viewer
        communicationBackend.register(on: view)
        viewer.register(context.coordinator)

        view.isInspectable = true
        return view
    }

    @MainActor
    func updateView(_ nsView: WKWebView, context: Context) {}
}

public extension URL {
    static let doc = URL(string: "doc://")!
}

struct PreviewProvider: ResourceProvider {
    let baseURI: URL

    init(baseURI: URL = URL(string: "https://developer.apple.com/")!) {
        self.baseURI = baseURI
    }

    func provideAsset(_ kind: DocCViewerCore.BundleAssetKind, forBundle identifier: String, at path: String) async throws -> Data {
        let url = baseURI.appending(path: path)
        return try await URLSession.shared.data(from: url).0
    }

    func provideSource(_ kind: DocCViewerCore.AppSourceKind, at path: String) async throws -> Data {
        let url = baseURI.appending(path: path)
        return try await URLSession.shared.data(from: url).0
    }
}
//
//#Preview {
//    DocumentationView(viewer: .init(provider: PreviewProvider()))
//}

#if os(macOS)

// MARK: View (macOS)

extension DocumentationView: NSViewRepresentable {
    public func makeNSView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        updateView(nsView, context: context)
    }
}
#else

// MARK: View (iOS)

extension DocumentationView: UIViewRepresentable {
    public func makeUIView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        updateView(uiView, context: context)
    }
}
#endif
