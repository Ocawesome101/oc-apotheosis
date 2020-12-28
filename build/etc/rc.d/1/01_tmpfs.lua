-- mount the tmpfs at /root --

local computer = require("computer")
local fs = require("filesystem")

fs.mount(computer.tmpAddress(), "/tmp")
