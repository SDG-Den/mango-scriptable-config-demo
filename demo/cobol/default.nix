{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  gnucobol,
  patchelf,
}:
let
  binary = runCommand "mango-cobol-bin" {
    nativeBuildInputs = [ gnucobol patchelf ];
  } ''
    mkdir -p $out/bin
    cobc -x -I ${libPkg}/lib ${./config.cob} -o $out/bin/mango-cobol
    patchelf --set-rpath ${gnucobol.lib}/lib $out/bin/mango-cobol
  '';
  driver = writeShellScriptBin "mango-config" ''
    export PATH=${mangoPkg}/bin:$PATH
    ${binary}/bin/mango-cobol | while IFS= read -r run; do
      mmsg $run || true
    done
    echo "config done"
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
runCommand "mango-demo-cobol" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''