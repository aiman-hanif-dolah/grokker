# Marionette MCP — Grokker

Drive the running Flutter Windows app from AI agents (Grok, Claude, Cursor).

## One-time setup

```powershell
cd C:\Users\hanif\StudioProjects\grokker
flutter pub add marionette_flutter
dart pub global activate marionette_mcp
dart pub global activate marionette_cli
```

Ensure `%USERPROFILE%\.puro\shared\pub_cache\bin` (or your pub-cache `bin`) is on `PATH`.

### Grok Build MCP config

User config (`~/.grok/config.toml`) and project (`.grok/config.toml`):

```toml
[mcp_servers.marionette]
command = 'C:\Users\hanif\.puro\shared\pub_cache\bin\marionette_mcp.bat'
args = []
enabled = true
startup_timeout_sec = 60
```

Restart Grok after adding so MCP tools load.

## Run + connect

```powershell
flutter run -d windows --debug
```

Copy the VM Service URI from the console, e.g.:

```
A Dart VM Service on Windows is available at: http://127.0.0.1:53052/TOKEN=/
```

WebSocket form:

```
ws://127.0.0.1:53052/TOKEN=/ws
```

### CLI (no MCP session needed)

```powershell
marionette register grokker ws://127.0.0.1:PORT/TOKEN=/ws
marionette --uri ws://... take-screenshots --output capture.png
marionette --uri ws://... get-interactive-elements
marionette --uri ws://... tap --text "New session"
marionette --uri ws://... enter-text --text "hello" --focused-element
marionette --uri ws://... hot-reload
```

### Agent (MCP)

Ask Grok to connect with the VM service URI, then screenshot / tap / type.

## App wiring

`lib/main.dart` initializes `MarionetteBinding` in debug only, with custom Grokker widgets registered for discovery (`GrokkerPrimaryButton`, search field, etc.).

Screenshots land in `marionette_captures/` (gitignored optional).
