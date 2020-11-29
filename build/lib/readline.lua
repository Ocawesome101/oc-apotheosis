-- A more elegant readline from a more civilized age. Less convoluted than 
-- Monolith's - largely because it never dealt directly with signals. --

local function gets(n)
  io.write("\27(l\27(R\27[8m")
  local c = io.read(n or 1)
  io.write("\27(L\27(r\27[28m")
  return c
end

local function redraw1(buffer, pos)
  io.write(("\27[D"):rep(#buffer - pos - 1))
end

local function redraw2(buffer, pos, del)
  io.write(buffer)
  if del then
    io.write(" \27[D")
  end
  io.write(("\27[D"):rep(pos))
end

local function readline(opts)
  checkArg(1, opts, "table", "nil")
  local buffer = ""
  local pos = 0
  if opts and opts.prompt then
    io.write(opts.prompt)
  end
  while true do
    redraw1(buffer, pos)
    redraw2(buffer, pos)
    local char = gets(1)
    if char == "\27" then
      gets(1) -- remove the `['
      local esc = ""
      local esc_end
      while true do
        local new = gets(1)
        if new:match("[a-zA-Z]") then
          esc_end = new
          break
        else
          esc = esc .. new
        end
      end
      if esc_end == "C" then -- right
        redraw1(buffer, pos - 2)
        pos = math.max(0, pos - 1)
        redraw2(buffer, pos)
      elseif esc_end == "D" then -- left
        redraw1(buffer, pos - 2)
        pos = math.min(#buffer, pos + 1)
        redraw2(buffer, pos)
      end
    elseif char == "\8" then -- backspace
      if #buffer > 0 and pos <= #buffer then
        redraw1(buffer, pos)
        buffer = buffer:sub(0, #buffer - pos) .. buffer:sub(#buffer - pos + 2)
        redraw2(buffer, pos, true)
      end
    elseif char == "\127" then -- delete
      if #buffer > 0 and pos > 1 then
        redraw1(buffer, pos - 1)
        buffer = buffer:sub(0, #buffer - pos) .. buffer:sub(#buffer - pos + 2)
        redraw2(buffer, pos + 1, true)
      end
    elseif char == "\n" then
      io.write("\n")
      return buffer
    elseif char:match("[%g%s]") then
      buffer = buffer:sub(0, #buffer - pos) .. char .. buffer:sub(#buffer - pos + 1)
    end
  end
end

return readline
