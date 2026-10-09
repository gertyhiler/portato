#!/bin/sh
set -eu
export XDG_CONFIG_HOME="$PWD/.runtime/dev/config"
export XDG_STATE_HOME="$PWD/.runtime/dev/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
sockets=$(mktemp -d /tmp/portato-dev-XXXXXX)
export PORTATO_SOCKET="$sockets/ipc.sock"
printf '%s\n' "$PORTATO_SOCKET" > .runtime/dev/socket
child=
cleanup() {
    trap '' INT TERM HUP
    if [ -n "$child" ]; then kill -TERM "$child" 2>/dev/null || :; wait "$child" || :; fi
    rm -f .runtime/dev/socket
    rm -rf "$sockets"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
go build -o .runtime/dev/portato ./cmd/portato
.runtime/dev/portato --config "$XDG_CONFIG_HOME/portato/config.yaml" daemon &
child=$!
wait "$child"
