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

local function pinwheel_slots(count, mon)
  local cx = mon.x + mon.width / 2
  local cy = mon.y + mon.height / 2
  local w, h = 620, 400
  local slots = {}
  for i = 1, count do
    local quad, ring = (i - 1) % 4, math.floor((i - 1) / 4)
    local ofs = 120 + ring * 120
    local x, y
    if quad == 0 then x, y = cx + ofs, cy - h / 2 end
    if quad == 1 then x, y = cx - ofs, cy - h / 2 end
    if quad == 2 then x, y = cx - ofs, cy + h / 2 end
    if quad == 3 then x, y = cx + ofs, cy + h / 2 end
    slots[i] = { math.floor(x - w / 2), math.floor(y), w, h }
  end
  return slots
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