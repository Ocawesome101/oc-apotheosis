-- shut down

local process = require("process")
local out = io.stdout

out:write("init: sending SIGTERM to all processes\n")

for _, pid in pairs(process.list()) do
  process.signal(pid, process.signals.SIGTERM)
end

out:write("init: requesting kernel shutdown")
