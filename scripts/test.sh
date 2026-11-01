#!/bin/sh
# The runner and every test fixture use disposable Rex servers, never the user's server.
set -eu
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "${1:-}" = --unit ]; then
  for convention in rex lua; do
    luajit "$HERE/tests/config-fixture.lua" "$HERE/init.lua" "$convention"
  done
  exit
fi
REX=${REX_FLOATERS_REX:-${REX_HUNK_REX:-rex}}
TEMP=$(mktemp -d /tmp/rex-test-host.XXXXXXXX)
ENDPOINT="unix://$TEMP/rex.sock"
printf '%s\n' '-- Isolated test runner host.' > "$TEMP/init.lua"
REX_SESSION='' REX_BLOCK='' "$REX" server run --listen "$ENDPOINT" --state-dir "$TEMP/state" --config "$TEMP/init.lua" > "$TEMP/server.log" 2>&1 &
server=$!
cleanup() { kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :; rm -rf "$TEMP"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
attempt=0
until "$REX" --server "$ENDPOINT" --autostart=false server status >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 100 ] || ! kill -0 "$server" 2>/dev/null; then
    printf 'Isolated test runner server failed to start; inspect %s\n' "$TEMP/server.log" >&2
    exit 1
  fi
  sleep 0.05
done
REX_SESSION='' REX_BLOCK='' REX_CONFIG="$TEMP/init.lua" "$REX" --server "$ENDPOINT" --autostart=false 'do' "$HERE/tests/run.lua"
