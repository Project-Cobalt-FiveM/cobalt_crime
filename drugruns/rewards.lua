-- Drug package run payouts, server only
return {
    payout = { min = 800, max = 1500 }, -- marked bills paid per delivered package
    cooldownSeconds = 5 * 60, -- seconds one character waits after a delivered or lost run
    minBuyerDistance = 600.0, -- meters a buyer must be from the handler to be picked
    maxDistance = 6.0, -- meters the server allows between the player and the handler or buyer
}
