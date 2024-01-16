local ClassBuilder = require "src.common.api.class"
local Command = require "src.client.api.command"

--- @class FlushCommand: Command
--- @field new fun(self: Command, network: Network, interfaceId: integer): FlushCommand
--- @field private super Command
local FlushCommand = ClassBuilder:new(Command)

--- Internal constructor for FlushCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see FlushCommand.new
--- @param network Network Network to register broadcasted events to
--- @param id integer Interface ID to target
function FlushCommand:__new(network, id)
    self.super:__new("base/flush", network)
    self.id = id
    self.event_name = network:addBroadcast("flush")
end

function FlushCommand:execute(params)
    os.queueEvent(self.event_name, {
        id = self.id,
        cid = os.getComputerID(),
    })
end

return FlushCommand