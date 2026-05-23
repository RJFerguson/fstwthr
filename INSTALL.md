# Install — wire fstwthr's MCP server into your client

The MCP server at `https://mcp.fstwthr.com/mcp` speaks the
[Model Context Protocol](https://modelcontextprotocol.io/) over the
StreamableHTTP transport. Any MCP-compatible client can wire it up
in one config snippet.

No API keys. No auth. No setup beyond the config file below.

---

## Claude Desktop

Edit (or create) `~/Library/Application Support/Claude/claude_desktop_config.json`
on macOS, or `%APPDATA%\Claude\claude_desktop_config.json` on Windows:

```json
{
  "mcpServers": {
    "fstwthr": {
      "url": "https://mcp.fstwthr.com/mcp"
    }
  }
}
```

Restart Claude Desktop. You should see:

- **fstwthr** in the MCP-server status icon (bottom of the chat input).
- Three prompts in the prompt picker: `check_weather`, `best_window`,
  `travel_planning`.
- Five tools available to any conversation: `get_weather`,
  `get_forecast`, `get_alerts`, `get_best_window`, `get_nowcast`.

---

## Claude Code (CLI)

Add to `~/.config/claude-code/mcp.json` or whichever config path
your installation uses:

```json
{
  "mcpServers": {
    "fstwthr": { "url": "https://mcp.fstwthr.com/mcp" }
  }
}
```

---

## Cursor

`Cursor Settings → MCP → Add new MCP server`:

```json
{
  "fstwthr": {
    "url": "https://mcp.fstwthr.com/mcp"
  }
}
```

Or edit `~/.cursor/mcp.json` directly with the same shape.

---

## Continue.dev

`~/.continue/config.json`:

```json
{
  "mcpServers": {
    "fstwthr": {
      "transport": {
        "type": "http",
        "url": "https://mcp.fstwthr.com/mcp"
      }
    }
  }
}
```

---

## Cline (VS Code)

`Cline → MCP Servers → Edit Configuration`:

```json
{
  "mcpServers": {
    "fstwthr": {
      "url": "https://mcp.fstwthr.com/mcp",
      "type": "streamable-http"
    }
  }
}
```

---

## Zed

`~/.config/zed/settings.json` under the `context_servers` key:

```json
{
  "context_servers": {
    "fstwthr": {
      "command": null,
      "url": "https://mcp.fstwthr.com/mcp"
    }
  }
}
```

(Zed's MCP support is still settling — check Zed's MCP docs if this
shape no longer matches.)

---

## VS Code (with GitHub Copilot agentic mode)

Edit `.vscode/mcp.json` in your workspace, or the user settings:

```json
{
  "servers": {
    "fstwthr": {
      "type": "http",
      "url": "https://mcp.fstwthr.com/mcp"
    }
  }
}
```

---

## MCP Inspector (testing / debugging)

```bash
npx @modelcontextprotocol/inspector@latest
```

Then in the UI:

1. **Transport Type**: select **"Streamable HTTP"** (the default is
   STDIO, which tries to spawn the URL as a process — that'll fail).
2. **URL**: `https://mcp.fstwthr.com/mcp`.
3. Click **Connect**.

You'll see the tools/resources/prompts tabs populate.

---

## Raw curl (for diagnostics)

MCP is just JSON-RPC over HTTP. Session-affinity makes raw curl
slightly fiddly; use this two-step pattern:

```bash
# 1. initialize → capture the session id
SID=$(curl -sS -D - -o /dev/null -X POST https://mcp.fstwthr.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}}}' \
  | grep -iE '^mcp-session-id:' \
  | sed -E 's/^[Mm]cp-[Ss]ession-[Ii]d: *//' \
  | tr -d '\r\n')

# 2. send the initialized notification
curl -sS -X POST https://mcp.fstwthr.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# 3. list the tools
curl -sS -X POST https://mcp.fstwthr.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# 4. call a tool
curl -sS -X POST https://mcp.fstwthr.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call",
       "params":{"name":"get_weather","arguments":{"location":"boulder"}}}'
```

See `examples/mcp-call.sh` for a script version.

---

## Troubleshooting

**"Spawn ... ENOENT" in the MCP Inspector**
The inspector's default transport is STDIO; it's trying to execute
the URL as a local command. Switch the transport to **Streamable HTTP**
in the UI.

**"Mcp-Session-Id header is required"**
You're skipping the initialize → session-id capture step. Every call
after `initialize` must echo the `Mcp-Session-Id` returned by the
server (it lives in the response *headers*, not the JSON body).

**"Session not found"**
The session expired (idle DOs sleep after a few minutes) or the
header value is malformed. Run `initialize` again to get a fresh ID.

**HEAD requests return 404**
That's correct behavior — MCP only accepts `POST` for the JSON-RPC
endpoint. Use `curl -X POST`.

---

## Reporting issues

[Open an issue](https://github.com/RJFerguson/fstwthr/issues) — real-
world bug reports, especially around unusual locations or MCP client
behaviors, are very welcome.
