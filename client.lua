local config = require "rj.client.config"
local logger = (require "src.common.api.logger"):new("client")
local table = require "src.common.api.tablex"
local paralyze = require "src.common.api.paralyze"
local Network  = require "src.common.api.network"
local prompt   = require "src.client.api.prompt"
local completion = require "cc.completion"

assert(type(config) == "table", "Malformed config, check rj/config.lua")

local path
do
    local root = fs.getDir(shell.getRunningProgram())
    function path(...)
        return fs.combine(root, ...)
    end
end

local sx, sy = term.getSize()
--- @class WindowTermOverwrite: WindowTerm
local win = window.create(term.current(), 1, 1, sx, sy - 1)
local bsx, bsy = win.getSize()
local offset = 0
local uphist, downhist = {}, {}

local oscroll = win.scroll

win.scroll = function(n, nowrite) -- you can tell I had no idea what I'm doing
    if n == 0 then                -- reset
        local cy = #downhist
        if cy > 0 then
            win.scroll(cy, true)
            win.setCursorPos(1, bsy)
        end
    elseif math.abs(n) == n then -- down
        for i = 1, n do
            if nowrite and #downhist - 1 < 0 then
                return
            end
            uphist[#uphist + 1] = table.pack(win.getLine(1))
            oscroll(1)
            if #downhist > 0 then
                win.setCursorPos(1, bsy)
                win.blit(table.unpack(table.remove(downhist, #downhist)))
                win.setCursorPos(1, bsy - 1)
            end
        end
    else -- up
        for i = math.abs(n), 1, -1 do
            if offset <= 0 then
                return
            end
            downhist[#downhist + 1] = table.pack(win.getLine(bsy))
            oscroll(-1)
            if #uphist > 0 then
                win.setCursorPos(1, 1)
                win.blit(table.unpack(table.remove(uphist, #uphist)))
                win.setCursorPos(1, bsy - 1)
            end
        end
    end
    offset = offset + n
end


logger.addGlobalListener(function(entry)
    term.setCursorBlink(false)
    local ot = term.redirect(win)
    logger.renderEntryLevel(entry)
    print(entry.message)
    term.redirect(ot)
end)


local network = Network:new("client")
local modpath = "src/client/modules/"
local modules, batch, commands = {}, {}, {} --- @type table<string, table>, function[], Command[]
-- initialize all modules
for _, namespace in ipairs(fs.list(path(modpath))) do
    if fs.isDir(path(modpath, namespace)) then
        local mod = require(modpath:gsub("/", ".") .. namespace)
        if type(mod) == "table" then
            modules[#modules + 1] = mod
            if not config.modules then
                logger:log("error", "Missing config.modules table. Using an empty table.")
                config.modules = {}
            end
            if not config.modules[namespace] then
                logger:log("warn", "Missing config for module \"" .. namespace .. "\"")
            end
            local modnet = network:subnet(namespace)
            local loadedcmds = mod.load(config.modules[namespace], modnet, logger)
            for _, command in ipairs(loadedcmds) do ---@cast command Command
                commands[#commands+1] = command
            end
            if type(mod.run) == "function" then
                batch[#batch+1] = function()
                    mod.run(config.modules[namespace], modnet, logger)
                end
            end
        else
            logger:log("error", "Expected table from module \""..namespace.."\", got "..type(mod)..". Module will not be initialized.")
        end
    end
end

if config.networking and config.networking.enabled then
    local haschannel = not config.networking.channel or type(config.networking.channel) == "number"
    if haschannel and type(config.networking.side) == "string" then
        batch[#batch + 1] = function()
            local channel = config.networking.channel or 0
            logger:log("info", "Networking enabled. Modem", tostring(config.networking.side), "channel", channel)
            Network.run(config.networking.side, channel)
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

---comment
---@param cmds Command[]
---@return function
local function handleCompletion(cmds)
    local names, invalid = {}, {} ---@type table<string, Command>, table<string, boolean>
    for _, command in ipairs(cmds) do
        local short = command:getName(true)
        if names[short] and not invalid[short] then
            names[short] = nil
            invalid[short] = true
        else
            names[short] = command
        end
        names[command:getName()] = command
    end
    local cmdnamelist = {}
    for name in pairs(names) do
        cmdnamelist[#cmdnamelist+1] = name
    end
    return function(input) -- Return a function that operates completion on both shell and current RJ commands.
        local words = {}
        for word in input:gmatch("%S+") do -- Break the input up into words
            words[#words+1] = word
        end
        if input:sub(-1, -1) == " " then -- If the last character is a space, start another word
            words[#words+1] = ""
        end
        if #words == 1 then -- If we're interpreting a command
            if words[1]:sub(1, 1) == "!" then -- If that command is intended to be a shell command
                local prog = words[1]:sub(2, -1) -- remove the "!"
                return shell.complete(prog) -- Shell program autocompletion
            else
                return completion.choice(words[1], cmdnamelist) -- RJ command autocompletion
            end
        elseif #words > 1 then -- If we're parsing an argument
            local command = table.remove(words, 1)
            if command:sub(1, 1) == "!" then -- Shell argument autocompletion
                local shcmd = command:sub(2, -1)
                command = shell.resolveProgram(shcmd)
                local shellCompletion = shell.getCompletionInfo()[command]
                if shellCompletion then -- If there's shell completion info, handle it.
                    local prev = table.clone(words)
                    prev[#prev] = nil
                    return shellCompletion.fnComplete(shell, #words, words[#words], prev)
                end
            elseif names[command] and names[command].completion then -- RJ argument autocompletion
                return names[command]:completion(words)
            end
        end
    end
end

-- Input thread
local function main()
    win.setCursorPos(1, 1)
    local ot = term.current()
    local history = {}
    while true do
        term.redirect(ot)
        term.setCursorPos(1, sy)
        term.setTextColor(colors.lime)
        term.write("> ")
        term.setTextColor(colors.white)
        term.redirect(win)
        local input = prompt(ot, history, handleCompletion(commands))
        if #input > 0 then
            if history[#history] ~= input then
                table.insert(history, input)
            end
            win.restoreCursor()
            term.setTextColor(colors.lime)
            write("> ")
            term.setTextColor(colors.white)
            print(input)
            local params = {} ---@type string[]
            for word in input:gmatch("%S+") do
                params[#params + 1] = word
            end
            if #params > 0 then
                local cmdword = table.remove(params, 1)
                if cmdword == "exit" then
                    term.redirect(ot)
                    term.clear()
                    term.setCursorPos(1, 1)
                    return
                end
                if cmdword:sub(1, 1) == "!" then -- Shell argument autocompletion
                    local shcmd = cmdword:sub(2, -1) .. " " .. table.concat(params, " ")
                    shell.run(shcmd)
                else
                    local matches = {} ---@type Command[]
                    for _, command in ipairs(commands) do
                        if command:getName() == cmdword then -- Exact match
                            matches = { command }
                            break
                        elseif command:getName(true):find(cmdword) == 1 then
                            matches[#matches + 1] = command
                        end
                    end
                    if #matches > 1 then
                        logger:log("error",
                            "More than one command matches " ..
                            cmdword .. ". Try again with more characters, or use the full command name.")
                    elseif #matches == 0 then
                        logger:log("error", "No match found for  '" .. cmdword .. "'.")
                    else
                        matches[1]:execute(params)
                    end
                end
            end
        end
    end
end

local function scroll()
    while true do
        local e, dir = os.pullEvent()
        if e == "mouse_scroll" then
            win.scroll(dir, true)
        elseif e == "key" and dir == keys.enter then
            win.scroll(0)
        end
    end
end

parallel.waitForAny(scroll, main, function()
    parallel.waitForAll(paralyze.run, table.unpack(batch))
end)