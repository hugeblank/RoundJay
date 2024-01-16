local paralyze = require "src.common.api.paralyze"
local table = require "src.common.api.tablex"
local ClassBuilder = require "src.common.api.class"
local Slot = require "src.server.api.slot"
local Item = require "src.server.api.item"

--- Class whose objects represent a collection of items across one or more storage.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @see Item
--- @class (exact) Index: Class
--- @field protected items table<string, Item>
--- @field protected logger Logger
--- @field side string
--- @field protected inventories string[]
--- @field protected freeCache table<string, freeInventoryDetails>
--- @field new fun(self: Class, side: string, inventories: string[], logger: Logger): Index --- ⚠️ Create a new Item index.
local Index = ClassBuilder:new()

--- @class freeInventoryDetails
--- @field total integer
--- @field slots integer[]

--- Internal constructor for Index object
--- @protected
--- @see Index.new
--- @param side string
--- @param inventories string[]
--- @param logger Logger
function Index:__new(side, inventories, logger)
    for i, inv in ipairs(inventories) do
        local _, role = peripheral.call(side, "getTypeRemote", inv)
        if not role == "inventory" then
            logger:log("warn", "peripheral", inv, "is not a detected inventory, skipping")
            table.remove(inventories, i)
        end
    end
    self.logger = logger
    self.side = side
    self.inventories = inventories
    self.freeCache = {}
    self:reload() -- Establish index
end


--- Gets the entire item index
--- @return table<string, Item> # The list of items internally used by index
function Index:get()
    return self.items
end


--- Gets an item from a given Minecraft identifier, and an optional display name.
--- @param name string # The minecraft identifier of the item to get.
--- @param dName string|nil The display name of the item to get.
--- @return Item|nil # The corresponding item to the given hash, if one exists.
function Index:getItemFromName(name, dName)
    for k, item in pairs(self.items) do
        if item:getIdentifier() == name and (dName == item:getDisplayName(true) or not dName) then
            return item
        end
    end
end

--- Gets an item that matches the common slot hash of the passed hash string.
--- @see Slot.getHash
--- @param hash string The slot hash of the item to get.
--- @return Item|nil # The corresponding item to the given hash, if one exists.
function Index:getItemFromHash(hash)
    return self.items[hash]
end

--- Add an item to the index.
--- @param item Item The item to add.
function Index:addItem(item)
    self.items[item:getHash()] = item
end

--- Remove an item from the index.
-- This should generally be used whenever an item has a count of 0, so those items do not display in any listings.
--- @param item Item The item to remove.
function Index:removeItem(item)
    self.items[item:getHash()] = nil
end

