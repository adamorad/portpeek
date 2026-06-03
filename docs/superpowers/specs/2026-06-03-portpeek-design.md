# PortPeek — Design Spec

**Date:** 2026-06-03  
**Status:** Approved  
**Distribution:** Mac App Store ($2.99)

---

## What It Is

A $2.99 Mac menu bar utility that acts as a **local port registry** for developers and AI coding agents. It tracks which localhost ports are in use, lets users label them, and exposes an MCP server so agents like Claude Code, Cursor, and Windsurf can query port availability before starting a server — eliminating "port already in use" errors.

---

## The Problem

When AI coding agents (Claude Code, Cursor, etc.) start a dev server, they pick a default port (3000, 8080, etc.). If that port is taken, the server fails. The agent doesn't know what's available before trying, and there's no lightweight tool that exposes this as a queryable API.

---

## Core Features

### 1. Port scanning
- Probes a curated list of ~60 common dev ports every 3 seconds using `NWConnection` (App Store sandbox-safe)
- Default list: 3000, 3001, 4000, 4200, 5000, 5173, 5432, 6379, 8000, 8080, 8443, 8888, 9000, 27017, and ~45 more
- Users can add/remove ports from the monitored list

### 2. Port reservations
- Any MCP client can reserve a port before a process starts listening
- Reservation holds for a configurable TTL (default: 5 minutes)
- Prevents race conditions when two agents start simultaneously and both check the same port as "free"
- Auto-expires; user can manually release

### 3. User labels
- Double-click any port row to name it ("My Rails API", "Postgres", "Frontend")
- Labels persist in UserDefaults, keyed by port number
- Show on every subsequent scan — no need to re-label

### 4. MCP server
- Runs on `localhost:27182` via `NWListener` (no external exposure)
- Implements MCP over HTTP (JSON-RPC 2.0)
- Four tools:

| Tool | Input | Output |
|------|-------|--------|
| `list_active_ports` | — | `[{port, status, label}]` |
| `get_available_port` | `preferred`, `reserve` | `{port, reserved, expires_in}` |
| `reserve_port` | `port`, `project`, `ttl_minutes` | `{success, expires_at}` |
| `release_port` | `port` | `{success}` |

### 5. One-click agent setup
- Settings panel has two copy buttons:
  - **"Copy Claude Code config"** → copies the MCP JSON snippet
  - **"Copy CLAUDE.md snippet"** → copies 3-line instruction for Claude Code projects

---

## UI Design

**Visual style:** Liquid glass (macOS Tahoe-inspired) — dark background, frosted glass panels, specular highlight at top of each surface, glowing status dots, backdrop blur.

**App icon:** FLUX.2 generated — dark navy/purple gradient rounded square with a glassy plug symbol. V1 selected.

### Menu bar
- Icon: V1 logo at 18px
- Green badge showing count of active + reserved ports
- Monochrome when no ports active

### Main popover (316px wide)
Three sections, separated by subtle dividers:
1. **Listening** — ports confirmed open (green pulsing dot)
2. **Reserved by Agent** — claimed but not yet listening (blue pulsing dot, shows time remaining, one-click release)
3. **Monitored** — in the watch list but currently idle (grey dot, hidden by default, toggle in settings)

Each row: `[status dot] [label or "double-click to name…"] [port number] [↗ open] [••• menu]`

Footer: `+ Add port` button (left) · `scanned Xs ago` (right)

### Settings panel (slides in)
- **MCP Server** section: port number, status dot, two copy buttons
- **Monitored Ports** section: tag chips with × to remove, + Add chip
- **Preferences**: scan interval (2s/3s/5s/10s), reservation TTL (2m/5m/10m), launch at login toggle, show available ports toggle

---

## Architecture

### Three layers

**Core (`/Core`)**
- `PortRegistry` — `ObservableObject`, single source of truth, combines scanner + reservations + labels
- `PortScanner` — `NWConnection`-based concurrent port probing with configurable timeout (500ms)
- `ReservationStore` — in-memory time-bounded reservations, persisted to UserDefaults within TTL
- `LabelStore` — `[Int: String]` dictionary in UserDefaults

**MCP (`/MCP`)**
- `MCPServer` — `NWListener` on `127.0.0.1:27182`
- `MCPHandler` — parses JSON-RPC 2.0, dispatches to tool implementations
- `MCPTools` — four tool implementations backed by `PortRegistry`

**UI (`/UI`)**
- `MenuBarController` — `NSStatusItem` + `NSPopover` lifecycle
- `ContentView` / `PortListView` / `PortRowView` — SwiftUI, reads from `PortRegistry` via `@EnvironmentObject`
- `SettingsView` — SwiftUI settings panel

### Data model

```swift
enum PortStatus {
    case listening
    case reserved(project: String, expires: Date)
    case available
}

struct PortEntry: Identifiable {
    let port: Int
    var status: PortStatus
    var userLabel: String?
}
```

### Entitlements
- `com.apple.security.app-sandbox` = true
- `com.apple.security.network.client` = true (port probing)
- `com.apple.security.network.server` = true (MCP server on localhost)

---

## Project Structure

```
PortPeek/
├── PortPeekApp.swift
├── AppDelegate.swift
├── Core/
│   ├── PortRegistry.swift
│   ├── PortScanner.swift
│   ├── ReservationStore.swift
│   └── LabelStore.swift
├── MCP/
│   ├── MCPServer.swift
│   ├── MCPHandler.swift
│   └── MCPTools.swift
├── UI/
│   ├── MenuBarController.swift
│   ├── ContentView.swift
│   ├── PortListView.swift
│   ├── PortRowView.swift
│   └── SettingsView.swift
└── PortPeek.entitlements
```

---

## Claude Code Integration

Users add to `~/.claude/settings.json`:
```json
{ "mcpServers": { "portpeek": { "url": "http://localhost:27182" } } }
```

Suggested `CLAUDE.md` snippet (copyable from Settings):
```markdown
## Port management
Before starting any dev server, call portpeek MCP `get_available_port` with your
preferred port. Always `release_port` when the server stops.
```

---

## Verification

1. Build and run app — confirm menu bar icon appears with badge
2. Start a local server (`python3 -m http.server 3000`) — confirm port 3000 shows as "listening" within 3s
3. `curl -X POST http://localhost:27182 -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_active_ports","arguments":{}},"id":1}'` — confirm JSON response
4. Call `reserve_port` via curl — confirm blue dot appears in UI, confirm TTL countdown
5. Add Claude Code MCP config — confirm Claude Code can call `get_available_port` and receives a valid port
6. Launch at login — confirm app restarts after system reboot
