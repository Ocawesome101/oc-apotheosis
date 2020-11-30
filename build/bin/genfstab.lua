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
local generated = [[]]
for addr, ctype in component.list("filesystem", true) do
  vprint("add managed filesystem: "..addr)
  generated = generated .. string.format("managed(%s,0)", addr)
end

for addr, ctype in component.list("drive", true) do
end

os.exit(0)
