-- Example rj v0.3.0 network file.
-- RJ is now breaking up into a server/client style application. Properly.
return { -- The network in which this server operates in.
    {
        -- All devices are required to have a side, a type, and a role.
        -- The role is determined by the device handler. All devices of the same type must have the same role
        side = "back",              -- What side this device can be interfaced from. Multi-device operations require that this match.
        type = "roundjay:basic_storage", -- Determines the behavior, and to which module the device should be directed to for processing.
        details = {                 -- The specific details of this device, may affect how it performs its role.
            inventories = { -- Required list of inventories that comprise the device.
                "minecraft:chest_0",
                "minecraft:chest_1",
                "minecraft:chest_2",
                "minecraft:chest_3",
                "minecraft:chest_4",
                "minecraft:chest_5",
            }
        }
    },
    { -- interface chests do both export and import, but has no specific logic behind *what* it requests/returns, as it is controlled by a player.
        side = "back",
        type = "roundjay:player_interface",
        details = {
            inventory = "minecraft:chest_6"
        }
    }
}
