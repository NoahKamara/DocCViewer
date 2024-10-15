//
//  DocumentationView.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import OSLog
import SwiftUI
import WebKit

public struct DocumentationView {
    public class Coordinator {
        let viewer: DocumentationViewer
        var view: WKWebView?

        @MainActor
        init(viewer: DocumentationViewer) {
            self.viewer = viewer
        }
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
        print("MAKE")
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(viewer.schemaHandler, forURLScheme: "doc")
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let contentController = WKUserContentController()
        let communicationBackend = WebKitBackend(delegate: context.coordinator.viewer.bridge)
        contentController.add(communicationBackend, name: "bridge")
        config.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.view = view
        context.coordinator.viewer.bridge.backend = communicationBackend
        communicationBackend.webView = view
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
