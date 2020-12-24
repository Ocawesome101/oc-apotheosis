-- A more elegant readline from a more civilized age. Less convoluted than 
-- Monolith's - largely because it never dealt directly with signals. --

-- TODO: move these `io.write's outside of `gets'
local function gets(n)
  io.write("\27(l\27(R\27[8m")
  local c = io.read(n or 1)
  io.write("\27(L\27(r\27[28m")
  return c
end

local function readline(opts)
  checkArg(1, opts, "table", "nil")
  opts = opts or {}
  local buffer = opts.buffer or ""
  local history = opts.history or {}
  history[#history + 1] = ""
  local hpos = #history -- position in history table
  local pos = 0
  local clr = false -- whether we need to clear the text on-screen
  local actions = setmetatable(opts.actions or {}, {
    __index = {
      -- up arrow
      A = function()
        if hpos > 1 then
          clr = true
          history[hpos] = buffer
          pos = 0
          hpos = hpos - 1
          buffer = history[hpos]
        end
      end,
      -- down arrow
      B = function()
        if hpos < #history then
          clr = true
          history[hpos] = buffer
          pos = 0
          hpos = hpos + 1
          buffer = history[hpos]
        end
      end,
      -- right arrow
      C = function()
        if pos > 0 then
          pos = pos - 1
        end
      end,
      -- left arrow
      D = function()
        if pos < #buffer then
          pos = pos + 1
        end
      end,
    }
  })
  local oblen = 0
  local obuf = buffer
  local opos = 0
  local function redraw()
    if obuf ~= buffer then -- buffer has changed
      if buffer:sub(1,-2) == obuf then -- added a char
        io.write(buffer:sub(-1))
      else
        io.write(string.format("\27[%dD", oblen - opos), (clr and "\27[J" or ""), buffer, " \27[D", string.format("\27[%dD", pos))
      end
    else
      if opos > pos then
        io.write(string.format("\27[%dC", opos - pos))
      elseif opos < pos then
        io.write(string.format("\27[%dD", pos - opos))
      end
    end
    oblen = #buffer
    obuf = buffer
    opos = pos
  end
  while true do
    redraw()
    local char = gets(1)
    if char == "\27" then
      local x = gets(1)
      if x == "[" then
        local seq = ""
        local c
        repeat
          c = gets(1)
          seq = seq .. c
        until c:match("[a-zA-Z]")
        seq = seq:sub(1, -2)
        if actions[c] then
          pcall(actions[c])
        end
      end
    elseif char == "\127" then
      buffer = buffer:sub(1, #buffer - pos - 1) ..
                    buffer:sub(#buffer - pos + 1)
    elseif char == "\n" or char == "\13" then
      pos = 0
      redraw()
      io.write("\n")
      if hpos == #history then
        history[hpos] = buffer
      else
        table.insert(history, buffer)
      end
      return buffer
    elseif not char:byte() then
      --os.exit()
    elseif char:byte() > 31 and char:byte() < 127 then
      buffer = buffer:sub(1, #buffer - pos) ..
                char .. buffer:sub(#buffer - pos + 1)
    end
  end
end

return readline
