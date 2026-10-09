---
name: portato-swift
description: Build or review the native Portato macOS menu, tunnel editor, daemon lifecycle, and Swift IPC client.
---
Read macos/README.md and docs/runbooks/development.md. UI mutations belong on the
main thread; socket and process work stays off it. DaemonClient is the shared
protocol boundary. Preserve unknown tunnel fields when editing and detect stale
forms. Never expose config secrets in menu text, diagnostics, or screenshots.
Read actual SMAppService status instead of persisting a second login-item flag.
Diagnostic modes must not start daemons or change login items. Quitting the menu
must leave tunnels running. Build the Go core and Swift app from the same checkout.
Use PortatoCoreChecks and the isolated smoke script; confirm app signing after
packaging. Full Xcode/XCTest is not assumed. Explain unverified GUI/login behavior
explicitly; use English in repository artifacts.
