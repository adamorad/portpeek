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
    // All valid ports except PortPeek's own MCP server port.
    static let defaultMonitoredPorts: [Int] = (1...65535).filter { $0 != 27182 }
}
