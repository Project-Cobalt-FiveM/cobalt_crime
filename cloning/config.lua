-- Plate cloning with the VIN cloner
return {
    item = 'vin_cloner', -- item that starts it
    durationMs = 18000, -- milliseconds to clone a plate
    maxDistance = 3.0, -- meters from the vehicle
    plateLength = { min = 1, max = 8 }, -- letters or digits allowed on the new plate
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }, -- animation while cloning
}
