-- suspend - suspend the system --

local pwman = require("pwman")

local ok, err = pwman.suspend()
if not ok and err then
  io.stderr:write("suspend: ", err, "\n")
  os.exit(1)
end

os.exit(0)
