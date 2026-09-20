local json = require("cjson")
local socket = require("socket")
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
  {"animation_duration_tag", "0"},
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
  "alt,q,killclient",
  "alt,f,togglefullscreen",
  "alt,equal,setkeymode,zoomin",
  "alt,minus,setkeymode,zoomout",
  "alt,Left,setkeymode,panleft",
  "alt,Right,setkeymode,panright",
  "alt,Up,setkeymode,panup",
  "alt,Down,setkeymode,pandown",
  "alt,r,setkeymode,resetview",
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

print("watching all-clients + keymode (pseudo-infinite canvas)")

local GAP = 4
local PAN = 80
local ZOOM = 1.35
local SCALE_MIN = 0.2
local SCALE_MAX = 4.0

local cam = { s = 1.0, ox = 0, oy = 0 }
local rel = {}
local cam_dirty = false
local last_focus = nil
local cam_mon = nil

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function monitor()
  local mons = data(mango.get("all-monitors")).monitors or {}
  return mons[1]
end

local function cursor()
  local ok, pos = pcall(mango.get, "cursorpos")
  if ok then return pos end
  return nil
end

local function layoutable(c)
  return not c.is_swallowing and not c.is_fullscreen and not c.is_maximized
end

local function sig(n)
  return (n >= 0 and "+" or "") .. string.format("%d", n)
end

local function iw(n)
  return string.format("%d", n)
end

local function pred(r)
  return math.floor(cam.ox + r.rx * cam.s),
         math.floor(cam.oy + r.ry * cam.s),
         math.max(1, math.floor(r.rw * cam.s)),
         math.max(1, math.floor(r.rh * cam.s))
end

local function nearest_sided(clients, px, py)
  local best, best_d, side = nil, math.huge, "right"
  for _, c in ipairs(clients) do
    if rel[c.id] then
      local cx = c.x + c.width / 2
      local cy = c.y + c.height / 2
      local dx = px - cx
      local dy = py - cy
      local d = dx * dx + dy * dy
      if d < best_d then
        best, best_d = c, d
        if math.abs(dx) >= math.abs(dy) then
          side = dx >= 0 and "right" or "left"
        else
          side = dy >= 0 and "down" or "up"
        end
      end
    end
  end
  return best, side
end

local function adopt(c, clients)
  local pos = cursor()
  local p, side = nil, "right"

  local ok, foc = pcall(mango.get, "focusing-client")
  local target_id = ok and foc and foc.id or nil
  if target_id == c.id then target_id = last_focus end
  if target_id then
    for _, o in ipairs(clients) do
      if o.id == target_id then p = o break end
    end
    if p and pos then
      local fx = p.x + p.width / 2
      local fy = p.y + p.height / 2
      local dx = pos.x - fx
      local dy = pos.y - fy
      if math.abs(dx) >= math.abs(dy) then
        side = dx >= 0 and "right" or "left"
      else
        side = dy >= 0 and "down" or "up"
      end
    end
  end

  if not p or not rel[p.id] then p, side = nil, "right" end
  if not p and pos then p, side = nearest_sided(clients, pos.x, pos.y) end
  if not p then
    for _, o in ipairs(clients) do
      if rel[o.id] and o.id ~= c.id then p = o break end
    end
  end

  if not p then
    rel[c.id] = {
      rx = (c.x - cam.ox) / cam.s,
      ry = (c.y - cam.oy) / cam.s,
      rw = c.width / cam.s,
      rh = c.height / cam.s,
      placed = false,
    }
    print("canvas root -> client " .. c.id)
    io.flush()
    return
  end

  local r = rel[p.id]
  local rw, rh = r.rw, r.rh
  local rx, ry
  if side == "right" then
    rx, ry = (p.x + p.width + GAP - cam.ox) / cam.s,
             (p.y - cam.oy) / cam.s
  elseif side == "left" then
    rx, ry = (p.x - GAP - rw * cam.s - cam.ox) / cam.s,
             (p.y - cam.oy) / cam.s
  elseif side == "up" then
    rx, ry = (p.x - cam.ox) / cam.s,
             (p.y - GAP - rh * cam.s - cam.oy) / cam.s
  else
    rx, ry = (p.x - cam.ox) / cam.s,
             (p.y + p.height + GAP - cam.oy) / cam.s
  end
  rel[c.id] = { rx = rx, ry = ry, rw = rw, rh = rh, placed = false }
end

