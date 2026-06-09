import Foundation

// Kept as module-level references so NWConnection callbacks remain valid after
// the Task body completes. Initialized once on the main actor, never mutated.
nonisolated(unsafe) var _registry: PortRegistry?
nonisolated(unsafe) var _server: MCPServer?
nonisolated(unsafe) var _sources: [DispatchSourceSignal] = []

// ── Launch-agent management ──────────────────────────────────────────────────
if CommandLine.arguments.contains("--install-launch-agent") {
    LaunchAgent.install()
    exit(0)
}
if CommandLine.arguments.contains("--uninstall-launch-agent") {
    LaunchAgent.uninstall()
    exit(0)
}

// ── stdio MCP transport ──────────────────────────────────────────────────────
if CommandLine.arguments.contains("--stdio") {
    Task { @MainActor in
        let registry = PortRegistry()
        registry.startScanning()
        Thread.detachNewThread {
            while let line = readLine(strippingNewline: true) {
                guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                Task { @MainActor in
                    let handler = MCPHandler(registry: registry)
                    if let resp = try? await handler.handle(data),
                       !resp.isEmpty,
                       let str = String(data: resp, encoding: .utf8) {
                        FileHandle.standardOutput.write(Data((str + "\n").utf8))
                    }
                }
            }
        }
    }
    RunLoop.main.run()
}

// ── HTTP server (default mode) ───────────────────────────────────────────────
Task { @MainActor in
    let registry = PortRegistry()
    let server = MCPServer(registry: registry)
    _registry = registry
    _server = server

    server.onRunningChanged = { isRunning in
        if isRunning {
            print("[portpeek-mcp] listening on 127.0.0.1:27182")
        }
    }
    server.onError = { error in
        fputs("[portpeek-mcp] error: \(error)\n", stderr)
    }

    do {
        try server.start()
    } catch {
        fputs("[portpeek-mcp] failed to start: \(error)\n", stderr)
        exit(1)
    }

    registry.startScanning()

    signal(SIGTERM, SIG_IGN)
    signal(SIGINT, SIG_IGN)

    let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigterm.setEventHandler {
        _registry?.stopScanning()
        _server?.stop()
        exit(0)
    }
    sigterm.resume()

    let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigint.setEventHandler {
        _registry?.stopScanning()
        _server?.stop()
        exit(0)
    }
    sigint.resume()

    _sources = [sigterm, sigint]
}

RunLoop.main.run()
