//
//  File.swift
//  DocCViewer
//
//  Created by Noah Kamara on 22.11.24.
//

import Foundation
import DocumentationKit
import SymbolKit
import UniformTypeIdentifiers


extension AsyncFileServer {
    /**
     Returns a tuple with a response and the given data.
     - Parameter request: The request coming from a web client.
     - Returns: The response and data which are going to be served to the client.
     */
    func response(to request: URLRequest) async -> (Data?, URLResponse) {
        guard let url = request.url else {
            let response = HTTPURLResponse.error(
                url: baseURL,
                statusCode: 400,
                error: URLError(.badURL)
            )
            return (nil, response)
        }
        
        
        do {
            let data: Data
            let mimeType: String
            
            guard url.absoluteString.hasPrefix(baseURL.absoluteString) else {
                let response = HTTPURLResponse.error(
                    url: baseURL,
                    statusCode: 403,
                    error: URLError(.unsupportedURL)
                )
                print("UNSUPPORTED URL")
                return (nil, response)
            }
            
            // We need to make sure that the path extension is for an actual file and not a symbol name which is a false positive
            // like: "'...(_:)-6u3ic", that would be recognized as filename with the extension "(_:)-6u3ic". (rdar://71856738)
            if url.pathExtension.isAlphanumeric && !url.lastPathComponent.isSwiftEntity {
                data = try await self.data(for: url)
                mimeType = AsyncFileServer.mimeType(for: url.pathExtension)
            } else { // request is for a path, we need to fake a redirect here
                if url.pathComponents.isEmpty {
                    print("Tried to load an invalid URL: \(url.absoluteString).\nFalling back to serve index.html.")
                }
                mimeType = "text/html"
                data = try await self.data(for: baseURL.appendingPathComponent("/index.html"))
            }
            
            let response = HTTPURLResponse.response(
                url: url,
                mimeType: mimeType,
                contentLength: data.count
            )
                
            return (data, response)
        } catch {
            let response = HTTPURLResponse.error(url: url, statusCode: 404, error: error)
            return (nil, response)
        }
    }
    
    /// Returns the MIME type based on file extension, best guess.
    internal static func mimeType(for ext: String) -> String {
        let defaultMimeType = "application/octet-stream"
        let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType
        return mimeType ?? defaultMimeType
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

    static func response(url: URL, mimeType: String, contentLength: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: contentLength,
            textEncodingName: "utf-8"
        )
    }
}


fileprivate extension String {
    /// Check that a given string is alphanumeric.
    var isAlphanumeric: Bool {
        return !self.isEmpty && self.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }
    
    /// Check that a given string is a Swift entity definition.
    var isSwiftEntity: Bool {
        let swiftEntityPattern = #"(?<=\-)swift\..*"#
        if let range = range(of: swiftEntityPattern, options: .regularExpression, range: nil, locale: nil) {
            let entityCheck = String(self[range])
            return isKnownEntityDefinition(entityCheck)
        }
        return false
    }
}

/// Checks whether the given string is a known entity definition which might interfere with the rendering engine while dealing with URLs.
fileprivate func isKnownEntityDefinition(_ identifier: String) -> Bool {
    return SymbolGraph.Symbol.KindIdentifier.isKnownIdentifier(identifier)
}

