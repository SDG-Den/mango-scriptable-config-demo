<?php
class MangoConnectError extends RuntimeException {}

function mango_socket_path(): string
{
    $path = getenv("MANGO_INSTANCE_SIGNATURE");
    if ($path === false || $path === "") {
        throw new RuntimeException("MANGO_INSTANCE_SIGNATURE is not set");
    }
    return $path;
}

function mango_call(string $cmd): array
{
    $fp = @stream_socket_client("unix://" . mango_socket_path(), $errno, $errstr, 2);
    if ($fp === false) {
        throw new MangoConnectError("connect failed: $errstr ($errno)");
    }
    fwrite($fp, $cmd . "\n");
    $line = fgets($fp);
    fclose($fp);
    if ($line === false) {
        throw new RuntimeException("connection closed without reply: $cmd");
    }
    $reply = json_decode(rtrim($line), true);
    if (!is_array($reply)) {
        throw new RuntimeException("bad reply: $line");
    }
    if (isset($reply["error"])) {
        throw new RuntimeException($reply["error"]);
    }
    return $reply;
}

function mango_retry(string $cmd, int $attempts = 50, float $delay = 0.1): array
{
    for ($i = 0; $i < $attempts; $i++) {
        try {
            return mango_call($cmd);
        } catch (MangoConnectError $e) {
            if ($i + 1 < $attempts) {
                usleep((int) ($delay * 1e6));
            }
        }
    }
    throw new RuntimeException("mango not reachable after $attempts attempts: $cmd");
}

function mango_get(string ...$spec): array
{
    return mango_call("get " . implode(" ", $spec));
}

function mango_set_option(string $key, string $value): array
{
    return mango_call("setoption $key $value");
}

function mango_dispatch(string $function, string ...$args): array
{
    return mango_call("dispatch " . implode(",", array_merge([$function], $args)));
}

function mango_unset_bind(string $mode, string $mods, string $keysym, string $family = "bind"): array
{
    return mango_call("unset bind $mode $mods $keysym $family");
}

function mango_unset_rule(string $kind, string $spec): array
{
    return mango_call("unset $kind $spec");
}

function mango_watch(string $subject, ?callable $handler = null): void
{
    $fp = @stream_socket_client("unix://" . mango_socket_path(), $errno, $errstr, 2);
    if ($fp === false) {
        throw new MangoConnectError("connect failed: $errstr ($errno)");
    }
    fwrite($fp, "watch $subject\n");
    while (($line = fgets($fp)) !== false) {
        $line = rtrim($line);
        if ($line === "") {
            continue;
        }
        $event = json_decode($line, true);
        if (!is_array($event)) {
            throw new RuntimeException("bad frame: $line");
        }
        if (isset($event["error"])) {
            throw new RuntimeException($event["error"]);
        }
        if ($handler !== null && call_user_func($handler, $event) === false) {
            break;
        }
    }
    fclose($fp);
}

function mango_watch_first(string $subject): array
{
    $fp = @stream_socket_client("unix://" . mango_socket_path(), $errno, $errstr, 2);
    if ($fp === false) {
        throw new MangoConnectError("connect failed: $errstr ($errno)");
    }
    fwrite($fp, "watch $subject\n");
    $line = fgets($fp);
    fclose($fp);
    if ($line === false) {
        throw new RuntimeException("connection closed without frame: watch $subject");
    }
    $event = json_decode(rtrim($line), true);
    if (!is_array($event)) {
        throw new RuntimeException("bad frame: $line");
    }
    if (isset($event["error"])) {
        throw new RuntimeException($event["error"]);
    }
    return $event;
}

function mango_version(): ?string
{
    return mango_get("version")["version"] ?? null;
}

function mango_monitors(): array
{
    return mango_get("all-monitors")["monitors"] ?? [];
}

function mango_clients(): array
{
    return mango_get("all-clients")["clients"] ?? [];
}

