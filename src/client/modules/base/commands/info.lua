local ClassBuilder = require "src.common.api.class"
local Command = require "src.client.api.command"

--- @class InfoCommand: Command
--- @field new fun(self: Command, network: Network, interfaceId: integer): InfoCommand
--- @field private super Command
local InfoCommand = ClassBuilder:new(Command)

--- Internal constructor for InfoCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see InfoCommand.new
--- @param network Network Network to register broadcasted events to
--- @param id integer Interface ID to target
function InfoCommand:__new(network, id)
    self.super:__new("base/info", network)
    self.id = id
    self.event_name = network:addBroadcast("get_info")
end

function InfoCommand:execute(params)
    os.queueEvent(self.event_name, {
        id = self.id,
        cid = os.getComputerID()
    })
end

return InfoCommand