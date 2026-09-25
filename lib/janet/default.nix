{ runCommand }:
runCommand "mango-janet-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.janet} $out/lib/mango.janet
''