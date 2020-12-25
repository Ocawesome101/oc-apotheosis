-- base stuff.  primes the users api.

do
  -- uid:password:username:home:shell:permissions
  local format = "(%d+):(%g+):(%g+):(%g+):(%g+):(%d+)"
  local handle, err = io.open("/etc/passwd", "r")
  if not handle then
    log(31, "failed: " .. err)
    while true do coroutine.yield() end
  end
  local data = handle:read("a")
  handle:close()
  local pwdata = {}
  for line in data:gmatch("[^\n]+") do
    local uid, hash, name, home, shell, perms = line:match(format)
    pwdata[tonumber(uid)] = {
      hash = hash,
      name = name,
      home = home,
      shell = shell,
      permissions = perms
    }
  end
  require("users").prime(pwdata)
end
