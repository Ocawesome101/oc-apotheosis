-- wrap `io' to use relative paths --

local old_open = io.open

function io.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  local full_path, err = require("libpath").resolve(file, mode == "w")
  if not full_path then
    return nil, err
  end
  return old_open(full_path, mode or "r")
end
