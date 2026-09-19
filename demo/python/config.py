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
    "alt+Shift,q,quit",
    "alt,f,togglefullscreen",
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
    r = min(mon["width"], mon["height"]) * 0.35
    w, h = 560, 360
    slots = []
    for i in range(count):
        a = -math.pi / 2 + (math.pi / max(count - 1, 1)) * i
        slots.append((round(cx + r * math.cos(a) - w / 2), round(cy + r * math.sin(a) - h / 2), w, h))
    return slots


def layout_pass():
    mons = data(mango.get("all-monitors")).get("monitors", [])
    clients = [c for c in data(mango.get("all-clients")).get("clients", []) if not c.get("is_swallowing")]
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
