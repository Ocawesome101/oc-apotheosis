#!/usr/bin/env lua
-- edit: a text editor focused purely on speed --

local termio = require("termio")
local sleep = os.sleep or require("posix.unistd").sleep

local file = ...

local buffer = {""}
local cache = {}
local cl, cp = 1, 0
local scroll = {w = 0, h = 0}

if file then
  local handle = io.open(file, "r")
  if handle then
    buffer[1] = nil
    for line in handle:lines("l") do
      buffer[#buffer+1] = line
    end
    handle:close()
  end
else
  io.stderr:write("usage: edit FILE\n")
  os.exit(1)
end

local w, h = termio.getTermSize()

local function status(msg)
  io.write(string.format("\27[%d;1H\27[30;47m\27[2K%s\27[39;49m", h, msg))
end

local function redraw()
  for i=1, h-1, 1 do
    local n = i + scroll.h
    if not cache[n] then
      cache[n] = true
      io.write(string.format("\27[%d;1H%s\27[K", i, buffer[n] or ""))
    end
  end
  status(string.format("%s | ^W=quit ^S=save ^F=find | %d", file:sub(-16), cl))
  io.write(string.format("\27[%d;%dH",
    cl - scroll.h, math.max(1, math.min(#buffer[cl] - cp + 1, w))))
end

local function sscroll(up)
  if up then
    io.write("\27[T")
    scroll.h = scroll.h - 1
    cache[scroll.h + 1] = false
  else
    io.write("\27[S")
    scroll.h = scroll.h + 1
    cache[scroll.h + h - 1] = false
  end
end

local processKey
processKey = function(key, flags)
  flags = flags or {}
  if flags.ctrl then
    if key == "w" then
      io.write("\27[2J\27[1;1H")
      os.exit()
    elseif key == "s" then
      local handle, err = io.open(file, "w")
      if not handle then
        status(err)
        io.flush()
        sleep(1)
        return
      end
      handle:write(table.concat(buffer, "\n") .. "\n")
      handle:close()
    elseif key == "f" then
      status("find: ")
      io.write("\27[30;47m")
      local pat = io.read()
      io.write("\27[39;49m")
      cache = {}
      for i=cl+1, #buffer, 1 do
        if buffer[i]:match(pat) then
          cl = i
          scroll.h = math.max(0, cl - h + 2)
          return
        end
      end
      redraw()
      status("no match")
      io.flush()
      sleep(1)
    elseif key == "m" then
      table.insert(buffer, cl + 1, "")
      processKey("down")
      cache = {}
    end
  elseif not flags.alt then
    if key == "backspace" or key == "delete" or key == "\8" then
      if #buffer[cl] == 0 then
        processKey("up")
        table.remove(buffer, cl + 1)
        cp = 0
        cache = {}
      elseif cp == 0 and #buffer[cl] > 0 then
        buffer[cl] = buffer[cl]:sub(1, -2)
        cache[cl] = false
      elseif cp < #buffer[cl] then
        local tx = buffer[cl]
        buffer[cl] = tx:sub(0, #tx - cp - 1) .. tx:sub(#tx - cp + 1)
        cache[cl] = false
      end
    elseif key == "up" then
      local clch = false
      if (cl - scroll.h) == 1 and cl > 1 then
        sscroll(true)
        cl = cl - 1
        clch = true
      elseif cl > 1 then
        cl = cl - 1
        clch = true
      end
      if clch then
        local dfe_old = #buffer[cl + 1] - cp
        cp = math.max(0, #buffer[cl] - dfe_old)
      end
    elseif key == "down" then
      local clch = false
      if (cl - scroll.h) >= h - 1 and cl < #buffer then
        cl = cl + 1
        sscroll()
        clch = true
      elseif cl < #buffer then
        cl = cl + 1
        clch = true
      end
      if clch then
        local dfe_old = #buffer[cl - 1] - cp
        cp = math.max(0, #buffer[cl] - dfe_old)
      end
    elseif key == "left" then
      if cp < #buffer[cl] then
        cp = cp + 1
      end
    elseif key == "right" then
      if cp > 0 then
        cp = cp - 1
      end
    elseif #key == 1 then
      if cp == 0 then
        buffer[cl] = buffer[cl] .. key
      else
        buffer[cl] = buffer[cl]:sub(0, -cp - 1) .. key .. buffer[cl]:sub(-cp)
      end
      cache[cl] = false
    end
  end
end

io.write("\27[2J")
while true do
  redraw()
  local key, flags = termio.readKey()
  processKey(key, flags)
end
