-- Chop shop payouts, server only
return {
    cooldownSeconds = 8 * 60, -- seconds one character waits between chopped vehicles
    ownedBonus = { min = 500, max = 1500 }, -- marked bills added when the vehicle belongs to another player

    -- Vehicles the crew refuses
    excludedTypes = { boat = true, heli = true, plane = true, train = true, submarine = true }, -- GetVehicleType values
    excludedCategories = { cycles = true, emergency = true }, -- cobalt_core shared vehicle categories
    premiumCategories = { sportsclassics = true, sports = true, super = true }, -- categories that drop the premium table

    -- Parts from a regular vehicle: item, count range, and chance from 0.0 to 1.0 that the row drops
    basic = {
        { item = 'car_door', min = 1, max = 2, chance = 1.0 },
        { item = 'car_tire', min = 2, max = 4, chance = 1.0 },
        { item = 'car_battery', min = 1, max = 1, chance = 0.7 },
        { item = 'car_radiator', min = 1, max = 1, chance = 0.5 },
        { item = 'car_engine', min = 1, max = 1, chance = 0.2 },
        { item = 'car_transmission', min = 1, max = 1, chance = 0.15 },
    },

    -- Parts from a premium vehicle, same fields as basic
    premium = {
        { item = 'car_door', min = 2, max = 3, chance = 1.0 },
        { item = 'car_tire', min = 3, max = 4, chance = 1.0 },
        { item = 'car_battery', min = 1, max = 1, chance = 0.85 },
        { item = 'car_radiator', min = 1, max = 1, chance = 0.75 },
        { item = 'car_engine', min = 1, max = 1, chance = 0.55 },
        { item = 'car_transmission', min = 1, max = 1, chance = 0.45 },
        { item = 'car_turbo', min = 1, max = 1, chance = 0.3 },
        { item = 'car_ecu', min = 1, max = 1, chance = 0.2 },
    },
}
