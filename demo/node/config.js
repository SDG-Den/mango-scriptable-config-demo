const mango = require("mango");

const data = (reply) => reply.result ?? reply;

const count = (reply) => {
  const d = data(reply);
  if (Array.isArray(d)) return d.length;
  if (typeof d === "object") {
    return Object.values(d)
      .filter((v) => Array.isArray(v))
      .reduce((n, v) => n + v.length, 0);
  }
  return 0;
};

const onFocus = (event) => {
  const d = data(event);
  const appid = d.appid ?? d.app_id ?? "-";
  const title = d.title ?? "-";
  console.log(`focus -> ${appid} | ${title}`);
};

(async () => {
  console.log("mango " + JSON.stringify(data(await mango.retry("get version"))));

  for (const [key, value] of [
    ["borderpx", "3"],
    ["gappih", "6"],
    ["gappiv", "6"],
    ["rootcolor", "2e3440ff"],
    ["focused_opacity", "0.95"],
    ["unfocused_opacity", "0.80"],
  ]) {
    await mango.setOption(key, value);
  }

  for (const bind of [
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
    "alt,z,togglefloating",
  ]) {
    await mango.setOption("bind", bind);
  }

  await mango.setOption("mousebind", "alt,btn_left,moveresize,curmove");
  await mango.setOption("tagrule", "id:1,layout_name:tile");
  await mango.setOption("tagrule", "id:2,layout_name:scroller");
  await mango.setOption("windowrule", "title:foot,isfloating:1");
  await mango.setOption("windowrule", "appid:firefox,isfullscreen:1,tags:2");
  await mango.setOption("layerrule", "layer_name:waybar,noanim:1,noshadow:1");

  console.log("binds: " + count(await mango.get("binds")));
  console.log("rules: " + count(await mango.get("rules")));

  await mango.dispatch("setlayout", "tile");
  console.log("dispatch setlayout tile -> ok");

  const GAP = { oh: 10, ov: 10, ih: 6, iv: 6 };

  // Golden-spiral dissection on a fixed 144x89 unit grid. Slots hold their
  // position independently of the total count, so previously placed windows
  // never move when a new one spawns. The front slot (index 0) is the 89x89
  // square: leftmost, full height. Each square is pinned flush to its side
  // (W,N,E,S clockwise), so a square only ever touches the previous one.
  const GRID = { w: 144, h: 89 };
  const SIZES = [89, 55, 34, 21, 13, 8, 5, 3, 2, 1, 1];
  const CANON = (() => {
    const slots = [];
    let x = 0, y = 0, w = GRID.w, h = GRID.h;
    for (let i = 0; i < SIZES.length; i++) {
      const s = SIZES[i];
      switch ("WNES"[i % 4]) {
        case "W":
          slots.push({ x, y, w: s, h: s });
          x += s; w -= s;
          break;
        case "N":
          slots.push({ x, y, w: s, h: s });
          y += s; h -= s;
          break;
        case "E":
          slots.push({ x: x + w - s, y, w: s, h: s });
          w -= s;
          break;
        case "S":
          slots.push({ x, y: y + h - s, w: s, h: s });
          h -= s;
          break;
      }
    }
    return slots;
  })();

  const area = (s) => s.w * s.h;

  // Overflow rule for more than eleven windows: split the smallest square into
  // four quadrants, keeping the first quadrant at the square's old spot. Only
  // squares with unit side 2+ split (a 1x1 halved renders sub-pixel once the
  // inner gap is subtracted); if none remain, new windows get no slot.
  const buildSquares = (count) => {
    const slots = CANON.map((s) => ({ ...s }));
    while (slots.length < count) {
      let idx = -1;
      for (let i = 0; i < slots.length; i++) {
        if (slots[i].w >= 2 && (idx === -1 || area(slots[i]) < area(slots[idx]))) {
          idx = i;
        }
      }
      if (idx === -1) break;
      const cur = slots[idx];
      const hw = cur.w / 2;
      const hh = cur.h / 2;
      const quads = [
        { x: cur.x, y: cur.y, w: hw, h: hh },
        { x: cur.x + hw, y: cur.y, w: hw, h: hh },
        { x: cur.x, y: cur.y + hh, w: hw, h: hh },
        { x: cur.x + hw, y: cur.y + hh, w: hw, h: hh },
      ];
      slots.splice(idx, 1, ...quads);
    }
    return slots.slice(0, count);
  };

  // Scales a unit square onto the monitor's usable area with independent X/Y
  // scaling (every slot keeps the same stretched aspect) plus a half inner
  // gap so adjacent windows never touch.
  const slotOf = (q, mon) => {
    const W = mon.width - 2 * GAP.oh;
    const H = mon.height - 2 * GAP.ov;
    const left = mon.x + GAP.oh + (q.x * W) / GRID.w + GAP.ih / 2;
    const top = mon.y + GAP.ov + (q.y * H) / GRID.h + GAP.iv / 2;
    const right = mon.x + GAP.oh + ((q.x + q.w) * W) / GRID.w - GAP.ih / 2;
    const bottom = mon.y + GAP.ov + ((q.y + q.h) * H) / GRID.h - GAP.iv / 2;
    return [Math.round(left), Math.round(top), Math.round(right - left), Math.round(bottom - top)];
  };

  // Chain order: index 0 is the master (biggest, leftmost slot). It mirrors
  // mango's all-clients order initially and is then maintained by the script
  // (prune dead ids, append new ones, move zoom targets to the front).
  let order = null;
  let pendingZoom = null;

  const layout = async () => {
    const mons = (data(await mango.get("all-monitors")).monitors || []);
    const clients = (data(await mango.get("all-clients")).clients || []).filter(
      (c) => !c.is_swallowing
    );
    if (!mons.length || !clients.length) return;
    const mon = mons[0];
    const byId = Object.fromEntries(clients.map((c) => [c.id, c]));
    const ids = new Set(clients.map((c) => c.id));

    // A client that left floating state is the zoom signal: pull it to front.
    if (pendingZoom) {
      const cur = byId[pendingZoom];
      if (!cur || cur.is_floating) pendingZoom = null;
    }
    const zoomTarget = clients.find((c) => !c.is_floating && c.id !== pendingZoom);
    if (zoomTarget) {
      pendingZoom = zoomTarget.id;
      console.log(`zoom -> front: client ${zoomTarget.id}`);
      order = order
        ? [zoomTarget.id, ...order.filter((id) => id !== zoomTarget.id)]
        : [zoomTarget.id];
      await mango.dispatch("togglefloating", "client," + zoomTarget.id);
    }

    // Maintain the chain: keep surviving ids in place, append unknowns.
    if (order) {
      order = order.filter((id) => ids.has(id));
      for (const c of clients) {
        if (!order.includes(c.id)) order.push(c.id);
      }
    } else {
      order = clients.map((c) => c.id);
    }

    const slots = buildSquares(order.length);
    for (let i = 0; i < order.length && i < slots.length; i++) {
      const c = byId[order[i]];
      const [x, y, w, h] = slotOf(slots[i], mon);
      if (c.x !== x || c.y !== y || c.width !== w || c.height !== h) {
        await mango.dispatch("movewin", x + "," + y, "client," + c.id);
        await mango.dispatch("resizewin", w + "," + h, "client," + c.id);
      }
    }
  };

  console.log("watching all-clients (layout engine)");
  await mango.watch("all-clients", () => layout());
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});