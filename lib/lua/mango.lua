local unix = require("socket.unix")
local socket = require("socket")
local json = require("cjson")
local M = {}

local buffers = {}

local function socket_path()
  local sig = os.getenv("MANGO_INSTANCE_SIGNATURE")
  if sig then return sig end
  error("MANGO_INSTANCE_SIGNATURE is not set")
end

function M.connect()
  local sock, err = unix()
  if not sock then error(err) end
  sock:settimeout(10)
  local ok, cerr = sock:connect(socket_path())
  if not ok then error(cerr) end
  return sock
end

function M.call(cmd)
  local sock = M.connect()
  local ok, err = sock:send(cmd .. "\n")
  if not ok then sock:close() error(err) end
  local line, rerr = sock:receive("*l")
  sock:close()
  if not line then error(rerr or ("connection closed without reply: " .. cmd)) end
  return json.decode(line)
end

function M.ensure_ok(reply)
  if reply.error then error(reply.error) end
  return reply
end

function M.retry(cmd, attempts, delay)
  attempts = attempts or 50
  delay = delay or 0.1
  for _ = 1, attempts do
    local ok, reply = pcall(M.call, cmd)
    if ok then return M.ensure_ok(reply) end
    socket.sleep(delay)
  end
  error("mango not reachable after " .. attempts .. " attempts: " .. cmd)
end

function M.get(...)
  return M.ensure_ok(M.call("get " .. table.concat({ ... }, " ")))
end

function M.set_option(key, value)
  M.ensure_ok(M.call("setoption " .. key .. " " .. value))
end

function M.dispatch(function_name, ...)
  M.ensure_ok(M.call("dispatch " .. table.concat({ function_name, ... }, ",")))
end

function M.unset_bind(mode, mods, keysym, family)
  family = family or "bind"
  M.ensure_ok(M.call("unset bind " .. mode .. " " .. mods .. " " .. keysym .. " " .. family))
end

function M.unset_rule(kind, spec)
  M.ensure_ok(M.call("unset " .. kind .. " " .. spec))
end

function M.watch(subject, on_event)
  local sock = M.connect()
  local ok, err = sock:send("watch " .. subject .. "\n")
  if not ok then sock:close() error(err) end
  sock:settimeout(nil)
  while true do
    local line, rerr = sock:receive("*l")
    if not line then break end
    if line ~= "" then
      on_event(M.ensure_ok(json.decode(line)))
    end
  end
  sock:close()
end

local function next_line(sock)
  while true do
    local line, err, partial = sock:receive("*l")
    if line then
      local head = buffers[sock]
      buffers[sock] = nil
      if head and #head > 0 then return head .. line end
      return line
    end
    if err == "timeout" then
      local head = buffers[sock] or ""
      buffers[sock] = head .. (partial or "")
      return nil
    end
    return nil, err
  end
end

function M.open_watch(subject)
  local sock = M.connect()
  local ok, err = sock:send("watch " .. subject .. "\n")
  if not ok then sock:close() error(err) end
  sock:settimeout(0)
  return sock
end

function M.read_event(sock)
  while true do
    local line, err = next_line(sock)
    if not line then return nil, err end
    if line ~= "" then
      local ok, obj = pcall(json.decode, line)
      if ok and not obj.error then return obj end
    end
  end
end

return M