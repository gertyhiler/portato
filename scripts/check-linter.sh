#!/bin/sh
set -eu
version=$(.tools/bin/golangci-lint version)
printf '%s\n' "$version" | awk '{for(i=1;i<NF;i++) if($i=="version") {v=$(i+1); sub(/^v/, "", v); exit(v!="1.64.8")} exit 1}' || {
    echo 'Expected golangci-lint v1.64.8; run make setup' >&2; exit 1;
}
printf '%s\n' "$version"
