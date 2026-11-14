local config <const> = require 'server.config'

local core <const> = exports.cobalt_core
local inventory <const> = exports.cobalt_inventory

local Crime <const> = {}

---@param source integer
---@return string?
function Crime.citizenid(source)
    return core:GetPlayer(source)?.PlayerData.citizenid
end

---@param source integer
---@return boolean
function Crime.isDown(source)
    local metadata <const> = core:GetPlayer(source)?.PlayerData.metadata

    if not metadata or metadata.isdead or metadata.inlaststand then return true end

    return GetEntityHealth(GetPlayerPed(source)) <= 100
end

---@param source integer
---@param text string
---@param kind? 'success' | 'error' | 'info' | 'warning'
function Crime.notify(source, text, kind)
    core:Notify(source, { description = text, type = kind or 'info' })
end

---@param source integer
---@return vector3
function Crime.coords(source)
    return GetEntityCoords(GetPlayerPed(source))
end

---@param source integer
---@param coords vector3
---@param radius number
---@return boolean
function Crime.isNear(source, coords, radius)
    return #(Crime.coords(source) - coords) <= radius
end

---@param source integer
---@param item string
---@param count? integer
---@return boolean
function Crime.has(source, item, count)
    return inventory:HasItem(source, item, count or 1)
end

---@param source integer
---@param item string weapon item name
---@return boolean
function Crime.holds(source, item)
    return inventory:GetCurrentWeapon(source)?.name == item
end

---@param source integer
---@param item string
---@return integer
function Crime.count(source, item)
    return inventory:GetItemCount(source, item)
end

---@param source integer
---@param item string
---@param count integer
---@param reason string
---@return boolean
function Crime.give(source, item, count, reason)
    return inventory:AddItem(source, item, count, nil, nil, reason)
end

---@param source integer
---@param item string
---@param count integer
---@param reason string
---@param quiet? boolean skip the "Removed" notification
---@return boolean
function Crime.take(source, item, count, reason, quiet)
    return inventory:RemoveItem(source, item, count, nil, reason, quiet)
end

---@param source integer
---@param amount integer
---@param reason string
---@return boolean
function Crime.payMarked(source, amount, reason)
    return Crime.give(source, config.markedbills, amount, reason)
end

---@param loot { item: string, min: integer, max: integer, chance: number }[]
---@return table<string, integer>
function Crime.rollLoot(loot)
    local awarded <const> = {}

    for _, row in ipairs(loot) do
        local count <const> = math.random() <= row.chance and math.random(row.min, row.max) or 0

        if count > 0 then
            awarded[row.item] = (awarded[row.item] or 0) + count
        end
    end

    return awarded
end

---@param source integer
---@param awarded table<string, integer>
---@param reason string
---@return table<string, integer> given
function Crime.giveAll(source, awarded, reason)
    local given <const> = {}

    for item, count in pairs(awarded) do
        if Crime.give(source, item, count, reason) then
            given[item] = count
        end
    end

    return given
end

---@param source integer
---@param crime string
---@param message string
---@param data? table
---@param level? LogLevel
function Crime.log(source, crime, message, data, level)
    core:LogPlayer(source, ('crime.%s'):format(crime), message, data, level)
end

---@param seconds integer
---@return string
function Crime.duration(seconds)
    return locale('common.duration', seconds // 60, seconds % 60)
end

return Crime
