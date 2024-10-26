//
//  Communication.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation

public struct EventType: Hashable, Sendable, Equatable, Codable, CustomStringConvertible {
    public var description: String { rawValue }
    let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        try rawValue.encode(to: encoder)
    }

    enum CodingKeys: CodingKey {
        case rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(String(from: decoder))
    }
}

// MARK: Default Events

public extension EventType {
    /// an event that can be sent to the viewer to trigger navigation to a new topic
    /// > data should be a url that has a shared base with the current url
    /// > (in most cases this means the new url must be in the same bundle)
    static let navigation = EventType("navigation")

    /// an event sent by the viewer after navigating to a page
    /// > data is the current page URL
    static let didNavigate = EventType("didNavigate")
    
    /// an event sent by the viewer when the user clicked on a non-documentation url
    /// > data is the requested URL
    static let openURL = EventType("openURL")
}

// struct Event<T: Codable>: RawRepresentable {
//    let type: String
//    let data: T
//
//    init(type: String, data: Codable) {
//        self.type = type
//        self.data = data
//    }
//
//    init(<#parameters#>) {
//        <#statements#>
//    }
//
//    static let navigation = EventType("navigation")
// }

public struct EmptyCodable: Codable {}

public struct DocumentationRenderEvent {
    let type: String
    let data: String
}

package protocol CommunicationDelegate {
    var backend: CommunicationBackend? { get set }
    func emit(_ type: EventType, data: Data)
}

package protocol CommunicationBackend {
    var delegate: CommunicationDelegate { get }

    func send<T: Encodable>(_ type: EventType, data: T) async throws
}

public actor AsyncChannel {
    private var listeners: [UUID: AsyncStream<Data>.Continuation] = [:]

    var isEmpty: Bool { listeners.isEmpty }

    func emit(_ data: Data) {
        for listener in listeners.values {
            listener.yield(data)
        }
    }

    public func values() -> AsyncStream<Data> {
        let identifier = UUID()

        return AsyncStream { continuation in
            listeners[identifier] = continuation

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.removeListener(withId: identifier)
                }
            }
        }
    }

    public func values<T: Decodable & Sendable>(as type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> AsyncThrowingMapSequence<AsyncStream<Data>, T> {
        values().map { data in
            try decoder.decode(T.self, from: data)
        }
    }

    private func removeListener(withId id: UUID) {
        listeners[id] = nil
    }
}

import OSLog
import WebKit

public class WebKitBackend: NSObject, CommunicationBackend {
    static let logger = Logger.doccviewer("WebKitBackend")
    package var delegate: CommunicationDelegate
    private weak var webView: WKWebView? = nil

    init(delegate: CommunicationDelegate) {
        self.delegate = delegate
        super.init()
        self.delegate.backend = self
    }

    @MainActor
    func register(on webView: WKWebView) {
        self.webView = webView

        // observe navigation changes
        let didNavigateScript = """
        (function() {
            let lastUrl = window.location.href;
            new MutationObserver(() => {
                const url = window.location.href;
                if (url !== lastUrl) {
                    lastUrl = url;
                    console.debug("didNavigate")
                    window.bridge.send({type: "didNavigate", data: url});
                }
            }).observe(document, {subtree: true, childList: true});
        })();
        """

        let userScript = WKUserScript(source: didNavigateScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }

    package func send(_ type: EventType, data: some Encodable) async throws {
        guard let webView else {
            Self.logger.error("send called before webView was registered")
            return
        }

        let data = try JSONEncoder().encode(Event(type: type, data: data))

        let script = "window.bridge.receive(\(String(data: data, encoding: .utf8)!))"

        print(script)
        await webView.evaluateJavaScript(script, in: .none, in: .page, completionHandler: { _ in })
    }
}

extension WebKitBackend: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = message.body as? [String: Any],
              let type = event["type"] as? String
        else {
            print("Invalid message format")
            return
        }

        if let eventData = event["data"] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: eventData, options: [.fragmentsAllowed])
                delegate.emit(.init(type), data: jsonData)
            } catch {
                Self.logger.error("failed to deserialize message for event '\(type)': \(message)")
            }
        } else {
            delegate.emit(.init(type), data: Data())
        }
    }
}

struct Event<T: Encodable>: Encodable {
    let type: EventType
    let data: T
}
