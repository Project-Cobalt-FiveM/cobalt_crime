local config <const> = require 'chopshop.config'
local rewards <const> = require 'chopshop.rewards'
local Crime <const> = require 'server.crime'
local Actions <const> = require 'server.actions'
local Cooldown <const> = require 'server.cooldown'

local cooldown <const> = Cooldown.new(rewards.cooldownSeconds)

---@type table<integer, string>
local categoryByModel <const> = {}

for model, vehicle in pairs(exports.cobalt_core:GetShared('Vehicles')) do
    categoryByModel[joaat(model)] = vehicle.category
end

---@param source integer
---@param vehicle integer
---@return boolean
local function inYard(source, vehicle)
    if not Crime.isNear(source, config.center, config.radius) then return false end

    return #(GetEntityCoords(vehicle) - config.center) <= config.radius
end

---@param vehicle integer
---@return string
local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$')
end

lib.callback.register('cobalt_crime:chopshop:start', function(source, netId)
    if type(netId) ~= 'number' then return end

    local citizenid <const> = Crime.citizenid(source)
    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if not citizenid or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local wait <const> = cooldown:remaining(citizenid)

    if wait > 0 then
        return Crime.notify(source, locale('chopshop.crew_busy', Crime.duration(wait)), 'error')
    end
    if not inYard(source, vehicle) then
        return Crime.notify(source, locale('chopshop.outside_yard'), 'error')
    end

    local category <const> = categoryByModel[GetEntityModel(vehicle)]

    if rewards.excludedTypes[GetVehicleType(vehicle)] or rewards.excludedCategories[category] then
        return Crime.notify(source, locale('chopshop.refused'), 'error')
    end

    local plate <const> = plateOf(vehicle)
    local owner <const> = plate ~= '' and exports.cobalt_core:GetVehicleOwnerByPlate(plate) or nil

    if owner == citizenid then
        return Crime.notify(source, locale('chopshop.own_vehicle'), 'error')
    end

    local action <const> = {
        citizenid = citizenid,
        netId = netId,
        plate = plate,
        owned = owner ~= nil,
        premium = rewards.premiumCategories[category] == true,
    }

    if not Actions.begin(source, 'chopshop', config.durationMs, action) then return end

    return config.durationMs
end)

lib.callback.register('cobalt_crime:chopshop:finish', function(source, completed)
    local action <const> = Actions.finish(source, 'chopshop', completed == true)

    if not action then return false end

    local vehicle <const> = NetworkGetEntityFromNetworkId(action.netId)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return Crime.notify(source, locale('common.vehicle_gone'), 'error')
    end
    if not inYard(source, vehicle) then
        return Crime.notify(source, locale('chopshop.left_yard'), 'error')
    end

    DeleteEntity(vehicle)
    cooldown:start(action.citizenid)

    local parts <const> = action.premium and rewards.premium or rewards.basic
    local given <const> = Crime.giveAll(source, Crime.rollLoot(parts), 'chopshop')
    local bonus <const> = action.owned and math.random(rewards.ownedBonus.min, rewards.ownedBonus.max) or 0

    if bonus > 0 then
        Crime.payMarked(source, bonus, 'chopshop')
    end

    Crime.log(source, 'chopshop', ('Chopped %s'):format(action.plate), {
        plate = action.plate,
        owned = action.owned,
        premium = action.premium,
        given = given,
        bonus = bonus,
    })
    local message <const> = bonus > 0 and locale('chopshop.stripped_bonus', bonus) or locale('chopshop.stripped')

    Crime.notify(source, message, 'success')

    return true
end)
