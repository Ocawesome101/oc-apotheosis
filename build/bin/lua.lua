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

if not io.input().tty then
  local dat = io.read("a")
  local ok, err = load(dat, "=stdin", "t", env)
  if not ok then
    io.stderr:write(err, "\n")
    os.exit(1)
  end
  local result = pcall(ok, ...)
  if not result[1] and result[2] then
    io.stderr:write(result[2], "\n")
    os.exit(1)
  else
    for i = 1, #result, 1 do
      io.write(tostring(result[i]), "\n")
    end
  end
  os.exit(0)
end

io.stdout:write(_VERSION, "  Copyright (c) 1994-2020 Lua.org, PUC-Rio\n")

while true do
  io.stdout:write("> ")
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
