{ runCommand }:
runCommand "mango-zsh-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.zsh} $out/lib/mango.zsh
''