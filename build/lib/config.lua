-- configuration utility --

local class = require("class")

local _cobj = class()
function _cobj:load(file)
  self.file = file
  local ok, err = io.open(file)
  if not ok then
    self.cfg = {}
    return true
  end
  local data = ok:read("a")
  ok:close()
  self.cfg = require("serializer").unserialize(data) or {}
  return true
end

function _cobj:set(k, v)
  self.cfg[k] = v
end

function _cobj:save(file)
  checkArg(1, file, "string", "nil")
  local file = file or self.file
  if not file then
    return nil, "no file"
  end
  local data = require("serializer").serialize(self.cfg or {})
  if self.__use_return then
    data = "return " .. data
  end
  local handle, err = io.open(file, "w")
  if not handle then
    return nil, err
  end
  handle:write(data)
  handle:close()
  return true
end

function _cobj:__init(file, sret)
  checkArg(1, file, "string", "nil")
  self.__use_return = not not sret
  if file then self:load(file) end
end

local lib = {}

function lib.new(...)
  return _cobj(...)
end

return lib
