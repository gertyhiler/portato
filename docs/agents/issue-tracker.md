# Issue tracker: GitHub

Use GitHub Issues in `gertyhiler/portato` through direct `gh` commands. Always
pass `--repo gertyhiler/portato` for fork tasks. An explicitly requested upstream
contribution uses `--repo portuber/portato` instead; confirm the destination from
the request and keep the two trackers distinct.
Read scope, comments and labels before changing a tracked task. Task scope and
acceptance criteria live in the owning issue, with meaningful
work logs, verification and next steps. Durable product contracts live in SPEC
and accepted ADRs; an issue links to them instead of silently overriding them.
Use a UTF-8 body file for multiline writes. Do not create local tracker wrappers.

PRs as a request surface: no.

Use English for all public issue, PR and documentation text. Readiness, implementation, local verification,
review, CI and human acceptance are separate facts. A ready label never authorizes
push, merge, release, deployment or issue closure. Follow the user's current scope.
For untracked small work, proceed in the conversation; no duplicate backlog file.
