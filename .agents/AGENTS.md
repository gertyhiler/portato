# Portato Agent Core

Write repository documentation, runbooks, agent instructions, issue text and
public reports in English. Conversation replies may follow the user's language.

Skills live directly in `skills/<name>/SKILL.md`, without category directories.
External skills are managed by the standard `npx skills` CLI and recorded in the
root `skills-lock.json`. Keep installed payloads in Git and preserve upstream
content. `portato-go` and `portato-swift` are repository-owned skills, maintained
in place and not registered as external packages.

Use the requested Matt skill with `docs/agents/issue-tracker.md`,
`triage-labels.md`, and `domain.md`. A Skill-tool invocation means read the
installed SKILL.md. Repository authorization overrides upstream commit/publish
steps. Small tasks need proportionate implementation and verification; do not
force a specification pipeline or a new issue for every edit.

See `docs/runbooks/development.md` for skill installation and updates. There is
no custom registry, integrity manager or automatic skill update during setup/CI.
The initial migration preserves the previously accepted Matt Pocock revision.
Review skill and lockfile diffs together before accepting an update.

`local/`, `tmp/`, and `work/` are ignored machine configuration, disposable
evidence and handoffs. Keep secrets and corporate context out of tracked files;
use the issue tracker instead of creating a parallel task tracker here.

The fork adopts Unix Runbook v1.0; see `docs/runbooks/command-contract.md`.

Root AGENTS defines document authority and upstream boundaries. Use numbered ADRs
(`0001-slug.md`) for architectural decisions and keep CONTEXT as a glossary.
Upstream phase records are reference material, not fork task gates. Skills cannot
authorize commits, publication or a change of tracker destination on their own.
