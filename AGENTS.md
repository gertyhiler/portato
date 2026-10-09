# Portato contributor and agent instructions

This repository extends upstream Portato with a native macOS client and optional
contributor tooling. The Go core remains upstream-compatible. Read the current
user request, then the documents relevant to the change.

## Contracts and authority

- `docs/SPEC.md`: current Go contracts and the explicitly marked client extension.
- `docs/adr/`: accepted architectural decisions and their rationale. Use sequential
  `0001-slug.md` names as defined by `.agents/skills/domain-modeling/ADR-FORMAT.md`; update links
  when renaming. New decisions must identify any decision they supersede.
- `docs/runbooks/`: exact commands, prerequisites and operational boundaries.
- `CONTEXT.md`: domain vocabulary, not implementation plans or task status.
- `docs/agents/issue-tracker.md`: task scope, acceptance criteria and evidence.
- `docs/ROADMAP.md`, `docs/CONVENTIONS.md` and `docs/phases/`: upstream planning
  history and workflow. They do not impose phase gates on work in this fork.

Current user instructions take precedence over repository process. Skills are
reusable procedures subordinate to these contracts, not another source of product
requirements. Surface contradictions before silently replacing an accepted ADR.

## Upstream-compatible boundaries

Keep `github.com/portuber/portato` as the Go module path. Preserve CLI/TUI behavior,
configuration formats, paths, authentication and service ownership. The Go core
owns tunnels, secrets and configuration persistence; clients consume its API.
New IPC endpoints must be additive, authenticated and independently testable.
See `docs/adr/0004-upstream-compatible-layer.md` and the upstream contribution
runbook for patch boundaries and release policy.

Keep Swift/AppKit code under `macos/`, contributor scripts under `scripts/`, and
agent procedures under `.agents/`. Go builds and tests remain usable directly
without Swift, Bun or agent tooling. Do not add runtime dependencies to the core
for a client or development workflow.

## Commands

Start with `make help`, `make setup`, and `make doctor`. Use `make verify` for
checks followed by tests, and `make build` for packaging. On macOS these include
the native client; on Linux they cover Go and contributor tooling. See
`docs/runbooks/development.md` for the full Unix Runbook v1.0 mapping.

For core-only work: `go build ./...`, `go test ./...`, and `go vet ./...`.
`make build-cli` and `make test-go` retain convenient Go-only entry points.
Use `make fmt` for Go formatting. Run both linter profiles with `make lint` after
`make setup`. Run relevant runtime checks when changing client/daemon integration.

`make dev` owns an isolated foreground daemon; `make dev-tui` attaches only to
that daemon. `make stop` never stops the installed user daemon. The explicit
`daemon-stop`, `install-service` and `reload` extensions affect user services.

## Skills and documentation

Read `.agents/AGENTS.md` for flat skills managed by `npx skills` and the checked-in
`skills-lock.json`. Route Go work to `portato-go` and native client work to
`portato-swift`. Use `docs/agents/domain.md`, `issue-tracker.md` and
`triage-labels.md` with Matt Pocock skills. Preserve external skill payloads.

Write repository documentation, runbooks, instructions and public tracker content
in English. Conversation replies may follow the user's language. Keep small work
proportionate; a new issue, spec or ADR is not mandatory for every edit.

## Changes and delivery

Use Conventional Commits, with a body explaining non-trivial changes. Separate
core fixes, additive IPC, native client and contributor tooling where each forms
an independently reviewable change. `docs(phase-N)` commits are for upstream
phase changes only, not a required lifecycle here.

Do not commit, push, create tags, publish, merge, deploy or close issues without
applicable user authorization. Do not rewrite pushed history or change global
Git configuration. Preserve unrelated work and private local files.

Update affected contracts with behavior changes and report them explicitly.
Follow surrounding code style; add comments only when requested. Avoid pinning
current application release versions in general docs; historical versions and
development toolchain pins are separate. Distinguish local verification, review,
CI, release and human acceptance in reports.
