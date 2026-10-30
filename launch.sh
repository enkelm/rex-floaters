#!/bin/sh
# The picker runs in Rex's embedded Lua and exits with Lazygit, without a shell prompt.
set -eu
if [ -n "${REX_BIN_DIR:-}" ]; then PATH="$REX_BIN_DIR:$PATH"; export PATH; fi
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "${REX_HUNK_REX:-rex}" --autostart=false 'do' "$HERE/cli.lua" "window=$1" "focus=$2" "zoom=$3"
