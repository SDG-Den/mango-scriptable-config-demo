{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  php,
}:
let
  driver = writeShellScriptBin "mango-config" ''
    export MANGO_LIB=${libPkg}/lib
    exec ${php}/bin/php ${./config.php}
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
runCommand "mango-demo-php" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''