---
phase: 59
title: "State-change hooks + desktop notifications"
status: todo
depends_on: [57]
---

## Goal

A headless daemon can finally report that something broke: `on_connect:` / `on_error:` hook commands per tuber, and desktop notifications on meaningful state transitions.

## Background

ROADMAP post-1.0 item 4, promoted. The daemon runs for hours; a dropped tunnel is invisible until the TUI is opened. Built on phase 57's typed event (name, old/new state, error) — hooks are just another subscriber.

## Tasks

- [ ] Config: per-tuber `on_connect:` / `on_error:` command strings (validated).
- [ ] Transition-based firing: `on_error` on transitions into Error (not retry loops — error→reconnecting→error does not re-fire without an intervening Connected); `on_connect` on transitions into Connected.
- [ ] Anti-flap cooldown per tuber (default 60s, configurable in defaults).
- [ ] Execution: direct exec (no shell), env context (`PORTATO_TUBER`, `PORTATO_STATE`, `PORTATO_ERROR`), a ~10s timeout, failures logged — never fatal to the daemon.
- [ ] Desktop notifications: `osascript` (darwin) / `notify-send` (Linux) / toast (Windows) behind a config knob, following the `service/` build-tag pattern; README examples for hook-based alternatives.
- [ ] Design choices to settle at phase start: `on_connect` on every connect vs recovery-only; engine-level subscription (works standalone too) vs daemon-level.

## Definition of Done

- [ ] A tuber dropping and recovering fires `on_error` then `on_connect` once each (test-asserted with a fake clock / fake exec).
- [ ] A retry loop fires `on_error` once, not per retry.
- [ ] A failing hook command does not affect the daemon (logged).
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/forward/... ./internal/config/... -run 'TestHook|TestNotify' -v
```

## Technical details

- Env-var context, not argv interpolation, avoids quoting/injection issues.
- The anti-flap rule is the core design subtlety: fire on state transitions, with a cooldown as the second guard.
