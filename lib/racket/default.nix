{ runCommand }:
runCommand "mango-racket-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.rkt} $out/lib/mango.rkt
''