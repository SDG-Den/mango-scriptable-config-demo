{ runCommand }:
runCommand "mango-nushell-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.nu} $out/lib/mango.nu
''