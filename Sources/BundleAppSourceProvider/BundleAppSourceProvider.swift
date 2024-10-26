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

public struct BundleAppSourceProvider: ResourceProvider {
    let bundleProvider: BundleResourceProvider
    let bundle: Bundle

    public init(bundleProvider: BundleResourceProvider, bundle: Bundle? = nil) {
        self.bundle = bundle ?? .module
        self.bundleProvider = bundleProvider
    }

    func resource(at path: String) throws -> Data {
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
