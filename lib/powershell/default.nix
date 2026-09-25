{ runCommand }:
runCommand "mango-powershell-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.ps1} $out/lib/mango.ps1
''