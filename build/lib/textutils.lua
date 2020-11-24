-- text utilities --

local lib = {}

function lib.padRight(str, n)
  checkArg(1, str, "string")
  checkArg(2, n, "number")
  return str .. (" "):rep(n - #str)
end

function lib.padLeft(str, n)
  checkArg(1, str, "string")
  checkArg(2, n, "number")
  return (" "):rep(n - #str) .. str
end

return lib
