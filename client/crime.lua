local core <const> = exports.cobalt_core

local APPROACH_TIMEOUT_MS <const> = 3000

---@class CrimeAnim
---@field dict string
---@field clip string
---@field flag? integer

local Crime <const> = {}

---@param text string
---@param kind? 'success' | 'error' | 'info' | 'warning'
function Crime.notify(text, kind)
    core:Notify({ description = text, type = kind or 'info' })
end

---@param label string
---@param durationMs integer
---@param anim? CrimeAnim
---@return boolean completed
function Crime.progress(label, durationMs, anim)
    return core:Progressbar({
        label = label,
        duration = durationMs,
        canCancel = true,
        anim = anim,
        disable = { move = true, car = true, combat = true },
    }) == true
end

---@param item string
---@return boolean
function Crime.has(item)
    return exports.cobalt_inventory:HasItem(item, 1) == true
end

---@return boolean
function Crime.onFoot()
    return not cache.vehicle
end

---@param entity integer
---@param standOff number meters between the entity and where the player stops
---@param timeoutMs? integer
---@return boolean reached
function Crime.approach(entity, standOff, timeoutMs)
    local target <const> = GetEntityCoords(entity)
    local from <const> = GetEntityCoords(cache.ped)
    local offset = vec2(from.x - target.x, from.y - target.y)

    if #offset < 0.05 then
        offset = -GetEntityForwardVector(entity).xy
    end

    local direction <const> = offset / #offset
    local spot <const> = vec2(target.x + direction.x * standOff, target.y + direction.y * standOff)
    local heading <const> = GetHeadingFromVector_2d(target.x - spot.x, target.y - spot.y)
    local timeout <const> = timeoutMs or APPROACH_TIMEOUT_MS
    local deadline <const> = GetGameTimer() + timeout

    TaskGoStraightToCoord(cache.ped, spot.x, spot.y, from.z, 1.0, timeout, heading, 0.05)

    while #(GetEntityCoords(cache.ped).xy - spot) > 0.2 do
        if GetGameTimer() > deadline then
            ClearPedTasks(cache.ped)

            return false
        end

        Wait(50)
    end

    TaskAchieveHeading(cache.ped, heading, 400)
    Wait(400)
    SetEntityHeading(cache.ped, heading)

    return true
end

---@param ped integer
---@param target integer
function Crime.face(ped, target)
    local from <const> = GetEntityCoords(ped)
    local to <const> = GetEntityCoords(target)

    SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
end

---@param model string
---@param coords vector4
---@param scenario? string
---@return integer ped
function Crime.spawnPed(model, coords, scenario)
    local hash <const> = lib.requestModel(model)
    local ped <const> = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)

    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    return ped
end

---@param coords vector3
---@param sprite integer
---@param colour integer
---@param label string
---@return integer blip
function Crime.blip(coords, sprite, colour, label)
    local blip <const> = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.75)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)

    return blip
end

return Crime
