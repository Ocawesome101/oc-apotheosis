--[[
        The standard UNIX text editor, Lua edition.
        
        Copyright (C) 2020 Ocawesome101

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.
        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]


local path = require("libpath")
local args, opts = require("argp").parse(...)

local filename
local current = 0
local buffer = {}

if opts.help then
  io.stderr:write([[
Ed is a line-oriented text editor.  It is used to
create, display, modify, and otherwise manipulate
text files interactively.  This version of ed
cannot execute shell commands.  Ed is the
'standard' text editor in the sense that it is the
original Unix editor, and thus widely available.
Ed is also lightweight and faster than most other
editors.  For most purposes, however, it is
superseded by modern full-screen editors such as
VLED or TLE.
]])
  os.exit(0)
end

error("'ed' is broken right now.  Use 'led' instead.")

local patterns = {
  linespec = "^([%d%$]*)(,?)([%d%$]*)(.)()"
}

local function epr(m)
  if opts.v or opts.verbose then
    print(m)
  else
    print("?")
  end
end

local prompt = false
local commands = {
  ["^q$"] = function()
    os.exit(0)
  end,
  ["^P$"] = function()
    prompt = not prompt
  end,
  ["^a$"] = function(n)
    current = n
    while true do
      local ln = io.read("l")
      if ln == "." then break end
      current = current + 1
      buffer[current] = ln
    end
  end,
  ["^c$"] = function(s, e)
    for i=s, e, 1 do
      table.remove(buffer, s)
    end
    local input = {}
    while true do
      local ln = io.read("l")
      if ln == "." then break end
      table.insert(input, ln)
    end
    for i=#input, 1, -1 do
      table.insert(buffer, s, input[i])
    end
    current = min(#buffer, s + #input)
  end,
  ["^d$"] = function(s, e)
    for i = s, e, 1 do
      table.remove(buffer, s)
    end
  end,
  ["^e (.+)$"] = function(_, _, arg)
    local path, err = path.resolve(arg)
    if not path then
      epr(err)
    end

    local file, err = io.open(path, "w")
    if not file then
      epr(err)
    end
    filename = arg
    buffer = {}
    for line in data:lines("l") do
      buffer[#buffer + 1] = line
    end
    file:close()
  end,
  ["^e$"] = function()
    if not filename then
      epr("no filename specified")
    end
    return commands["^e (.+)$"](nil, nil, filename)
  end,
  ["^f$"] = function()
    if filename then
      print(filename)
    end
  end,
  ["^f (.+)"] = function(_, _, arg)
    filename = arg
  end,
  -- g, G, h, H omitted
  ["^i$"] = function(ln)
    if ln == 0 then ln = 1 end
    local n = 0
    while true do
      local line = io.read("l")
      if line == "." then break end
      table.insert(buffer, ln + n, line)
      n = n + 1
    end
  end,
  ["^l$"] = function(s, e)
    if s == 0 then
      s = 1
    end
    for i = s, e, 1 do
      local p = buffer[i]:gsub("%$","\\$"):gsub("\27","\\27")
    end
  end,
  ["^p$"] = function(s, e)
    if s == 0 then
      s = 1
    end
    e = e or #buffer
    for i = s, e, 1 do
      print(buffer[i])
    end
    current = e
  end,
  ["^r (.+)$"] = function(ln, _, file)
    local handle, err = io.open(file, "r")
    if not handle then
      return epr(err)
    end
    local n = 1
    for line in handle:lines("l") do
      table.insert(buffer, ln + n, line)
      n = n + 1
    end
    handle:close()
  end,
  ["^s/(.+)/(.+)/"] = function(s, e, pat, rep)
    for i = s, e, 1 do
      buffer[i] = buffer[i]:gsub(pat, rep) or buffer[i]
    end
  end,
  ["^w (.+)$"] = function(s, e, file)
    local handle, err = io.open(file, "w")
    if not handle then
      return epr(err)
    end
    if s == 0 then s = 1 end
    if e > #buffer then e = #buffer end
    handle:write(table.concat(buffer, "\n", s, e))
    handle:close()
  end,
  ["^wq (.+)$"] = function(s, e, file)
    local handle, err = io.open(file, "w")
    if not handle then
      return epr(err)
    end
    if s == 0 then s = 1 end
    if e > #buffer then e = #buffer end
    handle:write(table.concat(buffer, "\n", s, e))
    handle:close()
    os.exit(0)
  end,
  ["^W (.+)$"] = function(s, e, file)
    local handle, err = io.open(file, "a")
    if not handle then
      return epr(err)
    end
    if s == 0 then s = 1 end
    if e > #buffer then e = #buffer end
    handle:write(table.concat(buffer, "\n", s, e))
    handle:close()
  end
}

local function execute(cmd, arg1)
  local first, comma, last, command, cN = cmd:match(patterns.linespec)
  if first == "$" then first = current end
  if last  == "$" then last  = current end
  first = tonumber(first) or 1
  last = tonumber(last) or current
  if not comma then last = nil end
  cmd = cmd:sub(cN - 1)
  if #cmd == 0 or cmd == "\n" then
    print(buffer[first])
  end
  for k, v in pairs(commands) do
    if cmd:match(k) then
      return v(first, last, cmd:match(k))
    end
  end
  epr("bad command")
end

local file = args[1]
if file then
  filename = file
  local handle, err = io.open(file, "r")
  if not handle then
    goto begin
  end
  for line in handle:lines("l") do
    buffer[#buffer + 1] = line
    current = 1
  end
  handle:close()
end

::begin::
while true do
  if prompt then
    io.write("*")
  end
  local command = io.read("l")
  execute(command)
end
