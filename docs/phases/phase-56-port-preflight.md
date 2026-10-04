---
phase: 56
title: "Port preflight + local: 0 (auto free port)"
status: in-progress
depends_on: []
---

## Goal

"Address already in use" is caught before a tunnel is enabled, not after; and `local: 0` binds an ephemeral free port, with the actual value reported in `Status`.

## Background

A busy local port surfaces only post-factum as an Error state. The TUI already auto-bumps duplicate ports inside the config (phase 39), but no check exists at enable time. `local: 0`/`auto` generalizes this — config validation currently rejects port 0.

## Tasks

- [ ] Enable-time preflight: probe the local port before starting; a conflict yields a clear error state (naming the conflict where discoverable).
- [ ] `local: 0` accepted by validation; binds ephemeral; `Status.Local` reports the actual bound port.
- [ ] Lift the duplicate-port auto-bump out of the TUI into a shared config helper (single implementation).
- [ ] Tests: conflict detection (bind a port, enable, expect the error state); ephemeral bind reports a real port; two tubers with `local: 0` get distinct ports.

## Definition of Done

- [ ] Enabling a tuber on a busy port fails fast with the conflict named, without entering the reconnect loop.
- [ ] `local: 0` works for `local` and `dynamic` types; `portato list` shows the real port.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/forward/... ./internal/config/... -run 'TestPreflight|TestAutoPort' -v
```

## Technical details

- FD-passing hand-off (phase 16) transfers the already-bound listener, so an ephemeral port survives the standalone→daemon transition.
- For `type: remote` the remote-side bind failure is already surfaced at `tuber.go:656`; the local side is the gap this phase closes.
