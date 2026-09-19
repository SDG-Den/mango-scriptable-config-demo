{ runCommand }:
runCommand "mango-guile-lib" { } ''
  mkdir -p $out/share/guile/site/3.0
  cp ${./mango.scm} $out/share/guile/site/3.0/mango.scm
''
