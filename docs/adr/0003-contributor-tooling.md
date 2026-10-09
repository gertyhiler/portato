---
status: accepted
---
# Bun and standard skill management

Accepted by the owner on 2026-10-09. Use Bun for non-trivial contributor checks,
process-group locking, fixtures and smoke tests; keep atomic commands in Make and
small environment/lifecycle operations in POSIX shell. This replaces the Python
runbook dispatcher without introducing a new general-purpose task runner.

Use `npx skills` with flat `.agents/skills/<name>/` directories and the standard
root `skills-lock.json`, replacing the custom registry and manager. Track installed
external payloads at their accepted revision; keep repository-owned Go/Swift
skills alongside them. Setup and CI consume the checkout without updating skills.
Node/npm are optional maintenance prerequisites for the requested `npx` command.

Contributor dependencies do not become Go runtime dependencies. Public repository
documentation, runbooks, instructions and tracker content use English. Conversation
replies may use the user's language.
