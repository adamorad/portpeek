// PortPeek/PortPeekTests/Core/LabelStoreTests.swift
import XCTest
@testable import PortPeek

final class LabelStoreTests: XCTestCase {
    var store: LabelStore!

    override func setUp() {
        store = LabelStore(defaults: UserDefaults(suiteName: "test.labels.\(UUID().uuidString)")!)
    }

    func test_setAndGetLabel() {
        store.setLabel("My API", for: 3000)
        XCTAssertEqual(store.label(for: 3000), "My API")
    }

    func test_removeLabel() {
        store.setLabel("My API", for: 3000)
        store.removeLabel(for: 3000)
        XCTAssertNil(store.label(for: 3000))
    }

    func test_labelForUnknownPort_isNil() {
        XCTAssertNil(store.label(for: 9999))
    }

    func test_labelsDict_reflectsAllLabels() {
        store.setLabel("A", for: 3000)
        store.setLabel("B", for: 5432)
        XCTAssertEqual(store.labels[3000], "A")
        XCTAssertEqual(store.labels[5432], "B")
        XCTAssertEqual(store.labels.count, 2)
    }

    func test_persistsAcrossReload() {
        store.setLabel("Persisted", for: 8080)
        // Create a new store with the same UserDefaults suite
        let suiteName = "test.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = LabelStore(defaults: defaults)
        store1.setLabel("Persisted", for: 8080)
        let store2 = LabelStore(defaults: defaults)
        XCTAssertEqual(store2.label(for: 8080), "Persisted")
    }
}
