-- sh - basic shell --

local fs = require("filesystem")
local pipe = require("pipe")
local shell = require("shell")
local paths = require("libpath")
local users = require("users")
local process = require("process")
local computer = require("computer")
local readline = require("readline")

os.setenv("PWD", os.getenv("PWD") or "/")
os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin")
os.setenv("SHLVL", (os.getenv("SHLVL") or "0") + 1)

local pgsub = {
  ["\\w"] = function()
    return (os.getenv("PWD") and os.getenv("HOME") and os.getenv("PWD"):gsub("^"..(os.getenv("HOME")).."?", "~")) or "/"
  end,
  ["\\W"] = function() return os.getenv("PWD"):match("%/(.+)$") end,
  ["\\h"] = function() return os.getenv("HOSTNAME") or "localhost" end,
  ["\\s"] = function() return "sh" end,
  ["\\v"] = function() return "1.0.0" end,
  ["\\a"] = function() return "\a" end,
  ["\\u"] = function() return users.userByID(users.user()) end,
  ["\\%$"] = function() return users.user() == 0 and "#" or "$" end
}

local exit = false
local oldExit = shell.exit
function shell.exit(n)
  exit = n
  shell.exit = oldExit
end

local function parse_prompt(prompt)
  local ret = prompt
  for pat, rep in pairs(pgsub) do
    ret = ret:gsub(pat, rep() or "")
  end
  return ret
end

os.setenv("PS1", os.getenv("PS1") or "\\u|\\s-\\v: \\w\\$ ")

process.sethandler(process.signals.SIGINT, function() io.write("^C\n",parse_prompt(os.getenv("PS1"))) end)

local hist = {}
while not exit do
  io.write(parse_prompt(os.getenv("PS1")))
  local input = readline({history = hist})
  if input then
    shell.execute(input)
  end
end

os.exit(exit)
