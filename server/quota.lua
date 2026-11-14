local WINDOW_SECONDS <const> = 60 * 60

---@class CrimeQuota
---@field limit integer
---@field hits table<string, integer[]>
local Quota <const> = {}
Quota.__index = Quota

---@param limit integer payouts allowed per citizenid in a rolling hour
---@return CrimeQuota
function Quota.new(limit)
    return setmetatable({ limit = limit, hits = {} }, Quota)
end

---@param key string
---@return integer[]
function Quota:recent(key)
    local cutoff <const> = os.time() - WINDOW_SECONDS
    local kept <const> = {}

    for _, at in ipairs(self.hits[key] or {}) do
        if at > cutoff then
            kept[#kept + 1] = at
        end
    end

    self.hits[key] = #kept > 0 and kept or nil

    return kept
end

---@param key string
---@return boolean
function Quota:full(key)
    return #self:recent(key) >= self.limit
end

---@param key string
---@return boolean reached true when this payout used up the last one in the hour
function Quota:add(key)
    local recent <const> = self:recent(key)

    recent[#recent + 1] = os.time()
    self.hits[key] = recent

    return #recent >= self.limit
end

return Quota
