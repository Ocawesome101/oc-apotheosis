-- GETTY implementation --

error("AAAAAAAAAAA")

local ok, err
if computer.runlevel() == 1 then
  ok, err = loadfile("/bin/sh.lua")
else
  ok, err = loadfile("/bin/login.lua")
end
if not ok then
  io.write(err,"\n")
else
  require("process").spawn(ok, "login")
end

while true do
  local sig = table.pack(coroutine.yield())
  if sig[1] == "thread_died" then
    print(sig[4])
  end
end
