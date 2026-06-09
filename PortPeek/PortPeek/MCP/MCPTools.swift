import Foundation

@MainActor
final class MCPTools {
    private let registry: PortRegistry

    init(registry: PortRegistry) {
        self.registry = registry
    }

    static let toolDefinitions: [[String: Any]] = [
        [
            "name": "list_active_ports",
            "description": "List all monitored ports with their current status and user labels.",
            "inputSchema": ["type": "object", "properties": [:] as [String: Any]]
        ],
        [
            "name": "get_available_port",
            "description": "Find an available port. Returns preferred if free, otherwise suggests the next available port in the monitored list.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "preferred": ["type": "integer", "description": "The port you'd like to use"],
                    "reserve": ["type": "boolean", "description": "Whether to reserve the port immediately"],
                    "project": ["type": "string", "description": "Project name for the reservation"],
                    "ttl_minutes": ["type": "integer", "description": "Minutes until reservation expires (default 5, clamped 1–1440)"]
                ],
                "required": ["preferred"]
            ] as [String: Any]
        ],
        [
            "name": "reserve_port",
            "description": "Reserve a port so other agents won't use it. The reservation expires after ttl_minutes.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "port": ["type": "integer"],
                    "project": ["type": "string"],
                    "ttl_minutes": ["type": "integer", "description": "Minutes until reservation expires (default 5)"]
                ],
                "required": ["port", "project"]
            ] as [String: Any]
        ],
        [
            "name": "release_port",
            "description": "Release a previously reserved port.",
            "inputSchema": [
                "type": "object",
                "properties": ["port": ["type": "integer"]],
                "required": ["port"]
            ] as [String: Any]
        ]
    ]

    func call(name: String, arguments: [String: Any]) async -> String {
        switch name {
        case "list_active_ports":  return listActivePorts()
        case "get_available_port": return await getAvailablePort(arguments)
        case "reserve_port":       return reservePort(arguments)
        case "release_port":       return releasePort(arguments)
        default:                   return jsonString(["error": "Unknown tool: \(name)"])
        }
    }

    private func listActivePorts() -> String {
        let ports = registry.entries.map { entry -> [String: Any] in
            var d: [String: Any] = ["port": entry.port]
            if let label = entry.userLabel { d["label"] = label }
            switch entry.status {
            case .listening:
                d["status"] = "listening"
            case .reserved(let project, let expires):
                d["status"] = "reserved"
                d["project"] = project
                d["expires_in_seconds"] = max(0, Int(expires.timeIntervalSinceNow))
            }
            return d
        }
        return jsonString(["ports": ports])
    }

    private func getAvailablePort(_ args: [String: Any]) async -> String {
        guard let preferred = args["preferred"] as? Int else {
            return jsonString(["error": "preferred port required"])
        }
        let shouldReserve = args["reserve"] as? Bool ?? false
        let project = args["project"] as? String ?? "agent"
        let ttl = (args["ttl_minutes"] as? Int).map { max(1, min($0, 1440)) } ?? 5

        let candidates = ([preferred] + (1...20).map { preferred + $0 }).filter { $0 != 27182 }

        for port in candidates {
            // Skip ports already reserved in the registry.
            let isReserved = registry.entries.first { $0.port == port && $0.status != .listening } != nil
            guard !isReserved else { continue }

            // Live probe — catches processes listening on ports outside the monitored list.
            let isListening = await registry.scanner.probePort(port)
            guard !isListening else { continue }

            if shouldReserve {
                try? registry.reserve(port: port, project: project, ttlMinutes: ttl)
                return jsonString([
                    "port": port,
                    "was_preferred_free": port == preferred,
                    "reserved": true,
                    "expires_in_seconds": ttl * 60
                ])
            } else {
                return jsonString([
                    "port": port,
                    "was_preferred_free": port == preferred,
                    "reserved": false
                ])
            }
        }
        return jsonString(["error": "No available port found near \(preferred)"])
    }

    private func reservePort(_ args: [String: Any]) -> String {
        guard let port = args["port"] as? Int,
              let project = args["project"] as? String
        else {
            return jsonString(["error": "port and project are required"])
        }
        let ttl = (args["ttl_minutes"] as? Int).map { max(1, min($0, 1440)) } ?? 5
        do {
            try registry.reserve(port: port, project: project, ttlMinutes: ttl)
            let expires = Date().addingTimeInterval(TimeInterval(ttl * 60))
            return jsonString([
                "success": true,
                "expires_at": ISO8601DateFormatter().string(from: expires)
            ])
        } catch ReservationError.alreadyReserved(let p, let by) {
            return jsonString(["success": false, "error": "Port \(p) already reserved by \(by)"])
        } catch {
            return jsonString(["success": false, "error": error.localizedDescription])
        }
    }

    private func releasePort(_ args: [String: Any]) -> String {
        guard let port = args["port"] as? Int else {
            return jsonString(["error": "port is required"])
        }
        registry.release(port: port)
        return jsonString(["success": true])
    }

    private func jsonString(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
