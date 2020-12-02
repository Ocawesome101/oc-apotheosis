-- shared text editor functions and things --

local ed = {}

ed.buf = {}
function ed.buf:load(file)
  checkArg(1, file, "string")
  local file, err = io.open(file, "r")
  if not file then
    return nil, err
  end
  self.lines = {}
  for line in file:lines("l") do
    self.lines[#self.lines + 1] = line
  end
  file:close()
end

function ed.buf:save()
end

return ed
