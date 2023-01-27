--- RoundJay client
-- The default client shipped with RoundJay. Feel free to make your own!
-- @author hugeblank
-- @license MIT
-- @script rjclient

local version = "0.2.0"
-- Run self-diagnostics before starting
require("rj.client.tests").runTests()
local completion = require("cc.completion")
local rj = require("rj")
local table = require("rj.table")
local util = require("rj.util")


--- Handles autocompletion of commands and arguments
-- @see rj.getCompletions
-- @see util.closestMatch
-- @tparam table commands A table where the keys are command names, and values are command action functions.
-- @treturn function A function used in `read` to handle autocompletion.
local function handleCompletion(commands)
    local commandCompletions = rj.getCompletions() -- Up to date completion list.
    local keywords = {} -- Move command keywords into int key table
    for k, v in pairs(commands) do
        keywords[#keywords+1] = k
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
                return completion.choice(words[1], keywords) -- RJ command autocompletion
            end
        elseif #words > 1 then -- If we're parsing an argument
            local command = table.remove(words, 1)
            if command:sub(1, 1) == "!" then -- Shell argument autocompletion
                local shcmd = command:sub(2, -1)
                command = shell.resolveProgram(shcmd)
                local completion = shell.getCompletionInfo()[command]
                if completion then -- If there's shell completion info, handle it.
                    local prev = table.clone(words)
                    prev[#prev] = nil
                    return completion.fnComplete(shell, #words, words[#words], prev)
                end
            else -- RJ argument autocompletion
                local fCompletion = util.closestMatch(command, commandCompletions) -- Handle incomplete commands
                if fCompletion then -- If there's a completion function
                    return fCompletion(words)
                end
            end
        end
    end
end

--- Handle shell argument parsing, user input, and files with RJ commands.
-- @see rj.getCommands
-- @see handleCompletion
-- @see util.closestMatch
-- @tparam {string,...} params A table of parameters brought in from the shell. First parameter may be a file name.
local function handleKeywords(params)
    local history = {} -- `read` history
    local queue = {} -- Command queue
    -- Unique value for exit
    local exit = {}
    repeat
        local commands = rj.getCommands() -- Up to date command list. Re-loaded every input so loaded plugins get their commands added.
        commands["exit"] = exit -- Setting exit command value
        -- Shell Parameter & User Input parsing --
        if #queue == 0 then
            local directive = "" -- A string containing potentially multiple commands
            if params then -- If there are parameters we can handle, handle them first
                if fs.exists(params[1]) then -- If the first parameter is a file
                    for line in io.lines(params[1]) do -- Create one big directive using the lines
                        directive = directive..line..";"
                    end
                else -- Repair shell params disaster
                    table.foreachi(params, function(_, param)
                        if param:match(" ") then -- If a parameter has a space in it, wrap it in quotes
                            directive = directive.."\""..param.."\" "
                        else -- Otherwise just space separate them and let directive parsing handle the situation.
                            directive = directive..param.." "
                        end
                    end)
                end
                params = nil -- All done with params
            else 
                term.setTextColor(colors.lime)
                write("> ")
                term.setTextColor(colors.white)
                -- Get user input
                directive = read(nil, history, handleCompletion(commands))
            end
            local i = directive:find(";")
            while i do -- Break directive up into individual commands with arguments
                local command = directive:sub(1, i-1) -- Get an individual command
                queue[#queue+1] = command -- Add it to the queue and history
                history[#history+1] = history
                directive = directive:sub(i+1, -1)
                i = directive:find(";")
            end 
            if #directive > 0 then -- If there's still a command leftover, or there simply weren't any semicolons (just one command).
                queue[#queue+1] = directive -- Add it to the queue and history
                history[#history+1] = directive
            end
        end
        -- Individual command parsing --
        local cmd = table.remove(queue, 1) or "" -- Get a command off the queue (or a blank string)
        local args = {} -- Break up the command into arguments
        for word in cmd:gmatch("%S+") do
            args[#args+1] = word
        end
        local action = args[1]
        if action then -- If there was a command at all
            if action:sub(1, 1) == "!" then -- If that command is meant to be run through the shell
                shell.run(table.concat(args, " "):sub(2, -1)) -- Remove the "!"
            else
                local commandFunction = util.closestMatch(action, commands) -- Find the closest command name to the given action 
                -- Note: action may not be a complete command name, but we still have to find the users intent. ex. `p 10 cobblestone`
                if commandFunction == exit then
                    return -- The command was to exit rjclient
                elseif commandFunction then -- If there's a match
                    table.remove(args, 1) -- Remove the command name from the args
                    commandFunction(args, true) -- Run command, pass in args, and render
                else
                    printError("Invalid command. See 'help' for options.")
                end
            end
        end
    until false
end
  
local params = {...}
if #params == 0 then -- If there's no params, get fancy, show the header
    term.setTextColor(colors.lightBlue)
    print("RoundJay CLI "..version)
    rj.addThread(handleKeywords)
else -- Otherwise get straight into business
    rj.addThread(function() 
        handleKeywords(params) 
    end)
end
rj.run()
