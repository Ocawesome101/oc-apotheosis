-- set the hostname

local fs = require("filesystem")
local hostname = require("hostname")

if fs.stat("/etc/hostname") then
  local handle = io.open("/etc/hostname", "r")
  local hname = handle:read("l")
  handle:close()
  hostname.set(hname)
end
