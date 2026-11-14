---@meta

---`exports.cobalt_crime`. Each export is tagged with the side it exists on.
---@class CobaltCrimeExports
local CobaltCrimeExports = {}

exports.cobalt_crime = CobaltCrimeExports

---**Client.** The `vin_cloner` item's client export. On `usedItem` it asks for a new plate and reflashes the closest vehicle's plate, using up that cloner when it finishes.
---@param event 'usingItem' | 'usedItem'
---@param item table
---@param slot { id: string }
function CobaltCrimeExports:UseCloner(event, item, slot) end
