{ runCommand }:
runCommand "mango-node-lib" { } ''
  mkdir -p $out/lib/node_modules/mango
  cp ${./package.json} $out/lib/node_modules/mango/package.json
  cp ${./mango.js} $out/lib/node_modules/mango/mango.js
''
