local json = require("cjson")
local mango = require("mango")

local function data(reply)
  if reply.result ~= nil then return reply.result end
  return reply
end

local function count(reply)
  local d = data(reply)
  if type(d) ~= "table" then return 0 end
  local n = 0
  local is_object = false
  for k, v in pairs(d) do
    if type(k) ~= "number" then is_object = true end
    if type(v) == "table" then n = n + #v end
  end
  if is_object then return n end
  return #d
end

local function on_focus(event)
  local d = data(event)
  local appid = d.appid or d.app_id or "-"
  local title = d.title or "-"
  print("focus -> " .. appid .. " | " .. title)
  io.flush()
end

print("mango " .. json.encode(data(mango.retry("get version"))))

local options = {
  {"borderpx", "3"},
  {"gappih", "6"},
  {"gappiv", "6"},
  {"rootcolor", "2e3440ff"},
  {"focused_opacity", "0.95"},
  {"unfocused_opacity", "0.80"},
}
for _, kv in ipairs(options) do mango.set_option(kv[1], kv[2]) end

local binds = {
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
}
for _, bind in ipairs(binds) do mango.set_option("bind", bind) end

mango.set_option("mousebind", "alt,btn_left,moveresize,curmove")
mango.set_option("tagrule", "id:1,layout_name:tile")
mango.set_option("tagrule", "id:2,layout_name:scroller")
mango.set_option("windowrule", "title:foot,isfloating:1")
mango.set_option("windowrule", "appid:firefox,isfullscreen:1,tags:2")
mango.set_option("layerrule", "layer_name:waybar,noanim:1,noshadow:1")

print("binds: " .. count(mango.get("binds")))
print("rules: " .. count(mango.get("rules")))

mango.dispatch("setlayout", "tile")
print("dispatch setlayout tile -> ok")

print("watching all-clients (layout engine)")

local GOH, GOV, GIH, GIV = 10, 10, 6, 6

local function pinwheel(x, y, w, h, count, out)
  if count == 0 then return end
  if count == 1 then
    out[#out + 1] = { math.floor(x), math.floor(y), math.floor(w), math.floor(h) }
    return
  end
  local gw = (w - GIH) / 2
  local gh = (h - GIV) / 2
  local quads = {
    { x, y, gw, gh },
    { x + gw + GIH, y, gw, gh },
    { x + gw + GIH, y + gh + GIV, gw, gh },
    { x, y + gh + GIV, gw, gh },
  }
  for i = 1, 4 do
    local q = quads[i]
    local qn = (i < 4) and 1 or math.max(0, count - 3)
    if qn > 0 then pinwheel(q[1], q[2], q[3], q[4], qn, out) end
  end
end

local function pinwheel_slots(count, mon)
  local out = {}
  pinwheel(mon.x + GOH, mon.y + GOV, mon.width - 2 * GOH, mon.height - 2 * GOV, count, out)
  return out
end

mango.watch("all-clients", function(_event)
  local mons = data(mango.get("all-monitors")).monitors or {}
  local clients = data(mango.get("all-clients")).clients or {}
  if #mons == 0 or #clients == 0 then return end
  local mon = mons[1]
  table.sort(clients, function(a, b) return a.id < b.id end)
  for i = 1, #clients do
    local c = clients[i]
    local slot = pinwheel_slots(#clients, mon)[i]
    local x, y, w, h = slot[1], slot[2], slot[3], slot[4]
    if c.x ~= x or c.y ~= y or c.width ~= w or c.height ~= h then
      mango.dispatch("movewin", x .. "," .. y, "client," .. c.id)
      mango.dispatch("resizewin", w .. "," .. h, "client," .. c.id)
    end
  end
end)