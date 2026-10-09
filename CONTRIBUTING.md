# Contributing to Portato

This fork builds a native client and contributor tooling on the upstream Go core.
Read [the upstream contribution runbook](docs/runbooks/upstream-contributions.md)
for patch boundaries, compatibility and delivery.

- Small fixes may be proposed directly; keep one logical change per PR.
- Discuss larger changes in the receiving repository before proposing integration.
- Fork work follows the current request or issue and accepted ADRs.
- Upstream uses its own [phase workflow](docs/CONVENTIONS.md); follow that process
  when contributing there. Its phase records are historical references here.

The canonical technical briefing is **[AGENTS.md](./AGENTS.md)** — read it for
layout, build, and conventions. This file covers the process layer.

## Development setup

- Go **1.26+**.
- The fork adopts [Unix Runbook v1.0](docs/runbooks/command-contract.md).
- Start with `make setup`, `make doctor`, `make verify`, then `make build`.
- `make dev` runs an isolated foreground daemon. Bare `make` prints command help.
- See the [development runbook](docs/runbooks/development.md) for prerequisites,
  cleanup boundaries, platform coverage and optional runtime checks.
- Write repository documentation, runbooks, issues and pull requests in English.
- Local release snapshot (no publish): `make snapshot` (needs goreleaser).
- Running locally: start the daemon (`./bin/portato daemon`) and attach
  (`./bin/portato attach`), or run standalone (`./bin/portato`).

## Code conventions

- Follow the style of surrounding code; run `make fmt` and `make lint` before
  sending a PR. The lint guard catches builtin shadowing (`predeclared`) and
  caps cyclomatic complexity (`gocyclo@15`).
- Follow the comment policy in [AGENTS.md](./AGENTS.md).
- **Tests required** for new behaviour; run `make test`.
- Keep changes focused — one logical change per PR.

## Commit messages

Follow [Conventional Commits](./docs/CONVENTIONS.md) — e.g. `fix(forward): …`,
`feat(tui): …`, `docs(readme): …`.

## Licensing

Portato is MIT-licensed (see [LICENSE](./LICENSE)). By submitting a pull request
you agree your contribution is licensed under the same terms. There is no CLA.

## Conduct

Be respectful and constructive. We're all here for the potatoes.
