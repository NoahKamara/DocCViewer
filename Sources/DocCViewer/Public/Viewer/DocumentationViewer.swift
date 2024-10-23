//
//  DocumentationViewer.swift
//  DocCViewer
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
    public let bridge: Bridge = .init()
    private var coordinator: DocumentationView.Coordinator?

    @MainActor
    public init(provider: ResourceProvider) {
        self.schemaHandler = DocumentationSchemeHandler(provider: provider)

        let didNavigatePublisher = bridge.channel(for: .didNavigate)

        self.monitoringTask = Task {
            let changes = await didNavigatePublisher.values()

            do {
                for try await url in changes {
                    await didNavigate()
                }
            } catch {
                print("monitoring failed", error)
            }
        }
    }

    deinit {
        self.monitoringTask.cancel()
    }

    @MainActor
    public convenience init(_ bundleProvider: BundleResourceProvider, app: AppResourceProvider) {
        self.init(provider: AnyResourceProvider(app: app, bundle: bundleProvider))
    }

    func register(_ coordinator: DocumentationView.Coordinator) {
        self.coordinator = coordinator
    }

    public var canGoBack: Bool = false
    public var canGoForward: Bool = false

    private var monitoringTask: Task<Void, Never> = Task {}

    @MainActor
    private func didNavigate() {
        withMutation(keyPath: \.canGoForward) {
            self.canGoForward = coordinator?.view?.canGoForward == true
        }
        withMutation(keyPath: \.canGoBack) {
            self.canGoBack = coordinator?.view?.canGoBack == true
        }
    }

    @MainActor
    public func goBack() {
        coordinator?.view?.goBack()
    }

    @MainActor
    public func goForward() {
        coordinator?.view?.goForward()
    }

    @MainActor
    public func navigate(to topicUrl: TopicURL) {
        logger.debug("navigating to \(topicUrl.url)")

        guard
            let currentUrl = coordinator?.view?.url,
            let currentBundleId = currentUrl.host ?? currentUrl.pathComponents.first
        else {
            logger.debug("attempt full page navigation to \(topicUrl.url)")
            coordinator?.view?.load(.init(url: topicUrl.url))
            return
        }

        Task {
            logger.debug("attempting dynamic navigation to \(topicUrl.url)")
            try await bridge.send(.navigation, data: topicUrl.path)
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
