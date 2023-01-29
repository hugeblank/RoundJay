--- RoundJay extension framework.
-- API for adding modules, building custom commands, and adding threads to be run in parallel with other executing code.
-- <p><b>Note:</b> functions marked with ⚠️ are yielding</p>
-- @author hugeblank
-- @license MIT
-- @module src
-- @alias out

-- Libraries
local raisin = require("src.raisin").manager(os.pullEvent)
local expect = require("cc.expect")
local config = require("src.config")
local table = require("src.tablex")
local index = require("src.index")
assert(config.load(), "Could not load config")

local out = {}
local actions = {}
local modules, paths = {}, {}

--- Template function for running commands.
-- @tparam table self The internal table of the command being run
-- @tparam table tArgs The table of arguments to be passed to the command action.
-- @tparam boolean doRender Whether or not to run the commands renderer, if it exists.
-- @treturn[1] boolean Whether or not the command was successful.
-- @treturn[1] ?string An error message if the command failed.
-- @return[2] If not rendering, returns whatever the commands action returns.
local function runCommand(self, tArgs, doRender)
    local out
    if doRender then
        local s, err = pcall(function() out = table.pack(self.action(table.unpack(tArgs))) end)
        if not s then
            printError("Error in command "..self.name..":\n"..err)
            if self.usage then
                print(self.usage)
            end 
            return false, err
        end
        if self.renderer then
            local s, err = pcall(function() self.renderer(table.unpack(out)) end)
            if not s then
                printError("Error in rendering "..self.name..":\n"..err)
                return false, err
            end
        end
        return true
    else
        return self.action(table.unpack(tArgs))
    end
end

--- Get a list of commands that can be executed.
-- This is one of the primary points of interaction in the RoundJay API. 
-- It enables you to call any command that could be accessed by the user in the client.
-- @see runCommand
-- @treturn {[string]=function} A table where keys are command names, and values are wrapped action functions 
out.getCommands = function()
    local out = {}
    for k, v in pairs(actions) do
        out[k] = v.run
    end
    return out
end

--- Get a list of completion functions for the built commands.
-- Primarily used for clients that are operating on user input.
-- @treturn {[string]=function} A table where the keys are command names, and values are completion functions, if they exist.
out.getCompletions = function()
    local out = {}
    for k, v in pairs(actions) do
        out[k] = v.completion
    end
    return out
end

--- Creates a new command builder.
-- Examples of usage can be found in the stock modules provided by RJ.
-- @tparam string name Name of the command, must not be the same as an existing command.
-- @tparam function action The function to run.
-- @tparam ?function renderer A function that takes in the returned values from the action function, and outputs them in a readable format.
-- @tparam ?function completion The auto-completion function.
-- @tparam ?string usage A string on how to use the command
out.addCommand = function(name, action, renderer, completion, usage)
    expect(1, name, "string")
    expect(2, action, "function")
    expect(3, renderer, "function", "nil")
    expect(4, completion, "function", "nil")
    expect(5, usage, "string", "nil")
    local command = {
        name = name,
        action = action,
        renderer = renderer,
        completion = completion,
        usage = usage,
    }
    command.run = function(...) runCommand(command, ...) end
    actions[name] = command
end

--- Add and load a module
-- Immediately loads the module, and gets added to the list of modules that get loaded on future program starts.
-- If you're writing a module be careful around this function. Do not add your own module in the same file, that will error.
-- @tparam string path The path to the module in require format ex: `rj.base`, `rj.multi`.
-- @treturn boolean Whether the module was found and loaded.
-- @treturn ?string An error string if the module was not found or loaded.
out.addModule = function(path)
    expect(1, path, "string")
    local info
    local s, err = pcall(function() info = require(path) end)
    if not s then
        return false, err
    end
    modules[#modules+1] = {name = info.name, version = info.version, path = path, loaded = true}
    local paths = config.get("modules") or {}
    paths[#paths+1] = path
    config.set("modules", paths)
    config.flush()
    return true
end

--- Removes a module
-- Removes a module from the list of modules that get loaded on future program starts. In order for commands and other features loaded by
-- this module to be completely removed, the program must be exited.
-- @tparam string path The path to the module in require format ex: `rj.base`, `rj.multi`.
-- @treturn boolean Whether the module was found and removed.
out.removeModule = function(path)
    local removed = false
    for i, v in pairs(paths) do
        if v == path then
            paths[i] = nil
            removed = true
        end
    end
    config.set("modules", paths)
    config.flush()
    return removed
end

--- Loads the list of added modules.
-- Used once on client or script load, and then never again. Not to be used by plugins.
out.loadModules = function()
    local paths = config.get("modules") or {}
    local out = {}
    for i = 1, #paths do
        local info = {}
        local s, err = pcall(function() info = require(paths[i]) end)
        modules[#modules+1] = {name = info.name, version = info.version, path = paths[i], loaded = s, error = err}
    end
end

--- Get the list of modules.
-- @treturn {moduleStatus,...} The list of module statuses.
out.getModules = function()
    return table.clone(modules)
end

local waitForAmount = 0
--- Add a thread to be run concurrently with other script or module threads.
-- Example of usage can be found in module rj.modules.multi.
-- @tparam func f The function to be executed
-- @tparam boolean waitFor Whether to wait for this thread should others surrounding it die. Generally avoid this.
out.addThread = function(f, waitFor)
    if waitFor then
        waitForAmount = waitForAmount + 1
    end
    return raisin.thread(f)
end

--- ⚠️ Process all threads passed into RoundJay.
-- When writing a client, or script, generally you want this call to be the last line in the program,
-- to ensure everything loads properly.
out.run = function()
    raisin.run(raisin.onDeath.waitForNInitial(waitForAmount))
end

--- A module status.
-- @tparam string name The name of the module.
-- @tparam string version The version of the module.
-- @tparam string path The path of the module in require format.
-- @tparam boolean loaded Whether the module successfully loaded
-- @tparam string error If the module did not load, a string detailling why.
-- @table moduleStatus

index.reload()
return out
