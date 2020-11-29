-- A more elegant readline from a more civilized age. Less convoluted than 
-- Monolith's - largely because it never dealt directly with signals. --

local function gets(n)
  io.write("\27(l\27(R")
  local c = io.read(n or 1)
  io.write("\27(L\27(r")
  return c
end

local function readline(opts)
  checkArg(1, opts, "table", "nil")
  local buffer = ""
  local pos = 0
  if opts and opts.prompt then
    io.write(opts.prompt)
  end
  while true do
    io.write(("\27[D"):rep(#buffer - pos), buffer, ("\27[D"):rep(pos))
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
        pos = math.max(0, pos - 1)
      elseif esc_end == "D" then -- left
        pos = math.min(#buffer, pos + 1)
      end
    elseif char == "\8" then -- backspace
      if #buffer > 0 and pos < #buffer then
        io.write(("\27[D"):rep(#buffer - pos))
        buffer = buffer:sub(0, #buffer - pos - 2) .. buffer:sub(-pos)
        io.write(buffer)
        io.write(("\27[D"):rep(pos))
      end
    elseif char == "\127" then -- delete
      if #buffer > 0 and pos > 1 then
        io.write(("\27[D"):rep(#buffer - pos))
        buffer = buffer:sub(0, #buffer - pos - 1) .. buffer:sub(-pos + 1)
        io.write(buffer)
        io.write(("\27[D"):rep(pos))
      end
    elseif char == "\n" then
      io.write("\n")
      return buffer
    end
  end
end

return readline
