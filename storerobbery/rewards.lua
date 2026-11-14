-- Store robbery payouts and server checks, server only
return {
    payout = { min = 2500, max = 4500 }, -- marked bills in the clerk's bag
    killedPayoutShare = 0.0, -- share of the payout from 0.0 to 1.0 the clerk drops when killed before the throw
    cooldownSeconds = 30 * 60, -- seconds a store waits between robberies
    minPolice = 0, -- on-duty police needed to start a robbery
    startDistance = 10.0, -- meters from the clerk the robber must be to start
    abortDistance = 25.0, -- meters the robber can move from the clerk before the robbery is called off
    reportDistance = 40.0, -- meters from the clerk the robber must be to report the clerk killed
    pickupDistance = 5.0, -- meters between the player and the bag the server allows on pickup
    bagLifetimeSeconds = 5 * 60, -- seconds before an unclaimed bag disappears
    throwSpeed = 4.0, -- meters per second the bag flies toward the robber
    throwLift = 2.0, -- meters per second of upward speed on the throw
}
