-- uevent - a slightly better event library on top of the kernel one --

local evt = require("event")

local lib = {}

function lib.filter(id)
  local e
  repeat
    e = table.pack(coroutine.yield())
  until e[1] == id
  return table.unpack(e)
end

return lib
