#!/usr/bin/env lua
-- TLE - The Lua Editor --

-- basic terminal interface library --

local vt = {}

function vt.set_cursor(x, y)
  io.write(string.format("\27[%d;%dH", y, x))
end

function vt.get_cursor()
  --os.execute("stty raw -echo")
  io.write("\27[6n")
  local resp = ""
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"
  local y, x = resp:match("\27%[(%d+);(%d+)R")
  --os.execute("stty sane")
  return tonumber(x), tonumber(y)
end

function vt.get_term_size()
  local cx, cy = vt.get_cursor()
  vt.set_cursor(9999, 9999)
  local w, h = vt.get_cursor()
  vt.set_cursor(cx, cy)
  return w, h
end
-- keyboard interface with standard VT100 terminals --

local kbd = {}

local patterns = {
  ["1;7."] = {ctrl = true, alt = true},
  ["1;5."] = {ctrl = true},
  ["1;3."] = {alt = true}
}

local substitutions = {
  A = "up",
  B = "down",
  C = "right",
  D = "left"
}

-- this is a neat party trick.  works for all alphabetical characters.
local function get_char(ascii)
  return string.char(96 + ascii:byte())
end

function kbd.get_key()
--  os.execute("stty raw -echo")
  local data = io.read(1)
  local key, flags
  if data == "\27" then
    local intermediate = io.read(1)
    if intermediate == "[" then
      data = ""
      repeat
        local c = io.read(1)
        data = data .. c
        if c:match("[a-zA-Z]") then
          key = c
        end
      until c:match("[a-zA-Z]")
      flags = {}
      for pat, keys in pairs(patterns) do
        if data:match(pat) then
          flags = keys
        end
      end
      key = substitutions[key] or "unknown"
    else
      key = io.read(1)
      flags = {alt = true}
    end
  elseif data:byte() > 31 and data:byte() < 127 then
    key = data
  elseif data:byte() == 127 then
    key = "backspace"
  else
    key = get_char(data)
    flags = {ctrl = true}
  end
  --os.execute("stty sane")
  return key, flags
end

local args = {...}

local cbuf = 1
local w, h = 1, 1
local buffers = {}

local commands -- forward declaration so commands and load_file can access this
local function load_file(file)
  local n = #buffers + 1
  buffers[n] = {name=file, cline = 1, cpos = 0, scroll = 1, lines = {}, cache = {}}
  local handle = io.open(file)
  cbuf = n
  if not handle then
    buffers[n].lines[1] = ""
    return
  end
  handle:close()
  for line in io.lines(file) do
    buffers[n].lines[#buffers[n].lines + 1] = (line:gsub("\n", ""))
  end
  if commands and commands.t then commands.t() end
end

if args[1] == "--help" then
  print("usage: tle [FILE]")
  os.exit()
elseif args[1] then
  load_file(args[1])
else
  buffers[1] = {name="<new>", cline = 1, cpos = 0, scroll = 0, lines = {""}, cache = {}}
end

local function truncate_name(n, bn)
  if #n > 16 then
    n = "..." .. (n:sub(-13))
  end
  if buffers[bn].unsaved then n = n .. "*" end
  return n
end

-- TODO: may not draw correctly on small terminals or with long buffer names
local function draw_open_buffers()
  vt.set_cursor(1, 1)
  local draw = "\27[2K\27[46m"
  for i=1, #buffers, 1 do
    draw = draw .. "\27[36m \27["..(i == cbuf and "107" or "46")..";30m " .. truncate_name(buffers[i].name, i) .. " \27[46m"
  end
  draw = draw .. "\27[K\27[39;49m"
  if #draw:gsub("\27%[.+m", "") > w then
    draw = draw:sub(1, w)
  end
  io.write(draw)--, "\n\27[G\27[2K\27[36m", string.rep("-", w))
end

local function draw_line(line_num, line_text)
  local write
  if line_text then
    line_text = line_text:gsub("\t", " ")
    if #line_text > (w - 4) then
      line_text = line_text:sub(1, w - 5)
    end
    if buffers[cbuf].highlighter then
      line_text = buffers[cbuf].highlighter(line_text)
    end
    write = string.format("\27[2K\27[36m%4d\27[37m %s", line_num,
                                   line_text)
  else
    write = "\27[2K\27[96m~\27[37m"
  end
  io.write(write)
end

local function draw_buffer()
  w, h = vt.get_term_size()
  io.write("\27[39;49m")
  draw_open_buffers()
  local buffer = buffers[cbuf]
  local top_line = buffer.scroll
  for i=1, h - 1, 1 do
    local line = top_line + i - 1
    if buffer.cache[line] ~= buffer.lines[line] or buffer.lines[line] == nil then
      vt.set_cursor(1, i + 1)
      draw_line(line, buffer.lines[line])
      buffer.cache[line] = buffer.lines[line]
    end
  end
end

