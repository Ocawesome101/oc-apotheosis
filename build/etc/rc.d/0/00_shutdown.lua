-- shut down

local process = require("process")
print("init: sending SIGTERM to all processes")

for _, pid in pairs(process.list()) do
  process.signal(pid, process.signals.SIGTERM)
end

os.sleep(1)

print("init: sending SIGKILL to all processes")

for _, pid in pairs(process.list()) do
  process.signal(pid, process.signals.SIGKILL)
end
