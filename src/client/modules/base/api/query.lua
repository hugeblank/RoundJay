local ClassBuilder = require "src.common.api.class"
local Command = require "src.client.api.command"
local network = require "src.common.api.network"
local completion = require "cc.completion"

--- @class QueryCommand: Command
--- @field private super Command
local QueryCommand = ClassBuilder:new(Command)

--- Internal constructor for QueryCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
---@param name string
function QueryCommand:__new(name)
    self.super:__new(name)
end

function QueryCommand:setNames(items)
    self.names = items
end

--- @param words string[]
--- @return string[]?
function QueryCommand:completion(words)
    if #words >= 1 and self.names then
        local query = table.concat(words, " "):lower()
        local valid = {} ---@type string[]
        if #query > 0 then
            for _, name in ipairs(self.names) do
                local ms, me = name:lower():find(query)
                if ms == 1 and #name > me then
                    valid[#valid + 1] = name:sub(me+1, -1)
                end
            end
        end
        table.sort(valid, function(a, b)
            return #a < #b
        end)
        return valid
    end
end

return QueryCommand