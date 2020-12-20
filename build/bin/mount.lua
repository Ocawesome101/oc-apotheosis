-- mount --

local argp = require("argp")
local path = require("path")
local fs = require("filesystem")
local users = require("users")
local component = require("component")

local args, opts = argp.parse(...)

if opts.help or #args == 1 then
  io.stderr:write([[
Usage:
 mount
 mount <source> <directory>
]])
  os.exit(0)
end

if #args == 0 then
  local mounts = fs.mounts()
  for addr, data in pairs(mounts) do
    io.write(string.format("%s on %s type %s\n", addr, data.path, data.type))
  end
else
  if users.user() ~= 0 then
    io.stderr:write("mount: only root can do that\n")
    os.exit(1)
  end
  local src, dest = args[1], args[2]
  local comp = component.proxy(src)
  if not src then
    io.stderr:write(src, ": no such component")
    os.exit(1)
  elseif src.type ~= "filesystem" and src.type ~= "drive" then
    io.stderr:write(src, ": not a valid component")
    os.exit(1)
  end
  local ok, err = fs.mount(src, dest)
  if not ok then
    io.stderr:write(err, "\n")
    os.exit(1)
  end
end

os.exit(0)
