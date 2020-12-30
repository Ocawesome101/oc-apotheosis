-- classes --

local function inherit(tbl, ...)
  tbl = tbl or {}
  local new = setmetatable({}, {__index = tbl, __call = inherit, __metatable = {}})
  if new.__init then
    new:__init(...)
  end
  return new
end

local function class(tbl, name)
  checkArg(1, tbl, "table", "string", "nil")
  checkArg(2, name, "string", "nil")
  local name = name
  if type(tbl) == "string" then
    name = tbl
    tbl = nil
  end
  return setmetatable(tbl or {}, {__call = inherit, __metatable = {}, __name = name})
end

return class
