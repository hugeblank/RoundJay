local ClassBuilder = require "src.common.api.class"
local QueryCommand = require "src.client.modules.base.api.query"
local completion = require "cc.completion"

--- @class PullCommand: QueryCommand
--- @field new fun(self: QueryCommand, network: Network, interfaceId: integer): PullCommand
--- @field private super QueryCommand
local PullCommand = ClassBuilder:new(QueryCommand)

--- Internal constructor for PullCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see PullCommand.new
--- @param network Network Network to register broadcasted events to
--- @param id integer Interface ID to target
function PullCommand:__new(network, id)
    self.super:__new("base/pull", network)
    self.id = id
    self.event_name = network:addBroadcast("pull")
end

function PullCommand:execute(params)
    local amtstr = table.remove(params, 1)
    if type(amtstr) == "string" then
        local query = table.concat(params, " ")
        if #query > 0 then
            os.queueEvent(self.event_name, {
                id = self.id,
                cid = os.getComputerID(),
                query = query,
                amount = amtstr
            })
        else
            self.logger:log("error", "Missing item query.")
        end
    else
        self.logger:log("error", "Expected first parameter, amount, got " .. type(amtstr))
    end
end

--- @param words string[]
--- @return string[]?
function PullCommand:completion(words)
    if #words == 0 then
        return
    elseif #words == 1 then
        return completion.choice(words[1], {"all", "stack"})
    elseif #words > 1 then
        table.remove(words, 1)
        return self.super:completion(words)
    end
end

return PullCommand