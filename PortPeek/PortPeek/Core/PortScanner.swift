import Foundation
import Network
import os

final class PortScanner {
    let timeout: TimeInterval
    let batchSize: Int
    // One shared concurrent queue for all NWConnections — avoids creating a new
    // DispatchQueue per probe (previously 500 queues per batch × 131 batches).
    private let queue = DispatchQueue(label: "com.portpeek.scanner", attributes: .concurrent)

    init(timeout: TimeInterval = 0.05, batchSize: Int = 100) {
        self.timeout = timeout
        self.batchSize = batchSize
    }

    func probePorts(_ ports: [Int]) async -> Set<Int> {
        var open = Set<Int>()
        let chunks = stride(from: 0, to: ports.count, by: batchSize).map {
            Array(ports[$0 ..< min($0 + batchSize, ports.count)])
        }
        for chunk in chunks {
            guard !Task.isCancelled else { break }
            let batch = await withTaskGroup(of: (Int, Bool).self) { group in
                for port in chunk {
                    group.addTask { [self] in (port, await self.probePort(port)) }
                }
                var result = Set<Int>()
                for await (port, isOpen) in group {
                    if isOpen { result.insert(port) }
                }
                return result
            }
            open.formUnion(batch)
        }
        return open
    }

    func probePort(_ port: Int) async -> Bool {
        guard port >= 1, port <= 65535,
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            let conn = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
            let didResume = OSAllocatedUnfairLock(initialState: false)

            let tryConsume: @Sendable () -> Bool = {
                didResume.withLock { flag -> Bool in
                    guard !flag else { return false }
                    flag = true; return true
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard tryConsume() else { return }
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    guard tryConsume() else { return }
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            conn.start(queue: self.queue)

            self.queue.asyncAfter(deadline: .now() + self.timeout) {
                guard tryConsume() else { return }
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}
