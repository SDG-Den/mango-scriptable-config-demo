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
  const DIRS = { 0: "up", 1: "right", 2: "down", 3: "left" };

  // Builds the fibonacci spiral in normalized units on a golden box that starts
  // at 1x1: each new square's side equals the box's perpendicular dimension,
  // attached on the side given by DIRS, growing the box. Sides come out
  // 1, 1, 2, 3, 5, 8... tiling golden rectangles (13x8, 13x21, 34x21) exactly.
  const buildSquares = (count) => {
    const box = { x: 0, y: 0, w: 1, h: 1 };
    const sqs = [{ x: 0, y: 0, w: 1, h: 1 }];
    for (let k = 1; k < count; k++) {
      const d = DIRS[k % 4];
      if (d === "right") {
        sqs.push({ x: box.x + box.w, y: box.y, w: box.h, h: box.h });
        box.w += box.h;
      } else if (d === "down") {
        sqs.push({ x: box.x, y: box.y + box.h, w: box.w, h: box.w });
        box.h += box.w;
      } else if (d === "left") {
        sqs.push({ x: box.x - box.h, y: box.y, w: box.h, h: box.h });
        box.x -= box.h;
        box.w += box.h;
      } else {
        sqs.push({ x: box.x, y: box.y - box.w, w: box.w, h: box.w });
        box.y -= box.w;
        box.h += box.w;
      }
    }
    return { sqs, box };
  };

  // Scales the normalized spiral onto the monitor's usable area via independent
  // X/Y scaling, so every client keeps the same stretched aspect ratio and the
  // whole area is covered with no overlap. Rebuilding from surviving ids
  // self-heals when windows are killed.
  const fibSlots = (count, mon) => {
    const W = mon.width - 2 * GAP.oh;
    const H = mon.height - 2 * GAP.ov;
    const { sqs, box } = buildSquares(count);
    return sqs.map((q) => {
      const left = Math.round(mon.x + GAP.oh + ((q.x - box.x) * W) / box.w);
      const top = Math.round(mon.y + GAP.ov + ((q.y - box.y) * H) / box.h);
      const right = Math.round(mon.x + GAP.oh + ((q.x - box.x + q.w) * W) / box.w);
      const bottom = Math.round(mon.y + GAP.ov + ((q.y - box.y + q.h) * H) / box.h);
      return [left, top, right - left, bottom - top];
    });
  };

  const layout = async () => {
    const mons = data(await mango.get("all-monitors")).monitors;
    const clients = (data(await mango.get("all-clients")).clients || []).filter((c) => !c.is_swallowing).sort((a, b) => a.id - b.id);
    if (!mons.length || !clients.length) return;
    const mon = mons[0];
    const slots = fibSlots(clients.length, mon);
    for (let i = 0; i < clients.length; i++) {
      const c = clients[i];
      const [x, y, w, h] = slots[i];
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