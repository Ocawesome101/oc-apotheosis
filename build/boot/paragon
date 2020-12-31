--[[
        Paragon kernel.
        Copyright (C) 2020 Ocawesome101
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.
        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

-- parse kernel arguments

local cmdline = table.concat(table.pack(...), " ") -- ex. "init=/bin/sh loglevel=3 quiet"
local kargs = {}

for word in cmdline:gmatch("[^%s]+") do
  local k, v = word:match("(.-)=(.+)")
  k, v = k or word, v or true
  kargs[k] = v
end

_G._KINFO = {
  name    = "Paragon",
  version = "0.8.7-dev",
  built   = "2020/12/30",
  builder = "ocawesome101@nil"
}

-- kernel i/o

local kio = {}

kargs.loglevel = tonumber(kargs.loglevel) or 0

-- kio.errors: table
--   A table of common error messages.
kio.errors = {
  FILE_NOT_FOUND = "no such file or directory",
  FILE_DIRECTORY = "file is a directory",
  IO_ERROR = "input/output error",
  UNSUPPORTED_OPERATION = "unsupported operation",
  PERMISSION_DENIED = "permission denied",
  DEV_FULL = "device is full",
  DEV_RO = "device is read only",
  BROKEN_PIPE = "broken pipe"
}

-- kio.loglevels: table
--   Supported loglevels. Currently DEBUG, INFO, WARNING, ERROR, and PANIC.
kio.loglevels = {
  DEBUG   = 0,
  INFO    = 1,
  WARNING = 2,
  ERROR   = 3,
  PANIC   = 4
}

kio.levels = {
  [0] = "DEBUG",
  "INFO",
  "WARNING",
  "ERROR",
  "PANIC"
}

-- _pipe: table
--   Pipe template. Methods:
local _pipe = {}
-- _pipe:read([n:string or number]): string or nil or nil, string
--   If `n` is `"l"`, read a line. If `n` is `"a"`, read all available bytes. If `n` is a number, read `n` bytes.
function _pipe:read(n)
  checkArg(1, n, "number", "string", "nil")
  if type(n) == "string" then n = n:gsub("%*", "") end
  if self.closed and #self.buf == 0 then return nil end
  if n == "l" then
    while (not self.buf:find("\n")) and self.strict do
      if self.closed then return self.buf end
      coroutine.yield()
    end
    local s = self.buf:find("\n") or #self.buf
    local ret = self.buf:sub(1, s)
    self.buf = self.buf:sub(s + 1)
    return ret
  elseif n == "a" then
    local ret = self.buf
    self.buf = ""
    return ret
  end
  while #self.buf < n and self.strict do
    if self.closed then return self.buf end
    coroutine.yield()
  end
  n = math.min(n, #self.buf)
  local ret = self.buf:sub(1, n)
  self.buf = self.buf:sub(n + 1)
  return ret
end

-- _pipe:write(data:string): boolean or nil, string
--   Write `data` to the pipe stream.
function _pipe:write(...)
  local args = table.pack(...)
  for i=1, args.n, 1 do
    args[i] = tostring(args[i])
  end
  local write = table.concat(args)
  if self.closed then
    return kio.error("BROKEN_PIPE")
  end
  self.buf = self.buf .. write
  return true
end

-- _pipe:size(): number
--   Return the current size of the pipe stream buffer.
function _pipe:size()
  return #self.buf
end

-- _pipe:close()
--   Close the pipe.
function _pipe:close()
  self.closed = true
end

-- _pipe:lines(fmt:string): function
--   Iterate over all lines in the pipe data.
function _pipe:lines(fmt)
  return function()
    return self:read(fmt or "l")
  end
end

-- kio.pipe(): table
--   Create a pipe.
function kio.pipe()
  return setmetatable({buf = "", strict = true}, {__index = _pipe}), "rw"
end

kio.__dmesg = {}

local console
do
  -- calling console() writes a line. that's it.
  local ac = kargs.console or ""
  local gpu, screen = ac:match("(.+),(.+)")
  gpu = (gpu and component.type(gpu) == "gpu" and gpu) or component.list("gpu")()
  screen = (screen and component.type(screen) == "screen" and screen) or component.list("screen")()
  gpu = component.proxy(gpu)
  gpu.bind(screen)
  local y = 0
  local w, h = assert(gpu.maxResolution())
  gpu.setResolution(w, h)
  gpu.fill(1, 1, w, h, " ")
  gpu.setForeground(0xaaaaaa)
  gpu.setBackground(0x000000)
  local _console = function(msg)
    if y == h then
      gpu.copy(1, 1, w, h, 0, -1)
      gpu.fill(1, h, w, 1, " ")
    else
      y = y + 1
    end
    gpu.set(1, y, msg)
  end

  function kio.__dmesg:write(msg)
  end

  kio.gpu = gpu
  kio.console = function(...)
    kio.__console(...)
    return kio.__dmesg:write(...)
  end
  kio.__console = _console
end

-- kio.error(err:string): nil, string
--   Return an error based on one of the errors in `kio.errors`.
function kio.error(err)
  return nil, kio.errors[err] or "generic error"
end

-- kio.dmesg(level:number, msg:string): boolean
--   Log `msg` to the console with loglevel `level`.
function kio.dmesg(level, msg)
  if not msg then msg = level level = nil end
  level = level or kio.loglevels.INFO
  for line in msg:gmatch("[^\n]+") do
    local mesg = string.format("[%5.05f] [%s] %s", computer.uptime(), kio.levels[level], line)
    if level >= kargs.loglevel then
      kio.console(mesg)
    else
      kio.__dmesg:write(mesg)
    end
--    table.insert(dmesg, mesg)
  end
  return true
end

function kio.redir(f)
  checkArg(1, f, "function")
  kio.console = f
end

do
  local panic = computer.pullSignal
  -- kio.panic(msg:string)
  --   Send the system into a panic state. After this function is called, the system MUST be restarted to resume normal operation.
  function kio.panic(msg)
    local traceback = msg
    local i = 1
    while true do
      local info = debug.getinfo(i)
      if not info then break end
      traceback = traceback .. string.format("\n  %s:%s: in %s'%s':", info.source:gsub("=*",""), info.currentline or "C", (info.namewhat ~= "" and info.namewhat .. " ") or "", info.name or "?")
      i = i + 1
    end
    traceback = traceback:gsub("\t", "  ")
    for line in traceback:gmatch("[^\n]+") do
      kio.dmesg(kio.loglevels.PANIC, line)
    end
    kio.dmesg(kio.loglevels.PANIC, "Kernel panic!")
    computer.beep(440, 1)
    while true do
      panic()
    end
  end
end

kio.dmesg(kio.loglevels.INFO, string.format("Starting %s version %s - built %s by %s", _KINFO.name, _KINFO.version, _KINFO.built, _KINFO.builder))

-- simple buffer implementation --

kio.dmesg(kio.loglevels.INFO, "ksrc/buffer.lua")

do

local buffer = {}

function buffer.new(stream, mode)
  local new = {
    tty = false,
    mode = {},
    rbuf = "",
    wbuf = "",
    stream = stream,
    closed = false,
    bufsize = math.max(512, math.min(8 * 1024, computer.freeMemory() / 8))
  }
  mode = mode or "r"
  for c in mode:gmatch(".") do
    new.mode[c] = true
  end
  return setmetatable(new, {
    __index = buffer,
    __name = "FILE*",
    __metatable = {}
  })
end

-- this might be inefficient but it's still much better than raw file handles!
function buffer:read_byte()
  if self.bufsize == 0 then
    return self.stream:read(1)
  end
  if #self.rbuf <= 0 then
    self.rbuf = self.stream:read(self.bufsize) or ""
  end
  local read = self.rbuf:sub(1,1)
  self.rbuf = self.rbuf:sub(2)
  if read == "" or not read then
    return nil
  end
  return read
end

function buffer:write_byte(byte)
  checkArg(1, byte, "string")
  byte = byte:sub(1,1)
  if #self.wbuf >= self.bufsize then
    self.stream:write(self.wbuf)
    self.wbuf = ""
  end
  self.wbuf = self.wbuf .. byte
end

function buffer:read(fmt)
  checkArg(1, fmt, "string", "number", "nil")
  fmt = fmt or "l"
  if type(fmt) == "number" then
    local ret = ""
    if self.bufsize == 0 then
      return self.stream:read(fmt)
    else
      for i=1, fmt, 1 do
        ret = ret .. (self:read_byte() or "")
      end
    end
    if ret == "" then
      return nil
    end
    return ret
  else
    local ret = ""
    local read = 0
    if fmt == "a" then
      repeat
        local byte = self:read_byte()
        ret = ret .. (byte or "")
        if byte then read = read + 1 end
      until not byte
    elseif fmt == "l" then
      repeat
        local byte = self:read_byte()
        if byte ~= "\n" then
          ret = ret .. (byte or "")
        end
        if byte then read = read + 1 end
      until byte == "\n" or not byte
    elseif fmt == "L" then
      repeat
        local byte = self:read_byte()
        ret = ret .. (byte or "")
        if byte then read = read + 1 end
      until byte == "\n" or not byte
    else
      error("bad argument to 'read' (invalid format)")
    end
    if read > 0 then
      return ret
    end
    return nil
  end
end

function buffer:lines(fmt)
  return function()
    return self:read(fmt)
  end
end

function buffer:write(...)
  local args = table.pack(...)
  for i=1, args.n, 1 do
    args[i] = tostring(args[i])
  end
  local write = table.concat(args)
  if self.bufsize == 0 then
    self.stream:write(write)
  else
    for byte in write:gmatch(".") do
      self:write_byte(byte)
    end
  end
  return self
end

function buffer:seek(whence, offset)
  checkArg(1, whence, "string", "nil")
  checkArg(2, offset, "number", "nil")
  if whence then
    self:flush()
    return self.stream:seek(whence, offset)
  end
  if self.mode.r then
    return self.stream:seek() + #self.rbuf
  elseif self.mode.w or self.mode.a then
    return self.stream:seek() + #self.wbuf
  end
  return 0, self
end

function buffer:flush()
  if self.mode.w then
    self.stream:write(self.wbuf)
    self.wbuf = ""
  end
  return true, self
end

function buffer:setvbuf(mode)
  if mode == "no" then
    self.bufsize = 0
  else
    self.bufsize = 512
  end
end

function buffer:size()
  if self.stream.size then
    return self.stream:size()
  end
  return 0
end

function buffer:close()
  self:flush()
  self.stream:close()
  self.closed = true
  return true
end

kio.buffer = buffer

end



-- kernel drivers

kio.dmesg(kio.loglevels.INFO, "ksrc/kdrv.lua")

local kdrv = {}

kdrv.fs = {}
kdrv.net = {}


-- vfs

kio.dmesg(kio.loglevels.INFO, "ksrc/vfs.lua")

-- TODO: mount system is currently pretty basic.
local vfs = {}
do
  local mnt = {}

  --[[ expected procedure:
     1. use vfs.resolve to resolve a filepath to a proxy and a path on the proxy
     2. operate on the proxy
     the vfs api does not provide all available filesystem functions; see
     'src/fsapi.lua' for an api that does.
     note that while running a kernel without the fsapi module, you'll need to
     assign it as an initrd module for most of the system to function.  As such,
     fsapi is included by default. ]]

  local function segments(path)
    local segs = {}
    for s in path:gmatch("[^/]+") do
      if s == ".." then
        if #segs > 0 then
          table.remove(segs, #segs)
        end
      else
        table.insert(segs, s)
      end
    end
    return segs
  end

  -- XXX: vfs.resolve does NOT check if a file exists.
  -- vfs.resolve(path:string): table, string or nil, string
  --   Tries to resolve a file path to a filesystem proxy.
  function vfs.resolve(path)
    checkArg(1, path, "string")
    kio.dmesg(kio.loglevels.DEBUG, "vfs: resolve "..path)
    if not mnt["/"] then
      return nil, "root filesystem not mounted"
    end
    if path == "/" then
      return mnt["/"], ""
    end
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    if mnt[path] then
      return mnt[path], "/"
    end
    local segs = segments(path)
    for i=#segs, 1, -1 do
      local cur = "/" .. table.concat(segs, "/", i + 1, #segs)
      local try = "/" .. table.concat(segs, "/", 1, i)
      if mnt[try] then
        return mnt[try], cur
      end
    end
    if path:sub(1,1) == "/" then
      return vfs.resolve("/"), path
    end
    kio.dmesg(kio.loglevels.DEBUG, "no such file: ".. path)
    return kio.error("FILE_NOT_FOUND")
  end

  -- vfs.mount(prx:table, path:string): boolean or nil, string
  --   Tries to mount the provided proxy at the provided file path.
  function vfs.mount(prx, path, fstype)
    checkArg(1, prx, "table", "string")
    checkArg(2, path, "string")
    checkArg(3, fstype, "string", "nil")
    if not k.security.acl.hasPermission(k.security.users.user(), "MOUNT_FS") then
      return nil, "permission denied"
    end
    local proxy = prx
    if type(prx) == "string" then
      proxy = component.proxy(prx)
    end
    if proxy.type == "drive" and not fstype then
      return nil, "missing fstype"
    end
    fstype = fstype or "managed"
    if not prx.fstype then 
      prx = k.drv.fs[fstype].create(proxy)
    end
    path = "/" .. table.concat(segments(path), "/")
    if mnt[path] then
      return nil, "there is already a filesystem mounted there"
    end
    if path ~= "/" then
      local node, spath = vfs.resolve(path)
      node:makeDirectory(spath)
    end
    mnt[path] = prx
    return true
  end
  
  -- vfs.mounts(): table
  --   Return a table with keys addresses and values paths of all mounted filesystems.
  function vfs.mounts()
    local ret = {}
    for k, v in pairs(mnt) do
      ret[v.address] = {
        path = k,
        type = v.fstype
      }
    end
    return ret
  end

  -- vfs.umount(path:string): boolean or nil, string
  --   Tries to unmount the proxy at the provided path.
  function vfs.umount(path)
    checkArg(1, path, "string")
    if not k.security.acl.hasPermission(k.security.users.user(), "MOUNT_FS") then
      return nil, "permission denied"
    end
    path = "/" .. table.concat(segments(path), "/")
    if not mnt[path] then
      return nil, "no such device"
    end
    mnt[path] = nil
    return true
  end

  -- vfs.stat(file:string): table or nil, string
  --   Tries to get information about a file or directory.
  function vfs.stat(file)
    checkArg(1, file, "string")
    local node, path = vfs.resolve(file)
    if not node then
      return nil, path
    end
    return node:stat(path)
  end
end

-- utils

kio.dmesg(kio.loglevels.INFO, "ksrc/util.lua")
do
  -- from https://lua-users.org/wiki/CopyTable because apparently my implementation is incompetent
  local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      if copies[orig] then
        copy = copies[orig]
      else
        copy = {}
        copies[orig] = copy
        for orig_key, orig_value in next, orig, nil do
          copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
        end
        setmetatable(copy, deepcopy(getmetatable(orig), copies))
      end
    else -- number, string, boolean, etc
      copy = orig
    end
    return copy
  end
  function table.copy(t)
    checkArg(1, t, "table")
    return deepcopy(t)
  end

  local pullSignal = computer.pullSignal
  function collectgarbage()
    local miss = {}
    for i=1, 10, 1 do
      local sig = table.pack(pullSignal(0))
      if sig.n > 0 then
        table.insert(miss, sig)
      end
    end
    for i=1, #miss, 1 do
      computer.pushSignal(table.unpack(miss[i]))
    end
  end

  function string.hex(str)
    checkArg(1, str, "string")
    local ret = ""
    for c in str:gmatch(".") do
      ret = string.format("%s%02x", ret, c:byte())
    end
    return ret
  end
end

-- kernel api

kio.dmesg(kio.loglevels.INFO, "ksrc/kapi.lua")
_G.k = {}
k.args    = kargs
k.io      = kio
k.info    = _KINFO
k.drv     = kdrv or {}

-- various hooks called on different actions --

do
  local hooks = {}
  hooks.target = {}
  function hooks.add(k, v)
    checkArg(1, k, "string")
    checkArg(2, v, "function")
    hooks[k] = hooks[k] or setmetatable({}, {__call = function(self, ...) for k, v in ipairs(self) do v(...) end end})
    table.insert(hooks[k], v)
    return true
  end
  function hooks.call(k, ...)
    checkArg(1, k, "string")
    if hooks[k] then
      for k, v in ipairs(hooks[k]) do
        pcall(v, ...)
      end
    end
  end
  k.hooks = hooks
end

do
  -- some default hooks
  local function sbld()
    function k.sb.load(x, name, mode, env)
      return load(x, name, mode, env or k.sb)
    end
    k.sb.k.vfs = table.copy(vfs)
    k.sb.k.io.gpu = kio.gpu -- otherwise metatable weirdness happens
    k.sb.k.sb = nil -- just in case
  end
  k.hooks.add("sandbox", sbld)
end

-- security :^) --

kio.dmesg("ksrc/security.lua")

k.security = {}

-- users --

kio.dmesg("ksrc/security/users.lua")

do
  -- NOTE: processes cannot, and I repeat, CANNOT authenticate themselves as
  -- NOTE: a user other than their current one. This simplifies certain things.
  local users = {}
  local upasswd = {}

  -- this gets overridden later but we need this one
  local old_rawset = rawset
  
  -- users.prime(passwd:table): boolean or nil, string
  --   Prime the 'users' API with data from a passwd file, usually /etc/passwd.
  function users.prime(passwd)
    checkArg(1, passwd, "table")
    if not passwd[0] and passwd[0].hash and passwd[0].name and passwd[0].home
                                                                            then
      return nil, "no root password definition"
    end
    users.prime = nil
    old_rawset(k.sb.package.loaded.security.users, "prime", nil)
    upasswd = passwd
    k.security.acl.passwd = passwd
    return true
  end

  local msgs = {
    "no such user",
    "invalid credentials",
    "permission denied"
  }

  -- users.checkAuth(uid:number, passwd:string): boolean or nil, string
  --   Check if the provided credentials are valid.
  function users.checkAuth(uid, passwd, _)
    checkArg(1, uid, "number")
    checkArg(2, passwd, "string")
    if not upasswd[uid] then
      return nil, _ and 1 or msgs[1]
    end
    if string.hex(k.sha3.sha256(passwd)) == upasswd[uid].hash then
      return true
    else
      return nil, _ and 2 or msgs[2]
    end
  end

  -- users.spawnAs(uid:number, passwd:string, func:function, name:string): boolean or nil, string
  --   Tries to spawn a process from the provided function as user `uid`.
  function users.spawnAs(uid, passwd, func, name)
    checkArg(1, uid, "number")
    checkArg(2, passwd, "string")
    checkArg(3, func, "function")
    checkArg(4, name, "string")
    local ok, code = users.checkAuth(uid, passwd, true)
    if not ok then
      return nil, msgs[code <= 1 and code or 3]
    end
    local proc = k.sched.spawn(function()
      local env = k.sched.getinfo().env
      env.HOME = upasswd[uid].home
      env.SHELL = upasswd[uid].shell
      env.UID = tostring(uid)
      env.USER = upasswd[uid].name
      func()
    end, name, nil, uid)
    repeat
      coroutine.yield()
    until not k.sched.getinfo(proc.pid)
    return true
  end

  -- users.user(): number
  --   Returns the current process's owner.
  function users.user()
    return (k.sched.getinfo() or {}).owner or 0
  end

  -- users.idByName(name:string): number or nil, string
  --   Returns the UID associated with the provided name.
  function users.idByName(name)
    checkArg(1, name, "string")
    for uid, dat in pairs(upasswd) do
      if dat.name == name then
        return uid
      end
    end
    return nil, msgs[1]
  end

  -- users.userByID(uid:number): string or nil, string
  --   Returns the username associated with the provided UID.
  function users.userByID(uid)
    checkArg(1, uid, "number")
    if uid == -1 then
      return "all"
    end
    if not upasswd[uid] then
      return nil, msgs[1]
    end
    return upasswd[uid].name
  end

  function users.groupByID()
    return "none"
  end

  k.security.users = users
end

-- add sandbox hooks
do
  k.hooks.add("sandbox", function()
    -- raw component restrictions
    k.sb.component = setmetatable({}, {__index = function(_,m)
      if k.security.users.user() ~= 0 then
        error(string.format("component.%s: permission denied", m))
      end
      if m == "proxy" then
        return function(...)
          local prx = assert(component.proxy(...))
          local new = setmetatable({}, {__index = function(_, k)
            if type(prx[k]) == "function" then
              return function(...)
                local result = table.pack(prx[k](...))
                -- prevent huge amounts of component calls from freezing the
                -- system entirely
                coroutine.yield(0)
                return table.unpack(result)
              end
            else
            end
          end})
        end
      end
      return component[m]
    end, __metatable = {}})
  end)
  
  k.hooks.add("sandbox", function()
    -- `computer' API restrictions
    k.sb.computer.getDeviceInfo = nil
    k.sb.computer.shutdown = nil
    setmetatable(k.sb.computer, {
      __index = function(_, m)
        if computer[m] then
          if k.security.users.user() ~= 0 then
            error(string.format("computer.%s: permission denied", m))
          end
          return computer[m]
        end
      end,
      __metatable = {}
    })
  end)
end

-- access control lists....ish. --
-- these allow more granular control over what permissions certain users have

do
  local acl = {}
  acl.upasswd = {}

  local perms = {
    KILL_PROCESS = 1,
    FILE_ACCESS = 2,
    MOUNT_FS = 4,
    KILL_NOT_OWNED = 8,
    WRITE_NOT_OWNED = 16,
    RESTRICTED_API = 32,
    NO_SUDO_PASSWORD = 512
  }
  function acl.hasPermission(uid, pms)
    checkArg(1, uid, "number", "nil")
    checkArg(2, pms, "number", "string")
    uid = uid or k.security.users.user()
    pms = perms[pms] or pms
    if type(pms) == "string" then
      return nil, "no such permission: "..pms
    end
    local udat = acl.upasswd[uid] or (uid==0 and {permissions=1023})
    return uid == 0 or not (udat.permissions & pms) == 0
  end

  -- TODO: implement ability to give permissions to specific processes
  -- regardless of their owner

  k.security.acl = acl
end

-- sandbox hooks for wrapping kernel-level APIs more securely

do
  -- wrap rawset to respect blacklisted tables
  local old_rawset = rawset
  local blacklisted = {}
  function _G.rawset(tbl, key, val)
    checkArg(1, tbl, "table")
    if blacklisted[tbl] then
      -- trigger __newindex, throw error
      tbl[key] = val
    end
    old_rawset(tbl, key, val)
  end

  local function protect(tbl, name)
    local protected = setmetatable({}, {
      __index = tbl,
      __newindex = function()
        error((name or "lib") .. " is protected")
      end,
      __metatable = {}
    })
    blacklisted[protected] = true
    return protected
  end
  k.security.protect = protect

  -- snadbox hook for protecting certain sensitive APIs
  k.hooks.add("sandbox", function()
    k.sb.sha3 = protect(k.sb.k.sha3)
    k.sb.sha2 = protect(k.sb.k.sha2)
    k.sb.ec25519 = protect(k.sb.k.ec25519)
    k.sb.security = protect(k.sb.k.security)
    old_rawset(k.sb.security, "acl", protect(k.sb.k.security.acl))
    old_rawset(k.sb.security, "users", protect(k.sb.k.security.users))
  end)
end


-- scheduler part 1: process template

kio.dmesg(kio.loglevels.INFO, "ksrc/process.lua")

local process = {}

do
  -- process.signals: table
  --   A table of signals. Currently available: SIGHUP, SIGINT, SIGKILL, SIGTERM, SIGCONT, SIGSTOP. The table is reverse-indexed so that `process.signals[process.signals.SIGHUP] = "SIGHUP"`.
  local signals = {
    SIGHUP  = 1,
    SIGINT  = 2,
    SIGKILL = 9,
    SIGTERM = 15,
    SIGCONT = 18,
    SIGSTOP = 19,
    [1]     = "SIGHUP",
    [2]     = "SIGINT",
    [9]     = "SIGKILL",
    [15]    = "SIGTERM",
    [18]    = "SIGCONT",
    [19]    = "SIGSTOP"
  }
  process.signals = signals
  
  local function default(self, sig)
    self.dead = true
  end

  local function try_get(tab, field)
    if tab[field] then
      local ret = tab[field]
      tab[field] = nil
      return ret
    end
    return {}
  end

  -- process.new(args:table): table
  --   Create a new process. `args` is used for internal undocumented purposes.
  function process.new(args)
    checkArg(1, args, "table")
    local new = {
      pid = 1,                            -- process ID
      name = "unknown",                   -- process name
      env = {},                           -- environment variables
      threads = {},                       -- threads
      started = computer.uptime(),        -- time the process was started
      runtime = 0,                        -- time the process has spent running
      deadline = 0,                       -- signal wait deadline
      owner = k.security.users.user(),    -- process owner
      tty = args.stdin and args.stdin.tty
      or false,                           -- false if not associated with a tty,
                                          -- else a string in the format "ttyN"
                                          -- where N is the tty id
      msgs = {},                          -- internal thread message queue
      sighandlers = {},                   -- signal handlers
      handles = {},                       -- all open handles
      priority = math.huge,               -- lower values are resumed first
      io = {
        stdin = try_get(args, "stdin"),   -- standard input
        stdout = try_get(args, "stdout"), -- standard output
        stderr = try_get(args, "stderr")  -- standard error
      }
    }

    new.io.input = new.io.stdin
    new.io.output = new.io.stdout
    new.env.USER = new.env.USER or "root"
    new.env.UID = new.env.UID or 0
  
    for k,v in pairs(args) do new[k] = v end
    return setmetatable(new, {__index = process})
  end
  
  -- process:resume(...): boolean
  --   Resume all threads in the process.
  function process:resume(...)
    local resumed = computer.uptime()
    for i=1, #self.threads, 1 do
      local thd = self.threads[i]
      local ok, ec = coroutine.resume(thd.coro, ...)
      if (not ok) or coroutine.status(thd.coro) == "dead" then
        kio.dmesg(kio.loglevels.DEBUG, "process " .. self.pid .. ": thread died: " .. i)
        self.threads[i] = nil
        if ec then kio.dmesg(tostring(ec)) end
        if self.pid == 1 then -- we are init, PANIC!!!
          kio.panic(tostring(ec))
        end
        computer.pushSignal("thread_died", self.pid, (type(ec) == "string" and 1 or ec), type(ec) == "string" and ec)
      end
      -- TODO: this may result in incorrect yield timeouts with multiple threads
      if type(ec) == "number" then
        local nd = ec + computer.uptime()
        if nd < self.deadline then
          self.deadline = nd
        end
      else
        if ec then kio.dmesg(kio.loglevels.DEBUG, tostring(ec)) end
        self.deadline = math.huge
      end
    end
    if #self.threads == 0 then
      self.dead = true
    end
    self.runtime = self.runtime + (computer.uptime() - resumed)
    return true
  end

  -- process:addThread(func:function[, name:string])
  --   Add a thread to the process.
  function process:addThread(func, name)
    checkArg(1, func, "function")
    checkArg(2, name, "string", "nil")
    name = name or "thread" .. #self.threads + 1
    self.threads[#self.threads + 1] = {
      name = name,
      coro = coroutine.create(function()return assert(xpcall(func, debug.traceback)) end)
    }
    return true
  end
  
  -- XXX this function is very dangerous. it SHOULD NOT, and I repeat, SHOULD NOT
  -- XXX find its way into user code. EVER.
  -- process:info(): table
  --   See `k.sched.getinfo`.
  function process:info()
    return {
      io = self.io,
      pid = self.pid,
      env = self.env,
      name = self.name,
      owner = self.owner,
      started = self.started,
      runtime = self.runtime,
      threads = self.threads,
      deadline = self.deadline,
      sighandlers = self.sighandlers,
      stdin = process.stdin, -- convenience
      stdout = process.stdout,
      stderr = process.stderr,
      input = process.input,
      output = process.output
    }
  end

  -- process:handle(sig:number): boolean or nil, string
  --   Handles signal `sig` according to an internal signal handler. Unless the process's PID is 1, SIGKILL will always kill the process.
  function process:handle(sig)
    if sig == signals.SIGKILL and self.pid ~= 1 then -- init can override SIGKILL behavior
      self.dead = true
      return true
    end
    if sig == signals.SIGSTOP or sig == signals.SIGCONT then -- these are non-blockable
      self.stopped = sig == signals.SIGSTOP
      return true
    end
    local handler = self.sighandlers[sig] or default
    local result = table.pack(pcall(handler, self, sig))
    if not result[1] then
      return nil, result[2]
    end
    return table.unpack(result, 2)
  end

  -- process:kill()
  --   See `process:handle`.
  process.kill = process.handle

  -- process:input([file:table]): table
  --   If `file` is provided and is valid, set the process's io.input to `file`. Always returns the current standard input.
  function process:input(file)
    checkArg(1, file, "table", "nil")
    if file and file.read and file.write and file.close then
      if not self.io.input.tty then pcall(self.io.input.close, self.io.input) end
      self.io.input = file
    end
    return self.io.input
  end

  -- process:output([file:table]): table
  --   Like `process:stdin()`, but operates on the output.
  function process:output(file)
    checkArg(1, file, "table", "nil")
    if file and file.read and file.write and file.close then
      if not self.io.output.tty then pcall(self.io.output.close, self.io.output) end
      self.io.output = file
    end
    return self.io.output
  end

  -- process:stderr([file:table]): table
  --   Like `process:stdin()`, but operates on the standard error.
  function process:stderr(file)
    checkArg(1, file, "table", "nil")
    if file and file.read and file.write and file.close then
      if not io.stderr.tty then pcall(self.io.stderr.close, self.io.stderr) end
      self.io.stderr = file
    end
    return self.io.stderr
  end

  function process:stdin()
    return self.io.stdin
  end

  function process:stdout()
    return self.io.stdout
  end
end

-- a scheduler! --

kio.dmesg(kio.loglevels.INFO, "ksrc/scheduler.lua")

do
  local procs = {}
  local s = {}
  local last, current = 0, 0

  -- k.sched.spawn(func:function, name:string[, priority:number]): table
  --   Spawns a process, adding `func` to its threads.
  function s.spawn(func, name, priority, iua)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    checkArg(3, priority, "number", "nil")
    last = last + 1
    local p = procs[current]
    local new = process.new {
      pid = last,
      name = name,
      parent = current,
      priority = priority or math.huge,
      env = p and table.copy(p.env) or {},
      stdin = p and io.input() or {},
      stdout = p and io.output() or {},
      stderr = p and io.stderr or {},
      owner = iua,
      sighandlers = {}
    }
    new.env.UID = new.owner
    new.env.USER = k.security.users.userByID(new.owner)
    new:addThread(func)
    procs[new.pid] = new
    return new -- the userspace function will just return the PID
  end

  -- k.sched.getinfo(pid:number): table or nil, string
  --   Returns information about a process.
  -- XXX: This function is dangerous and should not appear in userspace under
  -- XXX: any circumstances!
  function s.getinfo(pid)
    checkArg(1, pid, "number", "nil")
    pid = pid or current
    if not procs[pid] then
      return nil, "no such process"
    end
    return procs[pid]:info()
  end

  -- k.sched.signal(pid:number, sig:number): boolean or nil, string
  --   Attempts to kill process `pid` with signal `sig`.
  function s.signal(pid, sig)
    checkArg(1, pid, "number")
    checkArg(2, sig, "number")
    if not procs[pid] then
      return nil, "no such process"
    end
    local allow = k.security.acl.hasPermission(nil, "KILL_PROCESS")
    local proc = procs[pid]
    if allow and (proc.owner == s.getinfo().owner 
                  or s.getinfo().owner == 0) then
      proc:handle(sig)
    else
      return kio.error("PERMISSION_DENIED")
    end
  end

  function s.newthread(func, name)
    checkArg(1, func, "function")
    checkArg(2, name, "string", "nil")
    local proc = procs[current]
    if not proc then
      return nil, "error adding thread"
    end
    return proc:addThread(func, name)
  end

  s.kill = s.signal

  local function getMinTimeout()
    local max = math.huge
    local upt = computer.uptime()
    for pid, proc in pairs(procs) do
      if not proc.stopped then -- don't use timeouts from stopped processes
        if proc.deadline < 0 then
          max = 0
          break
        end
        if upt - proc.deadline < max then
          max = upt - proc.deadline
        end
        if max <= 0 then
          max = 0
          break
        end
      end
    end
    return max
  end

  function s.loop()
    s.loop = nil
    kio.dmesg(kio.loglevels.DEBUG, "starting scheduler loop")
    while #procs > 0 do
      local timeout = getMinTimeout()
      local sig = table.pack(computer.pullSignal(timeout))
      local run = {}
      for pid, proc in pairs(procs) do
        if not proc.stopped then
          run[#run + 1] = proc
        end
      end
      table.sort(run, function(a, b)
        return a.priority < b.priority
      end)
      for i=1, #run, 1 do
        local proc = run[i]
        current = proc.pid
        proc:resume(table.unpack(sig))
        if proc.dead then
          kio.dmesg(kio.loglevels.DEBUG, "process died: " .. proc.pid)
          computer.pushSignal("process_died", proc.pid, proc.name)
          for k,v in pairs(proc.handles) do
            pcall(v.close, v)
          end
          procs[proc.pid] = nil
        end
      end
      if computer.freeMemory() < 1024 then
        kio.dmesg(kio.loglevels.DEBUG, "low memory - collecting garbage")
        collectgarbage()
      end
    end
    kio.panic("All processes died!")
  end
  k.sched = s

  k.hooks.add("shutdown", function()
    kio.dmesg("sending SIGTERM to all processes")
    for pid, proc in pairs(procs) do
      proc:handle(process.signals.SIGTERM)
    end
    kio.dmesg("waiting 1s for processes to stop")
    local max = computer.uptime() + 1
    repeat
      computer.pullSignal(max - computer.uptime())
    until computer.uptime() >= max
    kio.dmesg("sending SIGKILL to all processes")
    for pid, proc in pairs(procs) do
      proc:handle(process.signals.SIGKILL)
    end
  end)

  do
    local prev_stopped, lID, lID2, slept
    k.hooks.add("sleep", function()
      prev_stopped = {}
      kio.dmesg("registering wakeup listeners")
      lID = k.evt.register("key_down", function()
        k.hooks.wakeup()
      end)
      lID2 = k.evt.register("touch", function()
        k.hooks.wakeup()
      end)
      kio.dmesg("suspending all processes")
      for pid, proc in pairs(procs) do
        if proc.stopped then
          prev_stopped[pid] = true
        else
          proc:handle(process.signals.SIGSTOP)
        end
      end
      kio.dmesg("turning off screens")
      for addr in component.list("screen", true) do
        component.invoke(addr, "turnOff")
      end
    end)

    k.hooks.add("wakeup", function()
      k.evt.unregister(lID)
      k.evt.unregister(lID2)
      for addr in component.list("screen", true) do
        component.invoke(addr, "turnOn")
      end
      for pid, proc in pairs(procs) do
        if not prev_stopped[pid] then
          proc:handle(process.signals.SIGCONT)
        end
      end
    end)
  end

  k.hooks.add("sandbox", function()
    -- userspace process api
    local signals = process.signals
    local process = {}
    k.sb.process = process
    k.sb.process.signals = signals
    function k.sb.process.spawn(a,b,c)
      return k.sched.spawn(a,b,c).pid
    end
    
    -- userspace may want a list of all PIDs
    function k.sb.process.list()
      local ret = {}
      for pid, proc in pairs(procs) do
        ret[#ret + 1] = pid
      end
      return ret
    end

    -- we can safely return only a very limited subset of process info
    function k.sb.process.info(pid)
      checkArg(1, pid, "number", "nil")
      local info, err = k.sched.getinfo(pid)
      if not info then
        return nil, err
      end
      local ret = {
        owner = info.owner,
        started = info.started,
        runtime = info.runtime,
        name = info.name
      }
      if not pid then -- we can give a process more info about itself
        ret.env = info.env
        ret.io = info.io
      end
      return ret
    end

    function k.sb.process.current()
      return current
    end

    function k.sb.process.signal(pid, sig)
      return k.sched.signal(pid, sig)
    end

    function k.sb.process.thread(func, name)
      return k.sched.newthread(func, name)
    end

    function k.sb.process.sethandler(sig, func)
      checkArg(1, sig, "number")
      checkArg(2, func, "function")
      k.sched.getinfo().sighandlers[sig] = func
      return true
    end

    -- some of the userspace `os' api, specifically the process-centric stuff
    function k.sb.os.getenv(k)
      checkArg(1, k, "string", "number")
      return process.info().env[k]
    end

    function k.sb.os.setenv(k, v)
      checkArg(1, k, "string", "number")
      checkArg(2, v, "string", "number", "nil")
      process.info().env[k] = v
      return true
    end

    function k.sb.os.exit()
      process.signal(process.current(), process.signals.SIGKILL)
      coroutine.yield()
    end

    function k.sb.os.sleep(n)
      checkArg(1, n, "number")
      local max = computer.uptime() + n
      repeat
        coroutine.yield(max - computer.uptime())
      until computer.uptime() >= max
      return true
    end
  end)
end

-- hostname --

do
  local h = {}
  function h.set(hn)
    checkArg(1, hn, "string")
    if k.security.users.user() ~= 0 then
      return kio.error("PERMISSION_DENIED")
    end
    k.hooks.hnset(hn)
    return true
  end

  local hname = "localhost"
  function h.get()
    local names = {}
    k.hooks.hnget(names)
    return names.minitel or names.standard or names.gerti or hname or "localhost"
  end

  k.hooks.add("hnset", function(n)
    k.sched.getinfo().env.HOSTNAME = n
    hname = n
  end)

  k.hooks.add("hnget", function(t)
    t.standard = hname or (k.sched.getinfo() or {env={}}).env.HOSTNAME or "localhost"
  end)

  k.hostname = h
end

-- buffered file I/O and misc other --

kio.dmesg(kio.loglevels.INFO, "ksrc/io.lua")

do
  local io = {}
  _G.io = io

  local vfs = vfs

  local iomt = {
    __index = function(self, key)
      local info = k.sched.getinfo()
      if key == "stdin" then
        return info.io.stdin
      elseif key == "stdout" then
        return info.io.stdout
      elseif key == "stderr" then
        return info.io.stderr
      end
    end,
    __newindex = function(self, key, value)
      local info = k.sched.getinfo()
      if key == "stdin" then
        info.io.stdin = value
      elseif key == "stdout" then
        info.io.stdout = value
      elseif key == "stderr" then
        info.io.stderr = value
      else
        rawset(self, key, value)
      end
    end,
    __metatable = {}
  }
  setmetatable(io, iomt)

  local st = {}
  function st:read(n)
    return self.node:read(self.fd, n)
  end

  function st:write(d)
    return self.node:write(self.fd, d)
  end

  function st:close()
    return self.node:close(self.fd)
  end

  local function streamify(node, fd)
    local new = {
      node = node,
      fd = fd
    }
    return setmetatable(new, {__index = st})
  end
  
  -- io.open(file:string[, mode:string]): table or nil, string
  --   Returns a buffered file stream.
  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    mode = mode or "r"
    local node, path = vfs.resolve(file)
    if not node then
      return nil, path
    end
    local handle, err = node:open(path, mode)
    if not handle then
      if err == path then
        return nil, file..": no such file or directory"
      end
      return nil, err
    end
    local stream = streamify(node, handle)
    return kio.buffer.new(stream, mode)
  end

  local function open(f, m)
    if type(f) == "string" then
      return io.open(f, m)
    else
      return f
    end
  end

  function io.input(file)
    local info = k.sched.getinfo()
    return info:input(open(file, "r"))
  end

  function io.output(file)
    local info = k.sched.getinfo()
    return info:output(open(file, "w"))
  end

  function io.read(...)
    return io.input():read(...)
  end

  function io.write(...)
    return io.output():write(...)
  end

  function io.lines(file, ...)
    checkArg(1, file, "string", "nil")
    if not file then
      return io.input():lines(...)
    end
    return io.open(file, "r"):lines(...)
  end

  k.hooks.add("sandbox", function()
    setmetatable(k.sb.io, iomt)
    function k.sb.print(...)
      local args = table.pack(...)
      for i=1, args.n, 1 do
        args[i] = tostring(args[i])
      end
      if io.stdout.write then
        io.stdout:write(table.concat(args, "\t") .. "\n")
      end
      return true
    end
  end)
  --TODO: flesh out io, maybe in userspace?
end

-- simple filesystem API

kio.dmesg("src/fsapi.lua")

do
  -- for now, we'll just only provide userspace with this one
  k.hooks.add("sandbox", function()
    local vfs = vfs
    local fs = {}

    fs.stat = vfs.stat
    fs.mount = vfs.mount
    fs.mounts = vfs.mounts
    fs.umount = vfs.umounts

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
      while path:sub(-1) == "/" do path = path:sub(1,-2) end
      local sdir, dend = path:match("(.+)/(.+)$")
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
      return node:list(path) or {}
    end

    k.sb.fs = fs
  end)
end

-- Paragon eXecutable parsing?

kio.dmesg(kio.loglevels.INFO, "ksrc/exec/px.lua")


-- basic event listeners

kio.dmesg(kio.loglevels.INFO, "ksrc/event.lua")

do
  local event = {}
  local listeners = {}
  local ps = computer.pullSignal

  function computer.pullSignal(timeout)
    checkArg(1, timeout, "number", "nil")
    local sig = table.pack(ps(timeout))
    if sig.n > 0 then
      for k, v in pairs(listeners) do
        if v.sig == sig[1] then
          local ok, ret = pcall(v.func, table.unpack(sig))
          if not ok and ret then
            kio.dmesg(kio.loglevels.ERROR, "event handler error: " .. ret)
          end
        end
      end
    end

    return table.unpack(sig)
  end

  function event.register(sig, func)
    checkArg(1, sig, "string")
    checkArg(2, func, "function")
    local n = 1
    while listeners[n] do
      n = n + 1
    end
    listeners[n] = {
      sig = sig,
      func = func
    }
    return n
  end

  function event.unregister(id)
    checkArg(1, id, "number")
    listeners[id] = nil
    return true
  end

  -- users may expect these to exist
  event.pull = computer.pullSignal
  event.push = computer.pushSignal
  k.evt = event
end

kio.dmesg(kio.loglevels.INFO, "ksrc/misc/sha3.lua")

do
-- Copyright (c) 2014  Joseph Wallace
-- Copyright (c) 2015  Phil Leblanc
-- License: MIT - see LICENSE file
------------------------------------------------------------

-- 170612 SHA-3 padding fixed.
-- (reported by Michael Rosenberg https://github.com/doomrobo)

-- 150827 original code modified and optimized
-- (more than 2x performance improvement for sha3-512) --phil

-- Directly devived from a Keccak implementation by Joseph Wallace
-- published on the Lua mailing list in 2014
-- http://lua-users.org/lists/lua-l/2014-03/msg00905.html


------------------------------------------------------------
-- sha3 / keccak

local char	= string.char
local concat	= table.concat
local spack, sunpack = string.pack, string.unpack

-- the Keccak constants and functionality

local ROUNDS = 24

local roundConstants = {
0x0000000000000001,
0x0000000000008082,
0x800000000000808A,
0x8000000080008000,
0x000000000000808B,
0x0000000080000001,
0x8000000080008081,
0x8000000000008009,
0x000000000000008A,
0x0000000000000088,
0x0000000080008009,
0x000000008000000A,
0x000000008000808B,
0x800000000000008B,
0x8000000000008089,
0x8000000000008003,
0x8000000000008002,
0x8000000000000080,
0x000000000000800A,
0x800000008000000A,
0x8000000080008081,
0x8000000000008080,
0x0000000080000001,
0x8000000080008008
}

local rotationOffsets = {
-- ordered for [x][y] dereferencing, so appear flipped here:
{0, 36, 3, 41, 18},
{1, 44, 10, 45, 2},
{62, 6, 43, 15, 61},
{28, 55, 25, 21, 56},
{27, 20, 39, 8, 14}
}



-- the full permutation function
local function keccakF(st)
	local permuted = st.permuted
	local parities = st.parities
	for round = 1, ROUNDS do
--~ 		local permuted = permuted
--~ 		local parities = parities

		-- theta()
		for x = 1,5 do
			parities[x] = 0
			local sx = st[x]
			for y = 1,5 do parities[x] = parities[x] ~ sx[y] end
		end
		--
		-- unroll the following loop
		--for x = 1,5 do
		--	local p5 = parities[(x)%5 + 1]
		--	local flip = parities[(x-2)%5 + 1] ~ ( p5 << 1 | p5 >> 63)
		--	for y = 1,5 do st[x][y] = st[x][y] ~ flip end
		--end
		local p5, flip, s
		--x=1
		p5 = parities[2]
		flip = parities[5] ~ (p5 << 1 | p5 >> 63)
		s = st[1]
		for y = 1,5 do s[y] = s[y] ~ flip end
		--x=2
		p5 = parities[3]
		flip = parities[1] ~ (p5 << 1 | p5 >> 63)
		s = st[2]
		for y = 1,5 do s[y] = s[y] ~ flip end
		--x=3
		p5 = parities[4]
		flip = parities[2] ~ (p5 << 1 | p5 >> 63)
		s = st[3]
		for y = 1,5 do s[y] = s[y] ~ flip end
		--x=4
		p5 = parities[5]
		flip = parities[3] ~ (p5 << 1 | p5 >> 63)
		s = st[4]
		for y = 1,5 do s[y] = s[y] ~ flip end
		--x=5
		p5 = parities[1]
		flip = parities[4] ~ (p5 << 1 | p5 >> 63)
		s = st[5]
		for y = 1,5 do s[y] = s[y] ~ flip end

		-- rhopi()
		for y = 1,5 do
			local py = permuted[y]
			local r
			for x = 1,5 do
				s, r = st[x][y], rotationOffsets[x][y]
				py[(2*x + 3*y)%5 + 1] = (s << r | s >> (64-r))
			end
		end

		-- chi() - unroll the loop
		--for x = 1,5 do
		--	for y = 1,5 do
		--		local combined = (~ permuted[(x)%5 +1][y]) & permuted[(x+1)%5 +1][y]
		--		st[x][y] = permuted[x][y] ~ combined
		--	end
		--end

		local p, p1, p2
		--x=1
		s, p, p1, p2 = st[1], permuted[1], permuted[2], permuted[3]
		for y = 1,5 do s[y] = p[y] ~ (~ p1[y]) & p2[y] end
		--x=2
		s, p, p1, p2 = st[2], permuted[2], permuted[3], permuted[4]
		for y = 1,5 do s[y] = p[y] ~ (~ p1[y]) & p2[y] end
		--x=3
		s, p, p1, p2 = st[3], permuted[3], permuted[4], permuted[5]
		for y = 1,5 do s[y] = p[y] ~ (~ p1[y]) & p2[y] end
		--x=4
		s, p, p1, p2 = st[4], permuted[4], permuted[5], permuted[1]
		for y = 1,5 do s[y] = p[y] ~ (~ p1[y]) & p2[y] end
		--x=5
		s, p, p1, p2 = st[5], permuted[5], permuted[1], permuted[2]
		for y = 1,5 do s[y] = p[y] ~ (~ p1[y]) & p2[y] end

		-- iota()
		st[1][1] = st[1][1] ~ roundConstants[round]
	end
end


local function absorb(st, buffer)

	local blockBytes = st.rate / 8
	local blockWords = blockBytes / 8

	-- append 0x01 byte and pad with zeros to block size (rate/8 bytes)
	local totalBytes = #buffer + 1
	-- for keccak (2012 submission), the padding is byte 0x01 followed by zeros
	-- for SHA3 (NIST, 2015), the padding is byte 0x06 followed by zeros

	-- Keccak:
	-- buffer = buffer .. ( '\x01' .. char(0):rep(blockBytes - (totalBytes % blockBytes)))

	-- SHA3:
	buffer = buffer .. ( '\x06' .. char(0):rep(blockBytes - (totalBytes % blockBytes)))
	totalBytes = #buffer

	--convert data to an array of u64
	local words = {}
	for i = 1, totalBytes - (totalBytes % 8), 8 do
		words[#words + 1] = sunpack('<I8', buffer, i)
	end

	local totalWords = #words
	-- OR final word with 0x80000000 to set last bit of state to 1
	words[totalWords] = words[totalWords] | 0x8000000000000000

	-- XOR blocks into state
	for startBlock = 1, totalWords, blockWords do
		local offset = 0
		for y = 1, 5 do
			for x = 1, 5 do
				if offset < blockWords then
					local index = startBlock+offset
					st[x][y] = st[x][y] ~ words[index]
					offset = offset + 1
				end
			end
		end
		keccakF(st)
	end
end


-- returns [rate] bits from the state, without permuting afterward.
-- Only for use when the state will immediately be thrown away,
-- and not used for more output later
local function squeeze(st)
	local blockBytes = st.rate / 8
	local blockWords = blockBytes / 4
	-- fetch blocks out of state
	local hasht = {}
	local offset = 1
	for y = 1, 5 do
		for x = 1, 5 do
			if offset < blockWords then
				hasht[offset] = spack("<I8", st[x][y])
				offset = offset + 1
			end
		end
	end
	return concat(hasht)
end


-- primitive functions (assume rate is a whole multiple of 64 and length is a whole multiple of 8)

local function keccakHash(rate, length, data)
	local state = {	{0,0,0,0,0},
					{0,0,0,0,0},
					{0,0,0,0,0},
					{0,0,0,0,0},
					{0,0,0,0,0},
	}
	state.rate = rate
	-- these are allocated once, and reused
	state.permuted = { {}, {}, {}, {}, {}, }
	state.parities = {0,0,0,0,0}
	absorb(state, data)
	return squeeze(state):sub(1,length/8)
end

-- output raw bytestrings
local function keccak256Bin(data) return keccakHash(1088, 256, data) end
local function keccak512Bin(data) return keccakHash(576, 512, data) end

k.sha3 = {
	sha256 = keccak256Bin,
	sha512 = keccak512Bin,
}
end

-- bi32 module for Lua 5.3

kio.dmesg(kio.loglevels.INFO, "ksrc/misc/bit32_lua53.lua")

do
  if tonumber(_VERSION:match("5%.(.)")) > 2 then -- if we aren't on 5.3+ then don't do anything
    -- loaded from a string so this will still parse on Lua 5.3
    -- this is the OpenOS bit32 library
    load([[
_G.bit32 = {}

local function fold(init, op, ...)
  local result = init
  local args = table.pack(...)
  for i = 1, args.n do
    result = op(result, args[i])
  end
  return result
end

local function trim(n)
  return n & 0xFFFFFFFF
end

local function mask(w)
  return ~(0xFFFFFFFF << w)
end

function bit32.arshift(x, disp)
  return x // (2 ^ disp)
end

function bit32.band(...)
  return fold(0xFFFFFFFF, function(a, b) return a & b end, ...)
end

function bit32.bnot(x)
  return ~x
end

function bit32.bor(...)
  return fold(0, function(a, b) return a | b end, ...)
end

function bit32.btest(...)
  return bit32.band(...) ~= 0
end

function bit32.bxor(...)
  return fold(0, function(a, b) return a ~ b end, ...)
end

local function fieldargs(f, w)
  w = w or 1
  assert(f >= 0, "field cannot be negative")
  assert(w > 0, "width must be positive")
  assert(f + w <= 32, "trying to access non-existent bits")
  return f, w
end

function bit32.extract(n, field, width)
  local f, w = fieldargs(field, width)
  return (n >> f) & mask(w)
end

function bit32.replace(n, v, field, width)
  local f, w = fieldargs(field, width)
  local m = mask(w)
  return (n & ~(m << f)) | ((v & m) << f)
end

function bit32.lrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit32.rrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x << disp) | (x >> (32 - disp)))
  end
end

function bit32.lshift(x, disp)
  return trim(x << disp)
end

function bit32.rrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit32.lrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x >> disp) | (x << (32 - disp)))
  end
end

function bit32.rshift(x, disp)
  return trim(x >> disp)
end
    ]], "=(bit32)", "t", _G)()
  end
end

-- automatic card dock support --

do
  for k, v in component.list("carddock") do
    component.invoke(k, "bindComponent")
  end
  k.evt.register("component_added", function(_, a, t)
    if t == "carddock" then
      component.invoke(a, "bindComponent")
    end
  end)
end

kio.dmesg(kio.loglevels.INFO, "ksrc/misc/ec25519.lua")

do
-- Copyright (c) 2015  Phil Leblanc  -- see LICENSE file

------------------------------------------------------------
--[[
ec25519 - curve25519 scalar multiplication
Ported to Lua from the original C tweetnacl implementation,
(public domain, by Dan Bernstein, Tanja Lange et al
see http://tweetnacl.cr.yp.to/ )
To make debug and validation easier, the original code structure
and function names have been conserved as much as possible.
]]

------------------------------------------------------------

-- set25519() not used

local function car25519(o)
	local c
	for i = 1, 16 do
		o[i] = o[i] + 65536 -- 1 << 16
		-- lua ">>" doesn't perform sign extension...
		-- so the following >>16 doesn't work with negative numbers!!
		-- ...took a bit of time to find this one :-)
		-- c = o[i] >> 16
		c = o[i] // 65536
		if i < 16 then
			o[i+1] = o[i+1] + (c - 1)
		else
			o[1] = o[1] + 38 * (c - 1)
		end
		o[i] = o[i] - (c << 16)
	end
end --car25519()

local function sel25519(p, q, b)
	local c = ~(b-1)
	local t
	for i = 1, 16 do
		t = c & (p[i] ~ q[i])
		p[i] = p[i] ~ t
		q[i] = q[i] ~ t
	end
end --sel25519

local function pack25519(o, n)
	-- out o[32], in n[16]
	local m, t = {}, {}
	local b
	for i = 1, 16 do t[i] = n[i] end
	car25519(t)
	car25519(t)
	car25519(t)
	for _ = 1, 2 do
		m[1] = t[1] - 0xffed
		for i = 2, 15 do
			m[i] = t[i] - 0xffff - ((m[i-1] >> 16) & 1)
			m[i-1] = m[i-1] & 0xffff
		end
		m[16] = t[16] - 0x7fff - ((m[15] >> 16) & 1)
		b = (m[16] >> 16) & 1
		m[15] = m[15] & 0xffff
		sel25519(t, m, 1-b)
	end
	for i = 1, 16 do
		o[2*i-1] = t[i] & 0xff
		o[2*i] = t[i] >> 8
	end
end -- pack25519

-- neq25519() not used
-- par25519() not used

local function unpack25519(o, n)
	-- out o[16], in n[32]
	for i = 1, 16 do
		o[i] = n[2*i-1] + (n[2*i] << 8)
	end
	o[16] = o[16] & 0x7fff
end -- unpack25519

local function A(o, a, b) --add
	for i = 1, 16 do o[i] = a[i] + b[i] end
end

local function Z(o, a, b) --sub
	for i = 1, 16 do o[i] = a[i] - b[i] end
end

local function M(o, a, b) --mul  gf, gf -> gf
	local t = {}
	for i = 1, 32 do t[i] = 0  end
	for i = 1, 16 do
		for j = 1, 16 do
			t[i+j-1] = t[i+j-1] + (a[i] * b[j])
		end
	end
	for i = 1, 15 do t[i] = t[i] + 38 * t[i+16] end
	for i = 1, 16 do o[i] = t[i] end
	car25519(o)
	car25519(o)
end

local function S(o, a)  --square
	M(o, a, a)
end

local function inv25519(o, i)
	local c = {}
	for a = 1, 16 do c[a] = i[a] end
	for a = 253, 0, -1 do
		S(c, c)
		if a ~= 2 and a ~= 4 then M(c, c, i) end
	end
	for a = 1, 16 do o[a] = c[a] end
--~ 	pt(o)
end

--pow2523() not used

local t_121665 = {0xDB41,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

local function crypto_scalarmult(q, n, p)
	-- out q[], in n[], in p[]
	local z = {}
	local x = {}
	local a = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local b = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local c = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local d = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local e = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local f = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	for i = 1, 31 do z[i] = n[i] end
	z[32] = (n[32] & 127) | 64
	z[1] = z[1] & 248
--~ 	pt(z)
	unpack25519(x, p)
--~ 	pt(x)
	for i = 1, 16 do
		b[i] = x[i]
		a[i] = 0
		c[i] = 0
		d[i] = 0
	end
	a[1] = 1
	d[1] = 1
	for i = 254, 0, -1 do
		local r = (z[(i>>3)+1] >> (i & 7)) & 1
		sel25519(a,b,r)
		sel25519(c,d,r)
		A(e,a,c)
		Z(a,a,c)
		A(c,b,d)
		Z(b,b,d)
		S(d,e)
		S(f,a)
		M(a,c,a)
		M(c,b,e)
		A(e,a,c)
		Z(a,a,c)
		S(b,a)
		Z(c,d,f)
		M(a,c,t_121665)
		A(a,a,d)
		M(c,c,a)
		M(a,d,f)
		M(d,b,x)
		S(b,e)
		sel25519(a,b,r)
		sel25519(c,d,r)
	end
	for i = 1, 16 do
		x[i+16] = a[i]
		x[i+32] = c[i]
		x[i+48] = b[i]
		x[i+64] = d[i]
	end
	-- cannot use pointer arithmetics...
	local x16, x32 = {}, {}
	for i = 1, #x do
		if i > 16 then x16[i-16] = x[i] end
		if i > 32 then x32[i-32] = x[i] end
	end
	inv25519(x32,x32)
	M(x16,x16,x32)
	pack25519(q,x16)
	return 0
end -- crypto_scalarmult

local t_9 = { -- u8 * 32
	9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	}

local function crypto_scalarmult_base(q, n)
	-- out q[], in n[]
	return crypto_scalarmult(q, n, t_9)
end

------------------------------------------------------------------------
-- convenience function (using binary strings instead of byte tables)
--
-- curve point and scalars are represented as 32-byte binary strings
-- (encoded as little endian)

local function scalarmult(n, p)
	-- n, a scalar (little endian) as a 32-byte string
	-- p, a curve point as a 32-byte string
	-- return the scalar product np as a 32-byte string
	local qt, nt, pt = {}, {}, {} 
	for i = 1, 32 do 
		nt[i] = string.byte(n, i) 
		pt[i] = string.byte(p, i) 
	end
	crypto_scalarmult(qt, nt, pt)
	local q = string.char(table.unpack(qt))
	return q
end

-- base: the curve point generator = 9

local base = '\9' .. ('\0'):rep(31)

k.ec25519 = {
	crypto_scalarmult = crypto_scalarmult,
	crypto_scalarmult_base = crypto_scalarmult_base,
	--
	-- convenience function and definition
	--
	scalarmult = scalarmult,
	base = base,
	--
}

end

kio.dmesg(kio.loglevels.INFO, "ksrc/misc/sha2.lua")

do
-- Copyright (c) 2018  Phil Leblanc  -- see LICENSE file
------------------------------------------------------------------------

--        SHA2-256 and SHA2-512 -- see RFC 6234


-- sha2-256 initially based on code written by Roberto Ierusalimschy
-- for an early Lua 5.3rc with (un)packint() functions.
-- published by  Roberto on the Lua mailing list
-- http://lua-users.org/lists/lua-l/2014-03/msg00851.html
-- can be distributed under the MIT License terms. see:
-- http://lua-users.org/lists/lua-l/2014-08/msg00628.html
--
-- adapted to 5.3 (string.(un)pack()) --phil, 150827
--
-- optimized for performance, 181008. The core permutation
-- for sha2-256 and sha2-512 is lifted from the very good
-- implementation by Egor Skriptunoff, also MIT-licensed. See
-- https://github.com/Egor-Skriptunoff/pure_lua_SHA2


------------------------------------------------------------
-- local declarations

local string, assert = string, assert
local spack, sunpack = string.pack, string.unpack 

------------------------------------------------------------------------
-- sha256

-- Initialize table of round constants
-- (first 32 bits of the fractional parts of the cube roots of the first
-- 64 primes 2..311)
local k256 = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
   0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
   0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
   0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
   0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
   0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
   0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
   0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
   0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function pad64(msg, len)
	local extra = 64 - ((len + 1 + 8) % 64)
	len = spack(">I8", len * 8)    -- original len in bits, coded
	msg = msg .. "\128" .. string.rep("\0", extra) .. len
	assert(#msg % 64 == 0)
	return msg
end

local ww256 = {}
	  
local function sha256 (msg)
	msg = pad64(msg, #msg)
	local h1, h2, h3, h4, h5, h6, h7, h8 = 
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local k = k256
	local w = ww256
	local mlen = #msg
  	-- Process the message in successive 512-bit (64 bytes) chunks:
	for i = 1, mlen, 64 do
		w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], 
		w[9], w[10], w[11], w[12], w[13], w[14], w[15], w[16]
		= sunpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", msg, i)
		-- mix msg block in state
		for j = 17, 64 do
			local x = w[j - 15]; x = (x << 32) | x
			local y = w[j - 2]; y = (y << 32) | y
			w[j] = (  ((x >> 7) ~ (x >> 18) ~ (x >> 35))
				+ ((y >> 17) ~ (y >> 19) ~ (y >> 42))
				+ w[j - 7] + w[j - 16]  ) & 0xffffffff
		end
		local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
		-- main state permutation
		for j = 1, 64 do
			e = (e << 32) | (e & 0xffffffff)
			local t1 = ((e >> 6) ~ (e >> 11) ~ (e >> 25))
				+ (g ~ e & (f ~ g)) + h + k[j] + w[j]
			h = g
			g = f
			f = e
			e = (d + t1) 
			d = c
			c = b
			b = a
			a = (a << 32) | (a & 0xffffffff)
			a = t1 	+ ((a ~ c) & d ~ a & c) 
				+ ((a >> 2) ~ (a >> 13) ~ (a >> 22))
		end
		h1 = h1 + a
		h2 = h2 + b 
		h3 = h3 + c 
		h4 = h4 + d 
		h5 = h5 + e 
		h6 = h6 + f 
		h7 = h7 + g 
		h8 = h8 + h 
	end
	-- clamp hash to 32-bit words
	h1 = h1 & 0xffffffff
	h2 = h2 & 0xffffffff
	h3 = h3 & 0xffffffff
	h4 = h4 & 0xffffffff
	h5 = h5 & 0xffffffff
	h6 = h6 & 0xffffffff
	h7 = h7 & 0xffffffff
	h8 = h8 & 0xffffffff
	-- return hash as a binary string
	return spack(">I4I4I4I4I4I4I4I4", h1, h2, h3, h4, h5, h6, h7, h8)
end --sha256

------------------------------------------------------------------------
-- sha512

local k512 = {
0x428a2f98d728ae22,0x7137449123ef65cd,0xb5c0fbcfec4d3b2f,0xe9b5dba58189dbbc,
0x3956c25bf348b538,0x59f111f1b605d019,0x923f82a4af194f9b,0xab1c5ed5da6d8118,
0xd807aa98a3030242,0x12835b0145706fbe,0x243185be4ee4b28c,0x550c7dc3d5ffb4e2,
0x72be5d74f27b896f,0x80deb1fe3b1696b1,0x9bdc06a725c71235,0xc19bf174cf692694,
0xe49b69c19ef14ad2,0xefbe4786384f25e3,0x0fc19dc68b8cd5b5,0x240ca1cc77ac9c65,
0x2de92c6f592b0275,0x4a7484aa6ea6e483,0x5cb0a9dcbd41fbd4,0x76f988da831153b5,
0x983e5152ee66dfab,0xa831c66d2db43210,0xb00327c898fb213f,0xbf597fc7beef0ee4,
0xc6e00bf33da88fc2,0xd5a79147930aa725,0x06ca6351e003826f,0x142929670a0e6e70,
0x27b70a8546d22ffc,0x2e1b21385c26c926,0x4d2c6dfc5ac42aed,0x53380d139d95b3df,
0x650a73548baf63de,0x766a0abb3c77b2a8,0x81c2c92e47edaee6,0x92722c851482353b,
0xa2bfe8a14cf10364,0xa81a664bbc423001,0xc24b8b70d0f89791,0xc76c51a30654be30,
0xd192e819d6ef5218,0xd69906245565a910,0xf40e35855771202a,0x106aa07032bbd1b8,
0x19a4c116b8d2d0c8,0x1e376c085141ab53,0x2748774cdf8eeb99,0x34b0bcb5e19b48a8,
0x391c0cb3c5c95a63,0x4ed8aa4ae3418acb,0x5b9cca4f7763e373,0x682e6ff3d6b2b8a3,
0x748f82ee5defb2fc,0x78a5636f43172f60,0x84c87814a1f0ab72,0x8cc702081a6439ec,
0x90befffa23631e28,0xa4506cebde82bde9,0xbef9a3f7b2c67915,0xc67178f2e372532b,
0xca273eceea26619c,0xd186b8c721c0c207,0xeada7dd6cde0eb1e,0xf57d4f7fee6ed178,
0x06f067aa72176fba,0x0a637dc5a2c898a6,0x113f9804bef90dae,0x1b710b35131c471b,
0x28db77f523047d84,0x32caab7b40c72493,0x3c9ebe0a15c9bebc,0x431d67c49c100d4c,
0x4cc5d4becb3e42b6,0x597f299cfc657e2a,0x5fcb6fab3ad6faec,0x6c44198c4a475817
}

local function pad128(msg, len)
	local extra = 128 - ((len + 1 + 8) % 128)
	len = spack(">I8", len * 8)    -- original len in bits, coded
	msg = msg .. "\128" .. string.rep("\0", extra) .. len
	assert(#msg % 128 == 0)
	return msg
end

local ww512 = {}
	  
local function sha512 (msg)
	msg = pad128(msg, #msg)
	local h1, h2, h3, h4, h5, h6, h7, h8 = 
		0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
		0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
		0x510e527fade682d1, 0x9b05688c2b3e6c1f,
		0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
	local k = k512
	local w = ww512 -- 80 * i64 state
	local mlen = #msg
  	-- Process the message as 128-byte blocks:
	-- (this is borrowed to Egor Skriptunoff's pure_lua_SHA2
	-- https://github.com/Egor-Skriptunoff/pure_lua_SHA2)
	for i = 1, mlen, 128 do
		w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], 
		w[9], w[10], w[11], w[12], w[13], w[14], w[15], w[16]
		= sunpack(">i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8", msg, i)
		-- mix msg block in state

		for j = 17, 80 do
			local a = w[j-15]
			local b = w[j-2]
			w[j] = (a >> 1 ~ a >> 7 ~ a >> 8 ~ a << 56 ~ a << 63)
			  + (b >> 6 ~ b >> 19 ~ b >> 61 ~ b << 3 ~ b << 45) 
			  + w[j-7] + w[j-16]
		end
		local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
		-- main state permutation
		for j = 1, 80 do
			local z = (e >> 14 ~ e >> 18 ~ e >> 41 ~ e << 23 
				   ~ e << 46 ~ e << 50) 
				+ (g ~ e & (f ~ g)) + h + k[j] + w[j]
			h = g
			g = f
			f = e
			e = z + d
			d = c
			c = b
			b = a
			a = z + ((a ~ c) & d ~ a & c) 
			      + (a >> 28 ~ a >> 34 ~ a >> 39 ~ a << 25 
				~ a << 30 ~ a << 36)
		end
		h1 = h1 + a
		h2 = h2 + b 
		h3 = h3 + c 
		h4 = h4 + d 
		h5 = h5 + e 
		h6 = h6 + f 
		h7 = h7 + g 
		h8 = h8 + h 
	end
	-- return hash as a binary string
	return spack(">i8i8i8i8i8i8i8i8", h1, h2, h3, h4, h5, h6, h7, h8)
end --sha512

------------------------------------------------------------------------

k.sha2 = {
  sha256 = sha256,
  sha512 = sha512,
}

end

-- UUID module. UUID implementation copied from OpenOS

kio.dmesg(kio.loglevels.INFO, "ksrc/misc/uuid.lua")

do
  k.uuid = {}

  function k.uuid.next()
    local sets = {4, 2, 2, 2, 6}
    local result = ""
    local pos = 0

    for _, set in ipairs(sets) do
      if #result > 0 then
        result = result .. "-"
      end
      for i=1, set, 1 do
        local byte = math.random(0, 255)
        if pos == 6 then
          byte = bit32.bor(bit32.band(byte, 0x0F), 0x40)
        elseif pos == 8 then
          byte = bit32.bor(bit32.band(byte, 0x3F), 0x80)
        end
        result = string.format("%s%02x", result, byte)
        pos = pos + 1
      end
    end

    return result
  end
end


-- BROFS filesystem driver

do
  local drv = {}

  drv.name = "BROFS driver"
  drv.authors = {"Ocawesome101"}
  drv.license = {"GPLv3"}

  local temp = {}

  local function readSectors(d, s, e)
    local r = ""
    for i=s, e, 1 do
      r = r .. (d.readSector(i) or "")
    end
    return r
  end

  local function strip(t)
    return t:gsub("/+", "")
  end

  function temp:spaceUsed()
    return math.huge
  end

  function temp:spaceTotal()
    return self.dev.getCapacity()
  end

  function temp:isReadOnly()
    return true
  end

  local hn = 0
  function temp:open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    file = strip(file)
    kio.dmesg(kio.loglevels.DEBUG, "tryopen "..file)
    if self.ftable[file] then
      local new = {
        ptr = 0,
        file = self.ftable[file]
      }
      local n = hn + 1
      hn = n
      self.handles[n] = new
      kio.dmesg(kio.loglevels.DEBUG, "opened as " ..n)
      return n
    else
      return kio.error("FILE_NOT_FOUND")
    end
  end

  function temp:read(h, n)
    checkArg(1, h, "number")
    checkArg(2, n, "number")
    if not self.handles[h] then
      return nil, "bad file descriptor"
    end
    h = self.handles[h]
    if h.ptr >= h.file.size then
      return nil
    end
    if h.ptr + n >= h.file.size then
      n = h.file.size - h.ptr
    end
    local s, e = h.file.start + (h.ptr // 512), h.file.start + (h.ptr // 512) + (n // 512)
    local approx = readSectors(self.dev, s, e)
    local t = (h.ptr - ((h.ptr // 512) * 512))
    h.ptr = h.ptr + n
    local data = approx:sub(t, t + n)
    return data
  end

  function temp:seek(h, whence, offset)
    checkArg(1, h, "number")
    checkArg(2, whence, "string", "nil")
    checkArg(3, offset, "number", "nil")
    if not self.handles[h] then
      return nil, "bad file descriptor"
    end
    h = self.handles[h]
    whence, offset = whence or "cur", offset or 0
    whence = (whence == "cur" and h.ptr) or (whence == "set" and 0) or (whence == "end" and h.file.size)
    if type(whence) == "string" then
      return nil, "invalid 'whence' argument (expected 'cur', 'set', or 'end')"
    end
    h.ptr = math.max(0, math.min(h.file.size, whence + offset))
    return h.ptr
  end

  function temp:write(h, data)
    return kio.error("DEV_RO")
  end

  function temp:close(h)
    checkArg(1, h, "number")
    self.handles[h] = nil
  end

  function temp:makeDirectory()
    return kio.error("DEV_RO")
  end

  function temp:rename()
    return kio.error("DEV_RO")
  end

  function temp:exists(file)
    checkArg(1, file, "string")
    file = strip(file)
    kio.dmesg(kio.loglevels.DEBUG, "exists", file)
    if self.ftable[file] then
      return true
    end
    return false
  end

  function temp:isDirectory()
    return false -- directories are unsupported
  end

  function temp:lastModified()
    return 0
  end

  function temp:stat()
    return {
      permissions = 292, -- 100100100, r--r--r--
      -- TODO: possibly more fields?
    }
  end

  function temp:list()
    local files = {}
    for k, v in pairs(self.ftable) do
      table.insert(files, k)
    end
    return files
  end

  function temp:size(file)
    checkArg(1, file, "string")
    file = strip(file)
    if not self.ftable(file) then
      return kio.error("FILE_NOT_FOUND")
    end
    return self.ftable[file].size
  end

  function temp:remove()
    return kio.error("DEV_RO")
  end

  function temp:setLabel(label)
    checkArg(1, label, "string")
    if self.dev.setLabel then
      return self.dev.setLabel(label)
    else
      self.label = label
    end
  end

  function temp:getLabel()
    if self.dev.getLabel then
      return self.dev.getLabel()
    else
      return self.label
    end
  end

  function drv.create(prx, label) -- takes an unmanaged drive (or a partition / file wrapper) and returns a BROFS interface
    kio.dmesg(kio.loglevels.DEBUG, "reading BROFS file table")
    local ftbl = ""
    ftbl = readSectors(prx, 1, 2)
    local ftable = {}
    local inpack = "<I2I2I2I1I1c24"
    for i=1, 32, 1 do
      local n = (i - 1) * 32 + 1
      if n == 0 then n = 1 end
      kio.dmesg(kio.loglevels.DEBUG, n.." "..n+31)
      local seg = ftbl:sub(n, n + 31)
      local start, size, prealloc, flags, _, fname = string.unpack(inpack, seg)
      kio.dmesg(kio.loglevels.DEBUG, "BROFS: "..table.concat({start,size,fname}," "))
      if flags == 0 then
        kio.dmesg(kio.loglevels.DEBUG, "BROFS: file flags < 1")
        break
      end
      -- rid us of trailing \0s in the filename
      fname = fname:gsub("\0", "")
      -- file size is stored in approximate sectors but we need the exact count
      local last = prx.readSector(start + size - 1)
      last = last:gsub("\0", "")
      local xsize = (size - 1) * 512 + #last
      local ent = {
        start = start,
        size = xsize,
        sect = size
        -- NOTE: prealloc is not used as the generated interface is read-only
      }
      ftable[fname] = ent
    end
    return setmetatable({dev = prx, ftable = ftable, handles = {}, label = label or (prx.getLabel and prx.getLabel()) or "BROFS"}, {__index = temp})
  end

  kdrv.fs.brofs = drv
end

-- managed filesystem "driver"

do
  local drv = {}
  drv.name = "managed filesystem driver"
  drv.authors = {"Ocawesome101"}
  drv.license = {"GPLv3"}

  local default = {}
  setmetatable(default, {
    __index = function(_, k)
      default[k] = function(self, ...)
        if self.dev[k] then
          --local args={...}
          --for i=1,#args,1 do args[i]=tostring(args[i])end
          --kio.dmesg(kio.loglevels.PANIC, "INVOKE::"..k..":"..table.concat(args,","))
          return self.dev[k](...)
        else
          error((string.format("attempt to call field '%s' (a nil value)", k)))
        end
      end
      return default[k]
    end
  })
  
  function default:stat(file)
    checkArg(1, file, "string")
    if not self.dev.exists(file) then
      return nil, file .. ": file not found"
    end
    return {
      permissions = self:isReadOnly() and 365 or 511,
      isDirectory = self:isDirectory(file),
      owner       = -1,
      group       = -1,
      lastModified= self:lastModified(file),
      size        = self:size(file),
    }
  end
  
  function drv.create(prx)
    checkArg(1, prx, "table", "string")
    if type(prx) == "string" then prx = component.proxy(prx) end
    return setmetatable({dev = prx,
                         fstype = "managed",
                         address = prx.address
                       }, {__index = default})
  end

  kdrv.fs.managed = drv
end


-- internet card support --

kio.dmesg("ksrc/net/internet.lua")

do
  if component.list("internet")() then
    local card = component.proxy(component.list("internet")())
    local inet = {}
    local _sock = {}

    function _sock:read(n)
      if not self.socket then
        return nil, "socket is closed"
      end
      return self.socket.read(n)
    end

    function _sock:write(data)
      if not self.socket then
        return nil, "socket is closed"
      end
      while #value > 0 do
        local wr, rs = self.socket.write(value)
        if not wr then
          return nil, rs
        end
        value = value:sub(wr + 1)
      end
      return true
    end

    function _sock:seek()
      return nil, "bad file descriptor"
    end

    function _sock:close()
      if self.socket then
        self.socket.close()
        self.socket = nil
      end
    end

    function inet.socket(host, port)
      checkArg(1, host, "string")
      checkArg(2, port, "number", "nil")
      if port then
        host = host .. ":" .. port
      end

      local raw, err = card.connect(host)
      if not raw then
        return nil, err
      end

      return setmetatable({socket = raw}, {__index = _sock, __metatable = {}})
    end

    function inet.open(host, port)
      local sock, reason = inet.socket(host, port)
      if not sock then
        return nil, reason
      end
      return kio.buffer.new(sock, "rw")
    end

    kdrv.net.internet = inet
  else
    -- else, don't initialize module at all
    kio.dmesg(kio.loglevels.WARNING, "no internet card detected; not initializing wrapper")
  end
end

-- Minitel

kio.dmesg(kio.loglevels.INFO, "ksrc/net/minitel.lua")

do
  -- this is mostly a straight-up port of the OpenOS service
  -- slightly modified to work with the Paragon kernel's feature set
  -- and re-indented to match the rest of the code
  -- also all comments are completely stripped

  local component = component
  local computer = computer
  local event = k.evt

  local cfg = {
    debug = not not kargs["mtel.debug"],
    port = tonumber(kargs["mtel.modem-port"]) or 4096,
    retry = tonumber(kargs["mtel.retry"]) or 10,
    retrycount = tonumber(kargs["mtel.retry-count"]) or 10,
    route = not not kargs["mtel.route"]
  }

  cfg.sroutes = {}
  local rcache = setmetatable({}, {__index = cfg.sroutes})
  local pcache = {}
  cfg.rctime = 15
  cfg.pctime = 15
  local pqueue = {}

  local log
  local function dprint(...)
    if cfg.debug then
      log = log or io.open("/mtel-dbg.log", "a")
      if log then
        log:write(table.concat({...}, " ").."\n")
        log:flush()
      end
    end
  end
  k.hooks.add("shutdown", function()
    if log then log:close() end
  end)

  local hostname = k.hostname.get()
  k.hooks.add("hnset", function(name)
    hostname = name or computer.address():sub(1,4)
  end)

  k.hooks.add("hnget", function(names)
    names.minitel = hostname
  end)

  local modems = {}
  for a, t in component.list("modem", true) do
    modems[#modems + 1] = component.proxy(a)
    modems[#modems].open(cfg.port)
  end

  for a, t in component.list("tunnel", true) do
    modems[#modems + 1] = component.proxy(a)
  end
  
  local function genPacketID()
    local id = ""
    for i=1, 16, 1 do
      id = id .. string.char(math.random(32, 126))
    end
    return id
  end

  local function sendPacket(packetID,packetType,dest,sender,vPort,data,repeatingFrom)
    if rcache[dest] then
      dprint("Cached", rcache[dest][1],"send",rcache[dest][2],cfg.port,packetID,packetType,dest,sender,vPort,data)
      if component.type(rcache[dest][1]) == "modem" then
        component.invoke(rcache[dest][1],"send",rcache[dest][2],cfg.port,packetID,packetType,dest,sender,vPort,data)
      elseif component.type(rcache[dest][1]) == "tunnel" then
        component.invoke(rcache[dest][1],"send",packetID,packetType,dest,sender,vPort,data)
      end
    else
      dprint("Not cached", cfg.port,packetID,packetType,dest,sender,vPort,data)
      for k,v in pairs(modems) do
        -- do not send message back to the wired or linked modem it came from
        -- the check for tunnels is for short circuiting `v.isWireless()`, which does not exist for tunnels
        if v.address ~= repeatingFrom or (v.type ~= "tunnel" and v.isWireless()) then
          if v.type == "modem" then
            v.broadcast(cfg.port,packetID,packetType,dest,sender,vPort,data)
          elseif v.type == "tunnel" then
            v.send(packetID,packetType,dest,sender,vPort,data)
          end
        end
      end
    end
  end

  local function pruneCache()
    for k,v in pairs(rcache) do
      dprint(k,v[3],computer.uptime())
      if v[3] < computer.uptime() then
        rcache[k] = nil
        dprint("pruned "..k.." from routing cache")
      end
    end
    for k,v in pairs(pcache) do
      if v < computer.uptime() then
        pcache[k] = nil
        dprint("pruned "..k.." from packet cache")
      end
    end
  end

  local function checkPCache(packetID)
    dprint(packetID)
    for k, v in pairs(pcache) do
      dprint(k)
      if k == packetID then
        return true
      end
    end
    return false
  end

  local function processPacket(_,localModem,from,pport,_,packetID,packetType,dest,sender,vPort,data)
    pruneCache()
    if pport == cfg.port or pport == 0 then -- for linked cards
      dprint(cfg.port,vPort,packetType,dest)
      if checkPCache(packetID) then return end
      if dest == hostname then
        if packetType == 1 then
          sendPacket(genPacketID(),2,sender,hostname,vPort,packetID)
        end
        if packetType == 2 then
          dprint("Dropping "..data.." from queue")
          pqueue[data] = nil
          computer.pushSignal("net_ack",data)
        end
        if packetType ~= 2 then
          computer.pushSignal("net_msg",sender,vPort,data)
        end
      elseif dest:sub(1,1) == "~" then -- broadcasts start with ~
        computer.pushSignal("net_broadcast",sender,vPort,data)
      elseif cfg.route then -- repeat packets if route is enabled
        sendPacket(packetID,packetType,dest,sender,vPort,data,localModem)
      end
      if not rcache[sender] then -- add the sender to the rcache
        dprint("rcache: "..sender..":", localModem,from,computer.uptime())
        rcache[sender] = {localModem,from,computer.uptime()+cfg.rctime}
      end
      if not pcache[packetID] then -- add the packet ID to the pcache
        pcache[packetID] = computer.uptime()+cfg.pctime
      end
    end
  end

  event.register("modem_message", processPacket)

  local function queuePacket(_,ptype,to,vPort,data,npID)
    npID = npID or genPacketID()
    if to == hostname or to == "localhost" then
      computer.pushSignal("net_msg",to,vPort,data)
      computer.pushSignal("net_ack",npID)
      return
    end
    pqueue[npID] = {ptype,to,vPort,data,0,0}
    dprint(npID,table.unpack(pqueue[npID]))
  end

  event.register("net_send", queuePacket)

  local function packetPusher()
    for k,v in pairs(pqueue) do
      if v[5] < computer.uptime() then
        dprint(k,v[1],v[2],hostname,v[3],v[4])
        sendPacket(k,v[1],v[2],hostname,v[3],v[4])
        if v[1] ~= 1 or v[6] == cfg.retrycount then
          pqueue[k] = nil
        else
          pqueue[k][5]=computer.uptime()+cfg.retry
          pqueue[k][6]=pqueue[k][6]+1
        end
      end
    end
  end

  event.register("net_ack", dprint)

  local function ppthread()
    while true do
      coroutine.yield(0.5)
      packetPusher()
    end
  end

  k.hooks.add("uspace", function()
    k.sched.spawn(ppthread, "[kworker-mtel]")
  end)
end


-- load and mount the initfs as /

kio.dmesg(kio.loglevels.INFO, "ksrc/iramfs.lua")

do
  local fs = kargs.boot or (computer.getBootAddress and computer.getBootAddress()) or kio.panic("neither boot=? nor computer.getBootAddress present")

  local pspec, addr, pn = fs:match("(.+)%((.+),(%d+)%)")
  addr = addr or fs:gsub("[^%w%-]+", "")
  if not component.type(addr) then
    kio.panic("invalid bootfs specification (got " .. addr .. ")")
  end
  if component.type(addr) == "drive" then -- unmanaged, read partition table as specified
    if not pspec then
      kio.dmesg(kio.loglevels.WARNING, "no partitioning scheme specified!")
      kio.dmesg(kio.loglevels.WARNING, "defaulting to full drive as filesystem!")
    end
    if pspec and not kdrv.fs[pspec] then
      kio.panic("missing driver for partitioning scheme " .. pspec .. "!")
    end
  elseif component.type(addr) == "filesystem" then -- managed
    if not kdrv.fs.managed then
      kio.panic("managed filesystem driver not present!")
    end
    kio.dmesg(kio.loglevels.DEBUG, "creating 'managed' proxy")
    local temp = component.proxy(addr)
    kio.dmesg(kio.loglevels.DEBUG, "creating fake 'drive'")
    local fake = {} -- fake drive component to pass to the BROFS driver so we
                    -- can mount the initfs at /
    -- TODO: initfs from a managed disk will be REALLY SLOW if we keep using
    -- TODO: this method, maybe cache sectors?
    -- TODO: or maybe it isn't a big deal and people will just load from drives
    -- TODO: like intended.
    function fake.readSector(s)
      local handle, err = temp.open("pinitfs.img", "r")
      if not handle then
        kio.dmesg(kio.loglevels.DEBUG, "fakedrv: "..err)
      end
      s = (s - 1) * 512
      local ok, err = temp.seek(handle, "set", s)
      if not ok then
        temp.close(handle)
        return "", err
      end
      local data = temp.read(handle, 512)
      temp.close(handle)
      return data
    end
    function fake.getLabel()
      return "initfs"
    end
    kio.dmesg(kio.loglevels.DEBUG, "creating initfs proxy")
    local idisk = kdrv.fs.brofs.create(fake)
    kio.dmesg(kio.loglevels.INFO, "mounting initfs at /")
    vfs.mount(fake, "/", "brofs")
  else
    kio.panic("invalid bootfs specification:\n  component is not 'drive' or 'filesystem'")
  end
end

-- load modules in order from initfs/mod*.lua

kio.dmesg(kio.loglevels.INFO, "ksrc/mods.lua")

-- <basic> loadfile(file:string): function or nil, string
--   Tries to load `file` from the filesystem.
function loadfile(file)
  checkArg(1, file, "string")
  kio.dmesg(kio.loglevels.DEBUG, "loadfile: "..file)
  local node, path = vfs.resolve(file)
  if not node then
    kio.dmesg(kio.loglevels.DEBUG, "loadfile: "..path)
    return nil, path
  end
  local handle, err = node:open(path, "r")
  if not handle then
    kio.dmesg(kio.loglevels.DEBUG, "loadfile: node: "..err)
    return nil, err
  end
  local data = ""
  repeat
    local chunk, err = node:read(handle, math.huge)
    if not chunk and err then
      node:close(handle)
      kio.dmesg(kio.loglevels.DEBUG, "loadfile: "..err)
      return nil, err
    end
    data = data .. (chunk or "")
  until not chunk
  node:close(handle)
  return load(data, "=" .. file, "bt", _G)
end

do
  local rootfs, err = vfs.resolve("/")
  if not rootfs then
    kio.panic(err)
  end
  local files = rootfs:list("/")
  table.sort(files)
  kio.dmesg(kio.loglevels.DEBUG, "loading modules from initfs")
  for i=1, #files, 1 do
    kio.dmesg(kio.loglevels.DEBUG, files[i])
    if files[i]:sub(1,3) == "mod" and files[i]:sub(-4) == ".lua" then
      local ok, err = loadfile(files[i])
      if not ok then
        kio.dmesg(kio.loglevels.ERROR, files[i]..": "..err)
      else
        local ok, ret = pcall(ok)
        if not ok then
          kio.dmesg(kio.loglevels.ERROR, files[i]..": "..ret)
        end
      end
    end
  end
end

-- load the fstab from the specified rootfs and mount filesystems accordingly
-- from here on we work with the real rootfs, not the initfs

kio.dmesg(kio.loglevels.INFO, "ksrc/fstab.lua")

-- mount the rootfs
if not kargs.keep_initfs then
  kargs.root = kargs.root or computer.getBootAddress and
                       string.format("managed(%s,1)", computer.getBootAddress())
  if not kargs.root and not computer.getBootAddress then
    kio.panic("rootfs not specified and no way to find it!")
  end

  local pspec, addr, n = kargs.root:match("(%w+)%(([%w%-]+),(%d+)%)")
  kio.dmesg(kio.loglevels.DEBUG, pspec.."("..addr..","..n..")")
  addr = addr or kargs.root
  if component.type(addr) == "filesystem" then
    pspec = "managed"
    if not k.drv.fs.managed then
      kio.panic("managed fs driver required but not present")
    end
    local prx, err = component.proxy(addr)
    local rfs = kdrv.fs.managed.create(prx)
    vfs.umount("/")
    vfs.mount(rfs, "/")
  elseif component.type(addr) == "drive" then
    --[[ TODO TODO TODO TODO TODO
         SUPPORT UNMANAGED DRIVES!
         TODO TODO TODO TODO TODO ]]
    kio.panic("TODO - unmanaged drive support!")
    pspec = pspec or "unmanaged" -- defaults to full drive as filesystem
  else
    kio.panic("invalid rootfs partspec: "..kargs.root)
  end
end

-- load and parse the fstab
kio.dmesg("parsing /etc/fstab")
do
  local ifs, p = vfs.resolve("/etc/fstab")
  if not ifs then
    kio.panic(p)
  end
  local handle, err = ifs:open(p)
  if not handle then
    kio.dmesg(kio.loglevels.WARNING, "error opening /etc/fstab: "..err)
    goto eol
  end
  local data = ""
  repeat
    local chunk = ifs:read(handle, math.huge)
    data = data .. (chunk or "")
  until not chunk
  ifs:close(handle)
  -- partition table driver cache for better memory usage
  local dcache = {}
  vfs.umount("/")
  for line in data:gmatch("[^\n]+") do
    -- e.g. to specify the third partition on the OCGPT of a drive:
    -- ocgpt(42d7,3)   /   openfs   rw
    -- managed(5732,1)   /   managed   rw
    kio.dmesg(line)
    local pspec, path, fsspec, mode = line:match("(.-)%s+(.-)%s+(.-)%s+(.-)")
    local ptab, caddr, pnum = pspec:match("(%w+)%(([%w%-]+),(%d+)%)")
    if not k.drv.fs[ptab] then
      kio.dmesg(kio.loglevels.ERROR, ptab..": missing ptable driver")
    elseif ptab == "managed" or component.type(caddr) == "filesystem" then
      if not (ptab == "managed" and component.type(caddr) == "filesystem") then
        kio.dmesg(kio.loglevels.ERROR, "cannot use managed pspec on drive component")
      else
        local drv = k.drv.fs.managed.create(caddr)
        kio.dmesg("mounting " .. caddr .. " at " .. path)
        vfs.mount(drv, path)
      end
    else
      dcache[caddr] = dcache[addr] or k.drv.fs[ptab].create(caddr)
      local drv = dcache[addr]
      if fsspec ~= "managed" then
        drv = k.drv.fs[fsspec].create(drv:partition(tonumber(pnum)))
      end
      kio.dmesg("mounting " .. pspec .. " at " .. path)
      vfs.mount(drv, path)
    end
  end
  ::eol::
end

-- FINALLY proper system logging
do
  -- comment this out for debugging purposes
  goto no_log
  local LOG_PATH = "/boot/syslog"
  local logHandle = assert(io.open(LOG_PATH, "w"))
  
  kio.dmesg("bringing up proper system logging")

  function kio.__dmesg:write(msg)
    logHandle:write(msg, "\n")
    logHandle:flush()
  end

  for i=1, #kio.__dmesg.buffer, 1 do
    kio.__dmesg:write(kio.__dmesg.buffer[i])
  end
  kio.__dmesg.buffer = nil
end

::no_log::

-- TTY driver --

kio.dmesg(kio.loglevels.INFO, "ksrc/tty.lua")

do

local vt = {}

-- these are the default VGA colors
local colors = {
  0x000000,
  0xaa0000,
  0x00aa00,
  0xaaaa00,
  0x0000aa,
  0xaa00aa,
  0x00aaaa,
  0xaaaaaa
}
local bright = {
  0x555555,
  0xff5555,
  0x55ff55,
  0xffff55,
  0x5555ff,
  0xff55ff,
  0x55ffff,
  0xffffff
}
-- and these are the 240 \27[38;5;NNNm colors
local palette = {
  0x000000,
  0xaa0000,
  0x00aa00,
  0xaaaa00,
  0x0000aa,
  0xaa00aa,
  0x00aaaa,
  0xaaaaaa,
  0x555555,
  0xff5555,
  0x55ff55,
  0xffff55,
  0x5555ff,
  0xff55ff,
  0x55ffff,
  0xffffff,
  0x000000
}
-- programmatically generate the rest since they follow a pattern
local function inc(n)
  if n >= 0xff then
    return 0
  else
    return n + 40
  end
end
local function pack(r,g,b)
  return (r << 16) + (g << 8) + b
end
local r, g, b = 0x5f, 0, 0
local i = 0

repeat
  table.insert(palette, pack(r, g, b))
  b = inc(b)
  if b == 0 then
    b = 0x5f
    g = inc(g)
  end
  if g == 0 then
    g = 0x5f
    r = inc(r)
  end
  if r == 0 then
    break
  end
until r == 0xff and g == 0xff and b == 0xff

table.insert(palette, pack(r,g,b))

for i=0x8, 0xee, 10 do
  table.insert(palette, pack(i,i,i))
end

local min, max = math.min, math.max

-- This function takes a gpu and screen address and returns a (non-buffered!) stream.
function vt.new(gpu, screen)
  checkArg(1, gpu, "string", "table")
  checkArg(2, screen, "string", "nil")
  if type(gpu) == "string" then gpu = component.proxy(gpu) end
  if screen then gpu.bind(screen) end
  local mode = 0
  -- TTY modes:
  -- 0: regular text
  -- 1: received '\27'
  -- 2: received '\27[', in escape
  -- 3: received '\27(', in control
  local rb = ""
  local wb = ""
  local nb = ""
  local ec = true -- local echo
  local lm = true -- line mode
  local raw = false -- raw read mode
  local buf
  local cx, cy = 1, 1
  local fg, bg = colors[8], colors[1]
  local w, h = gpu.maxResolution()
  gpu.setResolution(w, h)

  -- buffered TTYs for fullscreen apps, just like before but using control codes 
  --       \27(B/\27(b rather than \27[*m escape sequences
  if gpu.allocateBuffer then
    buf = gpu.allocateBuffer()
  end

  local function scroll(n)
    n = n or 1
    gpu.copy(1, 1, w, h, 0, -n)
    gpu.fill(1, h - n + 1, w, n + 1, " ")
  end

  local function checkCursor()
    if cx > w then cx, cy = 1, cy + 1 end
    if cy >= h then cy = h - 1 scroll(1) end
    if cx < 1 then cx = w + cx cy = cy - 1 end
    if cy < 1 then cy = 1 end
    cx = max(1, min(w, cx))
    cy = max(1, min(h, cy))
  end

  local function flushwb()
    while unicode.len(wb) > 0 do
      checkCursor()
      local ln = unicode.sub(wb, 1, w - cx + 1)
      gpu.set(cx, cy, ln)
      cx = cx + unicode.len(ln)
      wb = unicode.sub(wb, unicode.len(ln) + 1)
    end
  end

  local stream = {}

  local p = {}
  -- Write a string to the stream. The string will be parsed for vt100 codes.
  function stream:write(str)
    checkArg(1, str, "string")
    if self.closed then
      return nil, "input/output error"
    end
    str = str:gsub("\8", "\27[D")
    local _c, _f, _b = gpu.get(cx, cy)
    gpu.setForeground(_b)
    gpu.setBackground(_f)
    gpu.set(cx, cy, _c)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    for c in str:gmatch(".") do
      if mode == 0 then
        if c == "\n" then
          flushwb()
          cx, cy = 1, cy + 1
          checkCursor()
        elseif c == "\t" then
          local t = cx + #wb
          t = ((t-1) - ((t-1) % 8)) + 9
          if t > w then
            cx, cy = 1, cy + 1
            checkCursor()
          else
            wb = wb .. (" "):rep(t - (cx + #wb))
          end
        elseif c == "\27" then
          flushwb()
          mode = 1
        elseif c == "\7" then -- ascii BEL
          computer.beep(".")
        else
          wb = wb .. c
        end
      elseif mode == 1 then
        if c == "[" then
          mode = 2
        elseif c == "(" then
          mode = 3
        else
          mode = 0
        end
      elseif mode == 2 then
        if tonumber(c) then
          nb = nb .. c
        elseif c == ";" then
          p[#p+1] = tonumber(nb) or 0
          nb = ""
        else
          mode = 0
          if #nb > 0 then
            p[#p+1] = tonumber(nb) or 0
            nb = ""
          end
          if c == "A" then
            cy = cy + max(0, p[1] or 1)
          elseif c == "B" then
            cy = cy - max(0, p[1] or 1)
          elseif c == "C" then
            cx = cx + max(0, p[1] or 1)
          elseif c == "D" then
            cx = cx - max(0, p[1] or 1)
          elseif c == "E" then
            cx, cy = 1, cy + max(0, p[1] or 1)
          elseif c == "F" then
            cx, cy = 1, cy - max(0, p[1] or 1)
          elseif c == "G" then
            cx = min(w, max(p[1] or 1))
          elseif c == "H" or c == "f" then
            cx, cy = max(0, min(w, p[2] or 1)), max(0, min(h - 1, p[1] or 1))
          elseif c == "J" then
            local n = p[1] or 0
            if n == 0 then
              gpu.fill(cx, cy, w, 1, " ")
              gpu.fill(1, cy + 1, w, h, " ")
            elseif n == 1 then
              gpu.fill(1, 1, w, cy - 1, " ")
              gpu.fill(cx, cy, w, 1, " ")
            elseif n == 2 then
              gpu.fill(1, 1, w, h, " ")
            end
          elseif c == "K" then
            local n = p[1] or 0
            if n == 0 then
              gpu.fill(cx, cy, w, 1, " ")
            elseif n == 1 then
              gpu.fill(1, cy, cx, 1, " ")
            elseif n == 2 then
              gpu.fill(1, cy, w, 1, " ")
            end
          elseif c == "S" then
            scroll(max(0, p[1] or 1))
            checkCursor()
          elseif c == "T" then
            scroll(-max(0, p[1] or 1))
            checkCursor()
          elseif c == "m" then
            local ic = false -- in RGB-color escape
            local icm = 0 -- RGB-color mode: 2 = 240-color, 5 = 24-bit R;G;B
            local icc = 0 -- the color
            local icv = 0 -- fg or bg?
            local icn = 0 -- which segment we're on: 1 = R, 2 = G, 3 = B
            p[1] = p[1] or 0
            for i=1, #p, 1 do
              local n = p[i]
              if ic then
                if icm == 0 then
                  icm = n
                elseif icm == 2 then
                  if icn < 3 then
                    icn = icn + 1
                    icc = icc + n << (8 * (3 - icn))
                  else
                    ic = false
                    if icv == 1 then
                      bg = icc
                    else
                      fg = icc
                    end
                  end
                elseif icm == 5 then
                  if palette[n] then
                    icc = palette[n]
                  end
                  ic = false
                  if icv == 1 then
                    bg = icc
                  else
                  fg = icc
                  end
                end
              else
                icm = 0
                icc = 0
                icv = 0
                icn = 0
                if n == 0 then -- reset terminal attributes
                  fg, bg = colors[8], colors[1]
                  ec = true
                  lm = true
                elseif n == 8 then -- disable local echo
                  ec = false
                elseif n == 28 then -- enable local echo
                  ec = true
                elseif n > 29 and n < 38 then -- foreground color
                  fg = colors[n - 29]
                elseif n > 39 and n < 48 then -- background color
                  bg = colors[n - 39]
                elseif n == 38 then -- 256/24-bit color, foreground
                  ic = true
                  icv = 0
                elseif n == 48 then -- 256/24-bit color, background
                  ic = true
                  icv = 1
                elseif n == 39 then -- default foreground
                  fg = colors[8]
                elseif n == 49 then -- default background
                  bg = colors[1]
                elseif n > 89 and n < 98 then -- bright foreground
                  fg = bright[n - 89]
                elseif n > 99 and n < 108 then -- bright background
                  bg = bright[n - 99]
                end
                gpu.setForeground(fg)
                gpu.setBackground(bg)
              end
            end
          elseif c == "n" then
            if p[1] and p[1] == 6 then
              rb = rb .. string.format("\27[%d;%dR", cy, cx)
            end
          end
          p = {}
        end
      elseif mode == 3 then
        mode = 0
        if c == "l" then
          lm = false
        elseif c == "L" then
          lm = true
        elseif c == "r" then
          raw = false
        elseif c == "R" then
          raw = true
        elseif c == "b" then
          if buf then gpu.setActiveBuffer(0)
                      gpu.bitblt(0, 1, 1, w, h, buf) end
        elseif c == "B" then
          if buf then gpu.setActiveBuffer(buf) end
        end
      end
    end
    flushwb()
    checkCursor()
    local _c, f, b = gpu.get(cx, cy)
    gpu.setForeground(b)
    gpu.setBackground(f)
    gpu.set(cx, cy, _c)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    return true
  end

  local keyboards = {}
  for k,v in pairs(component.invoke(screen or gpu.getScreen(),"getKeyboards"))do
    keyboards[v] = true
  end

  -- this key input logic is... a lot simpler than i initially thought
  -- it would be
  local function key_down(sig, kb, char, code)
    if keyboards[kb] then
      local c
      if char > 0 then
        c = (char > 255 and unicode.char or string.char)(char)
      -- up 00; down 208; right 205; left 203
      elseif code == 200 then
        c = "\27[A"
      elseif code == 208 then
        c = "\27[B"
      elseif code == 205 then
        c = "\27[C"
      elseif code == 203 then
        c = "\27[D"
      end

      c = c or ""
      if char == 13 and not raw then
        rb = rb .. "\n"
      else
        rb = rb .. c
      end
      if ec then
        if char == 13 and not raw then
          stream:write("\n")
        elseif char == 8 and not raw then
          stream:write("\8")
        elseif char < 32 and char > 0 then
          -- i n l i n e   l o g i c   f t w
          stream:write("^"..string.char(
            (char < 27 and char + 96) or
            (char == 27 and "[") or
            (char == 28 and "\\") or
            (char == 29 and "]") or
            (char == 30 and "~") or
            (char == 31 and "?")
          ):upper())
        else
          stream:write(c)
        end
      end
    end
  end

  local function clipboard(sig, kb, data)
    if keyboards[kb] then
      for c in data:gmatch(".") do
        key_down("key_down", kb, c:byte(), 0)
      end
    end
  end

  local id1 = k.evt.register("key_down", key_down)
  local id2 = k.evt.register("clipboard", clipboard)

  -- special character handling functions
  local chars = {
    ["\3"] = process.signals.SIGINT,
    ["\4"] = process.signals.SIGHUP
  }
  local function checkBuffer()
    for char, sign in pairs(chars) do
      if rb:find(char) then
        rb = ""
        stream:write("\n")
        k.sched.signal(k.sched.getinfo().pid, sign)
      end
    end
  end

  -- simpler than the original stream:read implementation:
  --   -> required 'n' argument
  --   -> does not support 'n' as string
  --   -> far simpler text reading logic
  function stream:read(n)
    checkArg(1, n, "number")
    if lm then
      while (not rb:find("\n")) or (rb:find("\n") < n) do
        checkBuffer()
        coroutine.yield()
      end
    else
      while #rb < n do
        checkBuffer()
        coroutine.yield()
      end
    end
    checkBuffer()
    local ret = rb:sub(1, n)
    rb = rb:sub(n + 1)
    return ret
  end

  function stream:seek()
    return nil, "Illegal seek"
  end

  function stream:close()
    self.closed = true
    k.evt.unregister(id1)
    k.evt.unregister(id2)
    return true
  end

  --[[local new = kio.buffer.new(stream, "rw")
  new:setvbuf("no")
  new.bufferSize = 0
  new.tty = true
  return new]]
  return stream
end

k.vt = vt

end

-- PTYs: open terminal streams --
-- PTY here doesn't mean quite the same thing as it does in most Unix-likes

kio.dmesg("ksrc/pty.lua")

do
  local opened = {}
  
  local pty = {}

  local dinfo = computer.getDeviceInfo()

  local gpus, screens = {}, {}

  for k,v in component.list() do
    if v == "gpu" then
      gpus[#gpus+1] = {addr=k,res=tonumber(dinfo[k].capacity),bound=false}
    elseif v == "screen" then
      screens[#screens+1] = {addr=k,res=tonumber(dinfo[k].capacity),bound=false}
    end
  end

  local function get(t, r)
    local ret = {}
    for i=1, #t, 1 do
      local o = t[i]
      if not o.bound then
        ret[o.res] = ret[o.res] or o
      end
    end
    return ret[r] or ret[8000] or ret[2000] or ret[800]
  end

  local function open_pty()
    local gpu = get(gpus)
    if gpu then
      local screen = get(screens, gpu.res)
      if screen then
        local new = k.vt.new(gpu.addr, screen.addr)
        gpu.bound = screen.addr
        screen.bound = gpu.addr
        local close = new.close
        function new:close()
          gpu.bound = false
          screen.bound = false
          close(new)
        end
        return new
      end
    end
    return nil
  end

  function pty.streams()
    return function()
      local new = open_pty()
      if new then
        local str = kio.buffer.new(new, "rw")
        str:setvbuf("no")
        str.bufferSize = 0
        str.tty = true
        return str
      end
      return nil
    end
  end

  k.pty = pty
end

-- package library --


k.hooks.add("sandbox", function()
  kio.dmesg("ksrc/package.lua")
  local package = {}
  k.sb.package = package
  local loading = {}
  local loaded = {
    _G = k.sb,
    os = k.sb.os,
    io = k.sb.io,
    pty = table.copy(k.pty),
    sha2 = k.sb.sha2,
    sha3 = k.sb.sha3,
    math = k.sb.math,
    pipe = {create = k.io.pipe},
    uuid = k.sb.k.uuid,
    event = table.copy(k.evt),
    table = k.sb.table,
    users = k.sb.security.users,
    bit32 = k.sb.bit32,
    vt100 = table.copy(k.vt),
    string = k.sb.string,
    buffer = table.copy(k.io.buffer),
    package = k.sb.package,
    process = k.sb.process,
    ec25519 = k.sb.ec25519,
    internet = table.copy(k.drv.net.internet or {}),
    security = k.sb.security,
    hostname = table.copy(k.hostname),
    computer = k.sb.computer,
    component = k.sb.component,
    coroutine = k.sb.coroutine,
    filesystem = k.sb.fs
  }
  k.sb.k = nil
  k.sb.fs = nil
  k.sb.vfs = nil
  k.sb.sha2 = nil
  k.sb.sha3 = nil
  k.sb.bit32 = nil
  k.sb.process = nil
  k.sb.ec25519 = nil
  k.sb.security = nil
  k.sb.computer = nil
  k.sb.component = nil
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
      if vfs.stat(search) then
        return search
      end
      searched[#searched + 1] = search
    end
    return nil, searched
  end

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
        k.sb.dofile(file)
        return tbl[key]
      end
    }
    if lib.internal then
      setmetatable(lib.internal, mt)
    end
    setmetatable(lib, mt)
  end

  function k.sb.require(module)
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
end)

-- power management-ish; specifically sleep-mode --

do
  k.hooks.add("sandbox", function()
    k.sb.package.loaded.pwman = {
      suspend = function()
        if k.security.users.user() ~= 0 then
          return nil, "only root can do that"
        end
        k.hooks.sleep()
      end
    }
  end)
end

-- sandbox --

kio.dmesg("ksrc/sandbox.lua")

-- loadfile --

function _G.loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  local handle, err = io.open(file, "r")
  if not handle then
    return nil, err
  end
  local data = handle:read("a")
  -- TODO: better shebang things
  if data:sub(1,1) == "#" then
    data = "--" .. data
  end
  handle:close()
  return load(data, "="..file, mode or "bt", env or k.sb or _G)
end

function _G.dofile(file, ...)
  checkArg(1, file, "string")
  local ok, err = loadfile(file)
  if not ok then
    error(err)
  end
  return ok(...)
end


do
  local sb = table.copy(_G)
  sb._G = sb
  k.sb = sb
  local iomt = k.iomt
  k.iomt = nil
  k.hooks.sandbox(iomt)
  function sb.package.loaded.computer.shutdown(rb)
    k.io.dmesg("running shutdown hooks")
    if k.hooks.shutdown then k.hooks.shutdown() end
    computer.shutdown(rb)
  end
end

-- load init from disk --

kio.dmesg("ksrc/loadinit.lua")

local function pre_run()
  if k.io.gpu then
    local vts = k.vt.new(k.io.gpu, k.io.screen)
    io.input(vts)
    io.output(vts)
    k.sched.getinfo():stderr(vts)
  end
end

do
  if computer.freeMemory() < 8192 then
    kio.dmesg("NOTE: init may not load; low memory")
  end
  local init = kargs.init or "/sbin/init.lua"
  local ok, err = loadfile(init, nil, k.sb)
  if not ok then
    kio.panic(err)
  end
  k.sched.spawn(function()pre_run()ok(k)end, "[init]", 1)
end

if k.hooks.uspace then
  k.hooks.uspace()
end
k.sched.loop()

kio.panic("premature exit!")
