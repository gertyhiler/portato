---
phase: 58
title: "Fast reconnect on wake / network change"
status: todo
depends_on: [57]
---

## Goal

After laptop sleep or a network change, tunnels reconnect in seconds instead of waiting out the keepalive timeout and the backoff.

## Background

Keepalive is hard-coded (`keepaliveInterval = 30s`, `keepaliveTimeout = 5s`, `tuber.go:20-24`); after a suspend the tuber only notices the dead connection on the next keepalive tick, then backs off 2s→30s (the first failed-dial pause is 2s: `attempt++` precedes `nextBackoff` at `tuber.go:487-488`) with no jitter. The laptop persona's most-felt daily annoyance.

## Tasks

- [ ] Wall-clock jump detection inside the keepalive ticker (a jump ≥ the interval ⇒ the machine slept ⇒ immediate reconnect, backoff reset).
- [ ] Backoff jitter so many tunnels don't retry in lockstep.
- [ ] Configurable `keepalive_interval` / `connect_timeout` in defaults (validated bounds).
- [ ] OS-native signals (darwin NSWorkspace, Linux D-Bus PrepareForSleep) explicitly out of scope — a follow-up only if wall-clock detection proves insufficient.

## Definition of Done

- [ ] A simulated wall-clock jump in tests triggers an immediate reconnect attempt with the backoff reset.
- [ ] Jitter keeps retries within the asserted bounds.
- [ ] `keepalive_interval` / `connect_timeout` are honored from config.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/forward/... -run 'TestWake|TestBackoff' -v
```

## Technical details

- Depends on 57: the wake detection and backoff changes land in the unified driver once, not twice.
