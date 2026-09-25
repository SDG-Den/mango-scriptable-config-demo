{ runCommand }:
runCommand "mango-cobol-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.cob} $out/lib/mango.cob
  cp ${./mango-ws.cob} $out/lib/mango-ws.cob
''