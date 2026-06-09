# portpeek-mcp

A lightweight MCP server that coordinates dev port usage between AI agents.
Runs headlessly on macOS — no GUI required.

Want port visibility in your menu bar? → [Get PortPeek](https://adamorad.github.io/portpeek/)

## Install

**Homebrew (recommended)**
```bash
brew install adamorad/tap/portpeek-mcp
```

**Direct binary**
```bash
curl -Lo portpeek-mcp.zip \
  https://github.com/adamorad/portpeek/releases/latest/download/portpeek-mcp-macos-arm64.zip
unzip portpeek-mcp.zip && mv portpeek-mcp /usr/local/bin/
```

**Build from source**
```bash
git clone https://github.com/adamorad/portpeek
cd portpeek/mcp-server
swift build -c release
cp .build/release/portpeek-mcp /usr/local/bin/
```

## Usage

### HTTP transport (Cursor, VS Code, Windsurf, Claude Code)

Start the server (runs in the foreground):
```bash
portpeek-mcp
# [portpeek-mcp] listening on 127.0.0.1:27182
```

Or auto-start at login via a macOS Launch Agent:
```bash
portpeek-mcp --install-launch-agent
# To remove: portpeek-mcp --uninstall-launch-agent
```

Add to your agent config:
```json
{
  "mcpServers": {
    "portpeek": {
      "url": "http://localhost:27182"
    }
  }
}
```

### Stdio transport (Claude Desktop)

Claude Desktop launches `portpeek-mcp` as a subprocess — no separate startup needed:
```json
{
  "mcpServers": {
    "portpeek": {
      "command": "portpeek-mcp",
      "args": ["--stdio"]
    }
  }
}
```

## Tools

| Tool | Description |
|---|---|
| `list_active_ports` | All monitored ports with their current status and user labels |
| `get_available_port` | Find a free port near your preferred one |
| `reserve_port` | Reserve a port so other agents won't use it |
| `release_port` | Release a previously reserved port |

## Notes

- Binds to `127.0.0.1:27182` only (never exposed to the network)
- Reservations are in-memory and lost on restart (by design)
- Compatible with PortPeek app — same protocol, same port, same config
- macOS 13 (Ventura) or later
