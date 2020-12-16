-- mount --

local argp = require("argp")
local path = require("path")
local fs = require("filesystem")
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
  local src, dest = args[1], args[2]
end

os.exit(0)
