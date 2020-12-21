-- more pager --

local shell = require("shell")
local argp = require("argp")
local vt = require("libvt")

local args, opts = argp.parse(...)

if (#args == 0 and io.input().tty) or opts.help then
  io.stderr:write("usage: more FILE\n")
  os.exit(opts.help and 0 or 1)
end

local handle, err
if io.input().tty then
  handle, err = io.open(args[1], "r")
  if not handle then
    shell.error("more", err)
    os.exit(1)
  end
else
  handle = io.input()
end

local w, h = vt.getResolution()
local write = {}

local function line_len(line)
  if not line then return end
  -- TODO: better ANSI handling
  return #(line:gsub("\27%[%d%dm", ""))
end

if handle then
  for line in handle:lines() do
    write[#write + 1] = line:gsub("\n", "")
  end
  
  handle:close()
end

local written = 0
for i=1, #write, 1 do
  local add = math.max(1, math.ceil((line_len(write[i]) + 1) / w))
  if written + add >= h - 1 then
    written = 0
    io.write("-- MORE --")
    io.stdin:read()
  else
    written = written + add
    io.write(write[i], "\n")
  end
end

os.exit(0)
