-- Epitome init system --

local log = k.io.dmesg
_G._IINFO = {
  name    = "Epitome",
  version = "0.3.0",
}

-- init logger --

log("INIT: src/logger.lua")
local bgpu, bscr
if k.io.gpu then
  local gpu = k.io.gpu
  bgpu, bscr = gpu.address, gpu.getScreen()
  local vts = k.vt.new(component.proxy(gpu.address))
  io.input(vts)
  io.output(vts)
  k.sched.getinfo():stderr(vts)
  vts:write("\27[2J\27[1;1H")
  function log(col, msg)
    if type(col) == "string" then
      msg = col
      col = 32
    end
    return io.write(string.format("\27[%dm* \27[97m%s\n", col + 60, msg))
  end
  k.io.hide()
end

log(34, string.format("Welcome to \27[92m%s \27[97mversion \27[94m%s\27[97m", _IINFO.name, _IINFO.version))

-- some sort of basic FS utility api for things the io lib doesn't have --

log("src/fs.lua")

do
  local vfs = k.vfs

  _G.fs = {}
  io.write("\27[92m*\27[97m Setting up filesystem functions....")

  fs.stat = vfs.stat
  fs.mount = vfs.mount
  fs.mounts = vfs.mounts
  fs.umount = vfs.umount

  function fs.isReadOnly(file)
    checkArg(1, file, "string", "nil")
    local node, path = vfs.resolve(file or "/")
    if not node then
      return nil, path
    end
    return node:isReadOnly(path)
  end

  function fs.makeDirectory(path)
    checkArg(1, path, "string")
    local sdir, dend = path:match("(.+)/(.-)")
    sdir = sdir or "/"
    dend = dend~=""and dend or path
    local node, dir = vfs.resolve(sdir)
    if not node then
      return nil, dir
    end
    local ok, err = node:makeDirectory(dir.."/"..dend)
    if not ok and err then
      return nil, err
    end
    return true
  end

  function fs.remove(file)
    checkArg(1, file, "string")
    local node, path = vfs.resolve(file)
    if not node then
      return nil, path
    end
    return node:remove(path)
  end

  function fs.list(dir)
    checkArg(1, dir, "string")
    local node, path = vfs.resolve(dir)
    if not node then
      return nil, path
    end
    return node:list(path)
  end

  io.write("Done.\n")
end

-- prime the users API with data from /etc/passwd --

log("src/passwd.lua")

do
  log("Loading data from /etc/passwd")
  -- uid:password:username:home:shell
  local format = "(%d+):(%g+):(%g+):(%g+):(%g+)"
  local handle, err = io.open("/etc/passwd", "r")
  if not handle then
    log(31, "failed: " .. err)
    while true do coroutine.yield() end
  end
  local data = handle:read("a")
  handle:close()
  local pwdata = {}
  for line in data:gmatch("[^\n]+") do
    local uid, hash, name, home, shell = line:match(format)
    pwdata[tonumber(uid)] = {
      hash = hash,
      name = name,
      home = home,
      shell = shell
    }
  end
  log("Priming users API")
  k.security.users.prime(pwdata)
end

-- package library --

log("src/package.lua")

