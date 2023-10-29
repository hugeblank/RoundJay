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
                ...
            },
            accepts = function(source, item, count, index) -- Before an insertion, this is ran
                -- Optional function that returns a number representing the amount of items that should be accepted into the pool.
                -- `source` The source device for the pending insertion
                -- `item`  Item object, found in src.src.server.api.item
                -- `count` the amount of items that the storage can accept, up to the amount of items originally requested in the device:accepts call.
                -- `index` the device index, granting the ability to gain greater context about the device.
            end,
            contains = function(target, item, count, index) -- Before an extraction, this is ran
                -- Optional function that returns the amount of items contained within the pool.
                -- `target` The target device for the pending extraction
                -- `item` is either an Item object, found in src.src.server.api.item, OR an item hash.
                -- `count` is the amount of items that the storage contains, found by the device:contain call.
                -- `index` is the device index, granting the ability to gain greater context about the device.
            end
        }
    },
    { -- interface chests do both export and import, but has no specific logic behind *what* it requests/returns, as it is controlled by a player.
        side = "back",
        type = "roundjay:player_interface",
        details = {
            inventory = "sc-goodies:iron_chest_1309",
            source = 1, -- Optional default device to source items from
            target = 1, -- Optional default device to put items back into.
            network = {      -- Optional information for local networking, sending information to clients
                channel = 0, -- Optional channel to communicate on. Default: 0
                -- Default for both of the above are all devices with the storage role.
                whitelist = {
                    -- list of client computer IDs that can use this interface
                }
            }
        }
    },
    {
        side = "back",
        type = "roundjay:import_bus",
        details = {
            -- You may choose to import directly to an export bus, which acts like a pipe! Note that items within this pipe are opaque to clients.
            target = 1,                               -- optional network index of the default target device for items to be pushed to. If nil, devices with the storage role will be iterated.
            inventory = "sc-goodies:iron_chest_6969", -- inventory peripheral ID to pull the items in from
            interval = 5, -- interval (in seconds) on which the inventory should be scanned. If nil, defaults to every 5 seconds.
            contains = function(item, count, index)
                -- See storage `contains`
            end
        }
    },
    {
        side = "back",
        type = "roundjay:export_bus",
        details = {
            source = 1, -- optional network index of the default target device for items to be pulled from. If nil, devices with the storage role will be iterated.
            inventory = "sc-goodies:gold_chest_1234", -- inventory peripheral ID to push the items out to
            interval = 5,                         -- interval (in seconds) on which the source(s) should be scanned. If nil, defaults to every 5 seconds.
            whitelist = { -- A whitelist of items to search for in the storage(s)
                ["minecraft:gold_ingot"] = 7,
                ["minecraft:redstone"] = 1,
                ["minecraft:glass_pane"] = 1
            },
            accepts = function(item)
                -- see storage `accepts`
            end
        }
    }
}