---
status: accepted
---
# Native macOS menu bar client

Status: accepted for this fork by the user on 2026-10-09.

Portato's daemon remains the sole owner of tunnels. Add a Swift/AppKit menu bar
client alongside the existing Go CLI and TUI. Communicate directly through the
existing authenticated HTTP API over a Unix socket, including SSE notifications.
Do not duplicate the SSH engine, create another daemon, or alter SSH configuration.
A live-probe regression requires one existing-engine repair: combine agent and
identity-file signers in a single public-key method so both are attempted.
Quitting the menu bar app must leave the daemon and tunnels running.

Keep native sources under `macos/` so upstream changes remain easy to merge.
Ship the matching CLI inside the app bundle for opening the TUI and explicit
service setup. The first version displays status and connection failures,
connects/disconnects/restarts tunnels, and offers HTTP URLs for connected local
TCP forwards. Credentials and host-key acceptance remain in the existing TUI.

Trade-offs: native macOS integration requires a small Swift IPC transport and a
second build toolchain. IPC compatibility must be tested against the bundled
Go daemon. Packaging uses a local ad-hoc signature. This fork distributes source for local
builds, as decided in [ADR-0005](0005-source-distribution.md). Existing upstream phase statuses are preserved.

## Interface and startup extension

Accepted by the owner on 2026-10-09: native configuration management, explicit port
directions, configurable startup and a combined Go/Swift build. The editor uses
Go APIs and preserves advanced fields. `/info` is the compatibility and actual
YAML-path contract. SSE is supplemented with a five-second refresh.

The app starts the bundled daemon once when no service is available; Settings can
disable this. SMAppService manages the separate app login item. The Go launchd
service remains an independent option for operation without the menu.
Trade-off: two startup controls whose distinct purposes are explained in the UI.

Startup and upstream compatibility are further constrained by [ADR-0004](0004-upstream-compatible-layer.md).
