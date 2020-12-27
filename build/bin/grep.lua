-- lua-pattern, probably-not-compliant version of grep --

local args, opts = require("argp").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
Usage: grep [OPTIONS]... PATTERN [FILE]
Searches the standard input, or FILE, for PATTERN
and displays all matches.  PATTERN is interpreted
as a Lua pattern.
]])
  os.exit(1)
end

if args[2] then
  io.input(args[2])
end

local pat = args[1]
if opts.i then
  for c in pat:gmatch(".") do
    if c:match("[%a-z%A-Z]") then
      if c:upper() ~= c then
        pat = pat:gsub(c:gsub("[%.%^%$%(%)]", "%%%1"),
                      "["..c..(c:upper() ~= c and c:upper() or "").."]")
      end
    end
  end
end
if opts.v then
  print("MATCHING: " .. pat)
end
local ln = 0
for line in io.lines() do
  ln = ln + 1
  if line:match(pat) then
    if opts.c then
      line = line:gsub(pat, "\27[91m%1\27[39m")
    end
    if opts.n then
      line = string.format("%4d:%s", ln, line)
    end
    io.write(line, "\n")
  end
end

os.exit(0)
