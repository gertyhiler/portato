---
status: accepted
---
# An upstream-compatible client and contributor layer

The owner chose to build on the original developer's core rather than maintain a
separate product architecture. Preserve the Go module identity, runtime contracts
and upstream history. Keep native client code, development tooling and agent
instructions in distinct directories so upstream can adopt each independently.

Core bug fixes and additive IPC changes should be independently reviewable from
the client and tooling. Upstream phase records remain history in this checkout;
fork work follows root AGENTS, accepted ADRs and issue scope. This does not claim
that upstream has adopted the client's behavior or our contributor practices.

An existing daemon that rejects authentication, lacks `/info`, has an unsupported
protocol or cannot be assessed must not trigger another daemon launch. Only a
missing/refused socket permits startup. The client must show the compatibility
error and leave the running daemon alone.

Keep upstream release configuration and updater semantics intact. Upstream
publication jobs run only in the upstream repository; the Make release entry
point refuses fork or ambiguous push destinations. Local app bundles are built from source; [ADR-0005](0005-source-distribution.md)
settles distribution without public binary app releases. Development bundles are
not upgraded in place from upstream releases.

This reduces merge and adoption costs at the expense of explicit compatibility
checks and separate review boundaries. See the [upstream contribution runbook](../runbooks/upstream-contributions.md).
