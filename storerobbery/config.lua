-- Store robberies at cobalt_inventory shop clerks
return {
    shops = { -- cobalt_inventory shop ids whose clerks can be robbed; each needs a storerobbery.shops.<id> name in locales/en.json
        ['247'] = true,
    },

    aimRange = 8.0, -- meters from the clerk to aim and start a robbery
    aimHoldMs = 1500, -- milliseconds of aiming before the clerk gives in
    aimGraceMs = 300, -- milliseconds the aim can slip before the hold resets
    pickupMs = 1500, -- milliseconds to pick up the bag of cash
    bagModel = 'p_poly_bag_01_s', -- prop of the cash bag
    tillModel = `prop_till_01`, -- till prop the clerk empties
    tillSearchRadius = 3.0, -- meters around the clerk searched for the till

    -- Timing in milliseconds
    timing = {
        holdupMs = 3000, -- clerk raises their hands
        sceneBlendIn = 1.0, -- animation blend speed
        registerMs = 25000, -- clerk empties the till
        releaseMs = 700, -- delay before the clerk lets go of the bag
        recoverMs = 60000, -- before the store resets after a robbery
    },

    -- Animations for the clerk and the robber
    anims = {
        handsUp = { dict = 'mp_am_hold_up', clip = 'handsup_base' }, -- clerk raises their hands
        scene = { -- synchronized scene at the till
            dict = 'mp_am_hold_up', -- animation dictionary for the whole scene
            ped = 'holdup_victim_20s', -- clerk filling the bag
            bag = 'holdup_victim_20s_bag', -- the bag prop
            till = 'holdup_victim_20s_till', -- the till drawer
        },
        throw = { dict = 'anim@heists@narcotics@trash', clip = 'throw_b' }, -- clerk throws the bag to the robber
        cower = { dict = 'mp_am_hold_up', intro = 'cower_intro', loop = 'cower_loop' }, -- clerk cowers until the store resets
        pickup = { dict = 'pickup_object', clip = 'pickup_low', flag = 0 }, -- player grabs the bag; flag 0 plays once on the full body
    },
}
