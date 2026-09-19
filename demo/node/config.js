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
    "alt+Shift,q,quit",
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

  const spiral = (count, mon) => {
    const cx = mon.x + mon.width / 2;
    const cy = mon.y + mon.height / 2;
    const slots = [];
    for (let i = 0; i < count; i++) {
      const r = 0.28 * Math.min(mon.width, mon.height) * Math.sqrt((i + 1) / count);
      const a = i * 0.9 + 1.2;
      const w = Math.max(320, 640 - i * 40);
      const h = Math.max(220, 440 - i * 30);
      slots.push([Math.round(cx + r * Math.cos(a)) - w / 2, Math.round(cy + r * Math.sin(a)) - h / 2, w, h]);
    }
    return slots;
  };

  const layout = async () => {
    const mons = data(await mango.get("all-monitors")).monitors;
    const clients = (data(await mango.get("all-clients")).clients || []).filter((c) => !c.is_swallowing).sort((a, b) => a.id - b.id);
    if (!mons.length || !clients.length) return;
    const mon = mons[0];
    const slots = spiral(clients.length, mon);
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