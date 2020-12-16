-- GETTY implementation --

local bgpu, bscr = ...

local event = require("event")
local vt100 = require("vt100")
local computer = require("computer")
local component = require("component")

local gpus, screens, ttys = {}, {}, {}
do
  local w, h = component.invoke(bgpu, "maxResolution")
  gpus[bgpu] = {
    bound = bscr,
    res = w*h
  }
  screens[bscr] = {
    bound = bgpu,
    res = w*h
  }
end

local function get(t, n)
  local res = {}
  for k, v in pairs(t) do
    if not v.bound then
      res[v.res] = res[v.res] or v
    end
  end
  return res[n] or res[8000] or res[2000] or res[800]
end

local function getDeviceInfo()
  local ok, err = pcall(computer.getDeviceInfo)
  if not ok and err then
    return setmetatable({}, {__index=function()return{}end})
  end
  return err
end

local ttyn = 0
local function scan(s, a, t)
  if t ~= "gpu" and t ~= "screen" then
    return nil
  end
  local dinfo = getDeviceInfo()

  for addr, ctype in component.list() do
    if ctype == "gpu" then
      gpus[addr] = gpus[addr] or {
        bound = false,
        res = tonumber(dinfo[addr].capacity) or 8000
      }
    elseif ctype == "screen" then
      screens[addr] = screens[addr] or {
        bound = false,
        res = tonumber(dinfo[addr].capacity) or 8000
      }
    end
  end
  
  for k, v in pairs(gpus) do
    if not dinfo[k] then
      if v.bound then
        process.signal(v.bound, process.signals.SIGHUP)
        screens[v.bound].bound = false
      end
      gpus[k] = nil
    end
  end

  for k, v in pairs(screens) do
    if not dinfo[k] then
      if v.bound then
        process.signal(v.bound, process.signals.SIGHUP)
        gpus[v.bound].bound = false
      end
      screens[k] = nil
    end
  end

  while true do
    local gpu, screen = get(gpus, 8000), get(screens, 8000)
    if not (gpu and screen) then
      break
    end
    local ios = vt100.new(gpu, screen)
    ios.tty = "tty"..ttyn
    gpus[gpu].bound = screen
    screens[screen].bound = gpu
    local ok, err = loadfile("/bin/login.lua")
    if not ok then
      io.stderr:write(err, "\n")
    else
      local i, o, e = io.input(), io.output(), io.error()
      io.input(ios)
      io.output(ios)
      io.error(ios)
      local pid = require("process").spawn(ok, "login")
      io.input(i)
      io.output(o)
      io.error(e)
    end
  end
end

event.register("component_added", scan)
event.register("component_removed", scan)

io.input().tty = "tty0"
ttys[ttyn] = {stream = io.input(), gpu = bgpu, screen = bscr}

local ok, err
if computer.runlevel() == 1 then
  ok, err = loadfile("/bin/sh.lua")
else
  ok, err = loadfile("/bin/login.lua")
end
if not ok then
  io.write(err,"\n")
else
  require("process").spawn(ok, "login")
end

while true do
  local sig = table.pack(coroutine.yield())
  if sig[1] == "thread_died" then
    print(sig[4])
  end
end
