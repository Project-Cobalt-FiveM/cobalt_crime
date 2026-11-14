-- Copper scrap payouts, server only
return {
    -- Loot per stripped unit, by prop group: item, count range, and chance from 0.0 to 1.0 that the row drops
    loot = {
        ac = {
            { item = 'copper', min = 2, max = 4, chance = 1.0 },
            { item = 'scrap', min = 0, max = 2, chance = 0.7 },
        },
        elec = {
            { item = 'copper', min = 1, max = 2, chance = 1.0 },
            { item = 'scrap', min = 1, max = 3, chance = 1.0 },
        },
    },
    liveChance = 0.1, -- chance from 0.0 to 1.0 that a unit is live and shocks the player even after a clean skill check
    breakChance = 0.2, -- chance from 0.0 to 1.0 that a shock breaks the wire cutters
    propCooldownSeconds = 30 * 60, -- seconds a stripped unit stays empty for everyone
    playerCooldownSeconds = 6, -- seconds one character waits between units
    maxDistance = 4.5, -- meters the server allows between the player and the unit
    hourlyLimit = 40, -- most units one character can strip in a rolling hour

    -- Scrap fence
    fence = {
        prices = { copper = 12, scrap = 8 }, -- marked bills paid per item
        cooldownSeconds = 30, -- seconds one character waits between sales
        maxDistance = 4.0, -- meters the server allows between the player and the fence
    },
}
