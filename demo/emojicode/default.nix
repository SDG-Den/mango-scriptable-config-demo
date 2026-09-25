{
  libPkg,
  mangoPkg,
  writeShellScriptBin,
  writeText,
  runCommand,
  fetchurl,
  stdenv,
  lib,
  autoPatchelfHook,
}:
let
  emojicodec = stdenv.mkDerivation {
    pname = "emojicodec";
    version = "0.9.0";
    src = fetchurl {
      url = "https://github.com/emojicode/emojicode/releases/download/v0.9/Emojicode-0.9.0-Linux-x86_64.tar.gz";
      sha256 = "80544bfd8205822c3cfc0e9f6b22668342f07a9a5fd2f78965f92cc019fb95d1";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    installPhase = ''
      mkdir -p $out/bin
      install -Dm755 emojicodec $out/bin/emojicodec
      cp -r packages $out/packages
      cp -r include $out/include
    '';
  };
  binary = stdenv.mkDerivation {
    pname = "mango-emojicode-bin";
    version = "0.9.0";
    nativeBuildInputs = [ emojicodec stdenv.cc ];
    src = ./config.emojic;
    installPhase = ''
      mkdir -p $out/bin
      cp ${./config.emojic} config.emojic
      cp ${libPkg}/lib/mango.emojic mango.emojic
      emojicodec config.emojic -S ${emojicodec}/packages -o $out/bin/mango-emojicode
    '';
  };
  driver = writeShellScriptBin "mango-config" ''
    export PATH=${mangoPkg}/bin:$PATH
    ${binary}/bin/mango-emojicode | while IFS= read -r run; do
      mmsg "$run" || true
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
runCommand "mango-demo-emojicode" { meta.mainProgram = "mango-demo"; } ''
  mkdir -p $out/bin
  install -Dm755 ${wrapper}/bin/mango-demo $out/bin/mango-demo
  install -Dm444 ${conf} $out/minimal.conf
''