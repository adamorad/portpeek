import XCTest
import Network
@testable import PortPeek

final class PortScannerTests: XCTestCase {
    func test_probePort_returnsTrueForListeningPort() async throws {
        let server = try TCPTestServer()
        defer { server.stop() }

        let scanner = PortScanner(timeout: 1.0)
        let isOpen = await scanner.probePort(server.port)
        XCTAssertTrue(isOpen)
    }

    func test_probePort_returnsFalseForClosedPort() async {
        let scanner = PortScanner(timeout: 0.5)
        let isOpen = await scanner.probePort(19999)
        XCTAssertFalse(isOpen)
    }

    func test_probePorts_returnsOnlyOpenPorts() async throws {
        let server = try TCPTestServer()
        defer { server.stop() }

        let scanner = PortScanner(timeout: 1.0)
        let results = await scanner.probePorts([server.port, 19998, 19997])
        XCTAssertTrue(results.contains(server.port))
        XCTAssertFalse(results.contains(19998))
        XCTAssertFalse(results.contains(19997))
    }
}

final class TCPTestServer {
    private var listener: NWListener?
    let port: Int

    init() throws {
        let l = try NWListener(using: .tcp, on: 0)
        l.stateUpdateHandler = { _ in }
        l.newConnectionHandler = { conn in conn.cancel() }
        l.start(queue: .global())
        // Allow the listener to bind and get an assigned port
        Thread.sleep(forTimeInterval: 0.15)
        let assigned = l.port.flatMap { Int($0.rawValue) } ?? 0
        if assigned == 0 { throw XCTSkip("Could not bind test listener") }
        self.port = assigned
        self.listener = l
    }

    func stop() {
        listener?.cancel()
    }
}
