{ runCommand }:
runCommand "mango-r-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.R} $out/lib/mango.R
''