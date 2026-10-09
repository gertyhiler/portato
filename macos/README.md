# Portato Menu Bar

A native macOS 13+ client for the Go daemon. The menu, CLI and TUI share one
configuration and one set of SSH tunnels. Quitting the menu leaves tunnels running.

## Features

- Native forms to add, edit and delete tunnels.
- Explicit Mac/SSH endpoints for local, remote and SOCKS5 forwarding.
- Connect, Disconnect and Restart; browser links for connected local HTTP ports.
- Shared YAML through Open Configuration; validation through Reload Configuration.
- SSE plus a five-second refresh to synchronize clients.
- Configurable daemon startup when the menu opens.
- Open Portato at Login through ServiceManagement; a separate Go login service.
- The root `logo.svg` potato for application and menu icons, rendered from one source.

Host-key confirmation and SSH password prompts remain in Open TUI. Advanced jump,
tags and SOCKS5 credentials are available through TUI/YAML and preserved by the
editor. The form detects a tunnel changed by another client before saving; this
is stale-form detection, not a transactional lock between clients.

## Build

The aggregate commands require Go, Bun and Apple Command Line Tools with Swift;
full Xcode is optional. See the development runbook for pinned prerequisites.

```sh
make setup
make verify
make build
make test-menubar-smoke
open "dist/Portato Menu Bar.app"
```

For a source installation into your user Applications directory:

```sh
git clone https://github.com/gertyhiler/portato.git
cd portato
make setup
make verify
```

Then build and open the app:

```sh
PORTATO_APP_DIR="$HOME/Applications/Portato Menu Bar.app" make build
open "$HOME/Applications/Portato Menu Bar.app"
```

The build compiles Go and Swift from the same checkout, generates icns and signs
ad-hoc. This fork distributes source, not a public prebuilt app. No Developer ID
or notarization pipeline is planned. To update, pull the intended revision,
rebuild, and reopen the app; coordinate any running daemon restart yourself.
Build outside cloud-synced Documents folders to avoid signature-invalidating
Finder attributes. `make menubar` is a macOS-only alias for the same build.

## Operation

Read [operation and troubleshooting](../docs/runbooks/macos-operations.md) and
[development and isolated checks](../docs/runbooks/development.md).

Discovery follows `PORTATO_SOCKET`, then a live marker at
`XDG_CONFIG_HOME/portato/daemon.socket`, then the canonical
`XDG_STATE_HOME/portato/portato-<uid>.sock`. Both XDG roots default to
`~/Library/Application Support` on macOS. Finder does not inherit shell-only
variables. Tokens are read per request and never displayed in diagnostics.

`--list-json` reads state; `--menu-json` checks the real NSMenu. Neither diagnostic
starts a daemon or changes login settings. A Go daemon lacking `/info` or using an unsupported protocol
requires a compatible core build. The menu shows the error without starting or
stopping a daemon. Automatic startup is allowed only for missing/refused sockets.
Update a local installation by rebuilding the complete bundle; do not replace its
Go binary through the upstream updater. See [the integration policy](../docs/runbooks/upstream-contributions.md).
