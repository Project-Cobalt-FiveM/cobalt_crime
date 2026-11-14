local config <const> = require 'storerobbery.config'
local Crime <const> = require 'client.crime'

local STATE_PREFIX <const> = 'cobalt_crime:store:'
local AIM_PROBE_FLAGS <const> = 1 | 4 | 8 | 16
local AIM_PROBE_LENGTH <const> = 20.0
local UNARMED <const> = `WEAPON_UNARMED`
local RIGHT_HAND <const> = 57005
local SCENE_RATE <const> = 1148846080

local inventory <const> = exports.cobalt_inventory
local anims <const> = config.anims
local timing <const> = config.timing

---@class StoreState
---@field phase 'holdup' | 'register' | 'throw' | 'cower' | 'dead'
---@field robber integer

---@class StoreScene
---@field phase string
---@field ped integer
---@field robber integer
---@field bag? integer
---@field watching? boolean

---@type table<string, StoreScene>
local scenes <const> = {}

---@param key string
---@return string shopId
---@return integer index
local function parseKey(key)
    local shopId, index = key:match('^(.+):(%d+)$')

    return shopId, tonumber(index) --[[@as integer]]
end

---@param scene StoreScene
local function dropLocalBag(scene)
    if scene.bag and DoesEntityExist(scene.bag) then
        DeleteEntity(scene.bag)
    end

    scene.bag = nil
end

---@param coords vector3
---@return integer bag
local function createLocalBag(coords)
    local model <const> = lib.requestModel(config.bagModel)
    local bag <const> = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(model)

    return bag
end

---@param key string
---@param ped integer
---@param scene StoreScene
local function watchForDeath(key, ped, scene)
    if scene.watching then return end

    scene.watching = true

    while scenes[key] == scene and scene.ped == ped and DoesEntityExist(ped) do
        if IsEntityDead(ped) then
            if scene.phase ~= 'dead' and GetPedSourceOfDeath(ped) == cache.ped then
                local shopId, index = parseKey(key)

                TriggerServerEvent('cobalt_crime:storerobbery:killed', shopId, index, GetEntityCoords(ped))
            end

            break
        end

        Wait(250)
    end

    scene.watching = false
end

---@param ped integer
---@return integer? till
local function findTill(ped)
    local coords <const> = GetEntityCoords(ped)
    local till <const> = GetClosestObjectOfType(
        coords.x, coords.y, coords.z,
        config.tillSearchRadius,
        config.tillModel,
        false, false, false
    )

    return till ~= 0 and till or nil
end

---@class TillFrame
---@field origin vector3
---@field rotation vector3
---@field facesClerk boolean the till's own rotation already puts the clerk behind it

---@param ped integer
---@param till integer
---@return TillFrame
local function tillFrame(ped, till)
    local dict <const>, clip <const> = anims.scene.dict, anims.scene.ped
    local origin <const> = GetEntityCoords(till)
    local rotation <const> = GetEntityRotation(till, 2)
    local clerk <const> = GetEntityCoords(ped).xy

    ---@param yaw number
    ---@return number
    local function startDistance(yaw)
        local start <const> = GetAnimInitialOffsetPosition(
            dict, clip,
            origin.x, origin.y, origin.z,
            rotation.x, rotation.y, yaw,
            0.0, 2
        )

        return #(start.xy - clerk)
    end

    local flipped <const> = rotation.z + 180.0
    local facesClerk <const> = startDistance(rotation.z) <= startDistance(flipped)

    return {
        origin = origin,
        rotation = vec3(rotation.x, rotation.y, facesClerk and rotation.z or flipped),
        facesClerk = facesClerk,
    }
end

---@type table<string, fun(key: string, ped: integer, scene: StoreScene)>
local phases <const> = {}

function phases.holdup(key, ped, scene)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    lib.playAnim(ped, anims.handsUp.dict, anims.handsUp.clip, 2.0, -2.0, -1, 1)
    watchForDeath(key, ped, scene)
end

