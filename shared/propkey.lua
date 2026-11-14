---@param coords vector3
---@return string
return function(coords)
    return ('%d:%d:%d'):format(math.floor(coords.x * 10 + 0.5), math.floor(coords.y * 10 + 0.5), math.floor(coords.z * 10 + 0.5))
end
