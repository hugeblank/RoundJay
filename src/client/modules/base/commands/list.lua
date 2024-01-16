local ClassBuilder = require "src.common.api.class"
local QueryCommand = require "src.client.modules.base.api.query"

--- @class ListCommand: QueryCommand
--- @field new fun(self: QueryCommand, network: Network, interfaceId: integer): ListCommand
--- @field private super QueryCommand
local ListCommand = ClassBuilder:new(QueryCommand)

--- Internal constructor for ListCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see ListCommand.new
--- @param network Network Network to register broadcasted events to
--- @param id integer Interface ID to target
function ListCommand:__new(network, id)
    self.super:__new("base/list", network)
    self.id = id
    self.event_name = network:addBroadcast("get_list")
end

function ListCommand:execute(params)
    local limstr = params[1]
    if tonumber(limstr) then
        table.remove(params, 1)
    end
    local query = table.concat(params, " ") ---@type string?
    if #query == 0 then
        query = nil
    end
    os.queueEvent(self.event_name, {
        id = self.id,
        cid = os.getComputerID(),
        query = query,
        limit = tonumber(limstr)
    })
end

function ListCommand:completion(words)
    if tonumber(words[1]) then
        table.remove(words, 1)
    end
    return self.super:completion(words)
end

return ListCommand