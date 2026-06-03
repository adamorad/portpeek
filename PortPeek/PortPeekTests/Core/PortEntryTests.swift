// PortPeek/PortPeekTests/Core/PortEntryTests.swift
import XCTest
@testable import PortPeek

final class PortEntryTests: XCTestCase {
    func test_displayName_usesUserLabel_whenSet() {
        let entry = PortEntry(port: 3000, status: .available, userLabel: "My API")
        XCTAssertEqual(entry.displayName, "My API")
    }

    func test_displayName_fallsBackToPortNumber_whenNoLabel() {
        let entry = PortEntry(port: 3000, status: .available, userLabel: nil)
        XCTAssertEqual(entry.displayName, "Port 3000")
    }

    func test_id_isPort() {
        let entry = PortEntry(port: 5432, status: .listening, userLabel: nil)
        XCTAssertEqual(entry.id, 5432)
    }

    func test_portStatus_equatable() {
        XCTAssertEqual(PortStatus.available, PortStatus.available)
        XCTAssertEqual(PortStatus.listening, PortStatus.listening)
        let date = Date()
        XCTAssertEqual(
            PortStatus.reserved(project: "proj", expires: date),
            PortStatus.reserved(project: "proj", expires: date)
        )
        XCTAssertNotEqual(PortStatus.available, PortStatus.listening)
    }

    func test_defaultMonitoredPorts_containsCommonDevPorts() {
        let ports = PortEntry.defaultMonitoredPorts
        XCTAssertTrue(ports.contains(3000))
        XCTAssertTrue(ports.contains(5432))
        XCTAssertTrue(ports.contains(6379))
        XCTAssertTrue(ports.contains(8080))
        XCTAssertTrue(ports.contains(27017))
    }
}
