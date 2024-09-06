//
//  File.swift
//  DocCViewer
//
//  Created by Noah Kamara on 06.09.24.
//

import Foundation
import WebKit

public struct TopicURL {
    public let bundleIdentifier: String
    public let path: String

    public init(bundleIdentifier: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }

    public var url: URL {
        URL(string: "doc://\(bundleIdentifier)\(path)")!
    }
}

extension DocumentationSchemeHandler: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.request.url?.scheme == "doc" else {
            return .cancel
        }

        return .allow
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStart", navigation)
    }
}
