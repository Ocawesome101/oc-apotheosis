-- managed loader for Paragon --

local addr, invoke = computer.getBootAddress(), component.invoke

local flags = string.format(
  "root=managed(%s,1) boot=managed(%s,1) loglevel=0 scheduler.timeout=1"
    , addr, addr)

local kernelPath = "/boot/paragon"

local handle, err = invoke(addr, "open", kernelPath)
if not handle then
  error(err)
end

local t = ""
repeat
  local c = invoke(addr, "read", handle, math.huge)
  t = t .. (c or "")
until not c

invoke(addr, "close", handle)

local ok, err = load(t, "=" .. kernelPath, "bt", _G)
if not ok then
  (kio and kio.panic or error)(err)
end

local ok, err = xpcall(ok, debug.traceback, flags)
if not ok and err then
  local h=invoke(addr,"open","/crash.txt","w")
  if h then
    invoke(addr,"write",h,err)
  end
  invoke(addr,"close",h)
  if k and k.io then
    k.io.panic(err)
  end
  error(err)
end