--- ⚠️ Reload the item index
-- Additionally refreshes free slot cache, which helps in determining where items can go
function Index:reload()
    self.items = {}
    local hashes = {} --- @type table<string, Slot[]>
    self:refreshFreeCache(function(name, slot, info)
        local slotobj = Slot:new(name, slot, info)
        local exists = hashes[slotobj:getHash()]
        if exists then
            exists[#exists + 1] = slotobj
        else
            hashes[slotobj:getHash()] = { slotobj }
        end
    end)
    os.pullEvent(paralyze.batch.pairs(hashes, function(hash, hslots)
        local item = self:getItemFromHash(hash)
        if not item then
            local slot = table.remove(hslots, 1)
            item = Item:new(slot)
        end
        for _, slot in ipairs(hslots) do
            item:addSlot(slot)
        end
        self:addItem(item)
    end))
end

--- ⚠️ Refresh the free slot cache of the index.
-- Called within reload, only use one or the other depending on the circumstance.
--- @param callback fun(name: string, slot: integer, info: table)? Optional callback function to get get the name, slot and details of an occupied slot
function Index:refreshFreeCache(callback)
    self.freeCache = {}
    local sizes, lists, batch = {}, {}, {}
    for _, name in ipairs(self.inventories) do
        batch[#batch + 1] = function()
            sizes[name] = peripheral.call(name, "size")
        end
        batch[#batch+1] = function()
            lists[name] = peripheral.call(name, "list")
        end
    end
    os.pullEvent(paralyze.addBatch(batch))
    for _, name in ipairs(self.inventories) do
        if not self.freeCache[name] then
            self.freeCache[name] = {
                total = sizes[name],
                slots = {}
            }
        end
        local freeinv = self.freeCache[name]
        for i = 1, freeinv.total do
            if not lists[name][i] then
                freeinv.slots[#freeinv.slots+1] = i
            end
        end
        for slot, info in pairs(lists[name]) do
            if callback then
                callback(name, slot, info)
            end
        end
    end
end

--- ⚠️ Transfer items between this index and another.
--- @param otherIndex Index The other index to move items between.
--- @param item Item The item or item hash to perform the move on.
--- @param amount integer The amount of items to move between the two indices. Positive moves go from this index to the other index (push). Negative moves go from the other index to this index (pull).
--- @return integer # Amount of items that were successfully moved.
function Index:move(otherIndex, item, amount)
    if amount < 0 then
        return 0
    end
    -- Get the respective item from both sides if present.
    local fromItem, toItem = item, otherIndex:getItemFromHash(item:getHash())

    if not fromItem then
        return 0 -- If there isn't an item from which to take from, then give up
    end

    amount = math.min(amount, fromItem:getCount())
    local o = amount -- Hold the amount to subtract from when we're finished moving items
    if toItem then -- If there's a matching item in the index we're moving the items to
        os.pullEvent(paralyze.batch.ivalue(toItem.slots, function(toSlot) -- Fill partially filled slots first
            if toSlot:getCount() < toItem.nbt.maxCount then -- This could be better.
                local sub = toSlot:putItem(fromItem, amount)
                amount = amount - sub
            end
        end))
    end
    if amount > 0 then -- If there's still more items to be moved
        -- tfns - List of functions handling full slot move operations
        local tfns, slots = {}, {}
        -- Get n empty slots, where n is the max amount of operations needed to fulfill the remaining move
        -- It could be less due to running out of space
        -- We represent this by returning the amount we were able to move at the end of the operation
        local emptySlots = otherIndex:getEmptySlots(math.ceil(amount / fromItem.nbt.maxCount))
        for offset, emptySlot in ipairs(emptySlots) do
            tfns[#tfns + 1] = function() -- move the items, and create a slot object
                local rawdetails = {
                    name = fromItem:getIdentifier(),
                }
                local nbt = fromItem:getHash():gsub("^.*#?", "")
                if #nbt > 0 then
                    rawdetails.nbt = nbt
                end
                if amount > 0 then
                    -- Take up to a stack from the item, slot offset keeps us from trying to eat from the same slot
                    local amt = fromItem:take(emptySlot.chest, emptySlot.slot, amount, offset)
                    amount = amount - amt
                    local details = table.clone(rawdetails)
                    details.count = amt
                    slots[#slots + 1] = Slot:new(emptySlot.chest, emptySlot.slot, details)
                end
            end
        end
        os.pullEvent(paralyze.addBatch(tfns)) -- Execute calculated operations
        if not toItem then                    -- If there wasn't an item in the index we're transferring to, create one
            toItem = Item:new(table.remove(slots, 1))
            otherIndex:addItem(toItem)
            -- One more pass over all the new slots
        end
        for _, slot in ipairs(slots) do -- Add all the new slots created by the transfer
            toItem:addSlot(slot)
        end
        os.pullEvent(paralyze.batch.ivalue(toItem.slots, function(toSlot) -- Fill partially filled slots first
            if toSlot:getCount() < toItem.nbt.maxCount then -- This could be better.
                local sub = toSlot:putItem(fromItem, amount)
                amount = amount - sub
            end
        end))
    end
    if fromItem:getCount() == 0 then -- If we cleared out the item from the source, remove it from the index
        self:removeItem(fromItem)
    end
    otherIndex:refreshFreeCache()
    self:refreshFreeCache()
    return o - amount
end

--- ⚠️ Get a total of the remaining free slots in the storage pool, and the total slots in the system.
--- @return integer # The total number of free slots remaining in the system.
--- @return integer # The total number of all slots in the system.
function Index:getFreeSpace()
    local empty, totals = 0, 0
    for _, freeinv in pairs(self.freeCache) do
        empty, totals = empty + #freeinv.slots, totals + freeinv.total
    end
    return empty, totals
end

--- A table representing an empty slot in the storage pool.
-- This is the precursor to what will eventually become a proper slot. 
-- We use this as an intermediary index to push the items, <i>then</i> we turn it into a slot object.
--- @see Slot
--- @class emptySlot
--- @field chest string The inventory to which this slot belongs.
--- @field slot integer The index of this slot within the inventory.

--- ⚠️ Get a list of empty slots.
--- @param amount integer The amount of slots to return.
--- @return emptySlot[]
function Index:getEmptySlots(amount)
    local slots = {}
    for _, chest in ipairs(self.inventories) do
        local freeinv = self.freeCache[chest].slots
        for i = 1, #freeinv do
            slots[#slots + 1] = {
                chest = chest,
                slot = table.remove(freeinv, 1)
            }
            if #slots == amount then
                return slots
            end
        end
    end
    if #slots < amount then
        self.logger:log("warn", "Out of space!")
    end
    return slots
end

return Index
