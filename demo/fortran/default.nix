{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  gfortran,
  patchelf,
}:
let
  binary = runCommand "mango-fortran-bin" {
    nativeBuildInputs = [ gfortran patchelf ];
  } ''
    mkdir -p $out/bin $out/include
    gfortran -J $out/include ${libPkg}/lib/mango.f90 ${./config.f90} -o $out/bin/mango-fortran
    patchelf --set-rpath ${gfortran.cc}/lib:${gfortran}/lib $out/bin/mango-fortran
  '';
  driver = writeShellScriptBin "mango-config" ''
    export PATH=${mangoPkg}/bin:$PATH
    ${binary}/bin/mango-fortran | while IFS= read -r run; do
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
runCommand "mango-demo-fortran" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''