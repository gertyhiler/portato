---
phase: 55
title: "Metadata-only refresh (tags edits don't reconnect)"
status: todo
depends_on: []
---

## Goal

Editing only a tuber's `tags:` no longer reconnects the SSH session: the config reload routes metadata-only changes through an `UpdateMetadata` path (`t.cfg = cfg` + notify, no restart).

## Background

ROADMAP post-1.0 item 6, promoted. `tuberChanged` (`engine.go:364-390`) compares `Tags` inline with connection-affecting fields (`engine.go:386-388`), so a tags-only edit triggers `Reconfigure` → a full SSH reconnect. The lumping is intentional (it keeps `Status().Tags` fresh — the comment at `engine.go:402-405`, the v1.4.1 fix), so the fix is a separate metadata path, not a revert.

## Tasks

- [ ] Split the changed-field check into connection-affecting fields vs metadata, with the classification explicit at the split site.
- [ ] `Engine.Reload`: a tags-only change → `UpdateMetadata` (update cfg, notify, keep the client and listeners); `Status().Tags` stays fresh.
- [ ] Tests: a tags-only reload leaves the SSH client instance unchanged (no reconnect, no state transition); a connection-field change still reconnects; `Status` reflects the new tags.

## Definition of Done

- [ ] Editing tags on a connected tuber does not blip the connection (test-asserted: same client, no state transition).
- [ ] `Status().Tags` reflects the new tags without a reconnect.
- [ ] `make fmt && make vet && make test && make lint` clean.

## Verification

```sh
go test ./internal/forward/... -run 'TestReload|TestMetadata' -v
```

## Technical details

- Keep the notify on the metadata path — the TUI/list refresh is the reason `Tags` was lumped into `tuberChanged` in the first place.
