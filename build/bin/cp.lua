-- cp --

local fs = require("filesystem")
local path = require("path")
local argp = require("argp")
local futil = require("futil")
local args, opts = argp.parse(...)

if opts.help then
  io.stderr:write([[
Usage: cp [OPTION]... SOURCE DEST
  or:  cp [OPTION]... SOURCE... DIRECTORY
Copy SOURCE to DEST, or multiple SOURCE(s) to
DIRECTORY.

  -r, --recurse
    Copy directories recursively.

  -v, --verbose
    Explain what is being done.
]])
  os.exit(0)
end

if #args == 0 then
  io.stderr:write("cp: missing file operand\n")
  os.exit(1)
elseif #args == 1 then
  io.stderr:write("cp: missing file operand after '", args[1], "'\n")
  os.exit(1)
end

local sources = table.pack(table.unpack(args, 1, #args - 1))
local dest = args[#args]

local info = fs.stat(path.resolve(dest, true))

if #sources > 1 and info and not dest.isDirectory then
  io.stderr:write("cp: target '", dest, "' is not a directory\n")
  os.exit(1)
end

for i=1, #sources, 1 do
  local full, err = path.resolve(sources[i])
  if not full then
    io.stderr:write("cp: ", err)
    os.exit(1)
  end
  local info = fs.stat(full)
  if info.isDirectory and not (opts.r or opts.recurse) then
    io.stderr:write("cp: -r not specified; omitting directory '", sources[i], "'\n")
  else
    futil.copy(sources[i], dest, opts.v or opts.verbose)
  end
end

os.exit(0)
