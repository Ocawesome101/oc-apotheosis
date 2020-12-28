-- start all available services --

local log = ...

log("Starting services")
local svc = require("svc")
local config = dofile("/etc/services.cfg")

for i, v in pairs(config) do
  if v then
    log(32, "Starting service: "..i)
    svc.start(i)
  end
end
