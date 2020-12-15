-- sh - basic shell --

local fs = require("filesystem")
local pipe = require("pipe")
local shell = require("shell")
local paths = require("libpath")
local process = require("process")
local computer = require("computer")
local readline = require("readline")

os.setenv("PWD", os.getenv("PWD") or "/")
os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin")
os.setenv("SHLVL", (os.getenv("SHLVL") or "0") + 1)

local pgsub = {
  ["\\w"] = function()
    return (os.getenv("PWD") and os.getenv("PWD"):gsub("^"..os.getenv("HOME").."?", "~")) or "/"
  end,
  ["\\W"] = function() return os.getenv("PWD"):match("%/(.+)$") end,
  ["\\h"] = function() return os.getenv("HOSTNAME") end,
  ["\\s"] = function() return "sh" end,
  ["\\v"] = function() return "0.6.0" end,
  ["\\a"] = function() return "\a" end
}

local exit = false
local oldExit = shell.exit
function shell.exit(n)
  exit = n
  shell.exit = oldExit
end

local function parse_prompt(prompt)
  local ret = prompt
  for pat, rep in pairs(pgsub) do
    ret = ret:gsub(pat, rep() or "")
  end
  return ret
end

--[[local function split_tokens(str)
  local ret = {}
  for token in str:gmatch("[^%s]+") do
    ret[#ret+1] = token
  end
  return ret
end

-- "a | b > c" -> {{cmd = {"a"}, i = <std>, o = <pipe>}, {cmd = {"b"}, i = <pipe>, o = <handle_to_c>}}
local function setup(str)
  local tokens = split_tokens(str)
  local stdin = io.input()
  local stdout = io.output()
  local ret = {}
  local cur = {cmd = {}, i = stdin, o = stdout}
  local i = 1
  while i <= #tokens do
    local t = tokens[i]
    if t == "|" then
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `|`"
      end
      local new = pipe.create()
      cur.o = new
      table.insert(ret, cur)
      cur = {cmd = {}, i = pipe, o = stdout}
    elseif t == ">" or t == ">>" then -- > write, >> append
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `"..t.."`"
      end
      i = i + 1
      local handle, err = io.open(tokens[i], t == ">" and "w" or "a")
      if not handle then
        return nil, err
      end
      cur.o = handle
    elseif t == "<" then
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `<`"
      end
      i = i + 1
      local handle, err = io.open(tokens[i], "r")
      if not handle then
        return nil, err
      end
      cur.i = handle
    else
      cur.cmd[#cur.cmd + 1] = t
    end
    i = i + 1
  end
  if #cur.cmd > 0 then
    table.insert(ret, cur)
  end
  return ret
end

local function resolve(cmd)
  if fs.stat(cmd) then
    return cmd
  end
  if fs.stat(cmd..".lua") then
    print(".lua")
    return cmd..".lua"
  end
  for path in os.getenv("PATH"):gmatch("[^:]+") do
    local check = paths.concat(path, cmd)
    if fs.stat(check) then
      return check
    end
    if fs.stat(check..".lua") then
      return check..".lua"
    end
  end
  sherr(cmd..": command not found")
  return nil
end

-- this should be simple, right? just loadfile() and spawn functions
local function execute(str)
  local exec, err = setup(str)
  if not exec then
    return nil, err
  end
  local pids = {}
  local errno = false
  for i=1, #exec, 1 do
    local func
    local ex = exec[i]
    local cmd = ex.cmd[1]
    local shEnv = false
    if builtins[cmd] then
      shEnv = process.info().env
      func = builtins[cmd]
    else
      local path, err = resolve(cmd)
      if not path then
        sherr(err)
        return nil
      end
      local ok, err = loadfile(path)
      if not ok then
        sherr(err)
        return nil
      end
      func = ok
    end
    local f = function()
      io.input(ex.i)
      io.output(ex.o)
      if shEnv then
        -- shadow tables
        local shadow = shEnv
        for k, v in pairs(process.info().env) do
          os.setenv(k, nil)
        end
        setmetatable(process.info().env, {__index = shadow, __newindex = function(t, k, v)
          rawset(shadow, k, v)
        end})
      end
      local ok, ret = xpcall(func, debug.traceback, table.unpack(ex.cmd, 2))
      if (not ok) and ret then
        errno = ret
        io.stderr:write(ex.cmd[1], ": ", tostring(ret), "\n")
        for i, _ in pairs(pids) do
          process.signal(pids[i], process.signals.SIGKILL)
        end
      end
    end
    table.insert(pids, process.spawn(f, table.concat(ex.cmd, " ")))
  end
  computer.pushSignal("sh_dummy")
  while true do
    local run = false
    for k, pid in pairs(pids) do
      if process.info(pid) then
        run = true
      end
    end
    coroutine.yield()
    if errno or not run then break end
  end
  if errno then
    return nil, errno
  end
  return true
end]]

os.setenv("PS1", os.getenv("PS1") or "\\s-\\v: \\w$ ")

while not exit do
  io.write(parse_prompt(os.getenv("PS1")))
  local input = io.read("l")
  if input then
    shell.execute(input)
  end
end

os.exit(exit)
