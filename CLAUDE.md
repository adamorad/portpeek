# PortPeek — Claude Code instructions

## Port usage

Before starting any dev server, background process, or anything else that binds to a port:

1. Call `mcp__portpeek__get_available_port` with your preferred port and `reserve: true`
2. Use the port number it returns (may differ from preferred if taken)
3. When done, call `mcp__portpeek__release_port` to free it

Never pick a port and hope it's free.
