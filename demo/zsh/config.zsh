#!/usr/bin/env zsh
set -euo pipefail
source "${MANGO_LIB:?MANGO_LIB is not set}/mango.zsh"

ok=0
for _ in {1..50}; do
  if mango_get version >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 0.1
done
if (( ok != 1 )); then
  echo "mango not reachable" >&2
  exit 1
fi

echo "version:"
mango_version
mango_set_option borderpx 0
mango_set_option gappih 4
mango_set_option rootcolor 1d1d2b
mango_set_option animations off
mango_dispatch setlayout tile
echo "binds:"
mango_binds
mango_watch_first all-clients
echo "config done"