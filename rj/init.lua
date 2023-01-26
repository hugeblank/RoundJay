-- Libraries
local raisin = require("rj.raisin").manager(os.pullEvent)
local expect = require("cc.expect").expect
local config = require("rj.config")
local table = require("rj.table")
local index = require("rj.index")
assert(config.load(), "Could not load config")


-- RoundJay extension framework. 
-- API for adding plugins and custom commands
local out = {}
local actions = {}
local plugins, paths = {}, {}

local function runCommand(self, query, doRender)
    local params = {}
    if query then
        for p in query:gmatch("%S+") do
            params[#params+1] = p
        end
    end
    local out
    if doRender then
        local s, err = pcall(function() out = table.pack(self.action(table.unpack(params))) end)
        if not s then
            printError("Error in command "..self.name..":\n"..err)
            if self.format then
                print(self.format)
            end
            return false, err
        end
        if self.render then
            local s, err = pcall(function() self.render(table.unpack(out)) end)
            if not s then
                printError("Error in rendering "..self.name..":\n"..err)
                return false, err
            end
        end
    else
        out = table.pack(self.action(table.unpack(params)))
    end
    return table.unpack(out)
end

-- Command creation factory
out.buildCommand = function(name)
    assert(not actions[name], "Command with name "..name.." already exists.")
    local builder = {}
    local command = {name = name}
    local built = false
    
    local function checkBuilt()
        assert(not built, "Command already built")
    end
    
    checkBuilt()
    
    builder.action = function(func)
        checkBuilt()
        expect(1, func, "function")
        command.action = func
        return builder
    end
    
    builder.renderer = function(func)
        checkBuilt()
        expect(1, func, "function")
        command.render = func
        return builder
    end
    
    builder.completion = function(func)
        checkBuilt()
        expect(1, func, "function")
        command.completion = func
        return builder
    end
    
    builder.format = function(formatText)
        command.format = formatText
        return builder
    end
    
    builder.build = function()
        checkBuilt()
        command.run = function(...) runCommand(command, ...) end
        actions[name] = command
        built = true
    end
    
    return builder
end

out.getCommands = function()
    local out = {}
    for k, v in pairs(actions) do
        out[k] = v.run
    end
    return out
end

out.getCompletions = function()
    local out = {}
    for k, v in pairs(actions) do
        out[k] = v.completion
    end
    return out
end

-- Add a plugin, in the require format
out.addPlugin = function(path)
    expect(1, path, "string")
    local info
    local s, err = pcall(function() info = require(path) end)
    if not s then
        return false, err
    end
    plugins[#plugins+1] = {name = info.name, version = info.version, path = path, loaded = true}
    local paths = config.get("plugins") or {}
    paths[#paths+1] = path
    config.set("plugins", paths)
    config.flush()
    return true
end

out.removePlugin = function(path)
    local removed = false
    for i, v in pairs(paths) do
        if v == path then
            paths[i] = nil
            removed = true
        end
    end
    config.set("plugins", paths)
    config.flush()
    return removed
end

out.loadPlugins = function()
    local paths = config.get("plugins") or {}
    local out = {}
    for i = 1, #paths do
        local info = {}
        local s, err = pcall(function() info = require(paths[i]) end)
        plugins[#plugins+1] = {name = info.name, version = info.version, path = paths[i], loaded = s, error = err}
    end
end

out.getPlugins = function()
    return table.clone(plugins)
end

local waitFor = 0
out.addThread = function(f, ignore)
    if not ignore then
        waitFor = waitFor + 1
    end
    return raisin.thread(f)
end

out.run = function()
    raisin.run(raisin.onDeath.waitForNInitial(waitFor))
end

index.reload()
return out