function phases.register(key, ped, scene)
    local dict <const> = anims.scene.dict
    local till <const> = findTill(ped)

    lib.requestAnimDict(dict)

    if scene.phase ~= 'register' then return end

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearPedTasks(ped)
    dropLocalBag(scene)

    if not till then
        TaskPlayAnim(ped, dict, anims.scene.ped, 2.0, -2.0, -1, 0, 0.0, false, false, false)
        RemoveAnimDict(dict)

        return watchForDeath(key, ped, scene)
    end

    local frame <const> = tillFrame(ped, till)
    local origin <const>, rotation <const> = frame.origin, frame.rotation
    local sceneId <const> = CreateSynchronizedScene(origin.x, origin.y, origin.z, rotation.x, rotation.y, rotation.z, 2)

    scene.bag = createLocalBag(origin)

    TaskSynchronizedScene(ped, sceneId, dict, anims.scene.ped, timing.sceneBlendIn, -4.0, 1, 0, SCENE_RATE, 0)
    PlaySynchronizedEntityAnim(scene.bag, sceneId, anims.scene.bag, dict, 1.0, -1.0, 0, SCENE_RATE)

    if frame.facesClerk then
        PlaySynchronizedEntityAnim(till, sceneId, anims.scene.till, dict, 1.0, -1.0, 0, SCENE_RATE)
    end

    RemoveAnimDict(dict)
    watchForDeath(key, ped, scene)
end

function phases.throw(key, ped, scene)
    local robberPlayer <const> = GetPlayerFromServerId(scene.robber)
    local robberPed <const> = robberPlayer ~= -1 and GetPlayerPed(robberPlayer) or 0

    dropLocalBag(scene)
    ClearPedTasks(ped)

    if robberPed ~= 0 then
        local from, to = GetEntityCoords(ped), GetEntityCoords(robberPed)

        SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
    end

    local bag <const> = createLocalBag(GetEntityCoords(ped))

    AttachEntityToEntity(
        bag, ped, GetPedBoneIndex(ped, RIGHT_HAND),
        0.12, 0.0, -0.02,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    scene.bag = bag
    lib.playAnim(ped, anims.throw.dict, anims.throw.clip, 8.0, -8.0, -1, 0)

    SetTimeout(timing.releaseMs, function()
        if scene.bag == bag then
            dropLocalBag(scene)
        end
    end)

    watchForDeath(key, ped, scene)
end

function phases.cower(_, ped, scene)
    dropLocalBag(scene)
    lib.requestAnimDict(anims.cower.dict)
    lib.playAnim(ped, anims.cower.dict, anims.cower.intro, 4.0, -4.0, -1, 2)
    Wait(math.floor(GetAnimDuration(anims.cower.dict, anims.cower.intro) * 1000))

    if scene.phase == 'cower' and scene.ped == ped then
        lib.playAnim(ped, anims.cower.dict, anims.cower.loop, 4.0, -4.0, -1, 1)
    end
end

function phases.dead(_, ped, scene)
    dropLocalBag(scene)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 0)
end

---@param key string
local function reset(key)
    local scene <const> = scenes[key]

    if not scene then return end

    scenes[key] = nil
    dropLocalBag(scene)
    TriggerEvent('cobalt_inventory:client:resetShopPed', parseKey(key))
end

---@param key string
---@param state? StoreState
local function apply(key, state)
    if not state then
        return reset(key)
    end

    local ped <const> = inventory:GetShopPed(parseKey(key))

    if not ped then return end

    local scene = scenes[key]

    if scene and scene.phase == state.phase and scene.ped == ped then return end

    scene = scene or {} --[[@as StoreScene]]
    scene.phase = state.phase
    scene.ped = ped
    scene.robber = state.robber
    scenes[key] = scene

    phases[state.phase](key, ped, scene)
end

