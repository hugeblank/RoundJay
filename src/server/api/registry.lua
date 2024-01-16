local table = require "src.common.api.tablex"

--- @class Registry
-- Represents the collection of devices registered to the network
local registry = {}
local network = {} ---@type Device[]

---register a device to the provided ID
---@param i integer
---@param device Device
function registry.register(i, device)
    assert(not network[i], "Device already registered to id "..i)
    network[i] = device
end

---Get the device registered to provided id
---@param id any
---@return Device
function registry.getDevice(id)
    return network[id]
end

---Get all registered devices
---@return Device[]
function registry.getDevices()
    return table.clone(network)
end

return registry