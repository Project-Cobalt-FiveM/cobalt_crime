local config <const> = require 'storerobbery.config'
local rewards <const> = require 'storerobbery.rewards'
local Crime <const> = require 'server.crime'
local Cooldown <const> = require 'server.cooldown'

local STATE_PREFIX <const> = 'cobalt_crime:store:'
local BAG_STATE <const> = 'cobaltCrimeBag'
local HAND_REACH <const> = 4.0
local DROP_REACH <const> = 5.0

local inventory <const> = exports.cobalt_inventory
local cooldown <const> = Cooldown.new(rewards.cooldownSeconds)
local bagModel <const> = joaat(config.bagModel)

---@alias StorePhase 'holdup' | 'register' | 'throw' | 'cower' | 'dead'

---@class StoreRobbery
---@field key string
---@field shopId string
---@field index integer
---@field coords vector3
---@field robber integer
---@field payout integer
---@field startedAt integer GetGameTimer when the hold-up began
---@field phase StorePhase

---@class StoreBag
---@field entity integer
---@field key string
---@field amount integer

---@type table<string, StoreRobbery>
local robberies <const> = {}

---@type table<integer, string>
local robbing <const> = {}

---@type table<integer, StoreBag>
local bags <const> = {}

---@type table<string, true>
local shownStores <const> = {}

---@param shopId string
---@param index integer
---@return string
local function storeKey(shopId, index)
    return ('%s:%d'):format(shopId, index)
end

---@param robbery StoreRobbery
---@param phase StorePhase
local function setPhase(robbery, phase)
    robbery.phase = phase
    shownStores[robbery.key] = true
    GlobalState[STATE_PREFIX .. robbery.key] = { phase = phase, robber = robbery.robber }
end

---@param key string
local function clearStore(key)
    shownStores[key] = nil
    GlobalState[STATE_PREFIX .. key] = nil
end

---@param robbery StoreRobbery
---@return boolean
local function isActive(robbery)
    return robberies[robbery.key] == robbery
end

---@param robbery StoreRobbery
---@param phase 'cower' | 'dead'
local function close(robbery, phase)
    if not isActive(robbery) then return end

    robberies[robbery.key] = nil
    robbing[robbery.robber] = nil
    cooldown:start(robbery.key)
    setPhase(robbery, phase)

    SetTimeout(config.timing.recoverMs, function()
        if not robberies[robbery.key] then
            clearStore(robbery.key)
        end
    end)
end

---@param netId integer
local function removeBag(netId)
    local bag <const> = bags[netId]

    if not bag then return end

    bags[netId] = nil

    if DoesEntityExist(bag.entity) then
        DeleteEntity(bag.entity)
    end
end

---@param entity integer
---@return integer owner server id, -1 when nobody owns it yet
local function waitForOwner(entity)
    local deadline <const> = GetGameTimer() + 1000
    local owner = NetworkGetEntityOwner(entity)

    while owner == -1 and GetGameTimer() < deadline do
        Wait(50)
        owner = NetworkGetEntityOwner(entity)
    end

    return owner
end

---@param origin vector3
---@param target? vector3
---@return vector3
local function tossVelocity(origin, target)
    if not target then
        return vec3(0.0, 0.0, 0.0)
    end

    local flat <const> = vec3(target.x - origin.x, target.y - origin.y, 0.0)
    local length <const> = #flat

    if length < 0.01 then
        return vec3(0.0, 0.0, rewards.throwLift)
    end

    return flat / length * rewards.throwSpeed + vec3(0.0, 0.0, rewards.throwLift)
end

---@param key string
---@param origin vector3
---@param amount integer
---@param target? vector3
local function spawnBag(key, origin, amount, target)
    local entity <const> = CreateObjectNoOffset(bagModel, origin.x, origin.y, origin.z, true, true, false)
    local deadline <const> = GetGameTimer() + 2000

    while not DoesEntityExist(entity) do
        if GetGameTimer() > deadline then return end

        Wait(0)
    end

    local netId <const> = NetworkGetNetworkIdFromEntity(entity)

    Entity(entity).state:set(BAG_STATE, true, true)
    bags[netId] = { entity = entity, key = key, amount = amount }

    SetTimeout(rewards.bagLifetimeSeconds * 1000, function()
        removeBag(netId)
    end)

    local owner <const> = waitForOwner(entity)

    if owner ~= -1 then
        TriggerClientEvent('cobalt_crime:storerobbery:toss', owner, netId, tossVelocity(origin, target))
    end
end

---@param robbery StoreRobbery
---@return boolean
local function robberStays(robbery)
    if GetPlayerPed(robbery.robber) == 0 or Crime.isDown(robbery.robber) then return false end

    return Crime.isNear(robbery.robber, robbery.coords, rewards.abortDistance)
end

---@param robbery StoreRobbery
---@param ms integer
---@return boolean active
local function hold(robbery, ms)
    local ends <const> = GetGameTimer() + ms

    while GetGameTimer() < ends do
        if not isActive(robbery) then return false end

        if not robberStays(robbery) then
            Crime.log(robbery.robber, 'storerobbery', 'Ran off before the bag came out', {
                store = robbery.key,
                phase = robbery.phase,
            })
            close(robbery, 'cower')

            return false
        end

        Wait(250)
    end

    return isActive(robbery)
end

