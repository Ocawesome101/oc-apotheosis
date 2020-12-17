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
  local hpos = 1
  local pos = 0
  local actions = setmetatable(opts.actions or {}, {
    __index = {
      -- up arrow
      A = function()
        if hist_pos > 1 then
          history[hist_pos] = buffer
          hist_pos = hist_pos - 1
          buffer = history[hist_pos]
        end
      end,
      -- down arrow
      B = function()
        if hist_pos < #history then
          history[hist_pos] = buffer
          hist_pos = hist_pos + 1
          buffer = history[hist_pos]
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
  local function redraw()
    io.write(string.rep("\27[D", #buffer - (1)), buffer, " \27[D", string.rep("\27[D", pos))
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
      io.write(string.rep("\27[D", #buffer + 1))
      buffer = buffer:sub(1, #buffer - pos - 1) ..
                    buffer:sub(#buffer - pos + 1)
      io.write(buffer .. " \27[D")
    elseif char == "\n" or char == "\13" then
      io.write("\n")
      return buffer
    elseif char:byte() > 31 and char:byte() < 127 then
      buffer = buffer:sub(1, #buffer - pos) ..
                char .. buffer:sub(#buffer - pos + 1)
    end
  end
end

return readline
