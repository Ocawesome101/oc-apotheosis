-- MOTDs --

local lib = {}

local m = {
  "Paragon is to Monolith as GNU Hurd is to Linux.",
  "Paragon is like GNU Hurd - in development for a long time and still unfinished.",
  "Why are you here?  Go use Monolith instead!",
  "Please contribute to this thing.  I'm tired of working on it!",
  "Paragon persists in refusing to finish itself.",
  "Coming in 2032 to a then-ancient Minecraft mod near you!"
}

function lib.random()
  return m[math.random(1, #m)]
end

return lib
