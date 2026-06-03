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

    func test_probePort_returnsFalseForInvalidPort() async {
        let scanner = PortScanner(timeout: 0.5)
        let zero = await scanner.probePort(0)
        let tooBig = await scanner.probePort(99999)
        XCTAssertFalse(zero)
        XCTAssertFalse(tooBig)
    }
}

final class TCPTestServer {
    private var listener: NWListener?
    let port: Int

    init() throws {
        let l = try NWListener(using: .tcp, on: 0)
        l.newConnectionHandler = { conn in conn.cancel() }

        let sem = DispatchSemaphore(value: 0)
        l.stateUpdateHandler = { state in
            if case .ready = state { sem.signal() }
        }
        l.start(queue: .global())
        guard sem.wait(timeout: .now() + 3) == .success else {
            l.cancel()
            throw XCTSkip("Test listener did not reach ready state in time")
        }

        guard let nwPort = l.port, nwPort != .any else {
            l.cancel()
            throw XCTSkip("Test listener has no assigned port")
        }
        self.port = Int(nwPort.rawValue)
        self.listener = l
    }

    func stop() {
        listener?.cancel()
    }
}
