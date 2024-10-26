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
import Docsy

@Observable
public class DocumentationViewer {
    let logger = Logger.doccviewer("Viewer")
    let schemaHandler: DocumentationSchemeHandler
    public let bridge: Bridge = .init()
    private var coordinator: DocumentationView.Coordinator?
    
    @MainActor
    public var themeSettings: ThemeSettings? {
        get { schemaHandler.globalThemeSettings }
        set {
            schemaHandler.globalThemeSettings = newValue
            reload()
        }
    }
    
    @MainActor
    public var useCustomTheme: Bool {
        get { schemaHandler.useCustomTheme }
        set {
            schemaHandler.useCustomTheme = newValue
            reload()
        }
    }
    
    @MainActor
    public init(provider: ResourceProvider, globalThemeSettings: ThemeSettings? = nil) {
        self.schemaHandler = DocumentationSchemeHandler(provider: provider)
        self.schemaHandler.globalThemeSettings = globalThemeSettings

        let didNavigatePublisher = bridge.channel(for: .didNavigate)

        self.monitoringTask = Task {
            let changes = await didNavigatePublisher.values(as: URL.self)

            do {
                for try await url in changes {
                    await didNavigate(to: url)
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
    func reload() {
        self.coordinator?.view?.reload()
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

    var currentTopic: TopicURL? = nil
    
    @MainActor
    private func didNavigate(to url: URL) {
        withMutation(keyPath: \.canGoForward) {
            self.canGoForward = coordinator?.view?.canGoForward == true
        }
        withMutation(keyPath: \.canGoBack) {
            self.canGoBack = coordinator?.view?.canGoBack == true
        }
        
        guard let topicUrl = TopicURL(url: url) else {
            print("invalid topic url: \(url)")
            return
        }
        
        self.currentTopic = topicUrl
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
        logger
            .debug(
                "navigating '\(self.currentTopic?.url.absoluteString ?? "-")' -> '\(topicUrl.url)'"
            )
        
        guard currentTopic != topicUrl else {
            logger.debug("DEBOUNDE: navigating to \(topicUrl.url)")
            return
        }
        
        defer { self.currentTopic = topicUrl }
        guard let currentTopic, currentTopic.bundleIdentifier == topicUrl.bundleIdentifier else {
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
