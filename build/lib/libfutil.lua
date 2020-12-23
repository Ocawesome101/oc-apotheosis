-- futil: file utils --

local fs = require("filesystem")
local path = require("path")

local lib = {}

function lib.delete(path)
  checkArg(1, path, "string")
  local info, err = fs.stat(path)
  if info == nil then
    return false, err
  elseif info.isDirectory then
    local stat = true
    for _, file in ipairs(fs.list(path)) do
      local info = fs.stat(path .. "/" .. file)
      if info.isDirectory then
        lib.delete(path .. "/" .. file)
      else
        fs.remove(path .. "/" .. file)
      end
    end
  end
  return fs.remove(path)
end

local function copy_file(f1, f2, v)
  if v then
    print(string.format("'%s' -> '%s'", f1, f2))
  end
  local info = fs.stat(f2)
  if info and info.isDirectory then
    f2 = f2 .. "/" .. (f1:match(".+/(.-)/$") or f1:match(".+/(.-)$"))
  end
  local fd1 = io.open(f1, "r")
  local fd2, err = io.open(f2, "w")
  if not fd2 then
    fd1:close()
    return nil, err
  end
  fd2:write((fd1:read("a")))
  fd1:close()
  fd2:close()
  return true
end

local function find_mnt(path)
  local mounts = fs.mounts()
  local potential = "/"
  for k, v in pairs(mounts) do
    local try = path:match("^"..v.path)
    if try and #try > #potential then
      potential = try
    end
  end
  for k, v in pairs(mounts) do
    if v.path == potential then
      return k
    end
  end
end

local function rcpy(src, dest, rec, verbose)
  local mp = find_mnt(src)
  rec[mp] = rec[mp] or {}
  for k, v in pairs(rec[mp]) do
    if src:match(v.."$") then
      return nil, "not recursing to filesystem at " .. mp
    end
  end
  rec[mp][src:sub(#mp+1)] = true
  if verbose then
    print(string.format("'%s' -> '%s'", src, dest))
  end
  local sfiles = fs.list(src) or {}
  local dinfo = fs.stat(dest)
  local disdir = (dinfo or {isDirectory = true}).isDirectory
  if not disdir then
    return nil, "cannot copy a directory into a file"
  end
  if not dinfo then
    fs.makeDirectory(dest)
  end
  for i=1, #sfiles, 1 do
    local sfull = path.concat(src, sfiles[i])
    local dfull = path.concat(dest, sfiles[i])
    if fs.stat(sfull).isDirectory then
      local ok, err = rcpy(sfull, dfull, rec, verbose)
      if not ok and err then
        return nil, err
      end
    else
      local ok, err = copy_file(sfull, dfull, verbose)
      if not ok and err then
        return nil, err
      end
    end
  end
  return true
end

function lib.copy(src, dest, verbose)
  checkArg(1, src, "string")
  checkArg(2, dest, "string")
  checkArg(3, verbose, "boolean", "nil")
  local src, err = path.resolve(src)
  if not src then
    return nil, err
  end
  local dest, err = path.resolve(dest, true)
  if not dest then
    return nil, err
  end
  local info = fs.stat(src)
  if info.isDirectory then
    return rcpy(src, dest, {}, verbose)
  else
    return copy_file(src, dest)
  end
end

return lib
