local config <const> = require 'drugruns.config'
local rewards <const> = require 'drugruns.rewards'
local Crime <const> = require 'server.crime'
local Cooldown <const> = require 'server.cooldown'

local INVENTORY_LOAD_TIMEOUT <const> = 10000

local cooldown <const> = Cooldown.new(rewards.cooldownSeconds)

---@class DrugRun
---@field citizenid string
---@field handler integer
---@field buyer integer
---@field delivering boolean

---@type table<integer, DrugRun>
local runs <const> = {}

---@param handlerIndex integer
---@return integer?
local function pickBuyer(handlerIndex)
    local origin <const> = config.handlers[handlerIndex].coords.xyz
    local pool <const> = {}

    for index, buyer in ipairs(config.buyers) do
        if #(origin - buyer.coords.xyz) >= rewards.minBuyerDistance then
            pool[#pool + 1] = index
        end
    end

    if #pool > 0 then
        return pool[math.random(#pool)]
    end
end

---@param source integer
---@param reason string
local function loseRun(source, reason)
    local run <const> = runs[source]

    if not run or run.delivering then return end

    runs[source] = nil
    cooldown:start(run.citizenid)
    Crime.take(source, config.package, 1, 'drugruns lost')
    TriggerClientEvent('cobalt_crime:drugruns:ended', source)
    Crime.notify(source, reason, 'error')
    Crime.log(source, 'drugruns', 'Lost a package run', { handler = run.handler, buyer = run.buyer, reason = reason })
end

lib.callback.register('cobalt_crime:drugruns:pickup', function(source, handlerIndex)
    local handler <const> = config.handlers[handlerIndex]
    local citizenid <const> = Crime.citizenid(source)

    if not handler or not citizenid or runs[source] then return end
    if not Crime.isNear(source, handler.coords.xyz, rewards.maxDistance) then return end

    local wait <const> = cooldown:remaining(citizenid)

    if wait > 0 then
        return Crime.notify(source, locale('drugruns.come_back', Crime.duration(wait)), 'error')
    end
    if Crime.has(source, config.package) then
        return Crime.notify(source, locale('drugruns.holding_package'), 'error')
    end

    local buyer <const> = pickBuyer(handlerIndex)

    if not buyer then
        return Crime.notify(source, locale('drugruns.no_buyer'), 'error')
    end

    runs[source] = { citizenid = citizenid, handler = handlerIndex, buyer = buyer, delivering = false }

    if not Crime.give(source, config.package, 1, 'drugruns pickup') then
        runs[source] = nil

        return Crime.notify(source, locale('drugruns.hands_full'), 'error')
    end

    Crime.log(source, 'drugruns', 'Picked up a package', { handler = handlerIndex, buyer = buyer })

    return buyer
end)

lib.callback.register('cobalt_crime:drugruns:deliver', function(source)
    local run <const> = runs[source]

    if not run or run.delivering then return false end
    if not Crime.isNear(source, config.buyers[run.buyer].coords.xyz, rewards.maxDistance) then
        return Crime.notify(source, locale('drugruns.get_closer'), 'error')
    end

    run.delivering = true

    if not Crime.take(source, config.package, 1, 'drugruns delivery') then
        run.delivering = false

        return Crime.notify(source, locale('drugruns.no_package'), 'error')
    end

    local pay <const> = math.random(rewards.payout.min, rewards.payout.max)

    runs[source] = nil
    cooldown:start(run.citizenid)

    if not Crime.payMarked(source, pay, 'drugruns delivery') then
        Crime.notify(source, locale('drugruns.no_room_for_cash'), 'error')
    else
        Crime.notify(source, locale('drugruns.paid', pay), 'success')
    end

    Crime.log(source, 'drugruns', ('Delivered a package for %d marked bills'):format(pay), {
        handler = run.handler,
        buyer = run.buyer,
        pay = pay,
    })

    return true
end)

AddStateBagChangeHandler('carry', nil, function(bagName, _, value)
    local source <const> = GetPlayerFromStateBagName(bagName)

    if source == 0 or not runs[source] or value == config.package then return end

    loseRun(source, locale('drugruns.dropped'))
end)

AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    local source <const> = GetPlayerFromStateBagName(bagName)

    if source == 0 or value ~= true then return end

    loseRun(source, locale('drugruns.died'))
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', function(source)
    loseRun(source, locale('drugruns.walked_away'))
end)

AddEventHandler('cobalt_core:Server:PlayerLoaded', function(player)
    local source <const> = player.PlayerData.source
    local loaded <const> = pcall(lib.waitFor, function()
        return Player(source).state.inventoryLoaded
    end, nil, INVENTORY_LOAD_TIMEOUT)

    if not loaded or runs[source] then return end

    local stray <const> = Crime.count(source, config.package)

    if stray > 0 then
        Crime.take(source, config.package, stray, 'drugruns stray package', true)
    end
end)

AddEventHandler('playerDropped', function()
    runs[source] = nil
end)
