# Project Runbook Contract

Version: **1.0**. Platform: **Unix** (macOS/Linux), GNU Make and a POSIX shell.
Windows is outside this contract. Read this document when adopting the runbook
in another repository or changing a base command's meaning.

This is a portable command interface, independent of language and framework.
Each repository supplies its own implementation and declares its prerequisites.
Copy/adopt the contract with the project; it requires no shared runner or network
service. Package scripts and native tooling may remain the implementation behind
Make and must stay aligned with their Make entrypoints.

## Base commands

| Command       | Contract                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make help`   | List base commands and project extensions, including relevant side effects. Bare `make` does the same and changes nothing.                                                |
| `make doctor` | Diagnose local prerequisites and configuration without installing, repairing, starting services, or exposing secrets. Report missing requirements with actionable errors. |
| `make setup`  | Prepare the checkout for development: install pinned dependencies and perform necessary local generation. Repeat safely; preserve existing configuration and data.        |
| `make dev`    | Start the primary development scenario with its necessary local services. Keep the main development process in the foreground.                                            |
| `make stop`   | Stop only background processes owned by this checkout's managed environment. Preserve data and shared or unrelated processes.                                             |
| `make fmt`    | Apply the project's source formatting. This command intentionally edits files.                                                                                            |
| `make check`  | Run static checks, including format validation and applicable lint, types, and configuration contracts. Do not auto-fix source files.                                     |
| `make test`   | Run the complete standard autonomous test set once, then exit with its result. Never enter watch mode. Include tests of maintained project tooling.                       |
| `make verify` | Run `check`, then `test`, stopping on failure. Exclude release builds and tests requiring external environments.                                                          |
| `make build`  | Produce the primary distributable artifact: application, binary, package, or site. Do not publish or deploy it.                                                           |
| `make clean`  | Remove only a fixed, documented allowlist of reproducible build/check artifacts. Preserve dependencies, environment files, databases, and user data.                      |

## Execution rules

- `setup` installs the declared versions without upgrading dependencies, rewriting
  lockfiles, installing global tools, or overwriting secrets. Missing credentials
  or system tools require an explicit diagnostic, not an automatic substitute.
- Base commands never deploy, migrate a shared database, or mutate production.
  Document any required network access, local service startup, and resource cost.
- Checks and tests may create disposable artifacts, compile test programs, and use
  isolated fixtures. They must not repair source files as a side effect.
- A failed required step fails the command. Missing tools or tests are not a
  successful check. Unsupported commands explain why they are unavailable and
  return a nonzero status; they must not silently succeed.
- Base aggregates always retain their full scope. Use named extensions to select
  a test, run watch mode, or skip a category; do not present a narrowed run as a
  successful full `test` or `verify`.
- Run aggregate checks in order even when Make is invoked with parallel jobs.
  Background service ownership must be verified before stopping anything.
- Stop active foreground development/build processes before `clean`. Cleanup
  validates every target before deleting any, refuses tracked content and target
  symlinks, and never uses a broad repository or Git cleanup command.
- For a library, `dev` can be the documented example application or a foreground
  watch loop. If no development scenario exists, explain that explicitly.

## Project extensions

Keep base meanings stable. Add descriptive extensions such as `test-unit`,
`test-integration`, `test-e2e`, `test-watch`, `dev-app`, `infra-up`, `infra-down`,
`build-image`, `db-migrate`, or `skills-check`. Mark destructive, shared-service,
network, and publishing operations in help. Existing command names may remain
aliases when their behavior is unchanged; an alias must not weaken a base rule.

Tool selection stays local: for example, a Go project can implement `test` with
`go test ./...`, a Python project with a pinned environment's test runner, and a
Rust project with `cargo test --locked`. The same outcome and side-effect rules
apply regardless of the tool.

## Adopting and changing the contract

1. Declare the contract version and platform in the repository's runbook.
2. Map every base command to real project operations and prerequisites. Document
   unavailable operations instead of adding success-only placeholders.
3. Keep `make help` as the executable index. Keep setup instructions, service
   ownership, cleanup scope, and exceptional risks in the repository README.
4. Verify command ordering, failure propagation, default behavior, and safety
   boundaries before adoption. Record actual checks separately from dry runs.

Bump the contract version when its semantics change: major for incompatible
meanings/removals, minor for compatible additions. Implementation changes that
preserve the contract do not need a version bump. Adopting a new version in another
repository is an explicit change, not an automatic remote update.
