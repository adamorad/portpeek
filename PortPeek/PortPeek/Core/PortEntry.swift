// PortPeek/PortPeek/Core/PortEntry.swift
import Foundation

enum PortStatus: Equatable {
    case listening
    case reserved(project: String, expires: Date)
    case available
}

struct PortEntry: Identifiable {
    let port: Int
    var status: PortStatus
    var userLabel: String?

    var id: Int { port }

    var displayName: String {
        userLabel ?? "Port \(port)"
    }
}

extension PortEntry {
    static let defaultMonitoredPorts: [Int] = [
        80, 443,
        3000, 3001, 3002, 3003,
        4000, 4200, 4321,
        5000, 5001, 5173, 5174,
        5432,       // Postgres
        6006,       // Storybook
        6379,       // Redis
        7000, 8000, 8001, 8080, 8081, 8443, 8888,
        9000, 9090,
        27017,      // MongoDB
    ]
}
