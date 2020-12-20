-- modified version of Monolith's shell API --

local fs = require("filesystem")
local pipe = require("pipe")
local paths = require("libpath")
local process = require("process")

local shell = {}
local aliases = {}
shell.aliases = aliases

function shell.setAlias(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string")
  shell.aliases[k] = v
end

function shell.error(cmd, err)
  checkArg(1, cmd, "string")
  checkArg(2, err, "string")
  io.stderr:write(string.format("%s: %s\n", cmd, err))
end

shell.builtins = {
  echo = function(...) print(table.concat({...}, " ")) os.exit(0) end,
  set = function(...)
    local set, opts = shell.parse(...)
    if #set == 0 or opts.p then
      for k,v in pairs(process.info().env) do
        print(string.format("%s=%s", k, tostring(v):gsub("\27", "\\27")))
      end
    else
      for k, v in pairs(set) do
        local var, val = v:match("(.-)=(.+)")
        os.setenv(var, val:gsub("\\27", "\27"))
      end
    end
    os.exit(0)
  end,
  alias = function(...)
    local ali, opts = shell.parse(...)
    if #ali == 0 then
      for k, v in pairs(shell.aliases) do
        print(string.format("alias %s='%s'", k, v))
      end
    else
      for k, v in pairs(ali) do
        local a, c = v:match("(.+)=(.+)")
        if not c then
          if shell.aliases[a] then
            print(string.format("alias %s='%s'", a, shell.aliases[a]))
          end
        else
          aliases[a] = c
        end
      end
    end
    os.exit(0)
  end,
  exit = function(n)
    shell.exit()
  end,
  cd = function(dir)
    dir = dir or os.getenv("HOME") or "/"
    local try = paths.resolve(dir)
    try = try:gsub("[/]+", "/")
    local info = fs.stat(try)
    if not info then
      print(dir..": no such file or directory")
      os.exit(1)
    end
    if not info.isDirectory then
      print(dir..": not a directory")
      os.exit(1)
    end
    os.setenv("PWD", try)
    os.exit(0)
  end,
  pwd = function()
    print(os.getenv("PWD"))
    os.exit(0)
  end
}

local function percent(s)
  local r = ""
  local special = "[%[%]%^%*%+%-%$%.%?%%]"
  for c in s:gmatch(".") do
    if s:find(special) then
      r = r .. "%" .. c
    else
      r = r .. c
    end
  end
  return r
end

function shell.expand(str)
  checkArg(1, str, "string")
  -- variable-in-brace expansion and brace expansion will come eventually
  -- variable expansion
  for var in str:gmatch("%$([%w_#@]+)") do
    str = str:gsub("%$" .. var, os.getenv(var) or "")
  end
  -- basic asterisk expansion
  if str:find("%*") then
    local split = shell.split(str)
    for i=2, #split, 1 do
      if split[i]:sub(-1) == "*" then
        local fpath = shell.resolve(split[i]:sub(1,-2))
        if fpath and fs.stat(fpath).isDirectory then
          split[i] = nil
          for file in fs.list(fpath) do
            table.insert(split, i, paths.concat(fpath, file))
          end
        end
      end
    end
    str = table.concat(split, " ")
  end
  return str
end

shell.vars = shell.expand -- backwards compatibility

function shell.parse(...)
  local params = {...}
  local inopt = true
  local cropt = ""
  local args, opts = {}, {}
  for i=1, #params, 1 do
    local p = tostring(params[i])
    if p == "--" then
      inopt = false
    elseif p:sub(1,2) == "--" and inopt then -- "long" option
      local o = p:sub(3)
      local op, vl = o:match([[([%w]+)=([%w%/%,%.%:%s%'%"%=]+)]]) -- I amaze myself with these patterns sometimes
      if op and vl then
        opts[op] = vl or true
      else
        opts[o] = true
      end
    elseif p:sub(1,1) == "-" and #p > 1 and inopt then -- "short" option
      for opt in p:gmatch(".") do
        opts[opt] = true
      end
    else
      args[#args + 1] = p
    end
  end
  return args, opts
end

function shell.resolve(cmd)
  if fs.stat(cmd) then
    return cmd
  end
  if fs.stat(cmd..".lua") then
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
  return nil, cmd..": command not found"
end

-- fancier split that deals with args like `prog print "this is cool" --text="this is also cool"`
function shell.split(str)
  checkArg(1, str, "string")
  local inblock = false
  local ret = {}
  local cur = ""
  local last = ""
  for char in str:gmatch(".") do
    if char == "'" then
      if inblock == false then inblock = true end
    elseif char == " " then
      if inblock then
        cur = cur .. " "
      elseif cur ~= "" then
        ret[#ret + 1] = cur:gsub("\\27", "\27")
        cur = ""
      end
    else
      cur = cur .. char
    end
    last = char
  end
  if #cur > 0 then
    ret[#ret + 1] = cur:gsub("\\27", "\27")
  end
  return ret
end

local function split(str, pat)
  local sep = {}
  for seg in str:gmatch(pat) do
    sep[#sep + 1] = seg
  end
  return sep
end

-- "a | b > c" -> {{cmd = {"a"}, i = <std>, o = <pipe>}, {cmd = {"b"}, i = <pipe>, o = <handle_to_c>}}
local function setup(str)
  str = shell.expand(str)
  local tokens = shell.split(str)
  local stdin = io.input()
  local stdout = io.output()
  local ret = {}
  local cur = {cmd = {}, i = stdin, o = stdout}
  local i = 1
  while i <= #tokens do
    local t = tokens[i]
    if t:match("(.-)=(.+)") and #cur.cmd == 0 then
      local k, v = t:match("(.-)=(.+)")
      cur.env = cur.env or {}
      cur.env[k] = v
    elseif t == "|" then
      if #cur.cmd == 0 or i == #tokens then
        return nil, "syntax error near unexpected token `|`"
      end
      local new = pipe.create()
      cur.o = new
      table.insert(ret, cur)
      cur = {cmd = {}, i = new, o = stdout}
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
    elseif shell.aliases[t] and #cur.cmd == 0 then
      local ps = shell.split(shell.expand(shell.aliases[t]))
      cur.cmd = ps
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
    if shell.builtins[cmd] then
      shEnv = process.info().env
      func = shell.builtins[cmd]
    else
      local path, err = shell.resolve(cmd)
      if not path then
        return nil, err
      end
      local ok, err = loadfile(path)
      if not ok then
        return nil, err
      end
      func = ok
    end
    local f = function()
      io.input(ex.i)
      io.output(ex.o)
      if shEnv then
        local shadow = shEnv
        for k, v in pairs(process.info().env) do
          os.setenv(k, nil)
        end
        setmetatable(process.info().env, {__index = shadow, __newindex = function(t, k, v)
          rawset(shadow, k, v)                                                                     
        end})
      end
      local ok, ret = xpcall(func, debug.traceback, table.unpack(ex.cmd, 2))
      if not ok and ret then
        errno = ret
        if type(ret) == "table" then
          ret = require("serializer").serialize(ret)
        end
        io.stderr:write(ret,"\n")
        for i, _ in pairs(pids) do
          process.signal(pids[i], process.signals.SIGKILL)
        end
      end
      if not io.input().tty then pcall(io.input().close, io.input) end
      if not io.output().tty then pcall(io.output().close, io.output) end
    end
    table.insert(pids, process.spawn(f, table.concat(ex.cmd, " ")))
  end
  require("computer").pushSignal("sh_dummy")
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
end

function shell.execute(...)
  local args = table.pack(...)
  local commands = split(shell.expand(table.concat(args, " ")), "[^%;]+")
  for i=1, #commands, 1 do
    local ok, err = execute(commands[i])
    err = tostring(err)
    if not ok then
      shell.error("sh", err)
    end
  end
  return true
end

os.execute = shell.execute

return shell
