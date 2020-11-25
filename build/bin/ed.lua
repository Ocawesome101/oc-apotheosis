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
  print([[
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
    for line in file:lines("l") do
      buffer[#buffer + 1] = line
    end
    file:close()
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
  end
}

local function execute(cmd, arg1)
  local first, comma, last, command, cN = cmd:match(patterns.linespec)
  if first == "$" then first = current end
  if last  == "$" then last  = current end
  first = tonumber(first) or current
  last = tonumber(last) or current
  if not comma then last = nil end
  cmd = cmd:sub(cN - 1)
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
