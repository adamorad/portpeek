import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let registry: PortRegistry
    private var cancellables = Set<AnyCancellable>()

    init(registry: PortRegistry) {
        self.registry = registry
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            updateButton(button, activeCount: 0)
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 316, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(registry)
        )
        self.popover = popover

        registry.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in
                let count = entries.filter {
                    switch $0.status {
                    case .listening, .reserved: return true
                    case .available: return false
                    }
                }.count
                if let button = self?.statusItem?.button {
                    self?.updateButton(button, activeCount: count)
                }
            }
            .store(in: &cancellables)
    }

    private func updateButton(_ button: NSStatusBarButton, activeCount: Int) {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.image = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: "PortPeek")?
            .withSymbolConfiguration(config)

        if activeCount > 0 {
            button.title = " \(activeCount)"
            button.imagePosition = .imageLeft
        } else {
            button.title = ""
        }
    }

    @objc private func togglePopover() {
        // AppKit guarantees button actions arrive on the main thread;
        // assumeIsolated asserts this so the @MainActor-isolated state is safe to access.
        MainActor.assumeIsolated {
            guard let button = statusItem?.button else { return }
            if let popover, popover.isShown {
                popover.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
