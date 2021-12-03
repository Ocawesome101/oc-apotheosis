-- xterm-256color handler --

local handler = {}

local termio = require("posix.termio")
local isatty = require("posix.unistd").isatty

handler.keyBackspace = 127
handler.keyDelete = 8

local default = termio.tcgetattr(0)
local raw = {}
for k,v in pairs(default) do raw[k] = v end
raw.oflag = 4
raw.iflag = 0
raw.lflag = 35376
default.cc[2] = handler.keyBackspace

function handler.setRaw(_raw)
  if _raw then
    termio.tcsetattr(0, termio.TCSANOW, raw)
  else
    termio.tcsetattr(0, termio.TCSANOW, default)
  end
end

function handler.cursorVisible(v)
  
end

function handler.ttyIn() return isatty(0) == 1 end
function handler.ttyOut() return isatty(1) == 1 end

return handler
