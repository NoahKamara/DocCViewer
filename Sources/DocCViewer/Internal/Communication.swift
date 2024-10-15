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

    static let navigation = EventType("navigation")

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

actor AsyncChannel {
    private var listeners: [UUID: AsyncStream<Data>.Continuation] = [:]

    var isEmpty: Bool { listeners.isEmpty }

    func emit(_ data: Data) {
        for listener in listeners.values {
            listener.yield(data)
        }
    }

    func values() -> AsyncStream<Data> {
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

    private func removeListener(withId id: UUID) {
        listeners[id] = nil
    }
}

public class CommunicationBridge: CommunicationDelegate {
    static let logger = Logger.doccviewer("CommunicationBridge")

    package var backend: CommunicationBackend? = nil
    private var channels: [EventType: AsyncChannel] = [:]

    init() {}

    package func emit(_ type: EventType, data: Data) {
        Self.logger.info("emitted '\(type)'")

        guard let channel = channels[type] else {
            Self.logger.debug("no one is listening for '\(type)' with \(String(data: data, encoding: .utf8) ?? "")")
            return
        }

        Task {
            await channel.emit(data)
        }
    }

    func on<T: Decodable>(_ type: EventType, of: T.Type) async -> some AsyncSequence<T, any Error> {
        let values = await createOrGetChannel(for: type).values()

        let decoder = JSONDecoder()

        return values.map { data in
            try decoder.decode(T.self, from: data)
        }
    }

//    func send()
    private func createOrGetChannel(for type: EventType) -> AsyncChannel {
        if let existing = channels[type] {
            return existing
        }

        let new = AsyncChannel()
        channels[type] = new
        return new
    }
}

import OSLog
import WebKit

public class WebKitBackend: NSObject, CommunicationBackend {
    static let logger = Logger.doccviewer("WebKitBackend")
    package var delegate: CommunicationDelegate
    weak var webView: WKWebView? = nil

    init(delegate: CommunicationDelegate) {
        self.delegate = delegate
        super.init()
        self.delegate.backend = self
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
                let jsonData = try JSONSerialization.data(withJSONObject: eventData)
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
