{ runCommand }:
runCommand "mango-lua-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.lua} $out/lib/mango.lua
''
