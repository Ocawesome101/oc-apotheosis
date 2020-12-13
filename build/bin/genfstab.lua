-- generate an fstab --

local argp = require("argp")
local users = require("users")
local component = require("component")

local args, opts = argp.parse(...)

if opts.help then
  print([[
Usage: genfstab [OPTION]...
Generates an fstab.  Optionally saves it to
/etc/fstab.]])
end

if users.user() ~= 0 then
  print("This program must be run as root!")
  os.exit(1)
end

local function vprint(...)
  if opts.v or opts.verbose then
    print(...)
  end
end

-- fstab entry format:
-- e.g. to specify the third partition on the OCGPT of a drive:
-- ocgpt(42d7,3)   /   openfs   rw
-- managed(5732,1)   /   managed   rw
local generated = {}
for addr, ctype in pairs(component.list("filesystem", true)) do
  local new = ""
  vprint("add managed filesystem: "..addr)
  new = new .. string.format("managed(%s,0)", addr)
  io.stderr:write("Please enter a path for ",addr,": ")
  local path = io.read()
  new = new .. " " .. path .. " managed rw\n"
  generated[#generated + 1] = new
end

local function add_unmanaged(addr)
  io.stderr:write("Please enter a partition table format for drive ",addr,": ")
  local pspec = io.read()
  io.stderr:write("How many partitions are on this drive? ")
  local nparts = io.read()
  for npart=1, tonumber(nparts), 1 do
    local new, path, fsspec = ""
    ::retry::
    new = new .. string.format("%s(%d,%s)", pspec, npart, addr)
    io.stderr:write("Please enter a path for ",addr,"(",npart.."","): ")
    path = io.read()
    io.stderr:write("Please enter the filesystem type for ",addr,"(",npart.."","): ")
    fsspec = io.read()
    new = new .. " " .. path .. " " .. fsspec
    io.stderr:write("Does this look correct? [Y/n]: ", new)
    if io.read() == "n" then
      goto retry
    end
    generated[#generated + 1] = new
  end
end

for addr, ctype in component.list("drive", true) do
  vprint("add unmanaged drive: "..addr)
  while not add_unmanaged(addr) do end
end

-- hax to make sure the rootfs comes first - otherwise things don't mount
local final = ""
local done = {}
local root_done = #generated == 1
local i = 1
local full = 0
while true do
  local entry = generated[i]
  if not root_done then 
    if entry:match("^%g+ (%g+)") == "/" then
      done[entry] = true
      root_done = true
      full = full + 1
      final = final .. entry .. "\n"
    end
  elseif not done[entry] then
    full = full + 1
    done[entry] = true
    final = final .. entry .. "\n"
  end
  if root_done and full == 0 then
    break
  end
  i = i + 1
  if i > #generated then i = 1 full = 0 end
end

final = final:gsub("\n+", "\n"):sub(1,-2)
print(final)

os.exit(0)
