local registry = require "src.server.api.registry"
local Index = require "src.server.api.index"
local Device = require "src.server.api.device"
local ClassBuilder = require "src.common.api.class"
local Logger = require "src.common.api.logger"

--- @class ImportBus: Device
--- @field new fun(self: Class, importBusConfig: importBusConfig): ImportBus --- ⚠️ Create a new ImportBus.
--- @field private super Device
local ImportBus = ClassBuilder:new(Device)

--- @class importBusConfig: deviceConfig
--- @field details importBusDetails

--- Details necessary to create an import bus
--- @class importBusDetails
--- @field inventory string Source inventory peripheral ID
--- @field target integer|nil Source device network table ID
--- @field interval integer|nil Amount of seconds between checking and requesting items.
--- @field contains fun(target: Device, item: Item|string, amount: integer, index:Index)|nil Custom contains function, called after the device completes its contains checks

--- ⚠️ Internal constructor for ImportBus object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see ImportBus.new
--- @param id integer
--- @param importBusConfig importBusConfig
function ImportBus:__new(id, importBusConfig)
    assert(importBusConfig.details, "Import Bus requires additional details field in network configuration (<device>.details)")
    assert(importBusConfig.details.inventory, "Import Bus requires a source inventory (<device>.details.inventory)")
    self.logger = Logger:new(importBusConfig.type .. "/" .. id)
    self.super:__new(id, "import", importBusConfig.type, Index:new(importBusConfig.side, { importBusConfig.details.inventory }, self.logger))
    self.details = importBusConfig.details
end

--- ⚠️ The target device is making a request for the given item (or item hash). Return the amount that may be allocated.
--- @see ImportBus.contains | A simple example of the contains method
--- @param target Device The device making the request.
--- @param item Item The item or item hash requested.
--- @return integer # The amount of the item this device is making available for the target device.
function ImportBus:contains(target, item)
    local indItem = self.index:getItemFromHash(item:getHash())
    local count = indItem and indItem:getCount() or 0
    if type(self.details.contains) == "function" then
        count = self.details.contains(target, item, count, self.index) or count
    end
    return count
end

--- Run the device handler. The server takes this method and provides the device ID of this device for ease of use.
function ImportBus:run()
    while true do
        local devices
        if self.details.target then
            devices = { registry.getDevice(self.details.target) }
        else
            devices = registry.getDevicesOfRole("storage")
        end
        local items = self.index:get()
        for key, item in pairs(items) do
            for _, device in ipairs(devices) do ---@cast device Device
                local amount = self:insert(device, item, item:getCount())
                self.logger:log("info", "Moved", tostring(amount).."x", item:getDisplayName(), "\nfrom:", self.type.."/"..self.id, "\nto:", device.type.."/"..device.id)
            end
        end
        sleep(self.details.interval or 5)
        self.index:reload()
    end
end

return ImportBus