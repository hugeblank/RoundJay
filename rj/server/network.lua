-- Example rj v0.3.0 network file.
-- RJ is now breaking up into a server/client style application. Properly.
return {
    {
        side = "back",
        type = "roundjay:basic_storage",
        details = {
            inventories = {
                "minecraft:chest_1",
                "minecraft:chest_2",
                "minecraft:chest_3",
                "minecraft:chest_4",
            }
        }
    },
    {
        side = "back",
        type = "roundjay:player_interface",
        details = {
            inventory = "minecraft:chest_0",
            network = {},
        }
    },
    {
        side = "back",
        type = "roundjay:export_bus",
        details = {
            inventory = "minecraft:chest_5",
            whitelist = {
                ["minecraft:sandstone"] = -1,
                ["minecraft:spruce_log"] = -1,
            }
        }
    }
}