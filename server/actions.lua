local SLACK_MS <const> = 1500

---@class CrimeAction
---@field crime string
---@field readyAt integer game timer
---@field data table

---@type table<integer, CrimeAction>
local pending <const> = {}

local Actions <const> = {}

---@param source integer
---@return boolean
function Actions.busy(source)
    return pending[source] ~= nil
end

---@param source integer
---@param crime string
---@return table? data the running action's data
function Actions.get(source, crime)
    local action <const> = pending[source]

    if action and action.crime == crime then
        return action.data
    end
end

---@param source integer
---@param crime string
---@param durationMs integer
---@param data table
---@return boolean started
function Actions.begin(source, crime, durationMs, data)
    if pending[source] then return false end

    pending[source] = { crime = crime, readyAt = GetGameTimer() + durationMs - SLACK_MS, data = data }

    return true
end

---@param source integer
---@param crime string
---@param completed boolean
---@return table? data nil when cancelled, finished early or never started
function Actions.finish(source, crime, completed)
    local action <const> = pending[source]

    if not action or action.crime ~= crime then return end

    pending[source] = nil

    if completed and GetGameTimer() >= action.readyAt then
        return action.data
    end
end

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)

return Actions
