-- more pager --

local shell = require("shell")
local argp = require("argp")
local vt = require("libvt")

local args, opts = shell.parse(...)

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

local function insert(line)
  if not line then return end
  -- TODO: better ANSI handling
  local raw_len = #(line:gsub("\27%[(%d+)m", ""))
  line = line:gsub("\n", "")
  if raw_len > w then
  else
    write[#write + 1] = line
  end
end

if handle then
  for line in handle:lines() do
    insert(line)
  end
  
  handle:close()
end

local written = 0
for i=1, #write, 1 do
  written = written + 1
  io.write(write[i], "\n")
  if written >= h - 1 then
    written = 0
    io.write("-- MORE --")
    io.stdin:read()
  end
end

os.exit(0)
