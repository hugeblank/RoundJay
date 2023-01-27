--- The Item class.
-- @author hugeblank
-- @license MIT
-- @module rj.item
-- @alias out

local table = require("rj.table")
local util = require("rj.util")

local out = {}
local item = {}

--- ⚠️ Create a new item.
-- @tparam rj.slot.slot slot An initial slot to identify this item.
out.new = function(slot)
    local key, slots = {}, {s}
    -- yielding
    local nbtDetails = s:getNbtDetails()
    local mt = {
        __index = {
            key = key,
            slots = slots,
            nbtDetails = nbtDetails,
        }
    }
    do
        local basic = s:getBasicDetails()
        key.hash = s:getHash()
        key.name = basic.name
        key.dName = nbtDetails.displayName
        local enc = nbtDetails.enchantments
        if s:hasNbt() and enc then
            for i = 1, #enc do
                key.dName = enc[i].displayName.." "..key.dName
            end
        end
    end
    
    return setmetatable(table.clone(item), mt)
end

--- A keytable for an item.
-- @tfield string name The item identifier.
-- @tfield string dName The display name, optionally contains display names of enchantments prefixing item name.
-- @tfield ?string hash The slot hash.
-- @see rj.slot.slot.getHash
-- @table keytable

--- Get the keytable of the item.
-- @treturn keytable The keytable for this item.
function item:getKey()
    return self.key
end

--- Add a slot to this item.
-- Slot hashes MUST match between the keytable and the slot argument!
-- @tparam rj.slot.slot slot The slot to add to this item.
function item:addSlot(slot)
    assert(slot.getHash() == self.key.hash, "hash mismatch! expected "..self.key.hash.." got "..slot.getHash())
    table.insert(self.slots, slot)
end

--- Get the total amount of items represented by this object.
-- @treturn int
function item:getCount()
    local amount = 0
    table.foreachi(self.slots, function(_, slot)
        local c = slot.getCount()
        amount = amount + c
    end)
    return amount
end

--- The details of an item and its corresponding slots.
-- @tfield int total The total amount of items across all slots.
-- @tfield {location,...} locations Information about each slot containing this item.
-- @tfield table nbtDetails NBT details in a similar form to `getItemMeta`.
-- @table itemDetail

--- The details of a specific slot
-- @tfield string chest The inventory this item is located in.
-- @tfield int slot The specific slot occupied by the item.
-- @tfield int count The amount of items in this slot.
-- @table location

    
--- Get all details of this item
-- @treturn itemDetail
function item:details()
    local o = s.getBasicDetails()
    o.count = nil
    local sinfo = {}
    table.foreachi(self.slots, function(_, slot)
        local chest, sl = slot:getLocation()
        local s = {
            chest = chest,
            slot = sl,
            count = slot:getCount()
        }
        sinfo[#sinfo+1] = s
    end)
    o.total = self:getCount()
    o.locations = sinfo
    o.metadata = self.nbtDetails
    return o
end

--- ⚠️ Take items from the pool of slots that this item represents
-- @tparam string location The destination inventory where the items should go
-- @tparam int count The amount of items to take. If greater than the total amount of items, will pull from all slots.
-- @tparam int slot The slot of the destination inventory where items should go.
-- @treturn int The amount of items taken.
function item:take(location, count, slot)
    local count = math.min(count, self:getCount())
    local o = count
    while count > 0 do
        count = count - self.slots[1]:take(location, count, slot)
        if self.slots[1]:getCount() == 0 then
            table.remove(self.slots, 1)
        end
    end
    return o
end
    
--- ⚠️ Store all items from a slot into an inventory/slot pair
-- If repeatedly calling, consider allocating `to` and `tslot` using `util.getRandomEmptySlots`.
-- @see util.getRandomEmptySlots
-- @tparam string from The inventory from which to pull items from.
-- @tparam string fslot The slot in `from`.
-- @tparam rj.slot.basicDetails fdetails The basic information about the slot being pulled from.
-- @tparam ?string to The inventory to put the items into.
-- @tparam ?int tslot The slot in `to`.
function item:store(from, fslot, fdetails, to, tslot)
    if not to or not tslot then
        to, tslot = util.getRandomEmptySlot()
    end
    
    local function newSlot()
        local slot = util.transferAndSlot(from, fslot, fdetails, to, tslot)
        self:addSlot(slot)
    end
    
    local count = fdetails.count
    if fdetails.count == self.nbtDetails.maxCount then
        newSlot()
    else
        table.foreachi(self.slots, function(i, slot)
            if slot.getCount() < self.nbtDetails.maxCount then
                local c = slot.put(from, fslot)
                count = count - c
                if count == 0 then 
                    return
                end
            end
        end)
        if count > 0 then
            fdetails.count = count
            newSlot()
        end
    end
end

return out