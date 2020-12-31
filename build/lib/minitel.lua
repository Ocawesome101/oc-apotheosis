-- the OpenOS version of the minitel lib.  slightly modified to compensate for
-- API differences
-- also has argument checking

local computer = require("computer")
local uevent = require("uevent")
local event = require("event")
local net = {}
net.mtu = 4096
net.streamdelay = 30
net.minport = 32768
net.maxport = 65535
net.openports = {}

function net.genPacketID()
 local npID = ""
 for i = 1, 16 do
  npID = npID .. string.char(math.random(32,126))
 end
 return npID
end

function net.usend(to,port,data,npID)
 computer.pushSignal("net_send",0,to,port,data,npID)
end

function net.rsend(to,port,data,block)
 local pid, stime = net.genPacketID(), computer.uptime() + net.streamdelay
 computer.pushSignal("net_send",1,to,port,data,pid)
 if block then return pid end
 local rpid
 repeat
  local a,b = event.pull(0.5)
  if a=="net_ack" then
   rpid=b
  end
 until rpid == pid or computer.uptime() > stime
 if not rpid then return false end
 return true
end

-- ordered packet delivery, layer 4?

function net.send(to,port,ldata)
 local tdata = {}
 if ldata:len() > net.mtu then
  for i = 1, ldata:len(), net.mtu do
   tdata[#tdata+1] = ldata:sub(1,net.mtu)
   ldata = ldata:sub(net.mtu+1)
  end
 else
  tdata = {ldata}
 end
 for k,v in ipairs(tdata) do
  if not net.rsend(to,port,v) then return false end
 end
 return true
end

-- socket stuff, layer 5?

local function cwrite(self,data)
 if self.state == "open" then
  if not net.send(self.addr,self.port,data) then
   self:close()
   return false, "timed out"
  end
 end
end
local function cread(self,length)
 length = length or "\n"
 local rdata = ""
 if type(length) == "number" then
  rdata = self.rbuffer:sub(1,length)
  self.rbuffer = self.rbuffer:sub(length+1)
  return rdata
 elseif type(length) == "string" then
  if length:sub(1,2) == "*a" then
   rdata = self.rbuffer
   self.rbuffer = ""
   return rdata
  elseif length:len() == 1 then
   local pre, post = self.rbuffer:match("(.-)"..length.."(.*)")
   if pre and post then
    self.rbuffer = post
    return pre
   end
   return nil
  end
 end
end

local function socket(addr,port,sclose)
 local conn = {}
 conn.addr,conn.port = addr,tonumber(port)
 conn.rbuffer = ""
 conn.write = cwrite
 conn.read = cread
 conn.state = "open"
 conn.sclose = sclose
 local function listener(_,f,p,d)
  if f == conn.addr and p == conn.port then
   if d == sclose then
    conn:close()
   else
    conn.rbuffer = conn.rbuffer .. d
   end
  end
 end
 local id=event.register("net_msg",listener)
 function conn.close(self)
  event.unregister(id)
  conn.state = "closed"
  net.rsend(addr,port,sclose)
 end
 return conn
end

function net.open(to,port)
 if not net.rsend(to,port,"openstream") then return false, "no ack from host" end
 local st = computer.uptime()+net.streamdelay
 local est = false
 while true do
  local _,from,rport,data = event.pull(st - computer.uptime())
  if to == from and rport == port then
   if tonumber(data) then
    est = true
   end
   break
  end
  if st < computer.uptime() then
   return nil, "timed out"
  end
 end
 if not est then
  return nil, "refused"
 end
 data = tonumber(data)
 sclose = ""
 repeat
  _,from,nport,sclose = uevent.filter("net_msg")
 until from == to and nport == data
 return socket(to,data,sclose)
end

function net.listen(port)
 repeat
  _, from, rport, data = uevent.filter("net_msg")
 until rport == port and data == "openstream"
 local nport = math.random(net.minport,net.maxport)
 local sclose = net.genPacketID()
 net.rsend(from,rport,tostring(nport))
 net.rsend(from,nport,sclose)
 return socket(from,nport,sclose)
end

function net.flisten(port,listener)
 local function helper(_,from,rport,data)
  if rport == port and data == "openstream" then
   local nport = math.random(net.minport,net.maxport)
   local sclose = net.genPacketID()
   net.rsend(from,rport,tostring(nport))
   net.rsend(from,nport,sclose)
   listener(socket(from,nport,sclose))
  end
 end
 event.register("net_msg",helper)
 return helper
end

return net
