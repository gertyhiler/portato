#!/bin/sh
set -eu
for tool in git go bun; do
    command -v "$tool" >/dev/null || { echo "Missing $tool; see docs/runbooks/development.md" >&2; exit 1; }
done
required=$(awk '$1 == "go" { print $2; exit }' go.mod)
actual=$(GOTOOLCHAIN=local go version)
printf '%s\n' "$actual" | awk -v required="$required" '{
    sub(/^go/, "", $3); split($3, a, "."); split(required, r, ".");
    if (a[1]+0 < r[1]+0 || (a[1]+0 == r[1]+0 && a[2]+0 < r[2]+0)) exit 1
}' || { echo "Install Go $required or newer; doctor does not download toolchains" >&2; exit 1; }
printf '%s\n' "$actual"
[ "$(bun --version)" = "$(cat .bun-version)" ] || { echo 'Install the Bun version in .bun-version' >&2; exit 1; }
bun --version
sh scripts/check-linter.sh
if [ "$(uname -s)" = Darwin ]; then
    for tool in swift xcrun iconutil codesign; do command -v "$tool" >/dev/null; done
    xcrun --find swift
fi
