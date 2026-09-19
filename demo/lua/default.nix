{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  lua5_4,
  lua54Packages,
}:
let
  luasocket = lua54Packages.luasocket;
  cjson = lua54Packages.cjson;
  driver = writeShellScriptBin "mango-config" ''
    export LUA_PATH="${libPkg}/lib/?.lua;${luasocket}/share/lua/5.4/?.lua;${luasocket}/share/lua/5.4/?/init.lua;;"
    export LUA_CPATH="${luasocket}/lib/lua/5.4/?.so;${cjson}/lib/lua/5.4/?.so;;"
    exec ${lua5_4}/bin/lua ${./config.lua}
  '';
  conf = writeText "mango-minimal.conf" ''
    tag_num=9
    animations=1
    rootcolor=2e3440ff
    gappih=6
    gappiv=6
    borderpx=3
    exec-once=${driver}/bin/mango-config
  '';
  wrapper = writeShellScriptBin "mango-demo" "exec ${mangoPkg}/bin/mango -c ${conf}";
in
runCommand "mango-demo-lua" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''
