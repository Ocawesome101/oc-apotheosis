-- hostname --

local argp = require("argp")
local hostname = require("hostname")

local args, opts = argp.parse(...)

if #args == 0 then
  print(hostname.get())
else
  local ok, err = hostname.set(args[1])
  if not ok and err then
    io.stderr:write("hostname: " .. tostring(err), "\n")
    os.exit(1)
  end
end

os.exit(0)
