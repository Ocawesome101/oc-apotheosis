-- rc - manage system services --

local svc = require("svc")
local argp = require("argp")
local users = require("users")
local config = require("config")
local filesystem = require("filesystem")

local args, opts = argp.parse(...)

if users.user() ~= 0 then
  io.stderr:write("rc: only root can do that\n")
  os.exit(255)
end

if #args == 0 then
  io.stderr:write([[
Usage: rc COMMAND ...
Manage system services.  Available COMMANDs are:
start, stop, enable, disable, list
]])
  os.exit(opts.help and 0 or 1)
end

local cfg = config.new("/etc/services.cfg", true)

local function ensure(p, c)
  if not p then
    io.stderr:write(string.format("usage: rc %s SERVICE\n", c))
    os.exit(1)
  end
end

local commands = {
  start = function(s)
    ensure(s, "start")
    return svc.start(s)
  end,
  
  stop = function(s)
    ensure(s, "stop")
    return svc.stop(s)
  end,
  
  enable = function(s)
    ensure(s, "enable")
    cfg:set(s, true)
  end,
  
  disable = function(s)
    ensure(s, "disable")
    cfg:set(s, nil)
  end,

  list = function()
    if opts.help then
      io.stderr:write("usage: rc list [-r|--running]")
      os.exit(0)
    end
    if opts.r or opts.running then
      local running = svc.running()
      print("      SERVICE    | PID")
      for k,v in pairs(running) do
        print(string.format("%16s | %d", k, v))
      end
      return true
    end
    local files = filesystem.list("/etc/services.d")
    if not files then return true end
    for i=1, #files, 1 do
      print(files[i])
    end
    return true
  end
}

local cmd, arg = args[1], args[2]
if commands[cmd] then
  local ok, err = commands[cmd](arg)
  if not ok then
    io.stderr:write(string.format("rc: %s\n", tostring(err)))
    os.exit(1)
  end
else
  io.stderr:write("rc: invalid command\n")
  os.exit(1)
end

local ok, err = cfg:save()
if not ok then
  io.stderr:write("error saving configuration: ", err, "\n")
  os.exit(2)
end

os.exit(0)
