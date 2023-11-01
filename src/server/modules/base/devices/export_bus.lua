local registry = require "src.server.api.registry"
local Index = require "src.server.api.index"
local ClassBuilder = require "src.common.api.class"
local Device = require "src.server.api.device"
local Logger = require "src.common.api.logger"

--- @class ExportBus: Device
--- @field new fun(self: Class, exportBusConfig: exportBusConfig): ExportBus --- ⚠️ Create a new ExportBus.
--- @field private super Device
local ExportBus = ClassBuilder:new(Device)

--- @class exportBusConfig: deviceConfig
--- @field details exportBusDetails

--- Details necessary to create an export bus
--- @class exportBusDetails
--- @field source integer Source device network table ID
--- @field whitelist table<string, integer> Whitelist table, where the key is the item hash, and the value is the amount of that item to fill
--- @field inventory string|nil Target inventory peripheral ID
--- @field interval integer|nil Amount of seconds between checking and requesting items.
--- @field accepts fun(source: Device, item: Item, amount: integer, index: Index)|nil Custom accepts function, called after the device completes its accepts checks

--- ⚠️ Internal constructor for ExportBus object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see ExportBus.new
--- @param id integer
--- @param exportBusConfig exportBusConfig
function ExportBus:__new(id, exportBusConfig)
    assert(exportBusConfig.details, "Export Bus requires additional details (<device>.details)")
    assert(exportBusConfig.details.inventory, "Export Bus requires a target inventory (<device>.details.inventory)")
    self.logger = Logger:new(exportBusConfig.type .. "/" .. id)
    self.super:__new(id, "export", exportBusConfig.type, Index:new(exportBusConfig.side, { exportBusConfig.details.inventory }, self.logger))
    self.details = exportBusConfig.details
end

--- ⚠️ When given an item from a source device, returns the amount that the targetted device (self) can accept.
--- @param source Device The source device giving the items.
--- @param item Item The item to be given.
--- @param amount integer The amount to be given.
--- @return integer # The amount that this device accepts.
function ExportBus:accepts(source, item, amount)
    if type(item) ~= "table" then
        self.logger:log("error","expected an item table, got "..tostring(item))
        return 0
    end
    local remaining = self.index:getFreeSpace()
    if remaining < math.ceil(amount / item.nbt.maxCount) then
        -- Return the most we can accept, running into the limit of space given.
        local left = 0
        local indItem = self.index:getItemFromHash(item:getHash())
        if indItem then
            left = item.nbt.maxCount - (indItem:getCount() % item.nbt.maxCount)
        end
        amount = (item.nbt.maxCount * remaining) + left
    end
    local whitelisted = false or not self.details.whitelist -- if there's a whitelist, check for the item
    for hash, requested in pairs(self.details.whitelist) do
        if hash == item:getHash() then
            whitelisted = true
            break
        end
    end
    if not whitelisted then -- if it's not on the whitelist, we don't accept it, unless the user has an overriding accepts function.
        amount = 0
    end
    if type(self.details.accepts) == "function" then
        amount = self.details.accepts(source, item, amount, self.index) or amount
    end
    return amount
end

--- Run the device handler. The server takes this method and provides the device ID of this device for ease of use.
function ExportBus:run()
    while true do
        local sources --- @type BasicStorage[]
        if self.details.source then
            local source = registry.getDevice(self.details.source) ---@cast source BasicStorage
            sources = {
                source
            }
        else
            sources = registry.getDevicesOfRole("storage")
        end
        for _, source in ipairs(sources) do
            for hash, requested in pairs(self.details.whitelist) do
                local sourceItem
                if hash:find("#") then -- Not a big fan of this
                    sourceItem = source.index:getItemFromHash(hash)
                else
                    sourceItem = source.index:getItemFromName(hash)
                end
                if sourceItem and (requested == -1 or requested - sourceItem:getCount() > 0) then
                    if requested == -1 then
                        requested = sourceItem:getCount()
                    end
                    print(requested)
                    local amount = source:insert(self, sourceItem, requested)
                    self.logger:log("info", "Moved", tostring(amount).."x", sourceItem:getDisplayName(), "\nfrom:", source.type.."/"..source.id, "\nto:", self.type.."/"..self.id)
                end
            end
        end
        sleep(self.details.interval or 5)
        self.index:reload()
    end
end

return ExportBus