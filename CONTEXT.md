# Portato

Portato manages SSH tunnels between a local machine and SSH servers.

## Language

**Tunnel**: A managed SSH forwarding configuration and its connection state.
Upstream code calls it a **tuber**; user-facing descriptions use **tunnel**.

**Local forward**: A listener on this machine forwards traffic through SSH to a
destination reached from the SSH server.

**Remote forward**: A listener on the SSH server forwards traffic through SSH to
a destination reached from this machine.

**Dynamic forward**: A local SOCKS5 listener forwards traffic through SSH to the
destination chosen by each SOCKS client.

**Daemon**: The background Portato process that keeps tunnels running independently
of the user interfaces attached to it.

**Standalone TUI**: A terminal interface that owns its tunnels until it stops them
or hands them over to a daemon.

**Attached client**: A terminal, command-line or menu bar interface controlling the
daemon's tunnels. Closing an attached client leaves those tunnels running.

**Daemon login service**: The operating-system service that starts the daemon at login.

**Menu bar login item**: The macOS login entry that opens the menu bar application.
It is distinct from the daemon login service.
