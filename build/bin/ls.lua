-- ls --

local fs = require("filesystem")
local argp = require("libargp")
local libvt = require("libvt")
local paths = require("libpath")
local users = require("users")
local permutil = require("permutil")
local textutils = require("textutils")

local args, opts = argp.parse(...)

if opts.help then
  io.stderr:write([[
Usage: ls [OPTION]... [FILE]...
List information about FILEs (the current
directory by default). Sort entries
alphabetically.
]])
  os.exit(0)
end

local w, h = libvt.getResolution()

local colors = {
  dir = 94,
  exec = 92,
  file = 97,
}

local pwd = os.getenv("PWD")
if #args == 0 then
  args[1] = pwd
end

local function esc(n)
  if io.output().tty and not opts.nocolor then
    return string.format("\27[%dm", n)
  end
  return ""
end

local formatted = ""
for i=1, #args, 1 do
  local name = args[i]
  if #args > 1 then
    if #formatted > 0 then
      formatted = formatted .. "\n"
    end
    formatted = formatted .. name .. ":\n"
  end
  local dir = paths.resolve(args[i]) or args[i]

  local dat = fs.stat(dir)
  if not dat then
    io.stderr:write(dir, ": no such directory\n")
    os.exit(1)
  end

  if not dat.isDirectory then
    io.stderr:write(dir, ": not a directory\n")
    os.exit(1)
  end

  local files = fs.list(dir)
  table.sort(files)

  local maxN = 1
  if not opts.l then
    -- find the longest file entry, and trim out those beginning with "."
    local rm = {}
    for i=1, #files, 1 do
      if files[i]:sub(1,1) == "." and not opts.a then
        rm[#rm + 1] = i
        goto cont
      end
      if #files[i] > maxN then
        maxN = #files[i]
      end
      ::cont::
    end
    for i = #rm, 1, -1 do
      table.remove(files, rm[i])
    end
    maxN = maxN + 2
  end
  if maxN >= w then
    opts["1"] = true
  end

  local ln = ""
  for i=1, #files, 1 do
    if opts.l then
      local full = paths.concat(dir, files[i] or "")
      local info, err = fs.stat(full)
      if not info then
        io.stderr:write(err, "\n")
        os.exit(1)
      end
      local ftype = "file"
      if info.isDirectory then
        ftype = "dir"
      elseif permutil.hasPermission(info.permissions, "x") then
        ftype = "exec"
      end
      formatted = string.format("%s%s%s %s %s %8d %s %s%s\27[39m\n",
                              formatted,
                              info.isDirectory and "d" or "-",
                              permutil.tostring(info.permissions),
                              users.userByID(info.owner),
                              users.groupByID(info.group),
                              info.size,
                              os.date("%b %e %H:%M"),
                              esc(colors[ftype]),
                              files[i])
    else
      local full = paths.concat(dir, files[i] or "")
      local info, err = fs.stat(full)
      if not info then
        io.stderr:write(err, "\n")
        os.exit(1)
      end
      local ftype = "file"
      if info.isDirectory then
        ftype = "dir"
      elseif permutil.hasPermission(info.permissions, "x") then
        ftype = "exec"
      end
      ln = string.format("%s\27[%dm%s", ln, colors[ftype], textutils.padRight(files[i] or "unknown", maxN))
      if #ln >= w then
        formatted = string.format("%s%s\n", formatted, ln)
        ln = ""
      end
    end
  end
  
  if #ln > 0 then
    formatted = string.format("%s%s\n", formatted, ln)
  end

  formatted = formatted .. "\27[39m"
end

io.write(formatted)

os.exit(0)

