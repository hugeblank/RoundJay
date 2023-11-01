local ClassBuilder = require "src.common.api.class"
local Index = require "src.server.api.index"
local Logger = require "src.common.api.logger"

--- Abstract device class, partially implements functionality.
-- Constructor accepts a deviceConfig provided by the server initialization, and an index created by the sub-device.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @class Device: Class
--- @field role "import"|"export"|"storage"|"convert"|"dummy" Role of this device
--- @field type string Custom type name of this device
--- @field protected index Index inventory index for this device
local Device = ClassBuilder:new()

--- @class deviceConfig
--- @field side string What side this device can be interfaced from. Multi-device operations require that this match.
--- @field type string Determines the behavior, and to which module the device should be directed to for processing.

--- Internal constructor for Device object
-- If extending from this class, be sure to call this method in your constructor (self.super:__new(...))
--- @protected
--- @param id integer
--- @param role "import"|"export"|"storage"|"convert"|"dummy"
--- @param type string
--- @param index Index
function Device:__new(id, role, type, index)
    self.id = id
    self.role = role
    self.type = type
    self.index = index
end

--- Return true if the device is compatible with the given type.
-- Used for devices that want to be compatible with other devices.
-- For example, if you wanted to implement a device that behaves akin to a BasicStorage you'd want to override this function.
--- @see BasicStorage
--- @param type string
function Device:is(type)
    return type == self.type
end

--- ⚠️ When given an item from a source device, returns the amount that the targetted device (self) can accept.
-- Devices of the 'export', 'storage', and 'convert' role should probably override this method.
--- @see ExportBus.accepts | A simple example of the accepts method
--- @param source Device The source device giving the items.
--- @param item Item The item to be given.
--- @param amount integer The amount to be given.
--- @return integer # The amount that this device accepts.
function Device:accepts(source, item, amount)
    return 0
end

--- ⚠️ The target device is making a request for the given item (or item hash). Return the amount that may be allocated.
-- Devices of the 'import', 'storage', and 'convert' role should probably override this method.
--- @see ImportBus.contains | A simple example of the contains method
--- @param target Device The device making the request.
--- @param item Item The item requested.
--- @return integer # The amount of the item this device is making available for the target device.
function Device:contains(target, item)
    return 0
end

--- ⚠️ Attempt to insert a given item from this device into another.
-- Amount is the smallest value between the amount the target chooses to accept and the amount the source device (self) has for the target passed in.
-- The `amount` parameter passed into this method is really only an 'intended amount' to hand off to the target.
--- @param target Device The device being sent the item
--- @param item Item The item or item hash being inserted
--- @param amount integer The maximum intended amount of items to be sent
--- @return integer # The amount actually inserted
function Device:insert(target, item, amount)
    assert(self ~= target, "Source and Destination must not be the same")
    -- self.logger:log("debug", "contains | accepts: ", self:contains(target, item), target:accepts(self, item, amount))
    local accepted = math.min(self:contains(target, item), target:accepts(self, item, amount))
    if accepted > 0 then
        return self.index:move(target.index, item, accepted)
    else
        return 0
    end
end

--- Run the device handler. The server takes this method and provides the device ID of this device for ease of use.
function Device:run()
end

return Device