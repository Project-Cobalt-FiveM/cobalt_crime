local config <const> = require 'cloning.config'
local Crime <const> = require 'client.crime'

local busy = false

---@param itemId string
local function clonePlate(itemId)
    if busy then return end
    if not Crime.onFoot() then
        return Crime.notify(locale('cloning.step_out'), 'error')
    end

    local vehicle <const> = lib.getClosestVehicle(GetEntityCoords(cache.ped), config.maxDistance, false)

    if not vehicle then
        return Crime.notify(locale('cloning.no_vehicle'), 'error')
    end

    local label <const> = locale('cloning.dialog_plate', config.plateLength.min, config.plateLength.max)
    local values <const> = exports.cobalt_core:InputDialog(locale('cloning.dialog_title'), {
        { type = 'input', label = label, required = true },
    })

    if not values then return end

    local netId <const> = NetworkGetNetworkIdFromEntity(vehicle)
    local durationMs <const> = lib.callback.await('cobalt_crime:cloning:start', false, netId, values[1], itemId)

    if not durationMs then return end

    busy = true
    local completed <const> = Crime.progress(locale('cloning.progress'), durationMs, config.anim)
    busy = false

    lib.callback.await('cobalt_crime:cloning:finish', false, completed)
end

exports('UseCloner', function(event, _, slot)
    if event == 'usedItem' then clonePlate(slot.id) end
end)
