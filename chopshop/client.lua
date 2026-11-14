local config <const> = require 'chopshop.config'
local Crime <const> = require 'client.crime'

local busy = false

---@param entity integer
---@return boolean
local function inYard(entity)
    return #(GetEntityCoords(entity) - config.center) <= config.radius
end

---@param vehicle integer
local function strip(vehicle)
    local durationMs <const> = lib.callback.await('cobalt_crime:chopshop:start', false, NetworkGetNetworkIdFromEntity(vehicle))

    if not durationMs then return end

    busy = true
    local completed <const> = Crime.progress(locale('chopshop.progress'), durationMs, config.anim)
    busy = false

    lib.callback.await('cobalt_crime:chopshop:finish', false, completed)
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'cobalt_crime:chopshop:strip',
        label = locale('chopshop.strip'),
        icon = 'fas fa-screwdriver-wrench',
        distance = 3.0,
        canInteract = function(entity)
            return not busy and Crime.onFoot() and NetworkGetEntityIsNetworked(entity) and inYard(entity)
        end,
        onSelect = function(data)
            strip(data.entity)
        end,
    },
})

lib.points.new({
    coords = config.center,
    distance = 30.0,
    nearby = function()
        DrawMarker(1, config.center.x, config.center.y, config.center.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            config.radius * 2.0, config.radius * 2.0, 1.0, 239, 68, 68, 80, false, false, 2, false, nil, nil, false)
    end,
})

local blip <const> = Crime.blip(config.center, 446, 1, locale('chopshop.blip'))

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then
        RemoveBlip(blip)
    end
end)
