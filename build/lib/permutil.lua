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

local permN = {
  owner = {
    r = 1,
    w = 2,
    x = 4
  },
  group = {
    r = 8,
    w = 16,
    x = 32
  },
  other = {
    r = 64,
    w = 128,
    x = 256
  }
}

function lib.hasPermission(perms, p, s)
  checkArg(1, perms, "number")
  checkArg(2, p, "string")
  checkArg(3, s, "string", "nil")
  if s and not permN[s] then
    return nil, "invalid permission group subset"
  end
  if s then
    return perms & (permN[s][p]) ~= 0
  else
    for _,v in pairs(permN) do
      if perms & v[p] ~= 0 then
        return true
      end
    end
  end
  return false
end

return lib
