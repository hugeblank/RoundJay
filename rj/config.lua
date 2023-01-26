local out = {}
local config

-- Note that unsafe should only be used during 
-- setup
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

out.get = function(key)
    if not config then 
        error("Config not loaded.")
    end
    return config[key]
end

local fname
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

out.flush = function()
    if not fname then
        fname = "/.rjcfg"
    end
    local file = fs.open(fname, "w")
    file.write(textutils.serialise(config))
    file.close()
end

return out
