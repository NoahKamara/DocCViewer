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

class DocumentationSchemeHandler: NSObject {
    let logger = Logger.doccviewer("DocumentationSchemeHandler")
    let provider: ResourceProvider

    var globalThemeSettings: ThemeSettings?
    var useCustomTheme: Bool = false

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

        tasks[urlSchemeTask.request] = Task {
            let (data, response) = await loadResource(at: url)
            await MainActor.run {
                guard tasks[urlSchemeTask.request] != nil else { return }
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            }
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        logger.debug("cancelling task \(urlSchemeTask.request)")
        tasks[urlSchemeTask.request]?.cancel()
        tasks[urlSchemeTask.request] = nil
    }

    private func loadResource(at url: URL) async -> (Data, URLResponse) {
        guard let resource = Resource(url: url) else {
            logger.warning("[GET] \(url): Not a resource URL")
            return (Data(), HTTPURLResponse.error(url: url, statusCode: 404))
        }

        // use global theme settings if available
        if
            case .bundleAsset(let asset) = resource,
            asset.kind == .themeSettings
        {
            logger.debug("[GET] \(url): overriding theme-settings.json")

            var data: Data? = nil

            // Attempt to use custom theme if allowed
            if useCustomTheme {
                logger.debug("[GET] \(url): attempting to load custom theme")

                do {
                    data = try await provider.provide(resource)
                } catch {
                    logger.debug("[GET] \(url): failed to load custom theme-settings.json")
                }
            }

            // Load global theme if available
            if let globalThemeSettings {
                logger.debug("[GET] \(url): attempting to load encode global theme")
                do {
                    data = try JSONEncoder().encode(globalThemeSettings)
                } catch {
                    logger.warning("[GET] \(url): failed to encode global theme-settings.json")
                    return (Data(), HTTPURLResponse.error(url: url, statusCode: 500, error: error))
                }
            }

            guard let data else {
                logger.warning("[GET] \(url): neither global theme nor custom theme")
                return (Data(), HTTPURLResponse.error(url: url, statusCode: 404))
            }

            print(String(data: data, encoding: .utf8)!)
            return (
                data,
                HTTPURLResponse.response(url: url, type: .json, contentLength: data.count)
            )
        }

        do {
            let responseType = UTType(filenameExtension: url.pathExtension) ?? .html
            let data = try await provider.provide(resource)

            logger.debug("[GET] \(url): provided \(data.count, format: .byteCount) of '\(responseType)'")
            return (
                data,
                HTTPURLResponse.response(url: url, type: responseType, contentLength: data.count)
            )
        } catch {
            logger.error("[GET] \(url) failed to load with error: \(error)")
            return (Data(), HTTPURLResponse.error(url: url, statusCode: 404, error: error))
        }
    }
}

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
