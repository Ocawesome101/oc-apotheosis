-- telnet - basic telnet client --

local internet = require("internet")
local process = require("process")
local argp = require("argp")

local args, opts = argp.parse(...)

if #args == 0 then
  io.stderr:write("USAGE: telnet ADDRESS [PORT]")
  os.exit(1)
end

local function connect(host, port)
  checkArg(1, host, "string")
  checkArg(2, port, "number", "nil")
  local socket, err = internet.socket(host, port)
  if not socket then
    io.write("\natc: ", tostring(err))
    os.exit(1)
  end
  io.write("Connecting...\n")
  local function thread1()
    while true do
      local evt = table.pack(coroutine.yield(1))
      if evt[1] == "internet_ready" then
        while true do
          local data, err = socket:read(1)
          if not data then
            if err then
              io.write("\natc: " .. tostring(err) .. "\n")
              socket:close()
              return
            end
          elseif data == "" then
            break
          else
            io.write(data)
          end
        end
      end
    end
  end

  local function thread2()
    while true do
      local line = io.read()
      socket:write(line)
      socket:write("\r\n")
    end
  end

  local pid1 = process.spawn(thread1, "[atc-output]")
  local pid2 = process.spawn(thread2, "[atc-input]")
  while process.info(pid1) and process.info(pid2) do
    coroutine.yield()
  end
  process.signal(pid1, process.signals.SIGKILL)
  process.signal(pid2, process.signals.SIGKILL)
  socket:close()
end

io.write([[
+---------------------------------+
|       /\     ========= +-----+  |
|      /  \        |     |     |  |
|     /    \       |     |        |
|    /======\      |     |        |
|   /        \     |     |     |  |
|  /          \    |     +-----+  |
|                                 |
|   Apotheosis  Telnet   Client   |
+---------------------------------+

]])

connect(args[1], tonumber(args[2]))