local function update_cursor()
  local buf = buffers[cbuf]
  local mw = w - 5
  local cx = (#buf.lines[buf.cline] - buf.cpos) + 6
  local cy = buf.cline - buf.scroll + 2
  if cx > mw then
    vt.set_cursor(1, cy)
    draw_line(buf.cline, (buf.lines[buf.cline]:sub(cx - mw + 1, cx)))
    cx = mw
  end
  vt.set_cursor(cx, cy)
end

local arrows -- these forward declarations will kill me someday
local function insert_character(char)
  local buf = buffers[cbuf]
  buf.unsaved = true
  if char == "\n" then
    local text = ""
    local old_cpos = buf.cpos
    if buf.cline > 1 then -- attempt to get indentation of previous line
      local prev = buf.lines[buf.cline]
      local indent = #prev - #(prev:gsub("^[%s]+", ""))
      text = (" "):rep(indent)
    end
    if buf.cpos > 0 then
      text = text .. buf.lines[buf.cline]:sub(-buf.cpos)
      buf.lines[buf.cline] = buf.lines[buf.cline]:sub(1,
                                          #buf.lines[buf.cline] - buf.cpos)
    end
    table.insert(buf.lines, buf.cline + 1, text)
    arrows.down()
    buf.cpos = old_cpos
    return
  end
  local ln = buf.lines[buf.cline]
  if char == "\8" then
    if buf.cpos < #ln then
      buf.lines[buf.cline] = ln:sub(0, #ln - buf.cpos - 1)
                                                  .. ln:sub(#ln - buf.cpos + 1)
    elseif ln == "" then
      if buf.cline > 1 then
        table.remove(buf.lines, buf.cline)
        arrows.up()
        buf.cpos = 0
      end
    elseif buf.cline > 1 then
      local line = table.remove(buf.lines, buf.cline)
      local old_cpos = buf.cpos
      arrows.up()
      buf.cpos = old_cpos
      buf.lines[buf.cline] = buf.lines[buf.cline] .. line
    end
  else
    buf.lines[buf.cline] = ln:sub(0, #ln - buf.cpos) .. char
                                                  .. ln:sub(#ln - buf.cpos + 1)
  end
end

local function trim_cpos()
  if buffers[cbuf].cpos > #buffers[cbuf].lines[buffers[cbuf].cline] then
    buffers[cbuf].cpos = #buffers[cbuf].lines[buffers[cbuf].cline]
  end
  if buffers[cbuf].cpos < 0 then
    buffers[cbuf].cpos = 0
  end
end

local function try_get_highlighter()
  local ext = buffers[cbuf].name:match("%.(.-)$")
  if not ext then
    return
  end
  local try = "/usr/share/TLE/"..ext..".lua"
  local also_try = os.getenv("HOME").."/.local/share/TLE/"..ext..".lua"
  local ok, ret = pcall(dofile, also_try)
  if ok then
    print("OK", also_try)
    return ret
  else
    io.stderr:write(ret)
    ok, ret = pcall(dofile, try)
    if ok then
      print("OK", try)
      return ret
    end
  end
  return nil
end

arrows = {
  up = function()
    local buf = buffers[cbuf]
    if buf.cline > 1 then
      local dfe = #(buf.lines[buf.cline] or "") - buf.cpos
      buf.cline = buf.cline - 1
      if buf.cline < buf.scroll and buf.scroll > 0 then
        buf.scroll = buf.scroll - 1
        buf.cache = {}
      end
      buf.cpos = #buf.lines[buf.cline] - dfe
    end
    trim_cpos()
  end,
  down = function()
    local buf = buffers[cbuf]
    if buf.cline < #buf.lines then
      local dfe = #(buf.lines[buf.cline] or "") - buf.cpos
      buf.cline = buf.cline + 1
      if buf.cline > buf.scroll + h - 3 then
        buf.scroll = buf.scroll + 1
        buf.cache = {}
      end
      buf.cpos = #buf.lines[buf.cline] - dfe
    end
    trim_cpos()
  end,
  left = function()
    local buf = buffers[cbuf]
    if buf.cpos < #buf.lines[buf.cline] then
      buf.cpos = buf.cpos + 1
    elseif buf.cline > 1 then
      arrows.up()
      buf.cpos = 0
    end
  end,
  right = function()
    local buf = buffers[cbuf]
    if buf.cpos > 0 then
      buf.cpos = buf.cpos - 1
    elseif buf.cline < #buf.lines then
      arrows.down()
      buf.cpos = #buf.lines[buf.cline]
    end
  end,
  -- not strictly an arrow but w/e
  backspace = function()
    insert_character("\8")
  end
}

-- TODO: clean up this function
local function prompt(text)
  -- box is max(#text, 18)x3
  local box_w = math.max(#text, 18)
  local box_x, box_y = w//2 - (box_w//2), h//2 - 1
  vt.set_cursor(box_x, box_y)
  io.write("\27[46m", string.rep(" ", box_w))
  vt.set_cursor(box_x, box_y)
  io.write("\27[30;46m", text)
  local inbuf = ""
  local function redraw()
    vt.set_cursor(box_x, box_y + 1)
    io.write("\27[46m", string.rep(" ", box_w))
    vt.set_cursor(box_x + 1, box_y + 1)
    io.write("\27[36;40m", inbuf:sub(-(box_w - 2)), string.rep(" ",
                                                          (box_w - 2) - #inbuf))
    vt.set_cursor(box_x, box_y + 2)
    io.write("\27[46m", string.rep(" ", box_w))
  end
  repeat
    redraw()
    local c, f = kbd.get_key()
    if c == "backspace" then
      inbuf = inbuf:sub(1, -2)
    elseif not f then
      inbuf = inbuf .. c
    end
  until (c == "m" and (f or {}).ctrl)
  io.write("\27[39;49m")
  buffers[cbuf].cache = {}
  return inbuf
end

commands = {
  b = function()
    if cbuf < #buffers then
      cbuf = cbuf + 1
      buffers[cbuf].cache = {}
    end
  end,
  v = function()
    if cbuf > 1 then
      cbuf = cbuf - 1
      buffers[cbuf].cache = {}
    end
  end,
  f = function()
    local search_pattern = prompt("Search pattern:")
    -- TODO: implement successive searching
    for i = 1, #buffers[cbuf].lines, 1 do
      if buffers[cbuf].lines[i]:match(search_pattern) then
        commands.g(i)
        break
      end
    end
  end,
  g = function(i)
    i = i or tonumber(prompt("Goto line:"))
    i = math.min(i, #buffers[cbuf].lines)
    buffers[cbuf].cline = i
    buffers[cbuf].scroll = i - math.min(i, h // 2)
  end,
  k = function()
    local del = prompt("# of lines to delete:")
    del = tonumber(del)
    if del and del > 0 then
      for i=1, del, 1 do
        local ln = buffers[cbuf].cline
        if ln > #buffers[cbuf].lines then return end
        table.remove(buffers[cbuf].lines, ln)
      end
      buffers[cbuf].cpos = 0
      buffers[cbuf].unsaved = true
      if buffers[cbuf].cline > #buffers[cbuf].lines then
        buffers[cbuf].cline = #buffers[cbuf].lines
      end
    end
  end,
  r = function()
    local search_pattern = prompt("Search pattern:")
    local replace_pattern = prompt("Replace with?")
    for i = 1, #buffers[cbuf].lines, 1 do
      buffers[cbuf].lines[i] = buffers[cbuf].lines[i]:gsub(search_pattern,
                                                                replace_pattern)
    end
  end,
  t = function()
    buffers[cbuf].highlighter = try_get_highlighter()
    buffers[cbuf].cache = {}
  end,
  h = function()
    insert_character("\8")
  end,
  m = function() -- this is how we insert a newline - ^M == "\n"
    insert_character("\n")
  end,
  n = function()
    local file_to_open = prompt("Enter file path:")
    load_file(file_to_open)
    draw_open_buffers()
  end,
  s = function()
    local ok, err = io.open(buffers[cbuf].name, "w")
    if not ok then
      prompt(err)
      return
    end
    for i=1, #buffers[cbuf].lines, 1 do
      ok:write(buffers[cbuf].lines[i], "\n")
    end
    ok:close()
    buffers[cbuf].unsaved = false
  end,
  w = function()
    -- the user may have unsaved work, prompt
    local unsaved
    for i=1, #buffers, 1 do
      if buffers[i].unsaved then
        unsaved = true
       break
      end
    end
    if unsaved then
      local really = prompt("Delete unsaved work? [y/N] ")
      if really ~= "y" then
        return
      end
    end
    table.remove(buffers, cbuf)
    cbuf = math.min(cbuf, #buffers)
    if #buffers == 0 then
      commands.q()
    end
    buffers[cbuf].cache = {}
  end,
  q = function()
    if #buffers > 0 then -- the user may have unsaved work, prompt
      local unsaved
      for i=1, #buffers, 1 do
        if buffers[i].unsaved then
          unsaved = true
          break
        end
      end
      if unsaved then
        local really = prompt("Delete unsaved work? [y/N] ")
        if really ~= "y" then
          return
        end
      end
    end
    io.write("\27[2J\27[1;1H\27(r\27(L\27[m")
    os.exit()
  end
}

commands.t()
io.write("\27[2J\27(R\27(l\27[8m")
draw_open_buffers()

while true do
  draw_buffer()
  update_cursor()
  local key, flags = kbd.get_key()
  flags = flags or {}
  if flags.ctrl then
    if commands[key] then
      commands[key]()
    end
  elseif flags.alt then
  elseif arrows[key] then
    arrows[key]()
  elseif #key == 1 then
    insert_character(key)
  end
end
