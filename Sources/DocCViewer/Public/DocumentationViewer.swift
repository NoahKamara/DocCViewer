//
//  DocumentationViewer.swift
//
//  Copyright © 2024 Noah Kamara.
//

@_exported import DocCViewerCore
import Foundation
import Observation
import OSLog

@Observable
public class DocumentationViewer {
    let logger = Logger.doccviewer("Viewer")
    let schemaHandler: DocumentationSchemeHandler
    private var coordinator: DocumentationView.Coordinator?

    public init(provider: ResourceProvider) {
        self.schemaHandler = DocumentationSchemeHandler(provider: provider)
    }

    public convenience init(_ bundleProvider: BundleResourceProvider, app: AppResourceProvider) {
        self.init(provider: AnyResourceProvider(app: app, bundle: bundleProvider))
    }

    func register(_ coordinator: DocumentationView.Coordinator) {
        self.coordinator = coordinator
    }

    public var canGoBack: Bool = false
    public var canGoForward: Bool = false

    @MainActor
    public func goBack() {
        withCoordinator { coordinator in
            coordinator.view?.goBack()
        }
    }

    @MainActor
    public func goForward() {
        withCoordinator { coordinator in
            coordinator.view?.goForward()
        }
    }

    @MainActor
    public func load(_ url: TopicURL) {
        logger.info("loading \(url.url)")
        withCoordinator { coordinator in
            coordinator.view?.load(URLRequest(url: url.url))
        }
    }

    @MainActor
    private func withCoordinator(_ closure: @MainActor (DocumentationView.Coordinator) -> Void) {
        guard let coordinator else {
            logger.warning("not attached to view")
            return
        }

        closure(coordinator)
    }
}
