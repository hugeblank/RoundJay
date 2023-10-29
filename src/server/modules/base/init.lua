local out = {}

local function getDevices()
    return {
        ["roundjay:basic_storage"] = require("src.server.modules.base.devices.basic_storage"),
        ["roundjay:export_bus"] = require("src.server.modules.base.devices.export_bus"),
        ["roundjay:import_bus"] = require("src.server.modules.base.devices.import_bus"),
        ["roundjay:player_interface"] = require("src.server.modules.base.devices.player_interface"),
    }
end

local function supports(config, deviceType)
    if config.devices and type(config.devices.enabled) == "boolean" then
        return config.devices.enabled
    elseif config.devices and config.devices[deviceType] and type(config.devices[deviceType].enabled) == "boolean" then
        return config.devices[deviceType].enabled
    end
    return false
end

out.load = function(config)
    local devices = getDevices()
    for id, device in pairs(devices) do
        if not supports(config, id) then
            devices[id] = nil
        end
    end
    return devices
end

return out