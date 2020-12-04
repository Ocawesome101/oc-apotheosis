-- ps --

local argp = require("argp")
local process = require("process")

local args, opts = argp.parse(...)
local pids = process.list()
table.sort(pids)


local top = "PID  TIME COMMAND"
print(top)
local fmt = "%4d %04.2f %s"
for i=1, #pids, 1 do
  local info = process.info(pids[i])
  local printable = string.format(fmt, pids[i], info.runtime, info.name)
  print(printable)
end

os.exit(0)
