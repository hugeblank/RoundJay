local ClassBuilder = require "src.common.api.class"
local Command = require "src.client.api.command"
local network = require "src.common.api.network"

--- @class FlushCommand: Command
--- @field new fun(self: Command, interfaceId: integer): FlushCommand
--- @field private super Command
local FlushCommand = ClassBuilder:new(Command)

--- Internal constructor for FlushCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see FlushCommand.new
--- @param id integer Interface ID to target
function FlushCommand:__new(id)
    self.super:__new("roundjay:flush")
    self.id = id
    network.addBroadcast("roundjay:base/player_interface/flush")
end

function FlushCommand:execute(params)
    os.queueEvent("roundjay:base/player_interface/flush", {
        id = self.id,
        cid = os.getComputerID(),
    })
end

return FlushCommand