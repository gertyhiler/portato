#!/bin/sh
set -eu
export XDG_CONFIG_HOME="$PWD/.runtime/dev/config"
export XDG_STATE_HOME="$PWD/.runtime/dev/state"
[ -f .runtime/dev/socket ] || { echo 'Start make dev first' >&2; exit 1; }
IFS= read -r PORTATO_SOCKET < .runtime/dev/socket
export PORTATO_SOCKET
[ -S "$PORTATO_SOCKET" ] || { echo 'Checkout daemon socket is unavailable; start make dev' >&2; exit 1; }
exec go run ./cmd/portato --config "$XDG_CONFIG_HOME/portato/config.yaml" attach
