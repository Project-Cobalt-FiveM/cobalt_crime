local propKey <const> = require 'shared.propkey'

local SAME_PROP_RADIUS <const> = 1.5

---@class PropCooldown
---@field name string
---@field seconds integer
---@field ends table<string, integer>
---@field spots table<string, vector3>
local PropCooldown <const> = {}
PropCooldown.__index = PropCooldown

---@type table<string, PropCooldown>
local registry <const> = {}

local Props <const> = {}

---@param name string
---@param seconds integer
---@return PropCooldown
function Props.new(name, seconds)
    local cooldown <const> = setmetatable({ name = name, seconds = seconds, ends = {}, spots = {} }, PropCooldown)

    registry[name] = cooldown

    return cooldown
end

---@param coords vector3
---@return integer seconds
function PropCooldown:remaining(coords)
    local now <const> = os.time()

    for key, spot in pairs(self.spots) do
        if #(spot - coords) <= SAME_PROP_RADIUS then return math.max(0, (self.ends[key] or 0) - now) end
    end

    return 0
end

---@param coords vector3
function PropCooldown:start(coords)
    local key <const> = propKey(coords)
    local endsAt <const> = os.time() + self.seconds

    self.ends[key] = endsAt
    self.spots[key] = coords
    TriggerClientEvent('cobalt_crime:props:emptied', -1, self.name, key, true)

    SetTimeout(self.seconds * 1000, function()
        if self.ends[key] ~= endsAt then return end

        self.ends[key] = nil
        self.spots[key] = nil
        TriggerClientEvent('cobalt_crime:props:emptied', -1, self.name, key, false)
    end)
end

lib.callback.register('cobalt_crime:props:emptied', function()
    ---@type table<string, string[]>
    local emptied <const> = {}
    local now <const> = os.time()

    for name, cooldown in pairs(registry) do
        local keys <const> = {}

        for key, endsAt in pairs(cooldown.ends) do
            if endsAt > now then
                keys[#keys + 1] = key
            end
        end

        emptied[name] = keys
    end

    return emptied
end)

return Props
