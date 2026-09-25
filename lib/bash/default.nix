{ runCommand }:
runCommand "mango-bash-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.sh} $out/lib/mango.sh
''