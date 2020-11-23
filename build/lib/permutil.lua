-- permutil - utilities for working with file permissions --

local lib = {}

local d, r, w, x = "-", "r", "w", "x"
function lib.tostring(perms)
  checkArg(1, perms, "number")
  return string.format("%s%s%s%s%s%s%s%s%s",
                       perms & 1   ~= 0 and r or d,
                       perms & 2   ~= 0 and w or d,
                       perms & 4   ~= 0 and x or d,
                       perms & 8   ~= 0 and r or d,
                       perms & 16  ~= 0 and w or d,
                       perms & 32  ~= 0 and x or d,
                       perms & 64  ~= 0 and r or d,
                       perms & 128 ~= 0 and w or d,
                       perms & 256 ~= 0 and x or d)
end

return lib
