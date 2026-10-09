---
status: accepted
---
# Unix runbook for contributors

Accepted by the owner on 2026-10-09. Adopt Unix Runbook v1.0 with Make as the public
contributor command interface, replacing the earlier choice to omit that standard.
Make sequences atomic commands; setup installs pinned local tools, development
owns isolated state, and cleanup removes only a validated artifact allowlist.

The base `stop` never stops the installed user daemon; `daemon-stop` preserves
that explicit operation. On macOS the aggregate build/check/test includes Swift;
on Linux it covers Go and contributor tooling. Direct Go commands remain available
without those tools. Checks and tests are distinct from packaging and publishing.
See [the command contract](../runbooks/command-contract.md) and
[the project mapping](../runbooks/development.md).
