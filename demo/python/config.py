import json
import math

import mango


def data(reply):
    return reply.get("result", reply)


def count(reply):
    d = data(reply)
    if isinstance(d, list):
        return len(d)
    if isinstance(d, dict):
        return sum(len(v) for v in d.values() if isinstance(v, list))
    return 0


def on_focus(event):
    d = data(event)
    appid = d.get("appid") or d.get("app_id") or "-"
    title = d.get("title") or "-"
    print(f"focus -> {appid} | {title}", flush=True)


print("mango " + json.dumps(data(mango.retry("get version"))))

for key, value in [
    ("borderpx", "3"),
    ("gappih", "6"),
    ("gappiv", "6"),
    ("rootcolor", "2e3440ff"),
    ("focused_opacity", "0.95"),
    ("unfocused_opacity", "0.80"),
]:
    mango.set_option(key, value)


for bind in [
    "alt,Return,spawn_shell,foot",
    "alt,space,setlayout,tile",
    "alt+Shift,space,setlayout,scroller",
    "alt,Tab,focusstack,next",
    "alt+Shift,Tab,focusstack,prev",
    "Ctrl,1,view,1",
    "Ctrl,2,view,2",
    "Ctrl,3,view,3",
    "Ctrl,4,view,4",
    "alt,q,killclient",
    "alt,f,togglefullscreen",
    "alt,m,togglemaximizescreen",
]:
    mango.set_option("bind", bind)

mango.set_option("mousebind", "alt,btn_left,moveresize,curmove")
mango.set_option("tagrule", "id:1,layout_name:tile")
mango.set_option("tagrule", "id:2,layout_name:scroller")
mango.set_option("windowrule", "title:foot,isfloating:1")
mango.set_option("windowrule", "appid:firefox,isfullscreen:1,tags:2")
mango.set_option("layerrule", "layer_name:waybar,noanim:1,noshadow:1")

print(f"binds: {count(mango.get('binds'))}")
print(f"rules: {count(mango.get('rules'))}")

mango.dispatch("setlayout", "tile")
print("dispatch setlayout tile -> ok")

print("watching all-clients (layout engine)")


def fan_slots(count, mon):
    cx = mon["x"] + mon["width"] / 2
    cy = mon["y"] + mon["height"] / 2
    k = min(mon["width"], mon["height"]) / 1080
    w, h = round(520 * k), round(420 * k)
    r = 0.30 * min(mon["width"], mon["height"])
    span = 1.05
    margin = 10
    half_arc = r * math.sin(span)
    left = mon["x"] + margin + w / 2
    right = mon["x"] + mon["width"] - margin - w / 2
    xs = []
    ys = []
    for i in range(count):
        a = -math.pi / 2 - span + 2 * span * i / max(count - 1, 1)
        t = (r * math.cos(a) + half_arc) / (2 * half_arc)
        xs.append(left + t * (right - left) - w / 2)
        ys.append(cy + r * math.sin(a) - h / 2)
    dy = mon["y"] + mon["height"] - margin - max(y + h for y in ys)
    if min(ys) + dy < mon["y"] + margin:
        dy = mon["y"] + margin - min(ys)
    return [(round(x), round(y + dy), w, h) for x, y in zip(xs, ys)]


def layout_pass():
    mons = data(mango.get("all-monitors")).get("monitors", [])
    clients = [c for c in data(mango.get("all-clients")).get("clients", []) if not c.get("is_swallowing") and not c.get("is_maximized")]
    clients.sort(key=lambda c: c["id"])
    if not mons or not clients:
        return
    mon = mons[0]
    rows = []
    for c, (x, y, w, h) in zip(clients, fan_slots(len(clients), mon)):
        if (c.get("x"), c.get("y"), c.get("width"), c.get("height")) != (x, y, w, h):
            mango.dispatch("movewin", f"{x},{y}", f"client,{c['id']}")
            mango.dispatch("resizewin", f"{w},{h}", f"client,{c['id']}")
        rows.append(f"#{c['id']}@{x},{y} {w}x{h}")
    print("  fan: " + ", ".join(rows))


mango.watch("all-clients", lambda event: layout_pass())
mango.watch("all-monitors", lambda event: layout_pass())
