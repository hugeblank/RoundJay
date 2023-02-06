-- If a mod provides a fuel item you want to use,
-- add its name here and provide how many items
-- it can smelt.
-- Feel free to use any of the provided tables
-- below.
local fuelmap = {
    ["minecraft:bamboo"] = 0.25,
    ["minecraft:scaffolding"] = 0.25,
    ["minecraft:stick"] = 0.5,
    ["minecraft:coal"] = 8,
    ["minecraft:charcoal"] = 8,
    ["minecraft:dried_kelp"] = 20,
    ["minecraft:blaze_rod"] = 24,
    ["minecraft:coal_block"] = 72,
    ["minecraft:lava_bucket"] = 100
}
do
    local function mc(name)
        return "minecraft:"..name
    end
    local odds = {
        "bow", 
        "crossbow", 
        "fishing_rod", 
        "ladder", 
        "mangrove_roots", 
        "composter", 
        "smithing_table", 
        "fletching_table",
        "cartography_table",
        "barrel",
        "loom",
        "daylight_detector",
        "lectern",
        "crafting_table",
        "bookshelf",
        "chest",
        "trapped_chest",
        "jukebox",
        "note_block"
    }
    table.foreachi(odds, function(_, name)
        fuelmap[mc(name)] = 1.5
    end)
    local lilodds = {
        "dry_bush",
        "bowl",
        "azalea",
        "flowering_azalea"
    }
    table.foreachi(lilodds, function(_, name)
        fuelmap[mc(name)] = 0.5
    end)
    
    local trees = {
        "oak", 
        "birch", 
        "spruce", 
        "jungle", 
        "acacia", 
        "dark_oak", 
        "mangrove"
    }
    local items = {
        sapling = 0.5,
        [{"stripped", "log"}] = 1.5,
        [{"stripped", "wood"}] = 1.5,
        planks = 1.5,
        slab = 0.75,
        fence = 1.5,
        stairs = 1.5,
        button = 0.5,
        pressure_plate = 1.5,
        door = 1,
        trapdoor = 1.5,
        fence_gate = 1.5,
        boat = 6,
        chest_boat = 6,
        sign = 1
    }
    table.foreachi(trees, function(_, tree)
        table.foreach(items, function(name, time)
            if type(name) == "table" then
                fuelmap[mc(name[1].."_"..tree.."_"..name[2])] = time
                fuelmap[mc(tree.."_"..name[2])] = time
            else
                if tree == "mangrove" and name == "sapling" then
                    name = "propagule"
                end
                fuelmap[mc(tree.."_"..name)] = time
            end
        end)
    end)
    local tools = {
        "pickaxe", 
        "sword", 
        "axe", 
        "shovel", 
        "hoe"
    }
    table.foreachi(tools, function(_, name)
        fuelmap[mc("wooden_"..name)] = 1
    end)
    
    local colors = {
        "white", 
        "orange", 
        "magenta", 
        "light_blue", 
        "yellow", 
        "lime", 
        "pink", 
        "gray", 
        "light_gray", 
        "cyan", 
        "purple", 
        "blue", 
        "brown", 
        "green", 
        "red"
    }
    table.foreachi(colors, function(_, color)
        fuelmap[mc(color.."_wool")] = 0.5
        fuelmap[mc(color.."_carpet")] = 1/3
        fuelmap[mc(color.."_banner")] = 1.5
    end)
end

return fuelmap
