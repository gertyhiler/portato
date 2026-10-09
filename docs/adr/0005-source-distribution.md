---
status: accepted
---
# Distribute the macOS client as source

The owner chose source distribution for this fork: users clone the repository,
build locally and install the app in their own Applications directory. There is
no planned public binary app release, Developer ID signing or notarization
pipeline. Ad-hoc signing remains a local packaging step. This fixes the delivery
choice left open in [ADR-0004](0004-upstream-compatible-layer.md).

The current complete build includes this checkout's Go binary because the client
requires the additive `/info` endpoint. An upstream proposal should first ask for
that small authenticated capability, allowing an independently maintained native
client to use upstream's runtime. Upstream may alternatively adopt the native
client itself. Its maintainer decides whether and how to distribute it.

Do not claim Swift-only installation against arbitrary upstream releases works
today. Until upstream provides the required capability, build the matching core
and client together. Once available upstream, supporting an external runtime and
its upgrade lifecycle is a separate integration change. Contributor tooling and
agent practices remain available in source, without an unsolicited upstream
adoption proposal. The existing SSH fix PR is independent of this proposal.
