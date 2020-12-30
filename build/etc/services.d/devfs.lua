-- devfs service --

local api = require("devfs")

while true do
  local sig = table.pack(coroutine.yield())
  if sig[1] == "component_added" then
    api.register(sig[2])
  elseif sig[1] == "component_removed" then
    api.register(sig[3])
  end
end
