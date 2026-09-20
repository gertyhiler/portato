---
phase: 52
title: "Editor round-trip integrity + missing fields"
status: todo
depends_on: []
---

## Goal

Editing a tuber in the TUI never silently drops config fields again: the editor keeps the original `config.Tuber` and overlays the form on top, and the currently-unreachable fields (`jump`, `socks5_user`, `socks5_password`, `password_auth`) become editable.

## Background

`tuberEditor.tuber()` (`internal/tui/editor.go:243-255`) rebuilds the tuber from eight form fields, carrying only `jump`/`enabled` across. `PasswordAuth`, `Socks5User` and `Socks5Password` are dropped on every save — and there is no merge on the way out: `ReplaceTuberNode` (`internal/config/patch.go`) replaces the whole YAML node. Two silent consequences:

- `socks5_user`/`socks5_password` lack `omitempty` (`config.go:143-144`), so they are written back as `""` — credentials erased, and a `dynamic` tuber's SOCKS5 proxy falls back to NoAuth (an open proxy on a non-loopback bind);
- `password_auth` has `omitempty` (`config.go:138`), so an explicit `password_auth: false` disappears and silently reverts to the on-by-default behaviour.

Triggers: `e` (edit) and `Shift+C` (duplicate, `update.go:658`) — opening and saving unchanged is enough. The daemon path (`server.go:826`) shares `ReplaceTuberNode`, so the persist layer is common. Existing tests miss the bug: `TestEditor_SaveEdit_CallsUpdateTuber` stops at a fake controller and never reaches YAML.

## Tasks

- [ ] Overlay model: `tuberEditor` keeps the source `config.Tuber`; `tuber()` returns a copy with the form fields overlaid, so non-form fields survive by construction.
- [ ] Expose `jump` (comma-chain text input), `socks5_user`/`socks5_password` (relevant for `type: dynamic`), `password_auth` (toggle) in the editor form, with focus order and validation.
- [ ] Regression tests through the real YAML persist path (load → editor save → persist → re-load) asserting the three fields survive an unchanged save; both triggers (`e` and `Shift+C`).
- [ ] Config-level test: `ReplaceTuberNode` with `PasswordAuth`/`Socks5User`/`Socks5Password` set round-trips them (covers both the local and the daemon persist paths).

## Definition of Done

- [ ] Saving an edit (`e`) with no changes leaves a tuber carrying `password_auth: false`, `socks5_user`, `socks5_password` intact in config.yaml (asserted via re-load, not a fake controller).
- [ ] `Shift+C` on that tuber produces a copy retaining all three fields.
- [ ] The editor exposes `jump`, `socks5_user`, `socks5_password`, `password_auth`, and a save round-trips them.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/tui/... ./internal/config/... -run 'Editor|ReplaceTuber' -v
```

Manual: hand-write a `dynamic` tuber with socks5 credentials and a tuber with `password_auth: false` into config.yaml, open `e`, save unchanged, confirm the fields are intact.

## Technical details

- Overlay, not a wider carry-through list: a list must be extended for every future config field; the overlay cannot rot.
- `password_auth` semantics: absent (default on), `true`, `false` — the editor must round-trip an explicit `false`, not collapse it with unset.
- Release: contains a data-loss fix but ships together with the new editor fields ⇒ MINOR.
