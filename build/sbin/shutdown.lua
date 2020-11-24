-- shutdown command --

local argp = require("libargp")

local args, opts = argp.parse(...)
local computer = require("computer")

local pwr = opts.poweroff or opts.P or opts.h or false
local rbt = opts.reboot or opts.r or false
local msg = opts.k or false

if opts.help or not (pwr or rbt or msg) then
  print([[
usage: shutdown [options]
options:
  --poweroff, -P, -h    power off
  --reboot, -r          reboot
  -k                    send the shutdown signal but do not shut down
]])
  return
end

computer.pushSignal("shutdown")
coroutine.yield()

if (pwr or rbt or hlt) and not msg then
  computer.shutdown(rbt)
end

os.exit(1)
