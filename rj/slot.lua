--- The Slot class.
-- @author hugeblank
-- @license MIT
-- @module rj.slot
-- @alias out

local expect = require("cc.expect")
local table = require("rj.table")

local out = {}
local slot = {}

--- Creates a slot object.
-- @tparam string inventory The inventory this slot resides in.
-- @tparam int slot The slot number of the inventory this slot represents.
-- @tparam table details The basic item details of this slot.
-- @treturn slot A slot object representing the parameters given.
out.new = function(inventory, slot, details)
    expect(1, inventory, "string")
    expect(2, slot, "number")
    expect(3, details, "table")
        
    return setmetatable(table.clone(slot), {__index={inventory = inventory, slot = slot, details = details}})
end

--- Basic information about an item stack.
-- @tfield string name The identifier of this item.
-- @tfield int count The amount of items in the slot.
-- @tfield ?string nbt The NBT hash of this item.
-- @table basicDetails

--- Class whose objects represents a single item stack in a slot in an inventory.
--@type slot

--- Get the unique hash of the item contained in a slot.
-- This is not the same as the nbt hash, but rather a combination of the item identifier and nbt hash, if it exists.
-- @treturn string The unique item hash.
function slot:getHash()
    local s = ""
    if self.details.nbt then
        s = " "..self.details.nbt
    end
    return self.details.name..s
end

--- Determine whether this slot has NBT
-- @treturn boolean Whether this slot has an NBT hash or not
function slot:hasNbt()
    return self.details.nbt ~= nil
end

--- ⚠️ Get NBT details from this slot.
-- @treturn table The details of this item.
function slot:getNbtDetails()
    local itemDetail = peripheral.call(self.inventory, "getItemDetail", self.slot)
    itemDetail.count = nil
    return itemDetail
end

--- Get basic details from this slot.
-- @treturn basicDetails The basic information about a slot.
function slot:getBasicDetails()
    return table.clone(self.details) 
end

--- Get the inventory and slot id this Slot object represents.
-- @treturn string The inventory of the slot.
-- @treturn int The slot number of the slot.
function slot:getLocation()
    return self.inventory, slot
end
    
--- ⚠️ Take items from this slot.
-- @tparam string to The inventory the items should be put into.
-- @tparam int amount The amount of items to be taken from the slot.
-- @tparam int tSlot The optional slot id of the `to` inventory the items should be put into.
-- @treturn int The number of items taken from the slot.
function slot:take(to, amount, tSlot)
    local c = peripheral.call(self.inventory, "pushItems", to, self.slot, amount, tSlot)
    self.details.count = self.details.count-c
    return c
end

--- ⚠️ Put items into this slot.
-- @tparam string from The inventory from which the items should be brought in from.
-- @tparam int fSlot The slot id of the `from` inventory in which the targeted items exist.
-- @treturn int the number of items put into the slot.
function slot:put(from, fSlot)
    -- Assumes the max stack size for any item is 64.
    local c = peripheral.call(inventory, "pullItems", from, fSlot, 64, self.slot)
    self.details.count = self.details.count+c
    return c
end

--- Get the amount of items in the slot.
-- @treturn int The amount of items in the slot.
function slot:getCount()
    return self.details.count
end

return out