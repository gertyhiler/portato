#!/bin/sh
set -eu
urls=$(git remote get-url --push --all origin)
case "$urls" in
    git@github.com:portuber/portato.git|https://github.com/portuber/portato.git|https://github.com/portuber/portato|ssh://git@github.com/portuber/portato.git) ;;
    *) echo 'Publication is reserved for upstream portuber/portato. Use make build or make snapshot for local artifacts; a fork release needs its own distribution policy.' >&2; exit 1 ;;
esac
