local config <const> = require 'parkingmeters.config'
local Crime <const> = require 'client.crime'
local Props <const> = require 'client.props'

local RIGHT_HAND <const> = 57005
local ANIM_FLAG_FULL_BODY <const> = 0
local ANIM_FLAG_FULL_BODY_LOOP <const> = 1

local strike <const> = config.strike
local sounds <const> = config.sounds
local particles <const> = config.particles

local busy = false

---@class MeterSequence
---@field running boolean

---@param tool { item: string, equipped?: boolean }
---@return boolean
local function hasTool(tool)
    if tool.equipped then
        return cache.weapon == joaat(tool.item)
    end

    return Crime.has(tool.item)
end

---@param name string
---@param coords vector3
local function playSound(name, coords)
    local sound <const> = sounds[name]

    if sound.bank then
        RequestScriptAudioBank(sound.bank, false)
    elseif sound.ambientBank then
        RequestAmbientAudioBank(sound.ambientBank, false)
    end

    PlaySoundFromCoord(-1, sound.name, coords.x, coords.y, coords.z, sound.set, false, 20, false)
end

---@param effect string
---@param coords vector3
local function playParticle(effect, coords)
    lib.requestNamedPtfxAsset(particles.asset)
    UseParticleFxAsset(particles.asset)
    StartParticleFxNonLoopedAtCoord(effect, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

---@alias MeterFx 'strike' | 'burst' | 'pick' | 'open' | 'coins'

RegisterNetEvent('cobalt_crime:parkingmeters:fx', function(kind, coords)
    playSound(kind, coords)

    if kind == 'strike' or kind == 'burst' then
        playParticle(particles[kind], coords)
    end
end)

---@param kind MeterFx
---@param coords vector3
local function sendFx(kind, coords)
    TriggerServerEvent('cobalt_crime:parkingmeters:fx', kind, coords)
end

---@param ped integer
---@param dict string
---@param clip string
---@param sequence MeterSequence
---@param phase number
---@return boolean reached
local function waitForPhase(ped, dict, clip, sequence, phase)
    while sequence.running do
        if not IsEntityPlayingAnim(ped, dict, clip, 3) then return false end
        if GetEntityAnimCurrentTime(ped, dict, clip) >= phase then return true end

        Wait(0)
    end

    return false
end

---@param ped integer
---@param entity integer
---@return vector3
local function impactPoint(ped, entity)
    local meter <const> = GetEntityCoords(entity)
    local hand <const> = GetPedBoneCoords(ped, RIGHT_HAND, 0.0, 0.0, 0.0)

    return vec3(meter.x, meter.y, hand.z)
end

---@param dict string
---@param clip string
---@param flag integer
local function play(dict, clip, flag)
    TaskPlayAnim(cache.ped, dict, clip, 4.0, -4.0, -1, flag, 0.0, false, false, false)
end

---@param sequence MeterSequence
---@param entity integer
local function grabCoins(sequence, entity)
    if not sequence.running then return end

    lib.requestAnimDict(config.grab.dict)
    play(config.grab.dict, config.grab.clip, ANIM_FLAG_FULL_BODY_LOOP)
    Wait(600)

    if sequence.running then
        sendFx('coins', GetEntityCoords(entity))
    end
end

---@param entity integer
---@param sequence MeterSequence
local function smashSequence(entity, sequence)
    local ped <const> = cache.ped

    lib.requestAnimDict(strike.dict)

    for index, clip in ipairs(strike.clips) do
        if not sequence.running then return end

        TaskPlayAnim(ped, strike.dict, clip, 8.0, -4.0, -1, ANIM_FLAG_FULL_BODY, 0.0, false, false, false)
        SetEntityAnimSpeed(ped, strike.dict, clip, strike.rate)
        Wait(50)

        if waitForPhase(ped, strike.dict, clip, sequence, strike.impactPhase) then
            sendFx(index == #strike.clips and 'burst' or 'strike', impactPoint(ped, entity))
        end

        waitForPhase(ped, strike.dict, clip, sequence, 0.9)
    end

    grabCoins(sequence, entity)
end

---@param entity integer
---@param kind table
---@param sequence MeterSequence
local function pickSequence(entity, kind, sequence)
    local pick <const> = kind.pick
    local coords <const> = GetEntityCoords(entity)

    lib.requestAnimDict(pick.enter.dict)
    play(pick.enter.dict, pick.enter.clip, ANIM_FLAG_FULL_BODY)
    Wait(50)
    waitForPhase(cache.ped, pick.enter.dict, pick.enter.clip, sequence, 0.95)

    local turn = 0

    while sequence.running do
        turn += 1

        local loop <const> = pick.loops[(turn - 1) % #pick.loops + 1]

        play(loop.dict, loop.clip, ANIM_FLAG_FULL_BODY)
        sendFx('pick', coords)
        Wait(50)
        waitForPhase(cache.ped, loop.dict, loop.clip, sequence, 0.95)
    end
end

---@param entity integer
---@param kind table
local function finishPick(entity, kind)
    local exit <const> = kind.pick.exit

    sendFx('open', GetEntityCoords(entity))
    play(exit.dict, exit.clip, ANIM_FLAG_FULL_BODY)
    Wait(50)
    waitForPhase(cache.ped, exit.dict, exit.clip, { running = true }, 0.95)
    grabCoins({ running = true }, entity)
    Wait(900)
end

---@param toolKey string
---@param kind table
---@param entity integer
local function empty(toolKey, kind, entity)
    local isCrowbar <const> = toolKey == 'crowbar'

    busy = true

    if not Crime.approach(entity, isCrowbar and kind.strikeStandOff or kind.pickStandOff) then
        busy = false

        return Crime.notify(locale('parkingmeters.cant_reach'), 'error')
    end

    local durationMs <const> = lib.callback.await('cobalt_crime:parkingmeters:start', false, toolKey, GetEntityCoords(entity))

    if not durationMs then
        busy = false

        return
    end

    ---@type MeterSequence
    local sequence <const> = { running = true }

    CreateThread(function()
        if isCrowbar then
            smashSequence(entity, sequence)
        else
            pickSequence(entity, kind, sequence)
        end
    end)

    local completed <const> = Crime.progress(locale(('parkingmeters.tools.%s.progress'):format(toolKey)), durationMs)

    sequence.running = false

    if completed and not isCrowbar then
        finishPick(entity, kind)
    end

    ClearPedTasks(cache.ped)
    lib.callback.await('cobalt_crime:parkingmeters:finish', false, completed)
    busy = false
end

for kindKey, kind in pairs(config.kinds) do
    local options <const> = {}

    for toolKey, tool in pairs(config.tools) do
        options[#options + 1] = {
            name = ('cobalt_crime:parkingmeters:%s:%s'):format(kindKey, toolKey),
            label = locale(('parkingmeters.tools.%s.label'):format(toolKey)),
            icon = tool.icon,
            distance = config.range,
            canInteract = function(entity)
                return not busy and Crime.onFoot() and hasTool(tool) and not Props.isEmptied('parkingmeters', entity)
            end,
            onSelect = function(data)
                empty(toolKey, kind, data.entity)
            end,
        }
    end

    exports.ox_target:addModel(kind.models, options)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and busy then ClearPedTasks(cache.ped) end
end)
