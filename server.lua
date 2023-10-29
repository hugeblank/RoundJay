local config = require "rj.server.config"
local netcfg = require "rj.server.network"
local network = require "src.common.api.network"
local registry = require "src.server.api.registry"
local logger = (require "src.common.api.logger"):new("server")
local paralyze = require "src.common.api.paralyze"

assert(type(netcfg) == "table", "Malformed network, check rj/network.lua")
assert(type(config) == "table", "Malformed config, check rj/config.lua")

-- module path
local path
do
    local root = fs.getDir(shell.getRunningProgram())
    function path(...)
        return fs.combine(root, ...)
    end
end

logger.addGlobalListener(logger.renderEntry)

local modpath = "src/server/modules/"
local modules, handlers, batch, invalid = {}, {}, {}, {} --- @type table<string, table>, table<string, Device>, function[], table<string, boolean>
-- initialize all modules
for _, namespace in ipairs(fs.list(path(modpath))) do
    if fs.isDir(path(modpath, namespace)) then
        local mod = require(modpath:gsub("/", ".") .. namespace)
        logger:log("info", "initializing", namespace)
        if type(mod) == "table" then
            modules[#modules + 1] = mod
            if not config.modules then
                logger:log("error", "Missing config.modules table. Using an empty table.")
                config.modules = {}
            end
            if not config.modules[namespace] then
                logger:log("warn", "Missing config for module \""..namespace.."\"")
            end
            local dhandlers = mod.load(config.modules[namespace], logger)
            for k, v in pairs(dhandlers) do
                if handlers[k] then
                    logger:log("error","Multiple device handlers registered for " ..
                    k .. ". No handlers will be registered for this device type.")
                    handlers[k] = nil
                    invalid[k] = true
                elseif not invalid[k] then
                    handlers[k] = v
                end
            end
            if type(mod.run) == "function" then
                batch[#batch + 1] = function()
                    logger:log("info", "Starting module", namespace)
                    mod.run(config.modules[namespace], logger)
                end
            end
        else
            logger:log("error", "Expected table from module \""..namespace.."\", got "..type(mod)..". Module will not be initialized.")
        end
    end
end

-- Set up threads and register devices
batch[#batch + 1] = function()
    logger:log("info", "Starting up!")
    local runners = {}
    for i, cfg in ipairs(netcfg) do
        logger:log("debug", "registering device", cfg.type)
        if handlers[cfg.type] then
            local device = handlers[cfg.type]:new(i, cfg)
            registry.register(i, device)
            if device.run then
                runners[#runners + 1] = function()
                    logger:log("info", "Starting device ", device.id)
                    local ok, err = pcall(device.run, device)
                    if not ok then
                        logger:log("error", "Device " .. i .. " exited with error: " .. tostring(err))
                    end
                end
            end
        else
            logger:log("error", "Missing device handler for " .. cfg.type .. ". Device " .. i .. " skipped!")
        end
    end
    parallel.waitForAll(table.unpack(runners))
end

if config.networking and config.networking.enabled then
    local haschannel = not config.networking.channel or type(config.networking.channel) == "number"
    if haschannel and type(config.networking.side) == "string" then
        batch[#batch + 1] = function()
            local channel = config.networking.channel or 0
            logger:log("info", "Networking enabled. Modem", tostring(config.networking.side), "channel", channel)
            network.run(config.networking.side, channel)
        end
    elseif haschannel then
        logger:log("error",
            "Expected string for config.networking.side, got " ..
            type(config.networking.side) .. ". Networking will not be enabled.")
    else
        logger:log("error",
            "Expected number for config.networking.channel, got " ..
            type(config.networking.channel) .. ". Networking will not be enabled.")
    end
end

parallel.waitForAll(paralyze.run, table.unpack(batch))
