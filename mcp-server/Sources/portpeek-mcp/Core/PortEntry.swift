import Foundation

enum PortStatus: Equatable {
    case listening
    case reserved(project: String, expires: Date)
}

struct PortEntry: Identifiable {
    let port: Int
    var status: PortStatus
    var userLabel: String?

    var id: Int { port }

    var displayName: String {
        userLabel ?? ":\(port)"
    }
}

extension PortEntry {
    static let monitoredPorts: [Int] = [
        // Web / app servers
        80, 443,
        1234, 1337,
        2000, 2001,
        3000, 3001, 3002, 3003,
        4000, 4200, 4321,
        5000, 5001,
        5173, 5174,         // Vite
        6000, 6001, 6006,   // 6006 = Storybook
        7000, 7001,
        7265, 7823,
        8000, 8001,
        8080, 8081,
        8443, 8765, 8888,
        9000, 9090, 9229,   // 9229 = Node debugger
        9999, 10000,

        // Databases
        3306,               // MySQL
        5432,               // Postgres
        5984,               // CouchDB
        6379,               // Redis
        9200, 9300,         // Elasticsearch
        27017,              // MongoDB

        // Dev tools & tunnels
        4040,               // ngrok
        4566,               // LocalStack
        6060,

        // AI / ML
        11434,              // Ollama
    ]
}
