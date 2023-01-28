--- Module for handling RoundJay configuration.
-- Note that config must be loaded first.
-- By default the config is found in the root directory at /.rjcfg, but can also be loaded from /.rj.cfg, or /rj.cfg.
-- @author hugeblank
-- @license MIT
-- @module rj.config
-- @alias out

local out = {}
local config

local fname
--- Load the config file.
-- Only reads the file once, future attempts to load the config will return true.
-- @treturn boolean Whether or not the file was loaded.
out.load = function()
    if config then 
        return true 
    end
    local locations = {"/rj.cfg", "/.rj.cfg", "/.rjcfg"}
    for i = 1, #locations do
        if fs.exists(locations[i]) then
            fname = locations[i]
            break
        end
    end
    if not fname then 
        return false 
    end
    local file = fs.open(fname, "r")
    config = textutils.unserialise(file.readAll())
    file.close()
    return true
end

--- Flush the config table in its current state to the file.
out.flush = function()
    if not fname then
        fname = "/.rjcfg"
    end
    local file = fs.open(fname, "w")
    file.write(textutils.serialise(config))
    file.close()
end

--- Set a config value.
-- This function does not save the set value to the config file. To save any modifications, use `config.flush`.
-- It is highly recommended to avoid use of the parameter `unsafe`. 
-- Its sole purpose is to be used on first run, when no config file exists.
-- @see config.flush
-- @tparam string key The key in the config that this value should be represented by.
-- @tparam string|table|number|boolean|nil value The set value. If this value is a table, that table must also respect the type restriction of the parameter.
-- @tparam ?boolean unsafe Unsafely overwrite the config table, if one was not already loaded.
-- @treturn boolean Always true, otherwise the function errored.
out.set = function(key, value, unsafe)
    if type(value) == "function" then
        error("Config can not save function values.")
    elseif not config and not unsafe then
        error("Config does not exist.")
    else
        if not config and unsafe then
            config = {}
        end
        if type(value) == "table" then
            local function check(t, key, value)
                if type(key) == "table" or type(key) == "function" then
                    error("Config cannot have table or function keys.")
                end
                local temp = t[key] or {}
                for k, v in pairs(value) do
                    if type(v) == "function" then
                        error("Config can not save function values.")
                    elseif type(v) == "table" then
                        temp[k] = check(value, k, v)
                    end
                end
                return value
            end
            config[key] = check(config, key, value)
        else
            config[key] = value
        end
    end
    return true
end

--- Get a config value
-- Errors if the config is not loaded.
-- @tparam string key The key in the config that the value can be found at.
-- @treturn string|table|number|boolean|nil The value found in the config.
out.get = function(key)
    if not config then 
        error("Config not loaded.")
    end
    return config[key]
end

return out
