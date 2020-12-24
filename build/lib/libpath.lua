-- file path utility functions --

local lib = {}

local fs = require("filesystem")

function lib.concat(...)
  local args = table.pack(...)
  for i=1, args.n, 1 do
    checkArg(i, args[i], "string")
  end
  return "/" .. (table.concat(args, "/"):gsub("[/\\]+", "/"))
end

function lib.segments(path)
  local segs = {}
  for segm in path:gmatch("[^/]+") do
    if segm == ".." then
      table.remove(segs, #segs)
    elseif segm ~= "." then
      segs[#segs + 1] = segm
    end
  end
  return segs
end

function lib.resolve(path, lenient)
  checkArg(1, path, "string")
  checkArg(1, lenient, "boolean", "nil")
  local ret
  if path:sub(1,1) ~= "/" then
    local pwd = os.getenv("PWD")
    local try = lib.concat(pwd, path)
    if fs.stat(try) or lenient then
      ret = try
    end
  elseif fs.stat("/"..path) or lenient then
    ret = "/"..path
  end
  if ret then
    return "/" .. table.concat(lib.segments(ret), "/")
  end
  return nil, path..": file not found"
end

return lib
