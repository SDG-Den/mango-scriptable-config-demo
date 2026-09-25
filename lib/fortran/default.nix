{ runCommand }:
runCommand "mango-fortran-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.f90} $out/lib/mango.f90
''