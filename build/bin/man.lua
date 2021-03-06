-- manual pager --

local argp = require("argp")
local paths = require("path")
local fs = require("filesystem")

local args, opts = argp.getopt(table.pack(...), "p:;")

local pager = os.getenv("MANPAGER") or "/bin/more.lua"
local path = "/usr/man/"

if #args == 0 then
  io.stderr:write("usage: man PAGE ...\n")
  os.exit(1)
end

local sections = {1,8,3,0,2,5,4,9,6,7}

local function show(file)
  --[[
  os.execute("fmt "..file.." > /temp_formatted_manpage")
  os.execute(pager.." /temp_formatted_manpage")
  fs.remove("/temp_formatted_manpage")--]]
  os.execute(string.format("fmt %s | %s", file, pager))
end

for i, page in ipairs(args) do
  local full = paths.concat(path, page)
  if fs.stat(full) then
    show(full)
    goto cont
  else
    for _, sect in ipairs(sections) do
      local try = full .. "." .. sect
      if fs.stat(try) then
        show(try)
        goto cont
      end
    end
  end
  io.stderr:write("no manual entry for ", page, "\n")
  os.exit(1)
  ::cont::
end

os.exit(0)
