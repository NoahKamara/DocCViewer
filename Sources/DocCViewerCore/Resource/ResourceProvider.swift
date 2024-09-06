//
//  ResourceProvider.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation

public protocol ResourceProvider: BundleResourceProvider, AppResourceProvider {
    func provide(_ resource: Resource) async throws -> Data
    func provideAsset(_ kind: BundleAssetKind, forBundle identifier: String, at path: String) async throws -> Data
    func provideSource(_ kind: AppSourceKind, at path: String) async throws -> Data
}

// MARK: Bundle Resources

public protocol BundleResourceProvider {
    func provideAsset(_ kind: BundleAssetKind, forBundle identifier: String, at path: String) async throws -> Data
}

// MARK: App Resources

public protocol AppResourceProvider {
    func provideSource(_ kind: AppSourceKind, at path: String) async throws -> Data
}

// MARK: Any

public struct AnyResourceProvider: ResourceProvider {
    let app: any AppResourceProvider
    let bundle: any BundleResourceProvider

    public init(app: any AppResourceProvider, bundle: any BundleResourceProvider) {
        self.app = app
        self.bundle = bundle
    }

    public func provide(_ resource: Resource) async throws -> Data {
        switch resource {
        case .bundleAsset(let asset):
            try await bundle.provideAsset(asset.kind, forBundle: asset.bundleIdentifier, at: asset.path)
        case .appSource(let source):
            try await app.provideSource(source.kind, at: source.path)
        }
    }

    public func provideAsset(_ kind: BundleAssetKind, forBundle identifier: String, at path: String) async throws -> Data {
        try await bundle.provideAsset(kind, forBundle: identifier, at: path)
    }

    public func provideSource(_ kind: AppSourceKind, at path: String) async throws -> Data {
        try await app.provideSource(kind, at: path)
    }
}

public extension ResourceProvider {
    func provide(_ resource: Resource) async throws -> Data {
        switch resource {
        case .bundleAsset(let asset): try await provideAsset(asset.kind, forBundle: asset.bundleIdentifier, at: asset.path)
        case .appSource(let source): try await provideSource(source.kind, at: source.path)
        }
    }
}
