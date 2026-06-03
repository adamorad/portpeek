// PortPeek/PortPeekTests/Core/ReservationStoreTests.swift
import XCTest
@testable import PortPeek

final class ReservationStoreTests: XCTestCase {
    var store: ReservationStore!

    override func setUp() {
        store = ReservationStore(defaults: UserDefaults(suiteName: "test.reservations.\(UUID().uuidString)")!)
    }

    func test_reserve_marksPortAsReserved() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        XCTAssertTrue(store.isReserved(3000))
    }

    func test_release_clearsReservation() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        store.release(port: 3000)
        XCTAssertFalse(store.isReserved(3000))
    }

    func test_reservation_includesProjectAndExpiry() throws {
        let before = Date()
        try store.reserve(port: 3000, project: "ideas-v2", ttl: 300)
        let r = try XCTUnwrap(store.reservation(for: 3000))
        XCTAssertEqual(r.project, "ideas-v2")
        XCTAssertGreaterThan(r.expires, before.addingTimeInterval(299))
    }

    func test_expiredReservation_isNotReserved() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: -1)
        store.pruneExpired()
        XCTAssertFalse(store.isReserved(3000))
    }

    func test_reservingAlreadyReservedPort_throws() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        XCTAssertThrowsError(try store.reserve(port: 3000, project: "other", ttl: 300))
    }
}
