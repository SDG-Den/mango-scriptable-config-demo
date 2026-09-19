{ runCommand }:
runCommand "mango-ruby-lib" { } ''
  mkdir -p $out/lib
  cp ${./mango.rb} $out/lib/mango.rb
''
