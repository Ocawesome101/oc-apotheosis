-- mtrsh - the Minitel Remote SHell client --

local argp = require("argp")
local mtel = require("minitel")

local args, opts = argp.parse(...)

if #args == 0 or opts.help then
  io.stderr:write("usage: mtrsh HOST [PORT]\n")
  os.exit(1)
end

local host, port = args[1], tonumber(args[2]) or 62

io.stderr:write("Connecting....")
local handle, err = mtel.open(host, port)
if not handle then
  io.stderr:write("failed to connect: " .. tostring(err), "\n")
  os.exit(2)
end

while handle.state == "open" do
  if #handle.rbuffer > 0 then
    io.stdout:write(handle:read())
  end
  local line = io.stdin:read()
  handle:write(line)
end

os.exit(0)
