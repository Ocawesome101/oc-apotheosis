-- mv.  very similar to cp, but deletes the source file(s) after copying. --

local fs = require("filesystem")
local path = require("path")
local argp = require("argp")
local futil = require("futil")
local args, opts = argp.parse(...)

if opts.help then
  io.stderr:write([[
Usage: mv [OPTION]... SOURCE DEST
  or:  mv [OPTION]... SOURCE... DIRECTORY
Move SOURCE to DEST, or multiple SOURCE(s) to
DIRECTORY.

  -r, --recurse
    Copy directories recursively.

  -v, --verbose
    Explain what is being done.
]])
  os.exit(0)
end

if #args == 0 then
  io.stderr:write("mv: missing file operand\n")
  os.exit(1)
elseif #args == 1 then
  io.stderr:write("mv: missing file operand after '", args[1], "'\n")
  os.exit(1)
end

local sources = table.pack(table.unpack(args, 1, #args - 1))
local dest = args[#args]

local info = fs.stat(path.resolve(dest, true))

if #sources > 1 and info and not dest.isDirectory then
  io.stderr:write("mv: target '", dest, "' is not a directory\n")
  os.exit(1)
end

for i=1, #sources, 1 do
  local full, err = path.resolve(sources[i])
  if not full then
    io.stderr:write("mv: ", err)
    os.exit(1)
  end
  local info = fs.stat(full)
  futil.copy(sources[i], dest, opts.v or opts.verbose)
  futil.delete(sources[i])
end

os.exit(0)
