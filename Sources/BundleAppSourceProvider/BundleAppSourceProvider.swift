//
//  BundleAppSourceProvider.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import DocCViewerCore
import Foundation

enum BundleAppSourceError: Error {
    case notFound
}

public struct BundleAppSourceProvider {
    let bundleProvider: BundleResourceProvider
    let bundle: Bundle

    public init(bundleProvider: BundleResourceProvider, bundle: Bundle? = nil) {
        self.bundle = bundle ?? .module
        self.bundleProvider = bundleProvider
    }

    func resource(at path: String) throws -> Data {
        print("RESOURCE", path)
        let resourcesURL = bundle.resourceURL?.appending(component: "ArchiveResources")

        guard let resourcesURL else {
            throw BundleAppSourceError.notFound
        }

        let url = resourcesURL.appending(path: path)

        return try Data(contentsOf: url)
    }

    public func provideAsset(_ kind: BundleAssetKind, forBundle identifier: String, at path: String) async throws -> Data {
        switch kind {
        case .documentation, .tutorial:
            try resource(at: "index.html")
        default:
            try await bundleProvider.provideAsset(kind, forBundle: identifier, at: path)
        }
    }

    public func provideSource(_ kind: AppSourceKind, at path: String) async throws -> Data {
        try resource(at: path)
    }
}

extension BundleAppSourceProvider {
    public func data(for path: String) async throws -> Data {
        print("APP SOURCE", path)
        let components = path
            .trimmingCharacters(in: .init(charactersIn: "/"))
            .split(separator: "/")
        
        guard !components.isEmpty else {
            print("PROVIDER", "empty path")
            throw BundleAppSourceError.notFound
        }
        
        return switch components.first {
            case nil, "index.html", "documentation", "tutorials": try resource(at: "index.html")
            case "js": try resource(at: path)
            case "css": try resource(at: path)
            case "img": try resource(at: path)
            default: throw BundleAppSourceError.notFound
        }
    }
}
