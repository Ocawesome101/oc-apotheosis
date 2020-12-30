-- faux filesystem object --

local uuid = require("uuid")
local libpath = require("libpath")

local _fs = {}

local function mknew(parent)
  return {
    isDirectory = false,
    parent = parent,
    methods = {}
  }
end

local function resolve(self, path, last_nonexistent)
  local cur = self.tree
  if path == "/" or path == "" then
    return cur
  end
  local segments = libpath.split(path)
  for i=1, #segments, 1 do
    if not cur.isDirectory then
      return nil, path .. ": not a directory"
    end
    if not (cur.children[segments[i]] or (i == #segments and last_nonexistent)) then
      return nil, path .. ": no such file or directory"
    end
    cur = cur.children[segments[i]] or mknew(cur)
  end
  return cur
end

function _fs:stat(file)
  local node, err = resolve(self, file)
  if not node then
    return nil, err
  end
end

local lib = {}

function lib.new(label)
  checkArg(1, label, "string", "nil")
  local new = setmetatable({
    label = label,
    tree = {}
  }, {__index = _fs})
end

return lib
