//
//  DocumentationSchemeHandler.swift
//
//  Copyright © 2024 Noah Kamara.
//

import DocCViewerCore
import OSLog
import SwiftUI
import Synchronization
import UniformTypeIdentifiers
import WebKit

class DocumentationSchemeHandler: NSObject {
    let logger = Logger.doccviewer("DocumentationSchemeHandler")
    let provider: ResourceProvider

    init(provider: ResourceProvider) {
        self.provider = provider
    }

    @MainActor
    var tasks: [URLRequest: Task<Void, Never>] = [:]
}

// MARK: URLSchemeHandler

extension DocumentationSchemeHandler: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            logger.error("failed to load documentation. request is missing url: \(urlSchemeTask.request)")
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        tasks[urlSchemeTask.request] = Task { @MainActor in
            let (data, response) = await loadResource(at: url)
            await MainActor.run {
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            }
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        logger.info("cancelling task \(urlSchemeTask.request)")
        tasks[urlSchemeTask.request]?.cancel()
    }

    private func loadResource(at url: URL) async -> (Data, URLResponse) {
        guard let resource = Resource(url: url) else {
            logger.warning("[GET] \(url): Not a resource URL")
            return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }
        print(resource, url)

        do {
            let responseType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "text/html"
            let resourceData = try await provider.provide(resource)

            let urlResponse = HTTPURLResponse(
                url: url,
                mimeType: responseType,
                expectedContentLength: resourceData.count,
                textEncodingName: "utf-8"
            )

            logger.info("[GET] \(url): provided \(resourceData.count, format: .byteCount) of '\(responseType)'")
            return (resourceData, urlResponse)
        } catch {
            logger.error("[GET] \(url) failed to load with error: \(error)")

            let urlResponse = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: [
                    "X-Documentation-Provider-Error": "\(error)",
                ]
            )!

            return (Data(), urlResponse)
        }
    }
}
