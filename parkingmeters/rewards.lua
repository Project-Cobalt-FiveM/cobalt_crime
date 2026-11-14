-- Parking meter and payphone payouts, server only
return {
    -- Marked bills per emptied prop, by tool
    tools = {
        crowbar = { min = 8, max = 25 },
        master_key = { min = 24, max = 75 },
    },
    propCooldownSeconds = 30 * 60, -- seconds an emptied prop stays empty for everyone
    playerCooldownSeconds = 8, -- seconds one character waits between props
    maxDistance = 3.5, -- meters the server allows between the player and the prop
    hourlyLimit = 60, -- most meters and phone boxes one character can empty in a rolling hour
}
