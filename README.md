# mango scriptable config demo

this repo uses a branch of mangoWM that extends the IPC to allow fully scriptable config.

The demo's and libs in this repo *are* vibe-coded, and should serve as a concept piece and inspiration for actual devs to write actual libraries. 



## Try it

Start mango on login with one of the generated configs. `exec-once` in the
minimal config spawns the per-language `mango-config` driver, which inherits
the socket path from `MANGO_INSTANCE_SIGNATURE`:

    $ nix run .              # same as .#python
    $ nix run .#ruby         # also .#node, .#lua, .#guile

`nix run .#python` builds the mango compositor (from the `mango` flake input)
and a `mango-demo` binary that launches it with `minimal.conf`.

Point the demo at another mango source:

    $ nix run . --override-input mango github:mangowm/mango

