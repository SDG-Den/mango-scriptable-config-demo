import json
import os
import socket
import time


def socket_path():
    path = os.environ.get("MANGO_INSTANCE_SIGNATURE")
    if path:
        return path
    raise RuntimeError("MANGO_INSTANCE_SIGNATURE is not set")


def connect():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(socket_path())
    return sock


def call(cmd):
    sock = connect()
    try:
        sock.sendall((cmd + "\n").encode())
        line = sock.makefile("r").readline()
    finally:
        sock.close()
    if not line:
        raise RuntimeError(f"connection closed without reply: {cmd}")
    return json.loads(line)


def ensure(reply):
    if "error" in reply:
        raise RuntimeError(reply["error"])
    return reply


def retry(cmd, attempts=50, delay=0.1):
    for _ in range(attempts):
        try:
            return ensure(call(cmd))
        except OSError:
            time.sleep(delay)
    raise RuntimeError(f"mango not reachable after {attempts} attempts: {cmd}")


def get(*spec):
    return ensure(call("get " + " ".join(spec)))


def set_option(key, value):
    ensure(call(f"setoption {key} {value}"))


def dispatch(function, *args):
    ensure(call("dispatch " + ",".join((function,) + args)))


def unset_bind(mode, mods, keysym, family="bind"):
    ensure(call(f"unset bind {mode} {mods} {keysym} {family}"))


def unset_rule(kind, spec):
    ensure(call(f"unset {kind} {spec}"))


def watch(subject, on_event):
    sock = connect()
    try:
        sock.sendall(f"watch {subject}\n".encode())
        for line in sock.makefile("r"):
            if not line.strip():
                continue
            on_event(ensure(json.loads(line)))
    finally:
        sock.close()