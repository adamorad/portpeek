// PortPeek/PortPeek/Core/LabelStore.swift
import Foundation
import Combine

final class LabelStore: ObservableObject {
    @Published private(set) var labels: [Int: String] = [:]

    private let defaults: UserDefaults
    private let key = "portpeek.labels"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func setLabel(_ label: String, for port: Int) {
        labels[port] = label
        save()
    }

    func removeLabel(for port: Int) {
        labels.removeValue(forKey: port)
        save()
    }

    func label(for port: Int) -> String? {
        labels[port]
    }

    private func load() {
        guard let raw = defaults.dictionary(forKey: key) as? [String: String] else { return }
        labels = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
            guard let port = Int(k) else { return nil }
            return (port, v)
        })
    }

    private func save() {
        let raw = Dictionary(uniqueKeysWithValues: labels.map { ("\($0.key)", $0.value) })
        defaults.set(raw, forKey: key)
    }
}
