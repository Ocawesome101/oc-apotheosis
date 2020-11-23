-- file path utility functions --

local lib = {}

function lib.concat(...)
  local args = table.pack(...)
  for i=1, args.n, 1 do
    checkArg(i, args[i], "string")
  end
  return "/" .. (table.concat(args, "/"):gsub("([/\\]+)", "/"))
end

return lib
