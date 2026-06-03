import Foundation
import Network

final class MCPServer {
    private var listener: NWListener?
    private let registry: PortRegistry
    private let port: UInt16
    private let queue = DispatchQueue(label: "com.portpeek.mcp", qos: .userInitiated)

    init(registry: PortRegistry, port: UInt16 = 27182) {
        self.registry = registry
        self.port = port
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("[PortPeek] MCP server failed: \(error)")
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self, let data, !data.isEmpty, error == nil else {
                connection.cancel()
                return
            }
            Task { @MainActor in
                guard let body = self.extractHTTPBody(from: data) else {
                    connection.cancel()
                    return
                }
                let handler = MCPHandler(registry: self.registry)
                guard let responseBody = try? handler.handle(body), !responseBody.isEmpty else {
                    connection.cancel()
                    return
                }
                let http = self.buildHTTPResponse(body: responseBody)
                connection.send(content: http, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private func extractHTTPBody(from data: Data) -> Data? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }
        let body = data[range.upperBound...]
        return body.isEmpty ? nil : Data(body)
    }

    private func buildHTTPResponse(body: Data) -> Data {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Data(header.utf8) + body
    }
}
