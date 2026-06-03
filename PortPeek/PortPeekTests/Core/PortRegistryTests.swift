import XCTest
@testable import PortPeek

@MainActor
final class PortRegistryTests: XCTestCase {
    var registry: PortRegistry!
    var suiteName: String!

    override func setUp() {
        suiteName = "test.registry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        registry = PortRegistry(
            monitoredPorts: [3000, 5432],
            labelStore: LabelStore(defaults: defaults),
            reservationStore: ReservationStore(defaults: defaults),
            defaults: defaults
        )
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func test_initialEntries_containsMonitoredPorts() {
        let ports = registry.entries.map(\.port)
        XCTAssertTrue(ports.contains(3000))
        XCTAssertTrue(ports.contains(5432))
    }

    func test_setLabel_updatesEntry() {
        registry.setLabel("My DB", for: 5432)
        let entry = registry.entries.first { $0.port == 5432 }
        XCTAssertEqual(entry?.userLabel, "My DB")
    }

    func test_reserve_updatesEntryStatus() throws {
        try registry.reserve(port: 3000, project: "ideas", ttlMinutes: 5)
        let entry = registry.entries.first { $0.port == 3000 }
        if case .reserved(let project, _) = entry?.status {
            XCTAssertEqual(project, "ideas")
        } else {
            XCTFail("Expected .reserved status")
        }
    }

    func test_release_clearsReservation() throws {
        try registry.reserve(port: 3000, project: "ideas", ttlMinutes: 5)
        registry.release(port: 3000)
        let entry = registry.entries.first { $0.port == 3000 }
        XCTAssertEqual(entry?.status, .available)
    }

    func test_addPort_appendsToMonitoredList() {
        registry.addPort(9000)
        XCTAssertTrue(registry.monitoredPorts.contains(9000))
    }

    func test_removePort_deletesFromMonitoredList() {
        registry.removePort(3000)
        XCTAssertFalse(registry.monitoredPorts.contains(3000))
    }
}
