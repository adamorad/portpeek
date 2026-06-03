import XCTest
@testable import PortPeek

@MainActor
final class MCPToolsTests: XCTestCase {
    var registry: PortRegistry!
    var tools: MCPTools!
    var suiteName: String!
    var suiteDefaults: UserDefaults!

    override func setUp() {
        suiteName = "test.tools.\(UUID().uuidString)"
        suiteDefaults = UserDefaults(suiteName: suiteName)!
        registry = PortRegistry(
            monitoredPorts: [3000, 3001, 5432],
            labelStore: LabelStore(defaults: suiteDefaults),
            reservationStore: ReservationStore(defaults: suiteDefaults),
            defaults: suiteDefaults
        )
        tools = MCPTools(registry: registry)
    }

    override func tearDown() {
        suiteDefaults.synchronize()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func test_listActivePorts_returnsJSON() throws {
        let result = tools.call(name: "list_active_ports", arguments: [:])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["ports"])
        let ports = json["ports"] as! [[String: Any]]
        XCTAssertEqual(ports.count, 3)
    }

    func test_getAvailablePort_returnsPreferredWhenFree() throws {
        let result = tools.call(name: "get_available_port", arguments: ["preferred": 3000, "reserve": false])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["port"] as? Int, 3000)
        XCTAssertEqual(json["reserved"] as? Bool, false)
    }

    func test_getAvailablePort_suggestsNextWhenPreferredReserved() throws {
        try registry.reserve(port: 3000, project: "other", ttlMinutes: 5)
        let result = tools.call(name: "get_available_port", arguments: ["preferred": 3000, "reserve": false])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotEqual(json["port"] as? Int, 3000)
    }

    func test_getAvailablePort_withReserveTrue_reservesPort() throws {
        let result = tools.call(name: "get_available_port", arguments: [
            "preferred": 3000, "reserve": true, "project": "myapp"
        ])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["reserved"] as? Bool, true)
        XCTAssertTrue(registry.reservationStore.isReserved(3000))
    }

    func test_reservePort_succeeds() throws {
        let result = tools.call(name: "reserve_port", arguments: [
            "port": 3000, "project": "myapp", "ttl_minutes": 5
        ])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertNotNil(json["expires_at"])
        XCTAssertTrue(registry.reservationStore.isReserved(3000))
    }

    func test_reservePort_alreadyReserved_returnsFalse() throws {
        try registry.reserve(port: 3000, project: "first", ttlMinutes: 5)
        let result = tools.call(name: "reserve_port", arguments: [
            "port": 3000, "project": "second", "ttl_minutes": 5
        ])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["success"] as? Bool, false)
        XCTAssertNotNil(json["error"])
    }

    func test_releasePort_clearsReservation() throws {
        try registry.reserve(port: 3000, project: "myapp", ttlMinutes: 5)
        let result = tools.call(name: "release_port", arguments: ["port": 3000])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertFalse(registry.reservationStore.isReserved(3000))
    }

    func test_ttlClamped_toMaxOneDayMinimumOne() throws {
        // TTL > 1440 minutes should be clamped to 1440
        let result = tools.call(name: "reserve_port", arguments: [
            "port": 3001, "project": "test", "ttl_minutes": 99999
        ])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["success"] as? Bool, true)
        let remaining = registry.reservationStore.reservation(for: 3001)?.secondsRemaining ?? 0
        XCTAssertLessThanOrEqual(remaining, 1440 * 60)
    }

    func test_unknownTool_returnsError() throws {
        let result = tools.call(name: "nonexistent", arguments: [:])
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["error"])
    }
}
