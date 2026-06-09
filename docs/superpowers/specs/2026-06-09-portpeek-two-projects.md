# PortPeek — Two Projects

## Overview

PortPeek ships as two distinct products that share the same MCP protocol and port 27182:

| | **PortPeek** | **portpeek-mcp** |
|---|---|---|
| Type | macOS menu bar app | Swift CLI |
| UI | SwiftUI popover | None |
| Distribution | Mac App Store | Homebrew, binary, source |
| Location | `PortPeek/` | `mcp-server/` |
| Audience | Developers who want visibility | Developers who just need the server |

The two are intentionally interchangeable at the protocol level: both bind `127.0.0.1:27182`, both implement the same 4 MCP tools, and both accept the same agent config snippet. A developer who starts with the CLI can switch to the app with no config change.

---

## Project 1: PortPeek (App + MCP) — existing, unchanged

macOS menu bar app built with SwiftUI/AppKit. Embeds the MCP server as a background service that starts automatically at launch. Gives developers a live view of what's listening, what's reserved, and which agent holds each port.

Distribution: Mac App Store (coming soon). No changes to this project as part of this spec.

---

## Project 2: portpeek-mcp (Swift CLI)

### Location

`mcp-server/` subfolder of the same `ideas/v2` repo. A self-contained Swift Package — no Xcode required.

### Structure

```
mcp-server/
├── Package.swift
├── README.md
└── Sources/
    └── portpeek-mcp/
        ├── main.swift
        ├── Core/
        │   ├── PortEntry.swift
        │   ├── PortScanner.swift
        │   ├── PortRegistry.swift
        │   ├── ReservationStore.swift
        │   └── LabelStore.swift
        └── MCP/
            ├── MCPServer.swift
            ├── MCPHandler.swift
            └── MCPTools.swift
```

### Code sharing

Core and MCP files are **copied** from `PortPeek/PortPeek/` into the CLI package. No symlinks, no shared library target. Both projects are independently buildable. When logic changes in the app's core (e.g. a new monitored port), the change is manually synced to `mcp-server/`. This is the right tradeoff at this stage — the two projects stay decoupled and the CLI can be built without Xcode.

### Package.swift

- Platform: macOS 13+
- Single executable target `portpeek-mcp`
- No external dependencies

### main.swift behaviour

1. Instantiate `PortRegistry`
2. Instantiate `MCPServer(registry:)`
3. Call `server.start()` — exits with code 1 on failure (e.g. port 27182 in use)
4. Call `registry.startScanning()`
5. Print `[portpeek-mcp] listening on 127.0.0.1:27182`
6. Register `DispatchSource` handlers for `SIGTERM` and `SIGINT`: call `registry.stopScanning()`, `server.stop()`, `exit(0)`
7. `RunLoop.main.run()` — keeps process alive

`PortRegistry` retains its `ObservableObject`/`@Published` from the app — Combine is available on macOS in CLI context and no-subscriber `@Published` is harmless. `@MainActor` isolation is preserved throughout; `RunLoop.main.run()` drives the main actor.

### Compatibility with app

- Same port: `127.0.0.1:27182`
- Same MCP protocol version: `2024-11-05`
- Same 4 tools: `list_active_ports`, `get_available_port`, `reserve_port`, `release_port`
- Same agent config snippet works for both:
  ```json
  { "mcpServers": { "portpeek": { "url": "http://localhost:27182" } } }
  ```

### Distribution

**Build from source** (always works):
```bash
git clone https://github.com/<your-org>/portpeek
cd portpeek/mcp-server
swift build -c release
cp .build/release/portpeek-mcp /usr/local/bin/
```

**Homebrew** (primary recommended path):
```bash
brew install portpeek/tap/portpeek-mcp
```
Formula lives in a `portpeek/homebrew-tap` GitHub repo. It runs `swift build -c release` and installs the resulting binary. No pre-built bottle initially.

**Direct binary** (curl):
GitHub Actions release job builds the binary on push to a version tag and attaches it to the GitHub Release. Users download and place in `$PATH`. Exact `curl` command documented in README.

---

## Website

The existing two-fold structure maps cleanly to the two products:

- **Fold 1 — PortPeek**: app hero, screenshot, email signup for App Store notification. No changes needed to the fold 1 copy — it already positions the app correctly.
- **Fold 2 — portpeek-mcp**: redesigned as a distinct product. Key copy changes: product name `portpeek-mcp` in monospace, headline "No app. Just the server.", install tabs updated to show `brew install portpeek/tap/portpeek-mcp` as primary. MCP config snippet stays.

The funnel direction: developers who discover `portpeek-mcp` are pointed toward the full app as the upgrade path ("Want port visibility in your menu bar? Get PortPeek").

---

## Out of scope

- Persistent reservations across CLI restarts (app-only differentiator)
- Windows/Linux support
- Homebrew bottle (pre-built binary via formula) — add later
- Automated sync between app core and CLI core
