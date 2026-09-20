---
phase: 57
title: "Engine foundation: unify reconnect loops + typed events"
status: todo
depends_on: []
---

## Goal

No user-visible change: `run()` and `runRemote()` merge into one reconnect driver, and the engine's change notification carries a payload (tuber name, old/new state, error) instead of a bare `struct{}{}`.

## Background

Two near-duplicate reconnect loops (`tuber.go:463` local/dynamic, `tuber.go:623` remote) — down to a copied comment block — force every engine feature (stats, lazy tunnels, fast reconnect, timeouts) to be written twice. `notify()` (`engine.go:89-98`) sends an empty `struct{}{}`; every consumer must re-`List()`. Both are the prerequisite layer for phases 58–59.

## Tasks

- [ ] One reconnect driver parameterised by the listen/serve strategy (local listener vs remote `client.Listen`), preserving the phase-35 pending-prompt and TOFU-pending semantics exactly.
- [ ] Typed event: `{Name, OldState, NewState, Err}` delivered to subscribers (the drop-old buffer semantics preserved); the SSE `/events` stream and the TUI updated as consumers.
- [ ] Behavioral parity tests: reconnect/backoff sequence, stable-reset, keepalive, error states — identical for local/remote/dynamic before and after.

## Definition of Done

- [ ] `go test ./...` green with no behavior-difference failures; E2E (`make e2e-handoff`) green.
- [ ] The duplicated loop body and the duplicated keepalive/select scaffolding are gone (single driver).
- [ ] SSE events carry the typed payload; the TUI list refresh works unchanged.
- [ ] `make fmt && make vet && make lint` clean.

## Verification

```sh
go test ./internal/forward/... -v
make e2e-handoff
```

## Technical details

- This is an engineering phase: no feature, the DoD is parity. `gocyclo ≤ 15` (lint) constrains the driver's shape — extract per-strategy helpers rather than one long function.
