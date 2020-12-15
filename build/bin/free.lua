-- free --

local computer = require("computer")

local args, opts = require("libargp").parse(...)

collectgarbage()
local total = computer.totalMemory()
local free = computer.freeMemory()
local used = total - free

if opts.h then
  io.write("total   used  free\n")
  io.write(string.format("%5dK %5dK %5dK\n",
                      math.floor(total/1024),
                      math.floor(used/1024),
                      math.floor(free/1024)))
else
  io.write("    total    used         free\n")
  io.write(string.format("%12d%12d%12d\n", total, used, free))
end

os.exit(0)
