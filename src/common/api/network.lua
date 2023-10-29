---@class Network
-- API for networking between server and clients
local network = {}

local broadcast, listen = {}, {} ---@type table<string, boolean>, table<string, boolean>

--- Add an event to broadcast out to the network
---@param event string
network.addBroadcast = function(event)
    broadcast[event] = true
end

--- Add an event to listen for on the network
---@param event string
network.addListener = function(event)
    listen[event] = true
end

--- Runner for the network.
-- Interprets events and modem messages, queueing events and broadcasting messages respectively.
network.run = function(side, channel)
    parallel.waitForAll(function() -- broadcast
        while true do
            local eventdata = table.pack(os.pullEvent())
            if broadcast[eventdata[1]] then
                peripheral.call(side, "transmit", channel, channel, {
                    type = "roundjay:modem_message",
                    from = os.getComputerID(), -- unused
                    data = eventdata,
                })
            end
        end
    end, function() -- listen
        peripheral.call(side, "open", channel)
        while true do
            local _, eside, echannel, _, eventdata = os.pullEvent("modem_message")
            if eside == side and echannel == channel and type(eventdata) == "table" and eventdata.type == "roundjay:modem_message" then
                os.queueEvent(table.unpack(eventdata.data))
            end
        end
    end)
end

return network