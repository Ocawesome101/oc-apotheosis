-- faux filesystem object --

local uuid = require("uuid")
local class = require("class")
local libpath = require("libpath")

local _fs = {}

-- nodes must implement their own instance of fauxfs.Handle
local _fhandle = class("fhandle")
function _fhandle:__init(hid, mode)
  if hid and mode then
    self.hid = hid
    self.mode = {}
    for c in mode:gmatch(".") do
      self.mode[c] = true
    end
  end
end

function _fhandle:read()
  return nil, "bad file descriptor"
end

function _fhandle:write()
  return nil, "bad file descriptor"
end

function _fhandle:seek()
  return nil, "bad file descriptor"
end

function _fhandle:close()
  self.closed = true
end

local Node = class("fnode")
function Node:__init(parent, isdir)
  self.isDirectory = isdir
  self.parent = parent
  if isdir then
    self.children = {}
  else
    self.methods = {}
  end
end

function _fs:resolve(path, last_nonexistent)
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
    cur.children[segments[i]] = cur.children[segments[i]] or Node(cur)
    cur = cur.children[segments[i]]
  end
  return cur
end

function _fs:stat(file)
  local node, err = self:resolve(file)
  if not node then
    return nil, err
  end
  return {
    permissions = 27, -- rw-rw----
    isDirectory = node.isDirectory,
    size = (node.methods and node.methods.size or function() return 0 end)(node),
    lastModified = 1000000000, -- sometime in 2001, eh
    owner = 0,
    group = -1,
  }
end

function _fs:open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string")
  local node, err = self:resolve(file)
  if not node then
    return nil, err
  end
  if node.isDirectory then
    return nil, file..": is a directory"
  end
  if not node.methods.handle then
    return nil, file..": cannot be opened"
  end
  local hid = self.__last_handle + 1
  self.__last_handle = hid
  self.handles[hid] = node.methods.handle(hid, mode)
  return hid
end

function _fs:read(fd, n)
  if not self.handles[fd] then return nil, "bad file descriptor" end
  return self.handles[fd]:read(n)
end

function _fs:write(fd, t)
  if not self.handles[fd] then return nil, "bad file descriptor" end
  return self.handles[fd]:write(t)
end

function _fs:seek(fd, wh, of)
  if not self.handles[fd] then return nil, "bad file descriptor" end
  return self.handles[fd]:seek(wh, of)
end

function _fs:close()
  if not self.handles[fd] then return nil, "bad file descriptor" end
  self.handles[fd]:close()
  self.handles[fd] = nil
end

setmetatable(_fs, {__index = function()
  return function()
    return nil, "functionality not implemented"
  end
end})

local lib = {}
lib.Handle = _fhandle
lib.Node = Node

function lib.new(label, fstype)
  checkArg(1, label, "string", "nil")
  checkArg(2, fstype, "string", "nil")
  local new = setmetatable({
    fstype = fstype or "fauxfs",
    address = uuid.next(),
    label = label,
    tree = Node({}, true),
    handles = {},
    __last_handle = 0,
  }, {__index = _fs, __metatable = {}, __name = "fauxfs"})
  new.tree.parent = new.tree
  return new
end

return lib
