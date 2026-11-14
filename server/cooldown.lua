---@class CrimeCooldown
---@field seconds integer
---@field ends table<string | integer, integer>
local Cooldown <const> = {}
Cooldown.__index = Cooldown

---@param seconds integer
---@return CrimeCooldown
function Cooldown.new(seconds)
    return setmetatable({ seconds = seconds, ends = {} }, Cooldown)
end

---@param key string | integer
---@return integer seconds
function Cooldown:remaining(key)
    return math.max(0, (self.ends[key] or 0) - os.time())
end

---@param key string | integer
function Cooldown:start(key)
    self.ends[key] = os.time() + self.seconds
end

return Cooldown
