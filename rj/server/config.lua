return {
    networking = {
        enabled = true, -- Whether networking to other clients (besides this computer) should be enabled
        channel = 0,
        side = "back", -- The side of the modem to connect with other clients on (ideally same as devices)
    },
    modules = {
        ["base"] = {
            devices = {
                -- enabled = true -- This line could replace all of the individual device handlers
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