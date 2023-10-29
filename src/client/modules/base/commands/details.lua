local ClassBuilder = require "src.common.api.class"
local QueryCommand = require "src.client.modules.base.api.query"
local network = require "src.common.api.network"
local completion = require "cc.completion"

--- @class DetailsCommand: QueryCommand
--- @field new fun(self: QueryCommand, interfaceId: integer): DetailsCommand
--- @field private super QueryCommand
local DetailsCommand = ClassBuilder:new(QueryCommand)

--- Internal constructor for DetailsCommand object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see DetailsCommand.new
--- @param id integer Interface ID to target
function DetailsCommand:__new(id)
    self.super:__new("roundjay:details")
    self.id = id
    network.addBroadcast("roundjay:base/player_interface/details")
end

function DetailsCommand:execute(params)
    local query = table.concat(params, " ")
    if #query > 0 then
        os.queueEvent("roundjay:base/player_interface/details", {
            id = self.id,
            cid = os.getComputerID(),
            query = query
        })
    else
        self.logger:log("error", "Missing item query.")
    end
end

return DetailsCommand