AddStateBagChangeHandler(nil, 'global', function(_, stateKey, value)
    if stateKey:sub(1, #STATE_PREFIX) ~= STATE_PREFIX then return end

    local key <const> = stateKey:sub(#STATE_PREFIX + 1)

    CreateThread(function()
        apply(key, value)
    end)
end)

AddEventHandler('cobalt_inventory:client:shopPedSpawned', function(shopId, index)
    local key <const> = ('%s:%d'):format(shopId, index)
    local state <const> = GlobalState[STATE_PREFIX .. key]

    if not state or not config.shops[shopId] then return end

    CreateThread(function()
        apply(key, state)
    end)
end)

lib.callback.register('cobalt_crime:storerobbery:hand', function(shopId, index)
    local ped <const> = inventory:GetShopPed(shopId, index)

    if ped then
        return GetPedBoneCoords(ped, RIGHT_HAND, 0.0, 0.0, 0.0)
    end
end)

RegisterNetEvent('cobalt_crime:storerobbery:toss', function(netId, velocity)
    local deadline <const> = GetGameTimer() + 1000
    local entity = NetworkGetEntityFromNetworkId(netId)

    while (entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < deadline do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end

    if entity == 0 or not NetworkHasControlOfEntity(entity) then return end

    ActivatePhysics(entity)
    SetEntityVelocity(entity, velocity.x, velocity.y, velocity.z)
end)

---@return vector3
local function cameraDirection()
    local rotation <const> = GetGameplayCamRot(2)
    local pitch <const> = math.rad(rotation.x)
    local yaw <const> = math.rad(rotation.z)
    local flat <const> = math.abs(math.cos(pitch))

    return vec3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
end

---@param ped integer
---@return boolean
local function crosshairOn(ped)
    local from <const> = GetGameplayCamCoord()
    local to <const> = from + cameraDirection() * AIM_PROBE_LENGTH
    local probe <const> = StartExpensiveSynchronousShapeTestLosProbe(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        AIM_PROBE_FLAGS, cache.ped, 7
    )
    local _, hit <const>, _, _, entity <const> = GetShapeTestResult(probe)

    return hit == 1 and entity == ped
end

---@return boolean
local function isFreeAiming()
    if not cache.weapon or cache.weapon == UNARMED then return false end

    return IsPlayerFreeAiming(cache.playerId)
end

---@param ped integer
---@return boolean
local function isAimingAt(ped)
    if not isFreeAiming() then return false end
    if IsPlayerFreeAimingAtEntity(cache.playerId, ped) then return true end

    local found <const>, target <const> = GetEntityPlayerIsFreeAimingAt(cache.playerId)

    if found and target == ped then return true end

    return crosshairOn(ped)
end

---@class AimPoint : CPoint
---@field shopId string
---@field index integer
---@field key string
---@field aimStart? integer
---@field lastSeen integer
---@field triggered boolean

---@param point AimPoint
local function resetAim(point)
    point.aimStart = nil
    point.triggered = false
end

---@param point AimPoint
local function watchAim(point)
    if not point.aimStart and not isFreeAiming() then return end

    local ped <const> = inventory:GetShopPed(point.shopId, point.index)

    if not ped or GlobalState[STATE_PREFIX .. point.key] then
        return resetAim(point)
    end

    local now <const> = GetGameTimer()

    if isAimingAt(ped) then
        point.lastSeen = now
        point.aimStart = point.aimStart or now
    elseif now - point.lastSeen > config.aimGraceMs then
        return resetAim(point)
    end

    if point.triggered or not point.aimStart or now - point.aimStart < config.aimHoldMs then return end

    point.triggered = true

    CreateThread(function()
        lib.callback.await('cobalt_crime:storerobbery:start', false, point.shopId, point.index)
    end)
end

for shopId in pairs(config.shops) do
    for index, location in ipairs(inventory:GetShopLocations(shopId) or {}) do
        lib.points.new({
            coords = location.xyz,
            distance = config.aimRange,
            shopId = shopId,
            index = index,
            key = ('%s:%d'):format(shopId, index),
            lastSeen = 0,
            triggered = false,
            nearby = watchAim,
            onExit = resetAim,
        })
    end
end

exports.ox_target:addModel(config.bagModel, {
    {
        name = 'cobalt_crime:storerobbery:collect',
        label = locale('storerobbery.grab_bag'),
        icon = 'fas fa-sack-dollar',
        distance = 2.0,
        canInteract = function(entity)
            if not Crime.onFoot() or not NetworkGetEntityIsNetworked(entity) then return false end

            return Entity(entity).state.cobaltCrimeBag == true
        end,
        onSelect = function(data)
            local netId <const> = NetworkGetNetworkIdFromEntity(data.entity)

            if not Crime.progress(locale('storerobbery.grabbing_bag'), config.pickupMs, anims.pickup) then return end

            lib.callback.await('cobalt_crime:storerobbery:collect', false, netId)
        end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for key, scene in pairs(scenes) do
        dropLocalBag(scene)
        TriggerEvent('cobalt_inventory:client:resetShopPed', parseKey(key))
    end
end)
