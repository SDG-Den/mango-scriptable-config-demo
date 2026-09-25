{ runCommand }:
runCommand "mango-chef-lib" { } ''
  mkdir -p $out/lib
  cp ${./chef.py} $out/lib/chef.py
''