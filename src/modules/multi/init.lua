local config = require("src.config")
local table = require("src.tablex")
local rj = require("src")
local logger = require("src.client.logger")

local modem = peripheral.wrap(config.get("pool"))
local blacklist = config.get("blacklist") or {}

local function daemon()
    modem.open(60)
    while true do
        local e, side, channel, _, inventory = os.pullEvent()
        if e == "terminate" then
            modem.close(60)
        elseif e == "modem_message" and side == config.get("pool") and channel == 60 then
            local exists = false
            table.foreachi(blacklist, function(i, inv)
                if inv == inventory then
                    exists = true
                end
            end)
            if not exists then -- New client!
                blacklist[#blacklist+1] = inventory
                config.set("blacklist", blacklist)
                config.flush()
                modem.transmit(60, 60, config.get("interface"))
            end
            
        end
    end
end

rj.addCommand("blacklist", 
function()
    return config.get("blacklist")
end,
function()
    logger.info("Blacklisted inventories:")
    table.foreachi(blacklist, function(_, chest)
        logger.info("  "..chest)
    end)
end)

rj.addThread(daemon, true)
modem.transmit(60, 60, config.get("interface"))

return {
    name = "RoundJay Multi-instance Service",
    version = "0.1.0"
}
