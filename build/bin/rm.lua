-- rm --

local fs = require("filesystem")
local argp = require("argp")
local futil = require("futil")
local paths = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 or opts.help then
  print([[
Usage: rm [OPTION]... [FILE]...
Remove the FILE(s).]])
  os.exit(0)
end

for i=1, #args, 1 do
  local path, err = paths.resolve(args[i])
  if not path then
    print(err)
    os.exit(1)
  end
  local info = fs.stat(path)
  if info.isDirectory then
    if not opts.r then
      print(args[i]..": is a directory")
      if not opts.f then
        os.exit(1)
      end
    else
      if opts.v then
        print("removing '"..args[i].."'")
      end
      local ok, err = futil.delete(path)
      if not ok then
        print(err)
        if not opts.f then
          os.exit(1)
        end
      end
    end
  else
    if opts.v then
      print("removing '"..args[i].."'")
    end
    local ok, err = fs.remove(path)
    if not ok then
      print(err)
      if not opts.f then
        os.exit(1)
      end
    end
  end
end

os.exit(0)
