-- Tests to be done before entering CUI
local config = require("rj.config")
local logger = require("rj.client.logger")

local tests = {}
local out = {}

-- Test must return true/false for pass/fail.
-- Must also have a priority greater than one
out.register = function(priority, test)
    table.insert(tests, priority, test)
end

out.runTests = function()
    for i = 1, #tests do
        if not tests[i]() then
            error("Self test failed.")
        end
    end
end

-- Check config parameters
out.register(1, function()
    if not config.load() or not config.get("pool") or not config.get("interface") then
        local modem
        if config.load() then
            modem = config.get("pool")
        end
        if not modem then
            local sides = rs.getSides()
            for i = 1, #sides do
                local m = peripheral.getType(sides[i])
                if m == "modem" and not modem then
                    modem = sides[i]
                elseif m == "modem" and modem then
                    logger.error("Could not auto-detect storage pool, too many modems. Leave only one connected and try again.")
                    return false
                end
            end
            if not modem then
                logger.error("Could not auto-detect storage pool, no modems connected. Connect one and try again.")
                return false
            end
            logger.info("Storage pool found!")
            config.set("pool", modem, true)
            config.flush()
        end
        if not config.get("interface") then
            local chest
            logger.info("Please attach (or detach/reattach) the modem the interface inventory is connected to.")
            logger.warn("Make sure only one chest is connected to the modem, to avoid confusion.")
            while not chest do
                local _, p = os.pullEvent("peripheral")
                local _, type = peripheral.call(modem, "getTypeRemote", p)
                if type == "inventory" then
                    chest = p
                end
            end
            logger.info("Interface found! Config saved.")
            config.set("interface", chest, true)
            config.flush()
        end
    end
    return true
end)

-- Load plugins, check for base. 
-- Warn if a plugin errors.
out.register(2, function()
    local rj = require("rj")
    rj.loadPlugins()
    local plugins = rj.getPlugins()
    local baseLoaded, baseFound = false, false
    table.foreachi(plugins, function(_, plugin)
        if not plugin.loaded then
            logger.warn("Plugin "..plugin.path.." failed to load:")
            logger.error(plugin.error)
        end
        if plugin.path == "rj.modules.base" then
            baseFound = true
            baseLoaded = plugin.loaded
        end
    end)
    if not baseFound then
        logger.warn("Base plugin not found. Is this a first run?")
        logger.warn("If so, welcome to RoundJay!")
        local s, err = rj.addPlugin("rj.base")
        baseLoaded = s
        if not s then
            logger.error(err)
        end
    end
    if not baseLoaded then
        logger.error("Base plugin failed to load! What's the point!")
        return false
    end
    return true
end)

return out
