local logger = require("src.common.api.logger"):new("item")
local table = require "src.common.api.tablex"
local ClassBuilder = require "src.common.api.class"
local Slot = require "src.server.api.slot"

--- Class whose objects represent a specific item across all slots in the storage system.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @class (exact) Item: Class
--- @field new fun(self:Class, slot: Slot): Item --- ⚠️ Create a new item.
--- @field private hash string
--- @field slots Slot[]
--- @field nbt table
local Item = ClassBuilder:new()

--- Internal constructor for Item object
--- @protected
--- @param slot Slot
--- @see Item.new
function Item:__new(slot)
    local key, slots = {}, { slot }
    self.hash = slot:getHash()
    self.slots = slots
    -- yielding
    self.nbt = slot:getNbtDetails()
end

--- Get the hash of the item.
--- @see Slot.getHash
--- @return string hash The identifier plus NBT hash of the item
function Item:getHash()
    return self.hash
end

--- Get the identifier of the item.
--- @return string name The identifier of the item
function Item:getIdentifier()
    return self.nbt.name
end

--- Get the display name of the item
--- @param raw boolean? strip the display name of enchantments
function Item:getDisplayName(raw)
    if raw then
        return self.nbt.displayName
    else
        local name = self.nbt.displayName ---@type string
        if self.nbt then
            local enc = self.nbt.enchantments
            if enc then
                for i = 1, #enc do
                    name = enc[i].displayName .. " " .. name
                end
            end
        end
        return name
    end
end

--- Gets the amount of slots associated with this item
--- @return integer slotCount
function Item:getSlotCount()
    return #self.slots
end

--- Add a slot to this item.
-- Slot hashes MUST match between the keytable and the slot argument!
--- @param slot Slot The slot to add to this item.
function Item:addSlot(slot)
    assert(slot:getHash() == self.hash, "hash mismatch! expected " .. self.hash .. " got " .. slot:getHash())
    table.insert(self.slots, slot)
end

--- Get the total amount of items represented by this object.
--- @return number amount
function Item:getCount()
    local amount = 0
    for _, slot in ipairs(self.slots) do
        local c = slot:getCount()
        amount = amount + c
    end
    return amount
end

--- The details of an item and its corresponding slots.
--- @class itemDetail
--- @field total number The total amount of items across all slots.
--- @field locations location[] Information about each slot containing this item.
--- @field nbt table NBT details in a similar form to `getItemMeta`.

--- The details of a specific slot
--- @class location
--- @field chest string The inventory this item is located in.
--- @field slot integer The specific slot occupied by the item.
--- @field count integer The amount of items in this slot.


--- Get all details of this item
-- Only returns nil if there are no slots to query the details from.
--- @return itemDetail|nil
function Item:details()
    if #self.slots == 0 then
        return
    end
    local o = self.slots[1]:getBasicDetails() ---@cast o table
    o.count = nil
    local sinfo = {}
    for _, slot in ipairs(self.slots) do
        local chest, sl = slot:getLocation()
        local s = {
            chest = chest,
            slot = sl,
            count = slot:getCount()
        }
        sinfo[#sinfo + 1] = s
    end
    o.total = self:getCount()
    o.locations = sinfo
    o.metadata = self.nbt
    return o
end

--- ⚠️ Take items from the pool of slots that this item represents
--- @param toLocation string The inventory to put the items
--- @param toSlot integer The slot to put the items
--- @param count integer The amount of items to provide. If greater than the total amount of items, will pull from all slots.
--- @param fromIndex? integer The index in this items slot index to pull from
--- @return integer # The amount of items taken.
function Item:take(toLocation, toSlot, count, fromIndex)
    count = math.min(count, self.nbt.maxCount)
    target = count
    while count > 0 do
        slot = self.slots[1]
        local amt = slot:take(toLocation, toSlot, count)
        if amt == 0 then
            break -- toSlot is presumably full, nothing we can do about that.
        end
        count = count - amt
        if slot:getCount() == 0 and slot == self.slots[1] then
            table.remove(self.slots, 1)
        end
    end
    return target - count
end

return Item
