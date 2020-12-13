-- more pager --

local shell = require("shell")
local argp = require("argp")
local vt = require("libvt")

local args, opts = shell.parse(...)

if #args == 0 or opts.help then
  io.stderr:write("usage: more FILE")
  os.exit(1)
end

local handle, err = io.open(args[1], "r")
if not handle then
  shell.error("more", err)
  os.exit(1)
end

if not (io.stdin.tty and io.stdout.tty) then
  shell.error("more", "input/output must be a tty")
  os.exit(1)
end

local w, h = vt.getResolution()
local write = {}
repeat
  local line = handle:read("l")
  if #line > w then
    for i = 1, #line, w do
      write[#write + 1] = line:sub(i, i + w - 1)
    end
  else
    write[#write + 1] = line
  end
until not line

handle:close()

for i = 1, 

os.exit(0)
