local config <const> = require 'parkingmeters.config'
local rewards <const> = require 'parkingmeters.rewards'
local Crime <const> = require 'server.crime'
local Actions <const> = require 'server.actions'
local Cooldown <const> = require 'server.cooldown'
local Props <const> = require 'server.props'
local Quota <const> = require 'server.quota'

local FX_REACH <const> = 2.5
local FX_LIMIT <const> = 40
local FX_KINDS <const> = { strike = true, burst = true, pick = true, open = true, coins = true }

local propCooldown <const> = Props.new('parkingmeters', rewards.propCooldownSeconds)
local playerCooldown <const> = Cooldown.new(rewards.playerCooldownSeconds)
local hourlyQuota <const> = Quota.new(rewards.hourlyLimit)

---@param source integer
---@param tool { item: string, equipped?: boolean }
---@return boolean
local function hasTool(source, tool)
    if tool.equipped then
        return Crime.holds(source, tool.item)
    end

    return Crime.has(source, tool.item)
end

lib.callback.register('cobalt_crime:parkingmeters:start', function(source, toolKey, coords)
    local tool <const> = config.tools[toolKey]

    if not tool or type(coords) ~= 'vector3' then return end

    local citizenid <const> = Crime.citizenid(source)

    if not citizenid then return end

    if playerCooldown:remaining(citizenid) > 0 then
        return Crime.notify(source, locale('common.slow_down'), 'error')
    end
    if hourlyQuota:full(citizenid) then
        return Crime.notify(source, locale('common.lay_low'), 'error')
    end
    if propCooldown:remaining(coords) > 0 then
        return Crime.notify(source, locale('parkingmeters.already_empty'), 'error')
    end
    if not Crime.isNear(source, coords, rewards.maxDistance) then
        return Crime.notify(source, locale('common.get_closer'), 'error')
    end
    if not hasTool(source, tool) then
        return Crime.notify(source, locale('parkingmeters.need_tool'), 'error')
    end

    local action <const> = {
        citizenid = citizenid,
        coords = coords,
        tool = toolKey,
        fx = 0,
    }

    if not Actions.begin(source, 'parkingmeters', tool.durationMs, action) then return end

    return tool.durationMs
end)

lib.callback.register('cobalt_crime:parkingmeters:finish', function(source, completed)
    local action <const> = Actions.finish(source, 'parkingmeters', completed == true)

    if not action then return false end
    if not Crime.isNear(source, action.coords, rewards.maxDistance + 0.5) then
        return Crime.notify(source, locale('common.moved_off'), 'error')
    end
    if propCooldown:remaining(action.coords) > 0 then return false end

    local reward <const> = rewards.tools[action.tool]
    local payout <const> = math.random(reward.min, reward.max)

    propCooldown:start(action.coords)
    playerCooldown:start(action.citizenid)

    if not Crime.payMarked(source, payout, 'parkingmeters') then
        return Crime.notify(source, locale('parkingmeters.pockets_full'), 'error')
    end

    Crime.log(source, 'parkingmeters', ('Emptied a meter for %d marked bills'):format(payout), {
        tool = action.tool,
        payout = payout,
    })
    Crime.notify(source, locale('parkingmeters.took', payout), 'success')

    if hourlyQuota:add(action.citizenid) then
        local message <const> = ('Reached the limit of %d meters an hour'):format(rewards.hourlyLimit)

        Crime.log(source, 'parkingmeters', message, nil, 'warn')
    end

    return true
end)

RegisterNetEvent('cobalt_crime:parkingmeters:fx', function(kind, coords)
    local source <const> = source
    local action <const> = Actions.get(source, 'parkingmeters')

    if not action or not FX_KINDS[kind] or type(coords) ~= 'vector3' then return end
    if #(coords - action.coords) > FX_REACH or action.fx >= FX_LIMIT then return end

    action.fx += 1

    for _, player in ipairs(lib.getNearbyPlayers(coords, config.fxDistance)) do
        TriggerClientEvent('cobalt_crime:parkingmeters:fx', player.id, kind, coords)
    end
end)
