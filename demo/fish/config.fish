#!/usr/bin/env fish
source "$MANGO_LIB/mango.fish"

set -l ok 0
for i in (seq 1 50)
    if mango_get version >/dev/null 2>&1
        set ok 1
        break
    end
    sleep 0.1
end
if test $ok != 1
    echo "mango not reachable" >&2
    exit 1
end

echo "version:"
mango_version
mango_set_option borderpx 0
mango_set_option gappih 4
mango_set_option rootcolor 1d1d2b
mango_set_option animations off
mango_set_option bind "alt,Return,spawn_shell,foot"
mango_dispatch setlayout tile
echo "binds:"
mango_binds
mango_watch_first all-clients
echo "config done"