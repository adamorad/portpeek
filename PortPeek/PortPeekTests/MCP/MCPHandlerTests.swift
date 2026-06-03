import XCTest
@testable import PortPeek

@MainActor
final class MCPHandlerTests: XCTestCase {
    var registry: PortRegistry!
    var handler: MCPHandler!
    var suiteName: String!

    override func setUp() {
        suiteName = "test.mcp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        registry = PortRegistry(
            monitoredPorts: [3000, 5432],
            labelStore: LabelStore(defaults: defaults),
            reservationStore: ReservationStore(defaults: defaults),
            defaults: defaults
        )
        handler = MCPHandler(registry: registry)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func test_initialize_returnsCapabilities() throws {
        let req = #"{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}"#
        let resp = try handler.handle(Data(req.utf8))
        let json = try JSONSerialization.jsonObject(with: resp) as! [String: Any]
        XCTAssertEqual(json["jsonrpc"] as? String, "2.0")
        XCTAssertNotNil(json["result"])
    }

    func test_toolsList_returnsFourTools() throws {
        let req = #"{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}"#
        let resp = try handler.handle(Data(req.utf8))
        let json = try JSONSerialization.jsonObject(with: resp) as! [String: Any]
        let result = json["result"] as! [String: Any]
        let tools = result["tools"] as! [[String: Any]]
        XCTAssertEqual(tools.count, 4)
        let names = tools.map { $0["name"] as! String }
        XCTAssertTrue(names.contains("list_active_ports"))
        XCTAssertTrue(names.contains("get_available_port"))
        XCTAssertTrue(names.contains("reserve_port"))
        XCTAssertTrue(names.contains("release_port"))
    }

    func test_unknownMethod_returnsError() throws {
        let req = #"{"jsonrpc":"2.0","method":"unknown/method","params":{},"id":3}"#
        let resp = try handler.handle(Data(req.utf8))
        let json = try JSONSerialization.jsonObject(with: resp) as! [String: Any]
        XCTAssertNotNil(json["error"])
    }

    func test_listActivePorts_returnsEntries() throws {
        let req = #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_active_ports","arguments":{}},"id":4}"#
        let resp = try handler.handle(Data(req.utf8))
        let json = try JSONSerialization.jsonObject(with: resp) as! [String: Any]
        XCTAssertNotNil(json["result"])
    }

    func test_notificationsInitialized_returnsEmptyData() throws {
        let req = #"{"jsonrpc":"2.0","method":"notifications/initialized","params":{},"id":5}"#
        let resp = try handler.handle(Data(req.utf8))
        XCTAssertTrue(resp.isEmpty)
    }
}