---@param robbery StoreRobbery
local function throwBag(robbery)
    setPhase(robbery, 'throw')
    Wait(config.timing.releaseMs)

    if not isActive(robbery) then return end

    local hand <const> = lib.callback.await('cobalt_crime:storerobbery:hand', robbery.robber, robbery.shopId, robbery.index)

    if not isActive(robbery) then return end

    local handValid <const> = type(hand) == 'vector3' and #(hand - robbery.coords) <= HAND_REACH
    local origin <const> = handValid and hand or robbery.coords + vec3(0.0, 0.0, 1.0)
    local target <const> = GetPlayerPed(robbery.robber) ~= 0 and Crime.coords(robbery.robber) or nil

    close(robbery, 'cower')
    spawnBag(robbery.key, origin, robbery.payout, target)
    Crime.log(robbery.robber, 'storerobbery', 'The shop keeper threw out the bag', {
        store = robbery.key,
        payout = robbery.payout,
    })
end

---@param robbery StoreRobbery
local function run(robbery)
    if not hold(robbery, config.timing.holdupMs) then return end

    setPhase(robbery, 'register')

    if not hold(robbery, config.timing.registerMs) then return end

    throwBag(robbery)
end

---@return integer
local function policeOnDuty()
    local onDuty <const> = exports.cobalt_management:GetDutyCount('leo')

    return onDuty
end

---@param robbery StoreRobbery
---@param label string
local function alertPolice(robbery, label)
    if GetResourceState('cobalt_police') ~= 'started' then return end

    exports.cobalt_police:SendDispatch({
        title = locale('storerobbery.dispatch_title'),
        code = '10-90',
        description = locale('storerobbery.dispatch_description', label),
        coords = robbery.coords,
        priority = 1,
    })
end

lib.callback.register('cobalt_crime:storerobbery:start', function(source, shopId, index)
    if not config.shops[shopId] or math.type(index) ~= 'integer' or robbing[source] then return false end

    local locations <const> = inventory:GetShopLocations(shopId)
    local location <const> = locations and locations[index]

    if not location or not Crime.citizenid(source) then return false end

    local key <const> = storeKey(shopId, index)

    if robberies[key] then
        return Crime.notify(source, locale('storerobbery.in_progress'), 'error')
    end
    if cooldown:remaining(key) > 0 then
        return Crime.notify(source, locale('storerobbery.recently_robbed'), 'error')
    end
    if not inventory:GetCurrentWeapon(source) then return false end
    if not Crime.isNear(source, location.xyz, rewards.startDistance) then return false end
    if policeOnDuty() < rewards.minPolice then
        return Crime.notify(source, locale('storerobbery.not_enough_police'), 'error')
    end

    local robbery <const> = {
        key = key,
        shopId = shopId,
        index = index,
        coords = location.xyz,
        robber = source,
        payout = math.random(rewards.payout.min, rewards.payout.max),
        startedAt = GetGameTimer(),
    } --[[@as StoreRobbery]]

    robberies[key] = robbery
    robbing[source] = key
    setPhase(robbery, 'holdup')

    local shopLabel <const> = locale(('storerobbery.shops.%s'):format(shopId))

    alertPolice(robbery, shopLabel)
    Crime.log(source, 'storerobbery', ('Held up the %s'):format(shopLabel), { store = key, payout = robbery.payout })

    CreateThread(function()
        run(robbery)
    end)

    return true
end)

RegisterNetEvent('cobalt_crime:storerobbery:killed', function(shopId, index, coords)
    local source <const> = source

    if type(shopId) ~= 'string' or math.type(index) ~= 'integer' then return end

    local robbery <const> = robberies[storeKey(shopId, index)]

    if not robbery or robbery.robber ~= source then return end
    if not Crime.isNear(source, robbery.coords, rewards.reportDistance) then return end
    if GetGameTimer() - robbery.startedAt < config.timing.holdupMs then return end

    local dropAt <const> = type(coords) == 'vector3' and #(coords - robbery.coords) <= DROP_REACH and coords or robbery.coords
    local amount <const> = math.floor(robbery.payout * rewards.killedPayoutShare)

    close(robbery, 'dead')
    Crime.log(source, 'storerobbery', 'Killed the shop keeper', {
        store = robbery.key,
        robber = robbery.robber,
        dropped = amount,
    })

    if amount > 0 then
        spawnBag(robbery.key, dropAt + vec3(0.0, 0.0, 0.5), amount)
    end
end)

lib.callback.register('cobalt_crime:storerobbery:collect', function(source, netId)
    local bag <const> = bags[netId]

    if not bag then
        return Crime.notify(source, locale('storerobbery.bag_taken'), 'error')
    end
    if not DoesEntityExist(bag.entity) then
        bags[netId] = nil

        return Crime.notify(source, locale('storerobbery.bag_gone'), 'error')
    end
    if not Crime.citizenid(source) then return false end
    if #(Crime.coords(source) - GetEntityCoords(bag.entity)) > rewards.pickupDistance then
        return Crime.notify(source, locale('storerobbery.get_closer'), 'error')
    end

    bags[netId] = nil

    if not Crime.payMarked(source, bag.amount, 'storerobbery') then
        bags[netId] = bag

        return Crime.notify(source, locale('storerobbery.no_room'), 'error')
    end

    DeleteEntity(bag.entity)
    cooldown:start(bag.key)
    Crime.log(source, 'storerobbery', ('Picked up %d marked bills'):format(bag.amount), {
        store = bag.key,
        amount = bag.amount,
    })
    Crime.notify(source, locale('storerobbery.bag_holds', bag.amount), 'success')

    return true
end)

AddEventHandler('playerDropped', function()
    local key <const> = robbing[source]
    local robbery <const> = key and robberies[key]

    if robbery then
        close(robbery, 'cower')
    end
end)

for shopId in pairs(config.shops) do
    for index in ipairs(inventory:GetShopLocations(shopId) or {}) do
        clearStore(storeKey(shopId, index))
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for netId in pairs(bags) do
        removeBag(netId)
    end

    for key in pairs(shownStores) do
        clearStore(key)
    end
end)
