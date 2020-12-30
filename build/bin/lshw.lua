-- lshw --

local argp = require("argp")
local component = require("component")
local computer = require("computer")
local users = require("users")

local args, opts = argp.parse(...)

if users.user() ~= 0 then
  io.stderr:write("lshw: permission denied\n")
  os.exit(1)
end

local dev_info = computer.getDeviceInfo()

for k, v in pairs(dev_info) do
  print(k)
  for _k, _v in pairs(v) do
    print(string.format("\t%s: %s", _k, _v))
  end
end

os.exit(0)
