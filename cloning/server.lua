local config <const> = require 'cloning.config'
local Crime <const> = require 'server.crime'
local Actions <const> = require 'server.actions'

local core <const> = exports.cobalt_core
local reach <const> = config.maxDistance + 1.5

---@param plate unknown
---@return string?
local function parsePlate(plate)
    if type(plate) ~= 'string' then return end

    local cleaned <const> = plate:upper():match('^%s*(.-)%s*$')

    if #cleaned < config.plateLength.min or #cleaned > config.plateLength.max then return end
    if not cleaned:match('^[A-Z0-9 ]+$') then return end

    return cleaned
end

---@param plate string
---@return boolean
local function isRegistered(plate)
    return core:GetVehicleOwnerByPlate(plate) ~= nil
end

---@param netId integer
---@return integer?
local function vehicleFrom(netId)
    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle ~= 0 and GetEntityType(vehicle) == 2 then
        return vehicle
    end
end

---@param vehicle integer
---@return string
local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$')
end

---@param source integer
---@param vehicle integer
---@return boolean
local function ownedByOther(source, vehicle)
    local owner <const> = core:GetVehicleOwnerByPlate(plateOf(vehicle))

    return owner ~= nil and owner ~= Crime.citizenid(source)
end

lib.callback.register('cobalt_crime:cloning:start', function(source, netId, plate)
    if type(netId) ~= 'number' then return end

    local vehicle <const> = vehicleFrom(netId)

    if not vehicle or not Crime.citizenid(source) then return end
    if #(Crime.coords(source) - GetEntityCoords(vehicle)) > reach then
        return Crime.notify(source, locale('cloning.get_closer'), 'error')
    end

    local newPlate <const> = parsePlate(plate)

    if not newPlate then
        return Crime.notify(source, locale('cloning.bad_plate', config.plateLength.min, config.plateLength.max), 'error')
    end
    if ownedByOther(source, vehicle) then
        return Crime.notify(source, locale('cloning.vin_owned'), 'error')
    end
    if isRegistered(newPlate) then
        return Crime.notify(source, locale('cloning.plate_taken'), 'error')
    end
    if not exports.cobalt_inventory:HasItem(source, config.item) then return end

    local oldPlate <const> = plateOf(vehicle)

    local action <const> = {
        netId = netId,
        oldPlate = oldPlate,
        newPlate = newPlate,
    }

    if not Actions.begin(source, 'cloning', config.durationMs, action) then return end

    return config.durationMs
end)

lib.callback.register('cobalt_crime:cloning:finish', function(source, completed)
    local action <const> = Actions.finish(source, 'cloning', completed == true)

    if not action then return false end

    local vehicle <const> = vehicleFrom(action.netId)

    if not vehicle then
        return Crime.notify(source, locale('common.vehicle_gone'), 'error')
    end
    if #(Crime.coords(source) - GetEntityCoords(vehicle)) > reach then
        return Crime.notify(source, locale('cloning.moved_away'), 'error')
    end
    if isRegistered(action.newPlate) then
        return Crime.notify(source, locale('cloning.plate_taken_meanwhile'), 'error')
    end
    if not exports.cobalt_inventory:RemoveItem(source, config.item, 1, nil, 'cloning') then return false end

    SetVehicleNumberPlateText(vehicle, action.newPlate)

    if GetResourceState('cobalt_vehiclekeys') == 'started' then
        exports.cobalt_vehiclekeys:GiveKey(source, action.newPlate, vehicle)
    end

    Crime.log(source, 'cloning', ('Cloned %s to %s'):format(action.oldPlate, action.newPlate), {
        oldPlate = action.oldPlate,
        newPlate = action.newPlate,
    })
    Crime.notify(source, locale('cloning.done', action.newPlate), 'success')

    return true
end)
