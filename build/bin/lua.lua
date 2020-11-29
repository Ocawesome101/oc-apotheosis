-- lua REPL --

local function tryreq(l)
  local ok, err = pcall(require, l)
  if not ok and err then
    return nil, err
  end
  return err
end

local env = setmetatable({}, {__index = function(t, k)
  if not _G[k] then
    local ok, err = tryreq(k)
    if not ok then
      print(err)
      return nil
    end
    env[k] = ok
    return ok
  else
    return _G[k]
  end
end})

while true do
  io.write("> ")
  local inp = io.read("l")
  local exec, err = load("print("..inp..")", "=stdin")
  if not exec then
    exec, err = load(inp, "=stdin")
  end
  if not exec then
    print(err)
  else
    print(pcall(exec))
  end
end
