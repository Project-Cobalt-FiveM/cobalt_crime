local propKey <const> = require 'shared.propkey'

---@type table<string, table<string, true>>
local emptied <const> = {}

---@param name string
---@param key string
---@param isEmpty boolean
local function mark(name, key, isEmpty)
    emptied[name] = emptied[name] or {}
    emptied[name][key] = isEmpty or nil
end

RegisterNetEvent('cobalt_crime:props:emptied', mark)

CreateThread(function()
    for name, keys in pairs(lib.callback.await('cobalt_crime:props:emptied', false) or {}) do
        for _, key in ipairs(keys) do
            mark(name, key, true)
        end
    end
end)

local Props <const> = {}

---@param name string
---@param entity integer
---@return boolean
function Props.isEmptied(name, entity)
    return emptied[name]?[propKey(GetEntityCoords(entity))] == true
end

return Props
