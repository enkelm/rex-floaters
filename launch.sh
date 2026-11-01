#!/bin/sh
# The popup's own Rex Lua runner survives hide/show and exits with its executor.
set -eu
BIN_DIR=${REX_FLOATERS_BIN_DIR:-${REX_BIN_DIR:-}}
if [ -n "$BIN_DIR" ]; then PATH="$BIN_DIR:$PATH"; export PATH; fi
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "${REX_FLOATERS_REX:-${REX_HUNK_REX:-rex}}" --autostart=false 'do' "$HERE/cli.lua" --args "$1"
