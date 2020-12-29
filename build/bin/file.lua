-- file: print the type of file --

local f = ...

local fs = require("filesystem")
local p = require("libpath")
local dat = fs.stat(p.resolve(f, true))

if dat then
  print(dat.isDirectory and "directory" or "file")
end
