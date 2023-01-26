local version = "0.2.0"
-- Run self-diagnostics before starting
require("rj.client.tests").runTests()
local completion = require("cc.completion")
local rj = require("rj")
local table = require("rj.table")
local util = require("rj.util")

local function handleKeywords(params)
    local history = {}
    local queue = {}
    -- Unique value for exit
    local exit = {}
    repeat
        local commands = rj.getCommands()
        local cmdcomplete = rj.getCompletions()
        commands["exit"] = exit
        if #queue == 0 then
            local batch = ""
            if not params then
                term.setTextColor(colors.lime)
                write("> ")
                term.setTextColor(colors.white)
                local keywords = {}
                for k, v in pairs(commands) do
                    keywords[#keywords+1] = k
                end
                batch = read(nil, history, function(input)
                    local words = {}
                    for word in input:gmatch("%S+") do
                        words[#words+1] = word
                    end
                    if input:sub(-1, -1) == " " then
                        words[#words+1] = ""
                    end
                    if #words == 1 then
                        if words[1]:sub(1, 1) == "!" then
                            -- Shell program autocompletion
                            local prog = words[1]:sub(2, -1)
                            return shell.complete(prog)
                        else
                            -- RJ command autocompletion
                            return completion.choice(words[1], keywords)
                        end
                    elseif #words > 1 then
                        local command = table.remove(words, 1)
                        if command:sub(1, 1) == "!" then 
                            -- Shell argument autocompletion
                            local shcmd = command:sub(2, -1)
                            command = shell.resolveProgram(shcmd)
                            local completion = shell.getCompletionInfo()[command]
                            local out = {}
                            if completion then
                                local prev = table.clone(words)
                                prev[#prev] = nil
                                return completion.fnComplete(shell, #words, words[#words], prev)
                            end
                        else
                            -- RJ argument autocompletion
                            local compfunc = cmdcomplete[command]
                            if compfunc then
                                return compfunc(words)
                            end
                        end
                    end
                end)
            else
                if fs.exists(params[1]) then
                    for line in io.lines(params[1]) do
                        batch = batch..line..";"
                    end
                else -- repair shell params disaster
                    table.foreachi(params, function(_, param)
                        if param:match(" ") then
                        batch = batch.."\""..param.."\" "
                        else
                            batch = batch..param.." "
                        end
                    end)
                end
                params = nil
            end
            while batch:find(";") do
                local i = batch:find(";")
                queue[#queue+1] = batch:sub(1, i-1)
                batch = batch:sub(i+1, -1)
            end 
            if #batch > 0 then
                queue[#queue+1] = batch
                history[#history+1] = batch
            end
        end
        local cmd = table.remove(queue, 1) or ""
        local args = {}
        for word in cmd:gmatch("%S+") do
            args[#args+1] = word
        end
        local action = args[1]
        if action then
            if action:sub(1, 1) == "!" then
                shell.run(table.concat(args, " "):sub(2, -1))
            else
                local commF = util.closestMatch(action, commands)
                if commF then
                    table.remove(args, 1)
                    if commF == exit then
                        return
                    end
                    commF(table.concat(args, " "), true)
                else
                    printError("Invalid command. See 'help' for options.")
                end
            end
        end
    until false
end
  
local query = {...}
if #query == 0 then
    term.setTextColor(colors.lightBlue)
    print("RoundJay CUI "..version)
    rj.addThread(handleKeywords)
else
    rj.addThread(function() 
        handleKeywords(query) 
    end)
end
rj.run()
