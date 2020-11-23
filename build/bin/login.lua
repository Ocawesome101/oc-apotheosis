-- login --

local users = require("users")
local hostname = require("hostname")

while true do
  io.write("\27[1H\27[0m\27[2J")
  print(string.format("\n%s %s\n", _KINFO.name, _KINFO.version))
  local hnames = hostname.get()
  io.write((hnames.minitel or hnames.gert or hnames.standard or "localhost") .. " login: ")
  local name = io.read("l")
  io.write("password: \27[8m")
  local pass = io.read("l")
  io.write("\27[0m")
  local uid, ok, err -- goto scoping
  do
    uid, err = users.idByName(name)
    if not uid then
      print(err)
      goto cont
    end
    local dat, ret = users.checkAuth(uid, pass)
    if not dat then
      print(ret)
      goto cont
    end
  end
  ok, err = loadfile("/bin/sh.lua")
  if not ok then
    print("error in shell: " .. err)
  else
    local done, ret = users.spawnAs(uid, pass, ok, "/bin/sh.lua")
    if not done then
      print("error in shell: " .. ret)
    end
  end
  ::cont::
  os.sleep(5)
end
