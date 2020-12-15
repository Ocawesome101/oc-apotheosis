-- rm --

local fs = require("filesystem")
local argp = require("argp")
local futil = require("futil")
local paths = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
Usage: rm [OPTION]... [FILE]...
Remove the FILE(s).
]])
  os.exit(0)
end

for i=1, #args, 1 do
  local path, err = paths.resolve(args[i])
  if not path then
    io.stderr:write(err, "\n")
    os.exit(1)
  end
  local info = fs.stat(path)
  if info.isDirectory then
    if not opts.r then
      io.stderr:write(args[i], ": is a directory\n")
      if not opts.f then
        os.exit(1)
      end
    else
      if opts.v then
        io.stderr:write("removing '", args[i], "'\n")
      end
      local ok, err = futil.delete(path)
      if not ok then
        io.stderr:write(err, "\n")
        if not opts.f then
          os.exit(1)
        end
      end
    end
  else
    if opts.v then
      io.stderr:write("removing '", args[i], "'\n")
    end
    local ok, err = fs.remove(path)
    if not ok then
      io.stderr:write(err, "\n")
      if not opts.f then
        os.exit(1)
      end
    end
  end
end

os.exit(0)
