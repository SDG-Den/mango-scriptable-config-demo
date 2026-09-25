{ runCommand }:
runCommand "mango-emojicode-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.emojic} $out/lib/mango.emojic
''