local ClassBuilder = require "src.common.api.class"

--- Class to somewhat securely whitelist events for external clients to operate on
-- Additionally handles incoming data through listeners
--- @class Network: Class
--- @field new fun(self: Class, namespace: string): Network --- ⚠️ Create a new Network.
--- @field private super Class
local Network = ClassBuilder:new()

--- ⚠️ Internal constructor for the Network object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see Network.new
--- @param namespace string namespace of the module creating this network
function Network:__new(namespace)
    self.namespace = namespace
    self.broadcast = {}
    self.listen = {}
end

--- Create a new subnetwork underneath this one.
--- Event names in the subnet will be tacked onto the main network like a path
--- Ex: roundjay/base
--- @param namespace string Namespace of this subnet
function Network:subnet(namespace)
    return Network:new(fs.combine(self.namespace, namespace))
end

local broadcast, listen = {}, {} ---@type table<string, boolean>, table<string, function[]>

--- Add an event to broadcast out to the network
--- @param event string path of the event, usually includes a device name
--- @return string # full name of the event that gets broadcasted
function Network:addBroadcast(event)
    event = fs.combine(self.namespace, event)
    broadcast[event] = true
    return event
end

--- Add an event to listen for on the network
--- @param event string path of the event, usually includes a device name
--- @param callback function Function to execute when event is found
function Network:addListener(event, callback)
    if not listen[event] then
        listen[event] = {}
    end
    listen[event][#listen[event]+1] = callback
end

--- Runner for the network
-- Interprets events and modem messages, queueing events and broadcasting messages respectively.
function Network.run(side, channel)
    local batches = {}
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
            if eside == side and echannel == channel and type(eventdata) == "table" and eventdata.type == "roundjay:modem_message" and type(eventdata.data) == "table" then
                data = eventdata.data
                if listen[data[1]] then -- Only act on events that have listeners
                    batches[#batches + 1] = { funcs = listen[data[1]], data = data[2]}
                    os.queueEvent("roundjay:network_run")
                end
            end
        end
    end, function() -- scuffed bifurcate
        while true do
            os.pullEvent("roundjay:network_run")
            while #batches > 0 do
                local batch = table.remove(batches, 1)
                for _, callback in ipairs(batch.funcs) do
                    callback(batch.data)
                end
            end
        end
    end)
end

return Network