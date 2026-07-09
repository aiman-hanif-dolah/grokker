# AGENTS.md — Grokker coding rules

## Principles

- Make the smallest possible change that solves the task
- Keep UI widgets lightweight — no business logic in widgets
- Move logic to Cubit, service, or repository layers
- Use immutable state classes (Equatable)
- Do not commit secrets or credentials
- Do not add telemetry or analytics
- Do not bypass Grok authentication — use official Grok CLI only
- Keep macOS and Windows compatibility — avoid Unix-only path assumptions

## Architecture

```
lib/
  app/           — app bootstrap, theme, service locator
  core/          — constants, errors, logging, platform utils
  features/      — feature modules (acp, chat, sessions, settings, …)
  shared/        — shared models and widgets
```

Each feature follows `data/`, `domain/`, `presentation/` where applicable.

## ACP integration

- Spawn `grok agent stdio` (or npx override) with `runInShell: true`
- JSON-RPC 2.0 over stdin/stdout
- Handle unknown ACP methods defensively — log, never crash
- Never invent quota/token values

## Testing

- Mock `GrokProcessService` and `AcpClient` in tests
- Do not require real Grok CLI in CI

## Desktop

- Use `window_manager` for window sizing
- Use `file_picker` for folder/file selection
- Test on both macOS and Windows before merging platform-specific code