//
//  DocumentationSchemeHandler.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import DocCViewerCore
import OSLog
import SwiftUI
import Synchronization
import UniformTypeIdentifiers
import WebKit
import SwiftDocC



private extension HTTPURLResponse {
    static func error(url: URL, statusCode: Int, error: (any Error)? = nil) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [
                "X-Documentation-Provider-Error": "\(error.map { "\($0)" } ?? "-")",
            ]
        )!
    }

    static func response(url: URL, type: UTType, contentLength: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            mimeType: type.preferredMIMEType ?? "text/html",
            expectedContentLength: contentLength,
            textEncodingName: "utf-8"
        )
    }
}


fileprivate let slashCharSet = CharacterSet(charactersIn: "/")

import DocumentationKit

public typealias DocumentationServerProvider = BundleRepositoryProvider


public class DocumentationSchemeHandler2: NSObject {
    let logger = Logger.doccviewer("DocumentationSchemeHandler")
    @MainActor
    private var tasks: [URLRequest: Task<Void, Never>] = [:]
    
    // The schema to support the documentation.
    public static let scheme = "doc"
    public static var fullScheme: String {
        return "\(scheme)://"
    }
    
    /// The `FileServer` instance for serving content.
    let fileServer: AsyncFileServer
    
    /// The `MemoryFileServerProvider` instance for serving in-memory content.
    let inMemoryFileServer: MemoryFileServerProvider = .init()
    
    public override init() {
        fileServer = AsyncFileServer(baseURL: URL(string: DocumentationSchemeHandler2.fullScheme)!)
    }
    
    /// Returns a response to a given request.
    public func response(to request: URLRequest) async -> (Data?, URLResponse) {
        return await fileServer.response(to: request)
    }
}

// MARK: WKURLSchemeHandler protocol
extension DocumentationSchemeHandler2: WKURLSchemeHandler {
    public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        tasks[urlSchemeTask.request] = Task {
            let (data, response) = await response(to: urlSchemeTask.request)
            await MainActor.run {
                guard tasks[urlSchemeTask.request] != nil else { return }
                urlSchemeTask.didReceive(response)
                if let data {
                    urlSchemeTask.didReceive(data)
                }
                urlSchemeTask.didFinish()
            }
        }
    }

    @MainActor
    public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        logger.debug("cancelling task \(urlSchemeTask.request)")
        tasks[urlSchemeTask.request]?.cancel()
        tasks[urlSchemeTask.request] = nil
    }
}

