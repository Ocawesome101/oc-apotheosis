-- cat --

local argp = require("libargp")
local pathutil = require("libpath")

local args, opts = argp.parse(...)

if #args == 0 then
  os.exit(0)
end

for i, file in ipairs(args) do
  local ok, err = pathutil.resolve(file)
  if not ok then
    print("cat: "..err)
    os.exit(1)
  end
  local handle, err = io.open(ok, "r")
  if not handle then
    print("cat: "..err)
    os.exit(1)
  end
  repeat
    local chunk = handle:read(2048)
    io.write(chunk)
  until not chunk
end

io.write("\n")

os.exit(0)