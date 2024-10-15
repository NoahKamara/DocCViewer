//
//  File.swift
//  DocCViewer
//
//  Created by Noah Kamara on 15.10.24.
//

import Foundation
import OSLog

public extension DocumentationViewer {
    class Bridge: CommunicationDelegate {
        static let logger = Logger.doccviewer("Events")
        
        package var backend: CommunicationBackend? = nil
        private var channels: [EventType: AsyncChannel] = [:]
        

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
                
        func on<T: Decodable>(_ type: EventType, of: T.Type) async -> some AsyncSequence<T, any Error> {
            let values = await createOrGetChannel(for: type).values()
            
            let decoder = JSONDecoder()
            
            return values.map { data in
                try decoder.decode(T.self, from: data)
            }
        }
        
        private func createOrGetChannel(for type: EventType) -> AsyncChannel {
            if let existing = channels[type] {
                return existing
            }
            
            let new = AsyncChannel()
            channels[type] = new
            return new
        }
        
        func send<T: Encodable>(_ type: EventType, data: T) async throws {
            guard let backend else {
                Self.logger.warning("backend not attached. cannot send")
                return
            }
            
            try await backend.send(type, data: data)
        }
    }
}

