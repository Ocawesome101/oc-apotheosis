-- mkdir --

local fs = require("filesystem")
local argp = require("argp")
local paths = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 or opts.help then
  print([[
Usage: mkdir [OPTION].. DIRECTORY...
Create the DIRECTORY(ies), if they do not already exist.]])
  os.exit()
end

for i=1, #args, 1 do
  local path, err = paths.resolve(args[i], true)
  if not path then
    print(err)
    os.exit(1)
  end
  if fs.stat(path) and not opts.p then
    print(args[i]..": file already exists")
    os.exit(1)
  end
  local ok, err = fs.makeDirectory(path)
  if not ok then
    print(err)
    os.exit(1)
  end
end

os.exit(0)
