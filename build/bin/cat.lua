-- cat --

local argp = require("libargp")
local pathutil = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 then
  while true do
    io.write(io.read())
  end
end

for i, file in ipairs(args) do
  local ok, err = pathutil.resolve(file)
  if not ok then
    io.stderr:write("cat: ", err, "\n")
    os.exit(1)
  end
  local handle, err = io.open(ok, "r")
  if not handle then
    io.stderr:write("cat: ", err, "\n")
    os.exit(1)
  end
  -- default buffer size is 512, this might be too small
  handle.bufferSize = 2048
  repeat
    local chunk = handle:read(64)
    if chunk then io.write(chunk) end
  until not chunk
end

io.write("\n")

os.exit(0)