do
  io.write("\27[92m*\27[97m Setting up package API...")
  _G.package = {}
  local loading = {}
  local loaded = {
    _G = _G,
    os = os,
    io = io,
    math = math,
    table = table,
    bit32 = bit32,
    string = string,
    package = package,
    process = process,
    computer = computer,
    component = component,
    coroutine = coroutine,
    filesystem = fs
  }
  io.write("Uncluttering _G...")
  _G.fs = nil
  _G.process = nil
  _G.computer = nil
  _G.component = nil
  package.loaded = loaded

  package.path = "/lib/?.lua;/lib/lib?.lua;/lib/?/init.lua"

  function package.searchpath(name, path, sep, rep)
    checkArg(1, name, "string")
    checkArg(2, path, "string")
    checkArg(3, sep, "string", "nil")
    checkArg(4, rep, "string", "nil")
    sep = "%" .. (sep or ".")
    rep = rep or "/"
    local searched = {}
    name = name:gsub(sep, rep)
    for search in path:gmatch("[^;]+") do
      search = search:gsub("%?", name)
      if require("filesystem").stat(search) then
        return search
      end
      searched[#searched + 1] = search
    end
    return nil, searched
  end

  local rs = rawset
  local blacklist = {}
  do
    function _G.rawset(tbl, k, v)
      checkArg(1, tbl, "table")
      if blacklist[tbl] then
        tbl[k] = v
      end
      return rs(tbl, k, v)
    end
  end

  io.write("Library protection...")
  function package.protect(tbl, name)
    local new = setmetatable(tbl, {
      __newindex = function() error((name or "lib") .. " is read-only") end,
      __metatable = {}
    })
    blacklist[new] = true
    return new
  end

  function package.protect(tbl, name)
    local new = setmetatable(tbl, {
      __newindex = function() error((name or "lib") .. " is read-only") end,
      __metatable = {}
    })
    blacklist[new] = true
    return new
  end

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
        dofile(file)
        return tbl[key]
      end
    }
    if lib.internal then
      setmetatable(lib.internal, mt)
    end
    setmetatable(lib, mt)
  end

  io.write("require()...")
  function _G.require(module)
    checkArg(1, module, "string")
    if loaded[module] ~= nil then
      return loaded[module]
    elseif not loading[module] then
      local library, status, step

      step, library, status = "not found", package.searchpath(module, package.path)

      if library then
        step, library, status = "loadfile failed", loadfile(library)
      end

      if library then
        loading[module] = true
        step, library, status = "load failed", pcall(library, module)
        loading[module] = false
      end
 
      assert(library, string.format("module '%s' %s:\n%s", module, step, status))
      loaded[module] = status
      return status
    else
      error("already loading: " .. module .. "\n" .. debug.traceback(), 2)
    end
  end

  io.write("Done.\n")
end

-- kernel-provided APIs, userspace edition --

log("src/klapis.lua")
do
  io.write("\27[92m*\27[97m Adding kernel APIs....")
  local k = k
  _G.k = nil
  package.loaded.sha3 = package.protect(k.sha3)
  package.loaded.sha2 = package.protect(k.sha2)
  package.loaded.ec25519 = package.protect(k.ec25519)
  package.loaded.uuid = k.uuid
  package.loaded.minitel = k.drv.net.minitel
  package.loaded.gert = k.drv.net.gert
  package.loaded.event = k.evt
  package.loaded.vt100 = k.vt
  package.loaded.hostname = k.hostname
  package.loaded.users = package.protect(k.security.users)
  package.loaded.buffer = k.io.buffer
  package.loaded.pipe = {
    create = k.io.pipe
  }
  io.write("Done.\n")
end


-- os API --

do
  local process = require("process")
  local computer = require("computer")

  function os.getenv(k)
    checkArg(1, k, "string", "number")
    return process.info().env[k]
  end

  function os.setenv(k, v)
    checkArg(1, k, "string", "number")
    checkArg(2, v, "string", "number", "nil")
    process.info().env[k] = v
    return true
  end

  function os.exit(c)
    process.signal(process.current(), process.signals.SIGKILL)
    coroutine.yield() -- allow signal processing
  end

  -- XXX: Accuracy depends on the scheduler timeout.
  -- XXX: Shorter intervals (minimum 0.05s) will produce greater accuracy but
  -- XXX: will cause the computer to consume more energy.
  function os.sleep(n)
    checkArg(1, n, "number")
    local max = computer.uptime() + n
    repeat
      coroutine.yield()
    until computer.uptime() >= max
    return true
  end
end


-- run scripts from /etc/epitome/scripts --

do
  local script_path = "/etc/epitome/scripts"
  local fs = require("filesystem")

  local files = fs.list(script_path)
  table.sort(files)
  for i=1, #files, 1 do
    log(34, files[i])
    local ok, err = pcall(dofile, script_path .. "/" .. files[i])  
    if not ok and err then
      io.write("\27[A\27[G")
      log(91, files[i].. ":" .. err)
      while true do coroutine.yield() end
    end
  end
end

-- load getty --

log("src/getty.lua")

log("Starting getty")
local ok, err = loadfile("/sbin/getty.lua")

if not ok then
  log(31, "failed: ".. err)
else
  require("process").spawn(function()local s, r = pcall(ok, bgpu, bscr) if not s and r then log(31, "failed: "..r) end end, "[getty]")
end

require("event").push("init")
while true do coroutine.yield() end

