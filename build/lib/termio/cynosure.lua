-- handler for the Cynosure terminal

local handler = {}

handler.keyBackspace = 8

function handler.setRaw(raw)
  if raw then
    io.write("\27?3;12c\27[8m")
  else
    io.write("\27?13;2c\27[28m")
  end
end

function handler.cursorVisible(v)
  io.write(v and "\27?4c" or "\27?14c")
end

function handler.ttyIn()
  return not not io.input().tty
end

function handler.ttyOut()
  return not not io.output().tty
end

return handler
