<?php
require getenv("MANGO_LIB") . "/mango.php";

$version = null;
try {
    $version = mango_retry("get version");
} catch (RuntimeException $e) {
    fwrite(STDERR, "mango not reachable\n");
    exit(1);
}

echo "version: ", $version["version"], PHP_EOL;
mango_set_option("borderpx", "0");
mango_set_option("gappih", "4");
mango_set_option("rootcolor", "1d1d2b");
mango_set_option("animations", "off");
mango_dispatch("setlayout", "tile");
echo "binds: ", count(mango_binds()), PHP_EOL;
echo "options: ", count(mango_options()), PHP_EOL;
echo "version-opt: ", mango_option("rootcolor") ?? "(unset)", PHP_EOL;
mango_watch_first("all-clients");
echo "config done", PHP_EOL;