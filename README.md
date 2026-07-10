# Grokker

Grokker is an open-source macOS and Windows Flutter desktop app that wraps your SuperGrok subscription through the official **Grok Build CLI** on your machine.

It is a **local-first interactive terminal** for Grok Build — fast scrollback + prompt (not a chatbot bubble UI). Paste or drop images and files, keep sessions and workspace memory, and stream agent output like a real terminal.

## Requirements

- Flutter SDK **3.11+** with desktop support enabled (tested on Flutter 3.41 / Dart 3.11)
- macOS or Windows
- [Grok Build CLI](https://docs.x.ai/build/cli) installed and authenticated
- Active SuperGrok subscription (managed by xAI via the CLI)

## Grok Build CLI setup

Grokker does **not** manage xAI authentication. Authenticate in your terminal first:

```bash
npm install -g @xai-official/grok
grok /login
grok --version
```

On Windows (PowerShell/cmd), use the same commands.

## Run on macOS

```bash
cd /path/to/grokker
flutter pub get
flutter run -d macos
```

## Run on Windows

```powershell
cd C:\Users\hanif\StudioProjects\grokker
flutter pub get
flutter run -d windows
```

### Terminal UX

- Main pane is a **scrollback + prompt** (not chat bubbles)
- Prefixes: `❯` you · `grok` assistant · `⚙` tools · `!` errors
- **Paste** images/files (Ctrl+V) · **drag-and-drop** onto the terminal
- Enter sends · Esc cancels · Ctrl+L focuses prompt
- **Controls rail** (right): all settings live here — no separate settings screen  
  Toggle with **Ctrl+Shift+I** or **Ctrl+,**, or the tune icon in the sidebar
- Streaming is throttled and does **not** rewrite session disk on every token

### Design system

Tokens live under `styles/` (`DESIGN.md`, `tokens.json`, `theme.css`, `variables.css`) — zinc neutrals + ember accent (`#ff5a00`). Flutter maps them in `lib/styles/design_tokens.dart`.

### Marionette (AI UI driving)

Debug builds register **Marionette** so agents can screenshot / tap / type in the live Windows app.

```powershell
flutter run -d windows --debug
# then use VM service URI with:
marionette register grokker ws://127.0.0.1:PORT/TOKEN=/ws
marionette --uri ws://... take-screenshots --output shot.png
```

See [docs/MARIONETTE.md](docs/MARIONETTE.md). Grok MCP: `[mcp_servers.marionette]` in `~/.grok/config.toml` or `.grok/config.toml`.

## How ACP integration works

Grokker spawns the official Grok Build CLI:

```bash
grok agent stdio
```

(or `npx @xai-official/grok agent stdio` if configured in Settings)

Communication uses **newline-delimited JSON-RPC 2.0** over stdin/stdout per the [Agent Client Protocol](https://agentclientprotocol.com/):

1. `initialize` — negotiate protocol version and capabilities
2. `session/new` — create a workspace session
3. `session/prompt` — send user messages
4. `session/update` — receive streamed assistant chunks, tool events, usage
5. `session/cancel` — stop generation

Grokker implements client-side filesystem and permission handlers when ACP requests them. File writes require approval by default.

## Privacy

- Local-first: all model access goes through your Grok Build CLI process
- No analytics, telemetry, or remote logging
- No credential storage — Grokker never reads `~/.grok/auth.json` for authentication
- Authentication and subscription enforcement are handled by xAI's CLI

## Known limitations

- Exact SuperGrok quota is **not exposed** unless Grok Build CLI reports it via ACP `usage_update`
- **Composer 2.5 Fast** availability depends on your Grok Build CLI account capabilities
- Model switching depends on what Grok Build ACP accepts; Grokker shows accurate status when confirmation fails
- Grokker does not manage xAI authentication
- Grokker does not bypass subscription restrictions

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Grok CLI not found | Install CLI, set custom path in Settings, or enable npx mode |
| Not authenticated | Run `grok /login` in terminal, restart Grokker |
| ACP initialize failed | Verify `grok agent stdio` works; restart Grok process from Diagnostics |
| Model unavailable | Select a different model; check CLI account capabilities |

## License

MIT