-- A more elegant readline from a more civilized age. Less convoluted than 
-- Monolith's - largely because it never dealt directly with signals. --

local actions = {}
actions["A"] = function(p, P, h, H)
  return nil, (h > 0) and (h - 1)
end
actions["B"] = function(p, P, h, H)
  return nil, (h < H) and (h + 1)
end
actions["C"] = function(p, P, h, H)
  return (p > 0) and (p - 1)
end
actions["D"] = function(p, P)
  return (p < P) and (p + 1)
end

local function readline(opts)
  checkArg(1, opts, "table", "nil")
  opts = opts or {}
  local prompt = opts.prompt or ""
  local arrows if opts.arrows == nil then arrows = true end
  local buf = ""
  local history = opts.history or {}
  local hist = #history + 1
  io.write("\27(R\27[l")
  local pos = 0
  while true do
    io.write(("\27[D"):rep(#buf), "\27[K", buf)
    history[hist] = buf
    local c = io.read(1)
    if c == "\27" then
      repeat
        local n = io.read(1)
        c = c .. n
      until not n:match("[%d;]")
      c = c:gsub("\27%[", "")
      if actions[c] then
        local npos, nhist = actions[c](pos, #buf, hist, #history)
        pos = npos or pos
        if nhist and hist ~= nhist then
          buf = history[nhist]
        end
        hist = nhist or hist
      end
    elseif c == "\8" then
      buf = buf:sub(1, #buf - pos - 1) .. buf:sub(#buf - pos + 1)
    elseif c == "\13" then
      io.write("\n")
      break
    else
      buf = buf .. c
    end
  end
  io.write("\27[0m\27(r\27(L")
  return buf
end

return readline
