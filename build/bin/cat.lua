-- cat --

local argp = require("libargp")
local pathutil = require("libpath")

local args, opts = argp.parse(...)

for i, file in ipairs(args) do
  local ok, err = pathutil.resolve(file)
  if not ok then
    print(err)
    os.exit(1)
  end
  local handle, err = io.open(ok)
  if not handle then
    print(err)
    os.exit(1)
  end
  repeat
    local chunk = handle:read(2048)
    io.write(chunk)
  until not chunk
end

io.write("\n")

os.exit()
