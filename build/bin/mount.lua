-- mount --

local argp = require("argp")
local path = require("path")
local fs = require("filesystem")

local args, opts = argp.parse(...)

if opts.help then
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
    io.write(string.format("%s on %s type %s", addr, data.path, data.type))
  end
end

os.exit(0)