function mango_focused_client(): ?array
{
    return mango_get("focusing-client");
}

function mango_binds(): array
{
    return mango_get("binds")["binds"] ?? [];
}

function mango_rules(): array
{
    return mango_get("rules")["rules"] ?? [];
}

function mango_option(string $key): ?string
{
    return mango_get("option $key")["value"] ?? null;
}

function mango_options(): array
{
    return mango_get("options");
}

function mango_bind(string $mode, string $mods, string $keysym, string $cmd): array
{
    return mango_dispatch("setup_bind", $mode, $mods, $keysym, $cmd);
}

function mango_rule(string $match, string ...$props): array
{
    return mango_dispatch("setup_rule", $match, ...$props);
}

function mango_rule_for_class(string $class, string ...$props): array
{
    return mango_rule("class=$class", ...$props);
}

function mango_set_layout(string $name): array
{
    return mango_dispatch("setlayout", $name);
}

function mango_toggle_layout(): array
{
    static $calls = 0;
    $calls++;
    return mango_set_layout($calls % 2 === 1 ? "tile" : "dwindle");
}

function mango_borders(int $px, string $color): array
{
    return [mango_set_option("borderpx", (string) $px), mango_set_option("bordercolor", $color)];
}

function mango_gaps(int $h, int $v): array
{
    return [mango_set_option("gappih", (string) $h), mango_set_option("gappiv", (string) $v)];
}

function mango_theme(string $hex, int $border_px): array
{
    return [
        mango_set_option("rootcolor", $hex),
        mango_set_option("bordercolor", $hex),
        mango_set_option("borderpx", (string) $border_px),
    ];
}

function mango_watch_until(string $subject, callable $predicate, float $timeout = 5.0): array
{
    $fp = @stream_socket_client("unix://" . mango_socket_path(), $errno, $errstr, 2);
    if ($fp === false) {
        throw new MangoConnectError("connect failed: $errstr ($errno)");
    }
    stream_set_timeout($fp, (int) $timeout);
    fwrite($fp, "watch $subject\n");
    $deadline = microtime(true) + $timeout;
    while (($line = fgets($fp)) !== false) {
        $line = rtrim($line);
        if ($line === "") {
            continue;
        }
        $frame = json_decode($line, true);
        if (!is_array($frame)) {
            throw new RuntimeException("bad frame: $line");
        }
        if (isset($frame["error"])) {
            throw new RuntimeException($frame["error"]);
        }
        if (call_user_func($predicate, $frame) === true) {
            fclose($fp);
            return $frame;
        }
        if (microtime(true) > $deadline) {
            throw new RuntimeException("watch_until timeout: watch $subject");
        }
    }
    fclose($fp);
    throw new RuntimeException("watch_until closed before match: watch $subject");
}

function mango_for_each_client(callable $fn): void
{
    foreach (mango_clients() as $client) {
        call_user_func($fn, $client);
    }
}

function mango_focused(callable $fn): void
{
    $client = mango_focused_client();
    if (isset($client["id"]) && $client["id"] !== null) {
        call_user_func($fn, $client);
    }
}

function mango_options_map(): array
{
    $raw = mango_options();
    if (isset($raw["options"]) && is_array($raw["options"])) {
        $map = [];
        foreach ($raw["options"] as $k => $v) {
            $map[$k] = isset($v["value"]) ? $v["value"] : $v;
        }
        return $map;
    }
    if (isset($raw["option"]) || isset($raw["value"])) {
        return [$raw["option"] ?? "" => $raw["value"] ?? null];
    }
    return $raw;
}

function mango_info(): array
{
    return [
        "version" => mango_version(),
        "monitors" => mango_monitors(),
        "options" => mango_options(),
    ];
}

function mango_apply_options(array $pairs): array
{
    $replies = [];
    foreach ($pairs as $key => $value) {
        $replies[] = mango_set_option((string) $key, (string) $value);
    }
    return $replies;
}