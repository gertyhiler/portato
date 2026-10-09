---
name: portato-go
description: Change or review Portato Go daemon, SSH forwarding, configuration, and IPC behavior.
---
Read CONTEXT.md, docs/SPEC.md and the relevant internal package before editing.
Daemon owns tunnels, config validation/persistence, secrets and SSH. Keep Swift
free of independent tunnel state or YAML persistence. Preserve CLI/TUI behavior.
When changing IPC, update Swift models and meaningful contract checks together.
Read docs/runbooks/development.md for verification. Use in-process SSH fixtures;
never depend on a personal host in automated tests. Test cancellation, deadline,
authentication and persistence behavior where the change affects those seams.
Report local checks, runtime evidence and remaining limits separately; use English in repository artifacts.
