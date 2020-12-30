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
  io.write(handle:read("a"))
end

io.write("\n")

os.exit(0)
