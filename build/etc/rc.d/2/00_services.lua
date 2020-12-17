-- start all available services --

local log = ...

log("Starting services")
local svc = require("svc")
local config = dofile("/etc/services.cfg")

for i=1, #config, 1 do
  log(32, "Starting service: "..config[i])
  svc.start(config[i])
end
