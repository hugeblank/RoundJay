
return {
    networking = {
        enabled = true, -- Whether networking to other clients (besides this computer) should be enabled 
        side = "back", -- The side of the modem to connect with other clients on (ideally same as devices)
        channel = 0 -- The channel to send/recieve messages from.
    },
    modules = {
        ["base"] = {
            devices = {
                ["roundjay:basic_storage"] = {
                    enabled = true
                },
                ["roundjay:import_bus"] = {
                    enabled = true
                },
                ["roundjay:export_bus"] = {
                    enabled = true
                },
                ["roundjay:player_interface"] = {
                    enabled = true
                }
            }
        }
    }
}
-- Devices are controlled by only one module. If there is a collision, a critical error takes place, and the module is not activated.
-- Similarly if there is no module to control a device, a critical error also takes place, and the module is not activated.
-- A module is not required to have the option to enable/disable control over the device, however it is good practice.
