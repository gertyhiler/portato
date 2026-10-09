# Maintaining an upstream-compatible layer

The core is `portuber/portato`; this checkout's collaboration repository is
`gertyhiler/portato`. Follow [ADR-0004](../adr/0004-upstream-compatible-layer.md).
The author can adopt the client and contributor practices independently.

## Patch boundaries

| Change | Location | Independent validation |
| --- | --- | --- |
| Core bug fix | Existing Go package | Relevant Go regression tests and core checks |
| Additive IPC | Daemon route and contract | Authentication, response and backward-compatibility tests |
| Native client | `macos/` | Swift IPC checks, bundle build and isolated smoke |
| Contributor workflow | Make, `scripts/`, CI, docs | Unix contract, lifecycle tests and platform checks |
| Agent procedures | `.agents/`, lockfile | Standard CLI listing, payload review and document links |

Keep unrelated layers out of a core bug-fix PR. Preserve the Go module path and
upstream license/attribution. Existing core CLI/TUI commands, config paths and
service behavior remain authoritative. `/info` is an additive client capability,
not a claim that all upstream releases already provide it. The menu requires that
capability and protocol version 1; absent/unsupported capability is an explicit
compatibility error, not evidence that no daemon is running.

Use direct Go build/test commands for a core-only review. Use `make verify`,
`make build` and `make test-menubar-smoke` for combined client changes. A UI client
must not persist a second tunnel configuration or implement its own SSH engine.

## Bringing in upstream changes

Inspect `git status`, remotes and the intended upstream ref first. Preserve local
changes; never reset a dirty checkout to make synchronization easier. Fetch and
compare upstream history when authorized by the task. Integrate on a suitable
branch, resolve the small client/tooling boundary explicitly, and rerun affected
checks. Keep upstream phase records intact; do not mark their work complete on
behalf of the author. Report local checks and CI separately.

## Issues and pull requests

Use the fork tracker by default as documented in `../agents/issue-tracker.md`.
An explicitly requested upstream contribution instead targets `portuber/portato`;
state the destination on every `gh` mutation. Follow the receiving project's
contribution process, including discussion of larger features. Do not infer push,
PR, merge or release permission from implementation authorization.

## Delivery and updates

`make build` produces the local app on macOS. CI validates the build without
distributing an installable application.
`make snapshot` packages the Go core locally without publication and requires
GoReleaser. Upstream install commands and badges in README refer to upstream,
not to the menu bar bundle or this fork's CI status.

The existing tag workflow and Homebrew/Scoop destinations belong to upstream.
The release job is repository-gated, and `make release*` checks all origin push
URLs before reaching its existing publication prompt. Do not bypass these guards
to create a fork release. The accepted delivery model is source-only.

The core updater continues to query upstream. Local development builds reject
`update apply`; rebuild the app bundle from the intended checkout to update it.
Replacing its bundled binary independently can remove client capabilities and
invalidate its signature. Never publish a versioned fork build while it still
uses upstream's release channel and distribution destinations.

## Upstream proposal

Propose the authenticated `/info` capability first so an external native client
can use the official runtime. Offer upstream adoption of the macOS client as an
alternative. Do not bundle contributor tooling or agent practices into that
proposal. The existing SSH fix PR is independent. Today the app still bundles
this checkout's matching Go core; Swift-only installation with an external
upstream runtime is future integration work after capability adoption.
