-- mtrsh - the Minitel Remote SHell --

local mtel = require("minitel")
local buffer = require("buffer")
local process = require("process")

local function spawn_getty()
  local ok, err = loadfile("/sbin/getty.lua")
  if ok then
    process.spawn(ok, "[getty-mtrsh]")
  end
end

local function init(socket)
  local buffered = buffer.new(socket, "rw")
  buffered:setvbuf("no")
  buffered.bufferSize = false
  buffered.tty = true
  io.input(buffered)
  io.output(buffered)
  io.stderr = buffered
  spawn_getty()
end

mtel.flisten(62, init)

while true do coroutine.yield(1) end
