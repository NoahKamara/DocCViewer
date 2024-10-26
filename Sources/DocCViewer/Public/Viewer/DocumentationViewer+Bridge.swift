//
//  DocumentationViewer+Bridge.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
import OSLog

public extension DocumentationViewer {
    class Bridge: CommunicationDelegate {
        static let logger = Logger.doccviewer("Events")

        package var backend: CommunicationBackend? = nil
        private var channels: [EventType: AsyncChannel] = [:]

        package func emit(_ type: EventType, value: some Encodable) throws {
            let data = try JSONEncoder().encode(value)
            emit(type, data: data)
        }

        package func emit(_ type: EventType, data: Data) {
            Self.logger.info("emitted '\(type)'")

            guard let channel = channels[type] else {
                Self.logger.info("no one is listening for '\(type)'")
                return
            }

            Task {
                await channel.emit(data)
            }
        }

        public func channel(for type: EventType) -> AsyncChannel {
            createOrGetChannel(for: type)
        }

        private func createOrGetChannel(for type: EventType) -> AsyncChannel {
            if let existing = channels[type] {
                return existing
            }

            let new = AsyncChannel()
            channels[type] = new
            return new
        }

        public func send(_ type: EventType, data: some Encodable) async throws {
            guard let backend else {
                Self.logger.warning("backend not attached. cannot send")
                return
            }

            try await backend.send(type, data: data)
        }
    }
}
