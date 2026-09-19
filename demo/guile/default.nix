{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  guile,
  guile-json,
}:
let
  driver = writeShellScriptBin "mango-config" ''
    export GUILE_LOAD_PATH=${libPkg}/share/guile/site/3.0:${guile-json}/share/guile/site/3.0
    export GUILE_AUTO_COMPILE=0
    exec ${guile}/bin/guile ${./config.scm}
  '';
  conf = writeText "mango-minimal.conf" ''
    tag_num=9
    animations=1
    rootcolor=2e3440ff
    gappih=6
    gappiv=6
    borderpx=3
    exec-once=${driver}/bin/mango-config
  '';
  wrapper = writeShellScriptBin "mango-demo" "exec ${mangoPkg}/bin/mango -c ${conf}";
in
runCommand "mango-demo-guile" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''
