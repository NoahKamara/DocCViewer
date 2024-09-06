import Foundation
import UniformTypeIdentifiers

/// A Documentation Resource
public enum Resource {
    case bundleAsset(BundleAsset)
    case appSource(AppSource)

    public init?(url: URL) {
        guard let bundleId = url.host() else {
            print("no host")
            return nil
        }

        let pathComponents = url.pathComponents.drop(while: { $0 == "/" })

        switch pathComponents.first {
        case "downloads":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .download, path: url.path()))
        case "images":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .image, path: url.path()))
        case "index":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .index, path: url.path()))
        case "documentation":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .documentation, path: url.path()))
        case "tutorial":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .tutorial, path: url.path()))
        case "data":
            self = .bundleAsset(.init(bundleIdentifier: bundleId, kind: .data, path: url.path()))
        case "js":
            self = .appSource(.init(kind: .js, path: url.path()))
        case "css":
            self = .appSource(.init(kind: .js, path: url.path()))
        case "img":
            self = .appSource(.init(kind: .js, path: url.path()))
//        case "theme-settings.json":
//            self = .bundleAsset(.init(bundleIdentifier: bundleID, kind: , path: url.path()))
        default:
            return nil
        }
    }
}

// MARK: AppSource

/// A resource that represents source code of the swift-docc-render JS client
public struct AppSource {
    public typealias Kind = AppSourceKind

    /// The kind of source
    public let kind: Kind

    /// The path to the source
    public let path: String
}

public enum AppSourceKind {
    case js
    case css
    case img
    case index
}

// MARK: BundleAsset

/// A resource that is specific to a bundle
public struct BundleAsset {
    public typealias Kind = BundleAssetKind

    /// The bundle related to this asset
    public let bundleIdentifier: String

    /// The kind of this asset
    public let kind: Kind

    /// The path to this asset
    public let path: String
}

public enum BundleAssetKind {
    case download
    case image
    case index
    case data
    case documentation
    case tutorial
    case themeSettings

    public var isDocument: Bool {
        switch self {
        case .download, .tutorial: true
        default: false
        }
    }
}
