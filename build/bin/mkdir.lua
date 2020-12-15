-- mkdir --

local fs = require("filesystem")
local argp = require("argp")
local paths = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
Usage: mkdir [OPTION].. DIRECTORY...
Create the DIRECTORY(ies), if they do not already exist.\n]])
  os.exit(0)
end

for i=1, #args, 1 do
  local path, err = paths.resolve(args[i], true)
  if not path and err then
    io.stderr:write(err, "\n")
    os.exit(1)
  end
  if fs.stat(path) and not opts.p then
    io.stderr:write(args[i], ": file already exists\n")
    os.exit(1)
  end
  local ok, err = fs.makeDirectory(path)
  if not ok and err then
    io.stderr:write(err, "\n")
    os.exit(1)
  end
end

os.exit(0)
