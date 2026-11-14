-- Chop shop where stolen vehicles are stripped
return {
    center = vec3(720.84, -1080.05, 22.16), -- middle of the work area
    radius = 12.0, -- meters from center a vehicle must be
    durationMs = 30000, -- milliseconds to strip one vehicle
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }, -- animation while stripping
}
