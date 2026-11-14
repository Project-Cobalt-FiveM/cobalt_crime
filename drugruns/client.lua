local config <const> = require 'drugruns.config'
local Crime <const> = require 'client.crime'

local box <const> = lib.load('@cobalt_inventory.data.items')[config.package].carry
local handoff <const> = config.handoff

---@type table<integer, integer>
local peds <const> = {}

---@type table<integer, integer> buyer ped to the box it walks off with
local leaving <const> = {}

---@class DrugRunClient
---@field buyer integer
---@field point CPoint
---@field blip integer

---@type DrugRunClient?
local run

local busy = false

---@param key integer
---@param data { coords: vector4, model: string, scenario?: string }
---@param option table
---@return CPoint
local function pedPoint(key, data, option)
    return lib.points.new({
        coords = data.coords.xyz,
        distance = config.pedDistance,
        onEnter = function()
            local ped <const> = Crime.spawnPed(data.model, data.coords, data.scenario)

            exports.ox_target:addLocalEntity(ped, { option })
            peds[key] = ped
        end,
        onExit = function()
            local ped <const> = peds[key]

            if not ped then return end

            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
            peds[key] = nil
        end,
    })
end

---@param ped integer
---@return integer prop
local function holdBox(ped)
    local model <const> = lib.requestModel(box.model)
    local coords <const> = GetEntityCoords(ped)
    local prop <const> = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(
        prop, ped, GetPedBoneIndex(ped, box.bone),
        box.pos.x, box.pos.y, box.pos.z,
        box.rot.x, box.rot.y, box.rot.z,
        true, true, false, true, 1, true
    )

    return prop
end

---@param ped integer
---@param clip string
local function playHandoff(ped, clip)
    TaskPlayAnim(ped, handoff.dict, clip, 8.0, -8.0, handoff.durationMs, 0, 0.0, false, false, false)
end

---@param ped integer
local function carryBox(ped)
    lib.requestAnimDict(box.anim.dict)
    TaskPlayAnim(ped, box.anim.dict, box.anim.clip, 8.0, -8.0, -1, box.anim.flag or 49, 0.0, false, false, false)
end

---@param ped integer
---@param key integer
local function walkOff(ped, key)
    local prop <const> = holdBox(ped)

    peds[key] = nil
    leaving[ped] = prop
    exports.ox_target:removeLocalEntity(ped)
    FreezeEntityPosition(ped, false)
    carryBox(ped)
    TaskWanderStandard(ped, 10.0, 10)
    SetEntityAsNoLongerNeeded(ped)

    SetTimeout(config.walkOffMs, function()
        if not leaving[ped] then return end

        leaving[ped] = nil
        DeleteEntity(prop)
        DeleteEntity(ped)
    end)
end

local function endRun()
    if not run then return end

    run.point:onExit()
    run.point:remove()
    RemoveBlip(run.blip)
    run = nil
end

---@param coords vector3
---@return integer blip
local function buyerBlip(coords)
    local blip <const> = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, config.blip.sprite)
    SetBlipColour(blip, config.blip.colour)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, config.blip.colour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('drugruns.blip'))
    EndTextCommandSetBlipName(blip)

    return blip
end

---@return boolean
local function carrying()
    return LocalPlayer.state.carry == config.package
end

---@param key integer
local function deliver(key)
    local ped <const> = peds[key]

    if busy or not ped then return end

    busy = true

    if not Crime.approach(ped, handoff.standOff) then
        busy = false

        return Crime.notify(locale('drugruns.cant_reach'), 'error')
    end

    lib.requestAnimDict(handoff.dict)
    Crime.face(ped, cache.ped)
    playHandoff(ped, handoff.take)
    Wait(handoff.transferMs)

    if lib.callback.await('cobalt_crime:drugruns:deliver', false) then
        playHandoff(cache.ped, handoff.give)
        walkOff(ped, key)
        endRun()
    end

    RemoveAnimDict(handoff.dict)
    busy = false
end

---@param buyerIndex integer
local function startRun(buyerIndex)
    local buyer <const> = config.buyers[buyerIndex]
    local key <const> = -buyerIndex

    local point <const> = pedPoint(key, buyer, {
        name = 'cobalt_crime:drugruns:deliver',
        label = locale('drugruns.hand_over'),
        icon = 'fas fa-handshake',
        distance = config.range,
        canInteract = function()
            return not busy and carrying()
        end,
        onSelect = function()
            deliver(key)
        end,
    })

    run = { buyer = buyerIndex, point = point, blip = buyerBlip(buyer.coords.xyz) }
    Crime.notify(locale('drugruns.run_started'))
end

---@param index integer
local function collect(index)
    local ped <const> = peds[index]

    if busy or run or not ped then return end

    busy = true

    if not Crime.approach(ped, handoff.standOff) then
        busy = false

        return Crime.notify(locale('drugruns.cant_reach'), 'error')
    end

    lib.requestAnimDict(handoff.dict)
    Crime.face(ped, cache.ped)

    local prop <const> = holdBox(ped)

    playHandoff(ped, handoff.give)
    playHandoff(cache.ped, handoff.take)
    Wait(handoff.transferMs)

    local buyerIndex <const> = lib.callback.await('cobalt_crime:drugruns:pickup', false, index)

    DeleteEntity(prop)
    RemoveAnimDict(handoff.dict)
    Wait(handoff.durationMs - handoff.transferMs)

    local scenario <const> = config.handlers[index].scenario

    if scenario and DoesEntityExist(ped) then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    if buyerIndex then
        startRun(buyerIndex)
    end

    busy = false
end

for index, handler in ipairs(config.handlers) do
    pedPoint(index, handler, {
        name = ('cobalt_crime:drugruns:pickup:%d'):format(index),
        label = locale('drugruns.ask_work'),
        icon = 'fas fa-box',
        distance = config.range,
        canInteract = function()
            return not busy and run == nil and not carrying()
        end,
        onSelect = function()
            collect(index)
        end,
    })
end

RegisterNetEvent('cobalt_crime:drugruns:ended', endRun)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, ped in pairs(peds) do
        DeleteEntity(ped)
    end

    for ped, prop in pairs(leaving) do
        DeleteEntity(prop)
        DeleteEntity(ped)
    end

    if run then
        RemoveBlip(run.blip)
    end
end)
