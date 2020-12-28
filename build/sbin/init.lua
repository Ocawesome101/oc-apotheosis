--[[
        Epitome init system.  SysV-style.
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

local k = ...
local log = k.io.dmesg
local _INFO = {
  name    = "Epitome",
  version = "0.8.0-dev",
}

-- init logger --

log("INIT: src/logger.lua")
io.write("\27[39;49m\27[2J\27[1;1H")
function log(col, msg)
  if type(col) == "string" then
    msg = col
    col = 32
  end
  return io.write(string.format("\27[%dm* \27[97m%s\n", col + 60, msg))
end
k.io.hide()

log(34, string.format("Welcome to \27[92m%s \27[97mversion \27[94m%s\27[97m", _INFO.name, _INFO.version))

-- services --

do
  local process = require("process")
  local running = {}

  local svc = {}
  local path = "/etc/services.d/"

  local function full(p)
    return string.format("%s%s.lua", path, s)
  end

  function svc.start(s)
    if running[s] and process.info(running[s]) then
      return true
    end
    local full = full(s)
    local ok, err = loadfile(full)
    if not ok then
      return nil, err
    end
    local pid = process.spawn(ok, "["..s.."]")
    running[s] = pid
  end

  function svc.stop(s)
    if not running[s] then
      return true
    end
    process.signal(running[s], process.signals.SIGTERM)
    running[s] = nil
  end
  
  function svc.running()
    return table.copy(running)
  end

  package.loaded.svc = svc
end

-- run levels

do
  local fs = require("filesystem")
  local computer = require("computer")
  local component = require("component")
  log(34, "Bringing up run level support")
  local _DEFAULT = 3
  --[[ Here's how run levels work under Epitome:
       
        - /etc/rc.d contains 7 subdirectories - one per runlevel.
        - These directories are named 0 through 6.
        - Each directory should contain a set of scripts to be executed
          in order when the corresponding run level is hit.
            ->  In a true sysV init, we'd jump straight to the default runlevel.
                However, this requires more complexity.
        - This leads to a directory structure similar to the following:
          /etc
            \- rc.d
               |- 0
               |  \- 00_shutdown.lua
               |- 1
               |  |- 00_base.lua
               |  \- 99_single_user_mode.lua
               |- 2
               |  \- 00_services.lua
               |- 3
               |  |- 00_base.lua
               |  |- 10_net_minitel.lua
               |  \- 20_net_gert.lua
               |- ...
              ...
  ]]

  -- the current system runlevel
  local runlevel = 1

  local function run_all(rlvl)
    log(32, "Executing runlevel: "..rlvl)
    local base = string.format("/etc/rc.d/%d/", rlvl)
    local files = fs.list(base)
    if not files then return end
    table.sort(files)
    for i=1, #files, 1 do
      if files[i]:sub(1,1) ~= "." then
        log(34, base .. files[i])
        local ok, err = pcall(dofile, base .. files[i], log)
        if not ok and err then
          log(31, "ERROR: " .. tostring(err))
          os.sleep(5)
        end
      end
    end
    runlevel = rlvl
  end

  log(32, "Bringing system to runlevel ".._DEFAULT)
  for i=1, _DEFAULT, 1 do
    run_all(i)
  end

  function computer.runlevel(n)
    if n and os.getenv("UID") ~= 0 then
      return nil, "only root can do that"
    end
    if n and n < runlevel then
      if n > 0 then
        return nil, "cannot reduce system runlevel"
      end
      run_all(0)
    end
    if n then
      for i=runlevel, n, 1 do
        run_all(i)
      end
    end
    return runlevel
  end
end

-- load getty --

log("src/getty.lua")

log("Initializing components")
do
  local component = require("component")
  for k,v in component.list() do
    require("computer").pushSignal("component_added", k, v)
  end
end

log("Starting getty")
do
  local pty = require("pty")
  local function start_getty(stdio)
    local ok, err = loadfile("/sbin/getty.lua")
  
    if not ok then
      log(31, "failed: ".. err)
    else
      local pid = require("process").spawn(
        function()
          io.input(stdio)
          io.output(stdio)
          io.stdin = stdio
          io.stdout = stdio
          io.stderr = stdio
          local s, r = pcall(ok)
          if not s and r then
            log(31, "failed: "..r)
          end
        end, "[getty]")
        io.write("\nStarted getty as " .. tostring(pid))
     end
  end

  for stream in pty.streams() do
    io.write("Starting getty on: " .. tostring(stream), "\n")
    start_getty(stream)
  end
end

require("event").push("init")
while true do coroutine.yield() end

