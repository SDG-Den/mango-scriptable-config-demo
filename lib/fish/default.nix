{ runCommand }:
runCommand "mango-fish-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.fish} $out/lib/mango.fish
''