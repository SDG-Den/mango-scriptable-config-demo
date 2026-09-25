#!/usr/bin/env nu
source mango.nu

def mango-up [] {
    try { mango-get version | ignore; true } catch { false }
}

for i in 0..50 {
    if (mango-up) { break }
    sleep 100ms
}
if not (mango-up) {
    error make { msg: "mango not reachable" }
    exit 1
}

print $"version:"
mango-version
mango-set-option borderpx 0
mango-set-option gappih 4
mango-set-option rootcolor 1d1d2b
mango-set-option animations off
mango-dispatch setlayout tile
print $"binds:"
mango-binds
mango-watch-first all-clients
print "config done"