-- Example RoundJay network file.
return { -- The network on which this server oversees.
    {
        -- All devices are required to have a side, a type, and a role.
        -- The role is determined by the device handler. All devices of the same type must have the same role
        side = "back",              -- What side this device can be interfaced from. Multi-device operations require that this match.
        type = "base/basic_storage", -- Determines the behavior, and to which module the device should be directed to for processing.
        details = {                 -- The specific details of this device, may affect how it performs its role.
            inventories = { -- Required list of inventories that comprise the device.
                ... -- These must be peripheral ID strings.
            },
            --- Optional function that returns a number representing the amount of items that should be accepted into the pool.
            ---@param source Device The source device for the pending insertion
            ---@param item Item The item object to be inserted
            ---@param count integer The amount of items evaluated by the parent accepts method, should you want to adjust it
            ---@param index Index The index of the storage device, for more advanced evaluation.
            accepts = function(source, item, count, index) end, -- Before an insertion, this is ran
            --- Optional function that returns the amount of items contained within the pool.
            --- @param target Device The target device for the pending extraction.
            --- @param item Item|string Either an item object, or a hash of the item to be inserted
            --- @param count integer The amount of items evaluated by the parent contains method, should you want to adjust it
            --- @param index Index The index of the storage device, for more advanced evaluation.
            contains = function(target, item, count, index) end, -- Before an extraction, this is ran
            --- NOTE: The smallest value between the one returned by the source device's contains method, and the target device's accepts method is picked.
            --- @see Device.insert
        }
    },
    { -- interface chests do both export and import, but has no specific logic behind *what* it requests/returns, as it is controlled by a player.
      -- As such, in the device's class it is registered with a "convert" role
        side = "back",
        type = "base/player_interface",
        details = {
            inventory = "sc-goodies:iron_chest_1309", -- Required inventory that this device represents
            source = 1, -- Optional default device to source items from
            target = 1, -- Optional default device to put items back into.
            whitelist = {
                -- Optional list of client computer IDs that can use this interface when networking is enabled (in server/config.lua)
                -- Note that a blank table (like this one!) will disallow all incoming connections.
            }
        }
    },
    {
        side = "back",
        type = "base/import_bus",
        details = {
            -- You may choose to import directly to an export bus, which acts like a pipe! Note that items within this pipe are opaque to clients.
            target = 1,                               -- optional network index of the default target device for items to be pushed to. If nil, devices with the storage role will be iterated.
            inventory = "sc-goodies:iron_chest_6969", -- inventory peripheral ID to pull the items in from
            interval = 5, -- interval (in seconds) on which the inventory should be scanned. If nil, defaults to every 5 seconds.
            contains = function(target, item, count, index)
                -- See storage `contains`
            end
        }
    },
    {
        side = "back",
        type = "base/export_bus",
        details = {
            source = 1, -- optional network index of the default target device for items to be pulled from. If nil, devices with the storage role will be iterated.
            inventory = "sc-goodies:gold_chest_1234", -- inventory peripheral ID to push the items out to
            interval = 5,                         -- interval (in seconds) on which the source(s) should be scanned. If nil, defaults to every 5 seconds.
            whitelist = { -- A whitelist of items to search for in the storage(s)
                ["minecraft:gold_ingot"] = 7,
                ["minecraft:redstone"] = 1,
                ["minecraft:glass_pane"] = 1
            },
            accepts = function(source, item, count, index)
                -- see storage `accepts`
            end
        }
    }
}