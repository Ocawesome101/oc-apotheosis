-- A more elegant readline from a more civilized age. Less convoluted than 
-- Monolith's - largely because it never dealt directly with signals. --

local function gets(n)
  io.write("\27(l\27(R\27[8m")
  local c = io.read(n or 1)
  io.write("\27(L\27(r\27[28m")
  return c
end

local function readline(opts)
  checkArg(1, opts, "table", "nil")
end

return readline
