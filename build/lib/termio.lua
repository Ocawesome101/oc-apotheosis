-- terminal I/O library --

local lib = {}

local function getHandler()
  local term = os.getenv("TERM") or "generic"
  return require("termio."..term)
end

-------------- Cursor manipulation ---------------
function lib.setCursor(x, y)
  if not getHandler().ttyOut() then
    return
  end
  io.write(string.format("\27[%d;%dH", y, x))
end

function lib.getCursor()
  if not (getHandler().ttyIn() and getHandler().ttyOut()) then
    return 1, 1
  end

  io.write("\27[6n")
  
  getHandler().setRaw(true)
  local resp = ""
  
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"

  getHandler().setRaw(false)
  local y, x = resp:match("\27%[(%d+);(%d+)R")

  return tonumber(x), tonumber(y)
end

function lib.getTermSize()
  local cx, cy = lib.getCursor()
  lib.setCursor(9999, 9999)
  
  local w, h = lib.getCursor()
  lib.setCursor(cx, cy)

  return w, h
end

function lib.cursorVisible(vis)
  getHandler().cursorVisible(vis)
end

----------------- Keyboard input -----------------
local patterns = {}

local substitutions = {
  A = "up",
  B = "down",
  C = "right",
  D = "left",
  ["5"] = "pageUp",
  ["6"] = "pageDown"
}

local function getChar(char)
  local byte = string.unpack("<I"..#char, char)
  if byte + 96 > 255 then
    return utf8.char(byte)
  end
  return string.char(96 + byte)
end

function lib.readKey()
  getHandler().setRaw(true)
  local data = io.stdin:read(1)
  local key, flags
  flags = {}

  if data == "\27" then
    local intermediate = io.stdin:read(1)
    if intermediate == "[" then
      data = ""

      repeat
        local c = io.stdin:read(1)
        data = data .. c
        if c:match("[a-zA-Z]") then
          key = c
        end
      until c:match("[a-zA-Z]")

      flags = {}

      for pat, keys in pairs(patterns) do
        if data:match(pat) then
          flags = keys
        end
      end

      key = substitutions[key] or "unknown"
    else
      key = io.stdin:read(1)
      flags = {alt = true}
    end
  elseif data:byte() > 31 and data:byte() < 127 then
    key = data
  elseif data:byte() == (getHandler().keyBackspace or 127) then
    key = "backspace"
  elseif data:byte() == (getHandler().keyDelete or 8) then
    key = "delete"
  else
    key = getChar(data)
    flags = {ctrl = true}
  end

  getHandler().setRaw(false)

  return key, flags
end

return lib
