{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  nushell,
}:
let
  src = runCommand "mango-nushell-src" { } ''
    mkdir -p $out
    cp ${libPkg}/lib/mango.nu $out/mango.nu
    cp ${./config.nu} $out/config.nu
  '';
  driver = writeShellScriptBin "mango-config" ''
    export PATH=${mangoPkg}/bin:$PATH
    cd ${src}
    exec ${nushell}/bin/nu ${src}/config.nu
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
runCommand "mango-demo-nushell" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''