-- Drug runs: pick up a package from a handler and deliver it to a buyer
return {
    package = 'drug_package', -- item carried between handler and buyer
    range = 2.5, -- meters to talk to a handler or buyer
    pedDistance = 60.0, -- meters within which handler and buyer peds spawn
    walkOffMs = 15000, -- milliseconds a buyer wanders off before being removed

    -- Buyer map blip; its name is drugruns.blip in locales/en.json
    blip = { sprite = 478, colour = 5 },

    -- Hand-off animation: standOff in meters, transferMs when the package changes hands, durationMs in total
    handoff = {
        dict = 'mp_common', -- animation dictionary
        give = 'givetake1_a', -- clip for whoever hands the package over
        take = 'givetake1_b', -- clip for whoever receives it
        standOff = 0.9, -- meters the player stands from the other ped
        transferMs = 900, -- milliseconds in when the package changes hands
        durationMs = 2000, -- milliseconds the whole hand-off takes
    },

    -- Where packages are picked up
    handlers = {
        { coords = vec4(-168.07, -1662.80, 33.31, 181.2), model = 's_m_y_dealer_01', scenario = 'WORLD_HUMAN_SMOKING' },
        { coords = vec4(-1243.73, -1359.72, 3.93, 293.2), model = 'g_m_y_mexgoon_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { coords = vec4(-683.23, -169.62, 37.74, 273.5), model = 'a_m_y_business_01', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        { coords = vec4(268.72, -25.92, 73.36, 334.9), model = 'a_m_m_hillbilly_01', scenario = 'WORLD_HUMAN_SMOKING' },
        { coords = vec4(488.49, -1284.10, 29.24, 94.2), model = 's_m_y_dealer_01', scenario = 'WORLD_HUMAN_LEANING' },
    },

    -- Where packages are delivered, one picked at random per run
    buyers = {
        { coords = vec4(118.06, -1943.96, 20.43, 75.5), model = 'g_m_y_famca_01' },
        { coords = vec4(297.94, -2018.26, 20.49, 91.2), model = 'g_m_y_ballaeast_01' },
        { coords = vec4(239.19, -681.50, 37.15, 275.8), model = 'a_m_y_business_02' },
        { coords = vec4(267.03, 276.01, 105.54, 141.2), model = 'a_m_y_hipster_01' },
        { coords = vec4(-546.90, 286.57, 82.85, 267.1), model = 'a_m_m_bevhills_01' },
        { coords = vec4(-1057.06, -515.45, 35.83, 357.0), model = 'a_m_y_business_01' },
        { coords = vec4(-1558.64, -478.22, 35.18, 209.7), model = 'a_m_y_vinewood_01' },
        { coords = vec4(-635.21, -1226.45, 11.80, 44.7), model = 'g_m_y_mexgoon_02' },
        { coords = vec4(-587.74, -1739.13, 22.47, 321.6), model = 'a_m_m_hillbilly_01' },
        { coords = vec4(21.65, 375.44, 112.67, 115.3), model = 'a_m_y_hipster_02' },
    },
}
