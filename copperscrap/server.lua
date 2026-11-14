local config <const> = require 'copperscrap.config'
local rewards <const> = require 'copperscrap.rewards'
local Crime <const> = require 'server.crime'
local Actions <const> = require 'server.actions'
local Cooldown <const> = require 'server.cooldown'
local Props <const> = require 'server.props'
local Quota <const> = require 'server.quota'

local propCooldown <const> = Props.new('copperscrap', rewards.propCooldownSeconds)
local playerCooldown <const> = Cooldown.new(rewards.playerCooldownSeconds)
local fenceCooldown <const> = Cooldown.new(rewards.fence.cooldownSeconds)
local hourlyQuota <const> = Quota.new(rewards.hourlyLimit)
local fenceCoords <const> = config.fence.coords.xyz

lib.callback.register('cobalt_crime:copperscrap:start', function(source, groupKey, coords)
    if not config.groups[groupKey] or type(coords) ~= 'vector3' then return false end

    local citizenid <const> = Crime.citizenid(source)

    if not citizenid then return false end

    if playerCooldown:remaining(citizenid) > 0 then
        return Crime.notify(source, locale('common.slow_down'), 'error')
    end
    if hourlyQuota:full(citizenid) then
        return Crime.notify(source, locale('common.lay_low'), 'error')
    end
    if propCooldown:remaining(coords) > 0 then
        return Crime.notify(source, locale('copperscrap.already_stripped'), 'error')
    end
    if not Crime.isNear(source, coords, rewards.maxDistance) then
        return Crime.notify(source, locale('common.get_closer'), 'error')
    end
    if not Crime.has(source, config.tool) then
        return Crime.notify(source, locale('copperscrap.need_cutters'), 'error')
    end

    local action <const> = {
        citizenid = citizenid,
        coords = coords,
        group = groupKey,
    }

    if not Actions.begin(source, 'copperscrap', config.durationMs, action) then return false end

    return config.durationMs
end)

---@param source integer
---@param action { citizenid: string, coords: vector3, group: string }
local function payOut(source, action)
    local given <const> = Crime.giveAll(source, Crime.rollLoot(rewards.loot[action.group]), 'copperscrap')
    local parts <const> = {}

    for item, count in pairs(given) do
        parts[#parts + 1] = ('%d %s'):format(count, item)
    end

    propCooldown:start(action.coords)
    Crime.log(source, 'copperscrap', 'Stripped a unit for scrap', {
        group = action.group,
        given = given,
    })

    if hourlyQuota:add(action.citizenid) then
        local message <const> = ('Reached the limit of %d units an hour'):format(rewards.hourlyLimit)

        Crime.log(source, 'copperscrap', message, nil, 'warn')
    end

    local message <const> = #parts > 0 and locale('copperscrap.pulled', table.concat(parts, ', ')) or locale('copperscrap.nothing_worth')

    Crime.notify(source, message, 'success')
end

---@param source integer
local function shock(source)
    if math.random() < rewards.breakChance and Crime.take(source, config.tool, 1, 'copperscrap shock') then
        return Crime.notify(source, locale('copperscrap.shocked_broke'), 'error')
    end

    Crime.notify(source, locale('copperscrap.shocked'), 'error')
end

---@alias CopperOutcome 'stripped' | 'shocked' | 'cancelled'

lib.callback.register('cobalt_crime:copperscrap:finish', function(source, outcome)
    local started <const> = Actions.get(source, 'copperscrap')

    if not started then return false end

    local action <const> = Actions.finish(source, 'copperscrap', outcome == 'stripped')

    if outcome == 'shocked' then
        playerCooldown:start(started.citizenid)
        shock(source)

        return true
    end

    if not action then return false end
    if not Crime.isNear(source, action.coords, rewards.maxDistance) then
        return Crime.notify(source, locale('common.moved_off'), 'error')
    end

    playerCooldown:start(action.citizenid)

    if math.random() < rewards.liveChance then
        shock(source)

        return 'shocked'
    end

    payOut(source, action)

    return true
end)

lib.callback.register('cobalt_crime:copperscrap:stock', function(source)
    if not Crime.isNear(source, fenceCoords, rewards.fence.maxDistance) then return {} end

    ---@type table<string, integer>
    local stock <const> = {}

    for _, item in ipairs(config.fence.items) do
        local count <const> = Crime.count(source, item)

        if count > 0 then
            stock[item] = count
        end
    end

    return stock
end)

lib.callback.register('cobalt_crime:copperscrap:sell', function(source, item, count)
    local price <const> = rewards.fence.prices[item]

    if not price or math.type(count) ~= 'integer' then return false end
    if count < 1 or count > config.fence.maxBatch then
        return Crime.notify(source, locale('copperscrap.batch_limit', config.fence.maxBatch), 'error')
    end

    local citizenid <const> = Crime.citizenid(source)

    if not citizenid then return false end
    if not Crime.isNear(source, fenceCoords, rewards.fence.maxDistance) then return false end
    if fenceCooldown:remaining(citizenid) > 0 then
        return Crime.notify(source, locale('copperscrap.still_counting'), 'error')
    end
    if Crime.count(source, item) < count or not Crime.take(source, item, count, 'copperscrap fence') then
        return Crime.notify(source, locale('copperscrap.not_enough', count), 'error')
    end

    local pay <const> = price * count

    if not Crime.payMarked(source, pay, 'copperscrap fence') then
        Crime.give(source, item, count, 'copperscrap fence refund')

        return Crime.notify(source, locale('copperscrap.cant_carry_cash'), 'error')
    end

    fenceCooldown:start(citizenid)
    Crime.log(source, 'copperscrap', ('Sold %d %s for %d marked bills'):format(count, item, pay), {
        item = item,
        count = count,
        pay = pay,
    })
    Crime.notify(source, locale('copperscrap.sold', count, pay), 'success')

    return true
end)
