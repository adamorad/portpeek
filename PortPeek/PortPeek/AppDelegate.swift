import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var mcpServer: MCPServer?
    private let registry = PortRegistry()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(registry: registry)
        menuBarController?.setup()

        mcpServer = MCPServer(registry: registry)
        mcpServer?.onRunningChanged = { [weak self] running in
            Task { @MainActor [weak self] in
                self?.registry.isMCPServerRunning = running
            }
        }
        mcpServer?.onError = { error in
            print("[PortPeek] MCP server error: \(error) — port 27182 may be in use")
        }
        try? mcpServer?.start()

        registry.startScanning(interval: 15.0)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mcpServer?.stop()
        registry.stopScanning()
    }
}
