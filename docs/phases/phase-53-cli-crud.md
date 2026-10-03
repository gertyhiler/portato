---
phase: 53
title: "CLI tuber CRUD (add / set / rm)"
status: in-progress
depends_on: []
---

## Goal

Tunnels can be created, modified and removed from the shell — `portato add`, `portato set`, `portato rm` — without the TUI. Unlocks CI, Ansible and dotfiles flows.

## Background

Tuber creation is TUI-only today (or `portato import`). The machinery already exists and is unused by the CLI: `client.AddTuber/UpdateTuber/DeleteTuber/MoveTuber` (`client.go:193-210`), daemon routes `POST/PUT/DELETE /tubers` (`server.go:366-383`), and the comment-preserving persist (`ReplaceTuberNode`). Only cobra commands are missing.

## Tasks

- [ ] `portato add <name> --type local|remote|dynamic --ssh <spec> --local <addr> --remote <addr> [--identity] [--jump] [--tags] [--enabled] [--password-auth] [--socks5-user] [--socks5-pass]` — validate via `config.Validate`, persist, optionally enable.
- [ ] `portato set <name> [--ssh] [--local] …` — change only the given flags (read-modify-persist, never a full rebuild from flags).
- [ ] `portato rm <name> [--yes]` — confirm unless `--yes`; stops the tuber if active.
- [ ] Commands run over the daemon controller when attached (matching `enable`/`disable`/`restart` semantics), local otherwise.
- [ ] TAB-completion of tuber names for `set`/`rm` (phase-45 pattern).

## Definition of Done

- [ ] `portato add demo --type local --ssh me@host:22 --local 8080 --remote 127.0.0.1:80` succeeds, `portato list` shows it, and comments elsewhere in config.yaml survive the persist.
- [ ] `portato set demo --local 8081` changes only that field.
- [ ] `portato rm demo --yes` removes it and stops a running tunnel.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/cmd/... -run 'TestAdd|TestSet|TestRemove' -v
```

## Technical details

- Reuse the `controller` abstraction (remote when a daemon is up, local fallback) like the existing mutating commands.
- `set` must read the current tuber, apply the flagged changes and persist — never construct a tuber from flags alone (the phase-52 field-loss lesson).
