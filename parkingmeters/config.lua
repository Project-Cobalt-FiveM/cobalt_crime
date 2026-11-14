-- Breaking into parking meters and payphones for coins
return {
    range = 2.0, -- meters from the prop
    fxDistance = 30.0, -- meters within which other players see the sparks and debris

    -- Prop kinds: world models, where the player stands to strike or pick (meters from the prop), and the pick animations
    kinds = {
        meter = {
            models = { 'prop_parknmeter_01', 'prop_parknmeter_02' },
            strikeStandOff = 1.05,
            pickStandOff = 0.55,
            pick = {
                enter = { dict = 'mini@safe_cracking', clip = 'step_into' },
                loops = {
                    { dict = 'mini@safe_cracking', clip = 'dial_turn_clock_slow' },
                    { dict = 'mini@safe_cracking', clip = 'dial_turn_anti_slow' },
                },
                exit = { dict = 'mini@safe_cracking', clip = 'step_out' },
            },
        },
        phone = {
            models = { 'prop_phonebox_01a', 'prop_phonebox_01b', 'prop_phonebox_02', 'prop_phonebox_03', 'prop_phonebox_04' },
            strikeStandOff = 1.1,
            pickStandOff = 0.6,
            pick = {
                enter = { dict = 'missheistfbisetup1', clip = 'unlock_enter_janitor' },
                loops = {
                    { dict = 'missheistfbisetup1', clip = 'unlock_loop_janitor' },
                },
                exit = { dict = 'missheistfbisetup1', clip = 'unlock_exit_janitor' },
            },
        },
    },

    -- Tools: item needed (equipped means it must be in hand), icon, milliseconds to open; target label and progress text are parkingmeters.tools.<tool> in locales/en.json
    tools = {
        crowbar = {
            item = 'weapon_crowbar',
            equipped = true,
            icon = 'fas fa-hammer',
            durationMs = 6500,
        },
        master_key = {
            item = 'master_key',
            icon = 'fas fa-key',
            durationMs = 7000,
        },
    },

    -- Crowbar swing animation; impactPhase is when in the clip the hit lands, 0.0 to 1.0
    strike = {
        dict = 'melee@large_wpn@streamed_core', -- animation dictionary
        clips = { 'short_0_attack', 'short_0_attack', 'short_0_attack' }, -- clip for each swing, in order
        impactPhase = 0.38, -- point in the clip where the hit lands, 0.0 to 1.0
        rate = 1.0, -- playback speed, 1.0 is normal
    },

    -- Animation for scooping the coins
    grab = { dict = 'amb@prop_human_parking_meter@male@idle_a', clip = 'idle_b' },

    -- Native GTA sounds for each step
    sounds = {
        strike = { name = 'Drill_Pin_Break', set = 'DLC_HEIST_FLEECA_SOUNDSET', bank = 'DLC_MPHEIST\\HEIST_FLEECA_DRILL' },
        burst = { name = 'SMASH_CABINET_PLAYER', set = 'JEWEL_HEIST_SOUNDS' },
        pick = { name = 'TUMBLER_TURN', set = 'SAFE_CRACK_SOUNDSET', ambientBank = 'SAFE_CRACK' },
        open = { name = 'TUMBLER_PIN_FALL_FINAL', set = 'SAFE_CRACK_SOUNDSET', ambientBank = 'SAFE_CRACK' },
        coins = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    },

    -- Particle effects on strikes and when the prop bursts open
    particles = {
        asset = 'core', -- particle asset the effects come from
        strike = 'mel_carmetal', -- effect on each strike
        burst = 'ent_brk_metal_frag', -- effect when the meter bursts open
    },
}
