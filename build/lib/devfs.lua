-- devfs lib --

local faux = require("fauxfs")
local class = require("class")
local users = require("users")
local filesystem = require("filesystem")

local object = faux.new("devfs")
filesystem.mount(object, "/dev")

local root = object:resolve("/")
local components = faux.Node(root, true)
root.children["components"] = components

local lib = {}

lib.Adapter = class("adapter")
function lib.Adapter:__init(addr, parent)
  self.node = faux.Node(parent)
  self:adapt(self.node)
  self:incrementOccurrences()
  self:setName()
end

function lib.Adapter:adapt()
end

function lib.Adapter:incrementOccurrences()
end

function lib.Adapter:setName()
end

local function try_get_driver(ctype)
  local try = string.format("devfs.%s", ctype)
  local ok, ret = pcall(require, try)
  if not ok then
    if comp ~= "generic" then
      local try, err = try_get_driver("generic")
      if not try then return nil, err end
      ret = try
    else
      return nil, ret or "driver returned nothing"
    end
  end
  return ret
end

local names = {}
local registered = {}
function lib.register(a, t)
  checkArg(1, a, "string")
  checkArg(2, t, "string")
  if registered[a] then
    return true
  end
  if users.user() ~= 0 then
    return nil, "permission denied"
  end
  local adapter, err = try_get_driver(t)
  if not adapter then
    return nil, err
  end
  components.children[a:sub(1,3)] = adapter(a, components).base
  if adapter.name then
    local new = adapter(a, root).base
    root.children[adapter.name] = new
    names[a] = adapter.name
  end
  registered[a] = true
  return true
end

function lib.unregister(a)
  checkArg(1, a, "string")
  if users.user() ~= 0 then
    return nil, "permission denied"
  end
  registered[a] = nil
  components.children[a:sub(1,3)] = nil
  if names[a] then
    root.children[names[a]] = nil
    names[a] = nil
  end
  return true
end

return lib
