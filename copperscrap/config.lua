-- Stripping copper and scrap from AC units and electrical boxes in the world
return {
    tool = 'wire_cutters', -- item needed to strip
    range = 2.0, -- meters from the prop
    shockDamage = 15, -- health lost on a failed skill check
    durationMs = 6000, -- milliseconds the wiring takes to pull out after the skill check

    -- Props that can be stripped, by group: icon and prop models; the target label is copperscrap.groups.<group> in locales/en.json
    groups = {
        ac = {
            icon = 'fas fa-fan',
            models = {
                'prop_aircon_l_01', 'prop_aircon_l_02', 'prop_aircon_l_03',
                'prop_aircon_s_01a', 'prop_aircon_s_02a', 'prop_aircon_s_02b',
                'prop_aircon_s_03a', 'prop_aircon_s_03b', 'prop_aircon_s_04a', 'prop_aircon_s_05a',
            },
        },
        elec = {
            icon = 'fas fa-bolt',
            models = {
                'prop_elecbox_01a', 'prop_elecbox_01b', 'prop_elecbox_02a', 'prop_elecbox_02b',
                'prop_elecbox_03a', 'prop_elecbox_04a', 'prop_elecbox_05a', 'prop_elecbox_06a',
                'prop_elecbox_07a', 'prop_elecbox_08', 'prop_elecbox_09', 'prop_elecbox_11',
                'prop_elecbox_12', 'prop_elecbox_13', 'prop_elecbox_18', 'prop_elecbox_20', 'prop_elecbox_21',
                'prop_elecbox_25', 'prop_elecbox_10', 'prop_sub_trans_01a',
            },
        },
    },

    -- Skill check while stripping
    skillCheck = {
        difficulty = { 'medium', 'medium' }, -- one entry per stage: 'easy', 'medium', 'hard' or { areaSize = degrees, speedMultiplier = n }
        inputs = { 'w', 'a', 's', 'd' }, -- keys the check can ask the player to press
    },

    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }, -- animation while stripping; flag 49 loops on the upper body so the player can still turn

    -- Fence ped that buys the scrap
    fence = {
        model = 's_m_y_dockwork_01', -- ped model
        coords = vec4(-460.69, -1721.88, 18.79, 175.0), -- ped position and heading
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- scenario the ped plays
        items = { 'copper', 'scrap' }, -- items the fence buys; each needs a copperscrap.items.<item> label in locales/en.json
        maxBatch = 40, -- most items sold in one go
    },
}
