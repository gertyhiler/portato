# Development and verification

This fork adopts [Unix Runbook v1.0](command-contract.md) on macOS and Linux.
Windows Go runtime support remains upstream functionality; these Make commands
require Unix, GNU Make, a POSIX shell, Git, Bun (the version in `.bun-version`) and the Go
version/toolchain declared in `go.mod`. macOS additionally needs Apple Command
Line Tools with Swift 5.9+ and the macOS SDK. Full Xcode is not required.

## First checkout

```sh
make help
make setup
make doctor
make verify
make build
```

Bare `make` prints help and changes nothing. `setup` downloads pinned Go modules
and installs golangci-lint v1.64.8 into `.tools/bin`; it needs network access and
never installs global tools or changes your Portato configuration. It preserves
existing development state. There are no Swift package dependencies or JavaScript
packages to install. Node/npm are only needed when explicitly using `npx skills`. `doctor` reports missing tools without installing them.

## Command mapping

| Command | Portato implementation |
| --- | --- |
| help | Base commands, extensions and side effects |
| doctor | Tool availability/version output, pinned linter and Bun runtime |
| setup | Go module download, pinned local linter |
| dev | Foreground Go daemon with checkout-owned configuration |
| stop | Reports no managed background services; use Ctrl-C in the foreground daemon |
| fmt | gofmt, modifying Go source |
| check | gofmt validation, go vet, both lint profiles, Swift compilation on macOS |
| test | All Go tests, runbook safety tests, Swift IPC fixtures on macOS |
| verify | check then test; first failure stops the command even with make -j |
| build | Go CLI; additionally the native application on macOS |
| clean | Validates and removes only the artifact allowlist |

Linux checks cover the Go/core/tooling portion; macOS CI additionally owns native
Swift validation. `menubar`, `menubar-test` and `test-menubar-smoke` require macOS.
The standard suite never requires a corporate host, Docker or user credentials.
Named `e2e-*` targets retain their documented external prerequisites.

## Development ownership and cleanup

`make dev` sets isolated XDG config/state paths under `.runtime/dev` and a temporary
Unix socket under `/tmp`. The daemon stays in the foreground. It neither attaches
to nor stops the user's installed daemon. Config persists across development runs.
Run `make dev-tui` from another terminal to attach the UI. It reads the checkout
socket explicitly and fails when unavailable, without global daemon discovery. The foreground daemon
cannot perform the standalone TUI background handoff. Use Ctrl-C to stop the daemon
and q to close the attached TUI. Close both terminals before cleaning. `make run`
retains the upstream user-config scenario.

Base mutating/check commands share an atomic directory lock and reject concurrent runs.
Make owns command sequencing; small POSIX shell scripts own environment/lifecycle.
Bun runs safety checks and test fixtures. A small Bun lock wrapper starts each
Make command in its own process group and stops remaining descendants before
releasing the lock. Internal `_` targets are implementation
details; use the public targets to retain locking.

The lock is `.runtime/runbook.lock.d`, with the wrapper PID in `pid`. Normal exits
and handled signals remove it. After SIGKILL or a crash, confirm that the recorded
process and its children have stopped before manually removing the stale lock.
Locks never expire automatically.
Finish development or builds before cleaning, including tools started outside Make.
`clean` validates every target before deleting anything, rejecting tracked files,
symlink targets and symlinked ancestors. Its fixed allowlist is:

- `bin/`
- `dist/`
- `cover.out`
- `macos/.build/out/` (new Swift build system)
- `macos/.build/arm64-apple-macosx/` and `macos/.build/x86_64-apple-macosx/` (native Swift build system)

`.tools`, `.runtime`, private environment files, module caches, Swift package
checkouts and user configuration are preserved. The previous shared-daemon stop
operation is now the explicit `make daemon-stop` extension. `reload` and
`install-service` also affect the user daemon and remain separate from base commands.

## macOS packaging and runtime checks

```sh
make build
make test-menubar-smoke
```

Packaging always builds Go and Swift from the same checkout, renders `logo.svg`
and signs the app ad-hoc. It does not publish or register a login item. The default
output is `dist/Portato Menu Bar.app`. For a persistent local installation, explicitly
set `PORTATO_APP_DIR="$HOME/Applications/Portato Menu Bar.app" make build`.
`clean` never deletes such external output. Prefer an output outside cloud-synced
folders, where Finder metadata can invalidate an ad-hoc signature.

Smoke scripts create isolated configs/sockets and verify native config CRUD,
validation, persistence, token rotation, real NSMenu bindings, daemon startup and
survival after menu exit. Run `bun macos/scripts/smoke.js --ssh <alias> --remote <host:port>`
explicitly for a real SSH probe. `--gui` waits for Enter before cleaning its fixtures.
Login-after-reboot behavior needs separate manual verification.

## Agent skills

Skills use a flat `.agents/skills/<name>/` layout and the standard root
`skills-lock.json`. Both installed payloads and the lockfile belong in Git.
Normal setup, checks and CI use this checkout without downloading skills.

```sh
npx skills list
npx skills add mattpocock/skills --agent codex --skill tdd code-review -y
npx skills update --project
npx skills experimental_install
```

The add command is an example of selecting skills; do not use `--skill '*'`
unless the whole upstream catalog is intended. Installation is project-local;
never add `--global` for repository maintenance. Restore from the lockfile with
`experimental_install` (an experimental upstream command). Review resulting
payload and lockfile diffs. The migration retains the accepted Matt revision
`6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`; adopting a newer upstream revision is
an explicit maintenance operation, not part of a build.

Keep repository-owned `portato-go` and `portato-swift` alongside external skills.
They have no external lock entries. These commands do not authorize commits or
publication. There are no custom skill-management Make targets or registry scripts.

## Upstream compatibility and publication

See [the upstream contribution runbook](upstream-contributions.md) for independent
patch boundaries. Direct Go commands remain available without contributor tools.
Upstream release jobs and `make release*` are restricted to the upstream repository;
local bundles and CI artifacts do not imply a public fork release.