local function paint()
  local clients = data(mango.get("all-clients")).clients or {}

  local alive = {}
  for _, c in ipairs(clients) do alive[c.id] = true end
  for id in pairs(rel) do
    if not alive[id] and not rel[id].hidden then rel[id] = nil end
  end

  for _, c in ipairs(clients) do
    if not rel[c.id] and layoutable(c) then adopt(c, clients) end
  end

  if cam_dirty and cam_mon then
    for _, c in ipairs(clients) do
      local r = rel[c.id]
      if r and layoutable(c) then
        local x, y, w, h = pred(r)
        if x + w <= cam_mon.x or x >= cam_mon.x + cam_mon.width
          or y + h <= cam_mon.y or y >= cam_mon.y + cam_mon.height then
          if not r.hidden then
            mango.dispatch("tag_special_silent", "client," .. iw(c.id))
            r.hidden = true
          end
        elseif r.hidden then
          mango.dispatch("tag_special_tag", "client," .. iw(c.id))
          r.hidden = false
        end
      end
    end
    for id, r in pairs(rel) do
      if r.hidden and not alive[id] then
        local x, y, w, h = pred(r)
        if x > cam_mon.x and x + w < cam_mon.x + cam_mon.width
          and y > cam_mon.y and y + h < cam_mon.y + cam_mon.height then
          mango.dispatch("tag_special_tag", "client," .. iw(id))
          local okc, c2 = pcall(mango.get, "client", id)
          if okc and c2 then
            mango.dispatch("movewin", sig(x - c2.x) .. "," .. sig(y - c2.y), "client," .. iw(id))
            mango.dispatch("resizewin", iw(w) .. "," .. iw(h), "client," .. iw(id))
          end
          r.hidden = false
        end
      end
    end
  end

  for _, c in ipairs(clients) do
    local r = rel[c.id]
    if r and layoutable(c) and not r.hidden then
      local x, y, w, h = pred(r)
      if not r.placed or not c.is_floating or cam_dirty then
        mango.dispatch("movewin", sig(x - c.x) .. "," .. sig(y - c.y), "client," .. iw(c.id))
        mango.dispatch("resizewin", iw(w) .. "," .. iw(h), "client," .. iw(c.id))
        r.placed = true
      end
    end
  end
  cam_dirty = false

  local okf, focf = pcall(mango.get, "focusing-client")
  if okf and focf and focf.id then last_focus = focf.id end
end

local function zoom(factor, mon)
  local mx = mon.x + mon.width / 2
  local my = mon.y + mon.height / 2
  local s2 = clamp(cam.s * factor, SCALE_MIN, SCALE_MAX)
  if s2 == cam.s then return end
  cam.ox = mx - (mx - cam.ox) * s2 / cam.s
  cam.oy = my - (my - cam.oy) * s2 / cam.s
  cam.s = s2
  cam_mon = mon
  cam_dirty = true
  paint()
end

local function pan(dx, dy, mon)
  cam.ox = cam.ox + dx
  cam.oy = cam.oy + dy
  cam_mon = mon
  cam_dirty = true
  paint()
end

local function reset_view(mon)
  cam.s = 1.0
  local minx, miny, maxx, maxy
  for _, r in pairs(rel) do
    local x, y, w, h = pred(r)
    if minx == nil or x < minx then minx = x end
    if miny == nil or y < miny then miny = y end
    if maxx == nil or x + w > maxx then maxx = x + w end
    if maxy == nil or y + h > maxy then maxy = y + h end
  end
  if minx then
    cam.ox = mon.x + mon.width / 2 - (minx + maxx) / 2
    cam.oy = mon.y + mon.height / 2 - (miny + maxy) / 2
  end
  cam_mon = mon
  cam_dirty = true
  paint()
end

local function on_keymode(ev)
  local mode = ev.keymode
  if not mode or mode == "default" then return end
  mango.dispatch("setkeymode", "default")
  local mon = monitor()
  if not mon then return end
  if mode == "zoomin" then
    zoom(ZOOM, mon)
  elseif mode == "zoomout" then
    zoom(1 / ZOOM, mon)
  elseif mode == "panleft" then
    pan(PAN, 0, mon)
  elseif mode == "panright" then
    pan(-PAN, 0, mon)
  elseif mode == "panup" then
    pan(0, PAN, mon)
  elseif mode == "pandown" then
    pan(0, -PAN, mon)
  elseif mode == "resetview" then
    reset_view(mon)
  end
end

local function handle(ev)
  local ok, err = pcall(function()
    if ev.clients ~= nil then
      paint()
    elseif ev.keymode ~= nil then
      on_keymode(ev)
    end
  end)
  if not ok then
    print("guard: " .. tostring(err))
    io.flush()
  end
end

local csock = mango.open_watch("all-clients")
local ksock = mango.open_watch("keymode")

local function reopen_watches()
  if csock then pcall(csock.close, csock) end
  if ksock then pcall(ksock.close, ksock) end
  socket.sleep(0.5)
  local ok1 = pcall(function() csock = mango.open_watch("all-clients") end)
  local ok2 = pcall(function() ksock = mango.open_watch("keymode") end)
  if ok1 and ok2 then
    local okg, km = pcall(mango.get, "keymode")
    if okg and type(km) == "table" and km.keymode and km.keymode ~= "default" then
      pcall(mango.dispatch, "setkeymode", "default")
      print("reconnect: reset stuck keymode -> default")
      io.flush()
    end
  end
end

local function pump(sock)
  while true do
    local ev, err = mango.read_event(sock)
    if ev then
      handle(ev)
    else
      if err then return "closed" end
      return
    end
  end
end

local loop_strikes = 0
while true do
  local ok, err = pcall(function()
    local ready = socket.select({ csock, ksock }, nil, nil)
    local reopened = false
    for _, s in ipairs(ready) do
      if pump(s) == "closed" and not reopened then
        reopened = true
        print("watch closed, reconnecting")
        io.flush()
        reopen_watches()
      end
    end
  end)
  if not ok then
    print("loop error: " .. tostring(err))
    io.flush()
    loop_strikes = loop_strikes + 1
    if loop_strikes >= 3 then reopen_watches() end
    socket.sleep(0.5)
  else
    loop_strikes = 0
  end
end