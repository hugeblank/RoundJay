local ClassBuilder = require "src.common.api.class"
local Command = require "src.client.api.command"
local network = require "src.common.api.network"

--- @class InfoCommand: Command
--- @field new fun(self: Command, interfaceId: integer): InfoCommand
--- @field private super Command
local InfoCommand = ClassBuilder:new(Command)

--- Internal constructor for InfoCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see InfoCommand.new
--- @param id integer Interface ID to target
function InfoCommand:__new(id)
    self.super:__new("roundjay:info")
    self.id = id
    network.addBroadcast("roundjay:base/player_interface/info")
end

function InfoCommand:execute(params)
    os.queueEvent("roundjay:base/player_interface/info", {
        id = self.id,
        cid = os.getComputerID()
    })
end

return InfoCommand