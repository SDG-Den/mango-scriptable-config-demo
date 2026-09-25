{ runCommand }:
runCommand "mango-php-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.php} $out/lib/mango.php
''