-- GETTY implementation --

local computer = require("computer")
io.write("\27[2J")

local ok, err, lname
if computer.runlevel() == 1 then
  ok, err = loadfile("/bin/sh.lua")
  lname = "sh"
else
  ok, err = loadfile("/bin/login.lua")
  lname = "login"
end
if not ok then
  io.stderr:write(err,"\n")
else
  require("process").spawn(ok, lname)
end

--[[while true do
  local sig = table.pack(coroutine.yield())
  if sig[1] == "process_died" and sig[4] then
    print(sig[4])
  end
end]]
os.exit()
