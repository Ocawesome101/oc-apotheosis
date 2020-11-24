-- futil: file utils --

local fs = require("filesystem")

local lib = {}

function lib.delete(path)
  local info, err = fs.stat(path)
  if info == nil then
    return false, err
  elseif info.isDirectory then
    local stat = true
    for _, file in ipairs(fs.list(path)) do
      local info = fs.stat(path .. "/" .. file)
      if info.isDirectory then
        lib.delete(path .. "/" .. file)
      end
      fs.remove(path .. "/" .. file)
    end
  end
  return fs.remove(path)
end

return lib
