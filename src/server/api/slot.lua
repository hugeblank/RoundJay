local logger = require("src.common.api.logger"):new("slot")
local expect = require "cc.expect"
local table = require "src.common.api.tablex"
local ClassBuilder = require "src.common.api.class"

--- Class whose objects represents a single item stack in a slot in an inventory.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @class (exact) Slot: Class
--- @field new fun(self: Slot, inventory: string, slot: integer, details:basicDetails): Slot -- Constructor for a slot object
--- @field private inventory string
--- @field private slot integer
--- @field private details basicDetails
local Slot = ClassBuilder:new()

--- Basic information about an item stack.
-- <p><b>See also:</b> <a href=https://tweaked.cc/generic_peripheral/inventory.html#v:list>cct:inventory.list</a></p>
--- @class basicDetails
--- @field name string The identifier of this item.
--- @field count integer The amount of items in the slot.
--- @field nbt ?string The NBT hash of this item.

--- Internal constructor for Slot object
--- @protected
--- @see Slot.new
--- @param inventory string
--- @param slot integer
--- @param details basicDetails
function Slot:__new(inventory, slot, details)
    expect(1, inventory, "string")
    expect(2, slot, "number")
    expect(3, details, "table")
    self.inventory = inventory
    self.slot = slot
    self.details = details
end

--- Get the unique hash of the item contained in a slot.
-- This is not the same as the nbt hash, but rather a combination of the item identifier and nbt hash, if it exists.
---@return string
function Slot:getHash()
    local s = ""
    if self.details.nbt then
        s = "#"..self.details.nbt
    end
    return self.details.name..s
end

--- Determine whether this slot has NBT.
--- @return boolean # Whether this slot has an NBT hash or not.
function Slot:hasNbt()
    return self.details.nbt ~= nil
end

--- ⚠️ Get NBT details from this slot.
-- <p><b>See also:</b> <a href=https://tweaked.cc/generic_peripheral/inventory.html#v:getItemDetail>cct:inventory.getItemDetail</a></p>
--- @return table # The details of this item.
function Slot:getNbtDetails()
    local itemDetail = peripheral.call(self.inventory, "getItemDetail", self.slot)
    itemDetail.count = nil
    return itemDetail
end

--- Get basic details from this slot.
--- @return basicDetails # The basic information about a slot.
function Slot:getBasicDetails()
    return table.clone(self.details)
end

--- Get the inventory and slot id this Slot object represents.
--- @return string # The inventory of the slot.
--- @return integer # The slot number of the slot.
function Slot:getLocation()
    return self.inventory, self.slot
end

--- ⚠️ Take items from this slot.
--- @param to string The inventory the items should be put into.
--- @param tSlot integer The optional slot id of the `to` inventory the items should be put into.
--- @param amount integer The amount of items to be taken from the slot.
--- @return integer # The number of items taken from the slot.
function Slot:take(to, tSlot, amount)
    local c = peripheral.call(self.inventory, "pushItems", to, self.slot, amount, tSlot)
    logger:log("debug", to, self.slot, amount, tSlot, "->", c)
    self.details.count = self.details.count-c
    return c
end

--- ⚠️ Put items into this slot.
--- @param from string The inventory from which the items should be brought in from.
--- @param fSlot integer The slot id of the `from` inventory in which the targeted items exist.
--- @return integer # the number of items put into the slot.
function Slot:put(from, fSlot)
    -- Assumes the max stack size for any item is 64.
    local c = peripheral.call(self.inventory, "pullItems", from, fSlot, 64, self.slot)
    self.details.count = self.details.count + c
    return c
end

--- ⚠️ Put items into this slot using an Item object.
--- @param fromItem Item The inventory from which the items should be brought in from.
--- @return integer # the number of items put into the slot.
function Slot:putItem(fromItem)
    local c = fromItem:take(self.inventory, self.slot, 64)
    self.details.count = self.details.count + c
    return c
end

--- Get the amount of items in the slot.
--- @return integer # The amount of items in the slot.
function Slot:getCount()
    return self.details.count
end

return Slot
