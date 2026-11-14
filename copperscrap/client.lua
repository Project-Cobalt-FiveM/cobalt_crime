local config <const> = require 'copperscrap.config'
local Crime <const> = require 'client.crime'
local Props <const> = require 'client.props'

local core <const> = exports.cobalt_core
local fence <const> = config.fence
local fenceLabel <const> = locale('copperscrap.fence')

local busy = false

---@param groupKey string
---@param entity integer
local function strip(groupKey, entity)
    local durationMs <const> = lib.callback.await('cobalt_crime:copperscrap:start', false, groupKey, GetEntityCoords(entity))

    if not durationMs then return end

    busy = true
    lib.playAnim(cache.ped, config.anim.dict, config.anim.clip, 8.0, -8.0, -1, config.anim.flag)

    ---@type CopperOutcome
    local outcome = 'shocked'

    if core:SkillCheck(config.skillCheck.difficulty, config.skillCheck.inputs) == true then
        outcome = Crime.progress(locale('copperscrap.progress'), durationMs) and 'stripped' or 'cancelled'
    end

    StopAnimTask(cache.ped, config.anim.dict, config.anim.clip, 1.0)
    busy = false

    local result <const> = lib.callback.await('cobalt_crime:copperscrap:finish', false, outcome)

    if outcome == 'shocked' or result == 'shocked' then
        SetEntityHealth(cache.ped, math.max(101, GetEntityHealth(cache.ped) - config.shockDamage))
    end
end

for groupKey, group in pairs(config.groups) do
    exports.ox_target:addModel(group.models, {
        {
            name = ('cobalt_crime:copperscrap:%s'):format(groupKey),
            label = locale(('copperscrap.groups.%s'):format(groupKey)),
            icon = group.icon,
            distance = config.range,
            canInteract = function(entity)
                return not busy and Crime.onFoot() and Crime.has(config.tool) and not Props.isEmptied('copperscrap', entity)
            end,
            onSelect = function(data)
                strip(groupKey, data.entity)
            end,
        },
    })
end

---@class ScrapStock
---@field value string
---@field label string
---@field count integer

---@return ScrapStock[]
local function carriedScrap()
    local counts <const> = lib.callback.await('cobalt_crime:copperscrap:stock', false) or {}
    local stock <const> = {}

    for _, item in ipairs(fence.items) do
        local count <const> = counts[item]

        if count then
            stock[#stock + 1] = {
                value = item,
                label = ('%s (%d)'):format(locale(('copperscrap.items.%s'):format(item)), count),
                count = count,
            }
        end
    end

    return stock
end

---@param stock ScrapStock[]
---@return ScrapStock?
local function pickItem(stock)
    if #stock == 1 then return stock[1] end

    local values <const> = core:InputDialog(fenceLabel, {
        { type = 'select', label = locale('copperscrap.dialog_item'), options = stock, required = true },
    })
    local picked <const> = values and values[1]

    for _, entry in ipairs(stock) do
        if entry.value == picked then return entry end
    end
end

---@param entry ScrapStock
---@return integer?
local function askQuantity(entry)
    local limit <const> = math.min(entry.count, fence.maxBatch)
    local values <const> = core:InputDialog(fenceLabel, {
        { type = 'select', label = locale('copperscrap.dialog_item'), options = { entry }, default = entry.value, disabled = true },
        { type = 'number', label = locale('copperscrap.dialog_quantity'), min = 1, max = limit, default = limit, required = true },
    })
    local quantity <const> = values and math.tointeger(values[2])

    if not quantity then return end
    if quantity < 1 or quantity > limit then
        core:Notify({ description = locale('copperscrap.batch_limit', limit), type = 'error' })

        return
    end

    return quantity
end

local function sellScrap()
    local stock <const> = carriedScrap()

    if #stock == 0 then
        core:AlertDialog({ header = fenceLabel, content = locale('copperscrap.nothing_to_sell'), cancel = false })

        return
    end

    local entry <const> = pickItem(stock)

    if not entry then return end

    local quantity <const> = askQuantity(entry)

    if not quantity then return end

    lib.callback.await('cobalt_crime:copperscrap:sell', false, entry.value, quantity)
end

---@type integer?
local fencePed

lib.points.new({
    coords = fence.coords.xyz,
    distance = 40.0,
    onEnter = function()
        fencePed = Crime.spawnPed(fence.model, fence.coords, fence.scenario)

        exports.ox_target:addLocalEntity(fencePed, {
            {
                name = 'cobalt_crime:copperscrap:sell',
                label = locale('copperscrap.sell'),
                icon = 'fas fa-coins',
                distance = 2.5,
                onSelect = sellScrap,
            },
        })
    end,
    onExit = function()
        if not fencePed then return end

        exports.ox_target:removeLocalEntity(fencePed)
        DeleteEntity(fencePed)
        fencePed = nil
    end,
})

local blip <const> = Crime.blip(fence.coords.xyz, 365, 5, fenceLabel)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    RemoveBlip(blip)

    if fencePed then
        DeleteEntity(fencePed)
    end
end)
