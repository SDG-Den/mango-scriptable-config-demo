{ runCommand }:
runCommand "mango-python-lib" { } ''
  mkdir -p $out/lib/python
  cp ${./mango.py} $out/lib/python/mango.py
''
