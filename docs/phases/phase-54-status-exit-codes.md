---
phase: 54
title: "status / wait + machine-readable exit codes"
status: todo
depends_on: []
---

## Goal

Scripts, CI and systemd units can ask "is this tunnel healthy?" and get the answer in the exit code: `portato status <name>`, `portato wait <name>`, plus `doctor --json` and a machine-readable `update check`.

## Background

`list --json` (a raw `[]forward.Status`) is the only machine surface today. `update check` returns 0 both when up-to-date and when an update exists (`update.go:52-53`); `doctor` has no `--json`. Nothing answers "healthy?" without parsing text.

## Tasks

- [ ] `portato status <name>`: prints state (+ error text); exit codes: 0 connected, 1 error, 2 off, 3 connecting/reconnecting, 4 unknown tuber, 5 daemon unreachable.
- [ ] `portato wait <name> [--timeout 30s]`: blocks until connected or timeout; same exit codes.
- [ ] `doctor --json`: structured findings.
- [ ] `update check --json` and a distinct exit code for "update available" (separate class from the tunnel codes).
- [ ] Exit-code table documented in help text and SPEC.

## Definition of Done

- [ ] `portato status <name>; echo $?` returns 0 for a connected tuber, 1 for an errored one; `wait` honours `--timeout`.
- [ ] `doctor --json` output parses; `update check` exit codes distinguish the verdicts.
- [ ] The exit-code table is in the help text and SPEC.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/cmd/... -run 'TestStatus|TestWait|TestDoctorJSON' -v
```

## Technical details

- Exit codes are CLI stability surface ⇒ document in SPEC and treat as contract (additive ⇒ MINOR).
- `wait` polls over IPC with a short interval/backoff, not a busy loop.
