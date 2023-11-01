local ClassBuilder = require "src.common.api.class"
local table = require "src.common.api.tablex"
local paralyze = require "src.common.api.paralyze"
local Slot = require "src.server.api.slot"
local Item = require "src.server.api.item"

--- TODO: Remove this class

--- The Transaction class.
-- Perform operations between two item indices.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @class Transaction: Class
--- @field new fun(Class: self, fromIndex: Index, toIndex: Index): Transaction Create a new transaction
local Transaction = ClassBuilder:new()

--- Internal constructor for Transaction object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see Transaction.new
--- @param fromIndex Index The index from which transactions will be made relative to.
--- @param toIndex Index The other index in the transaction.
function Transaction:__new(fromIndex, toIndex)
    assert(fromIndex ~= toIndex, "Cannot perform transactions on the same index.")
    assert(fromIndex.side == toIndex.side, "Cannot perform transactions on indexes with differing sides (" .. fromIndex.side .. " and " .. toIndex.side .. ").")
    self.fromIndex = fromIndex
    self.toIndex = toIndex
end

--- ⚠️ Perform an item transfer with the given amount of items.
-- Is functionally similar to `pushItems`
-- If the source index of the item transfer does not have the item, the move operation will return 0.
--- @see Item.getHash
--- @param item Item|string Item, or item hash of the item to perform the move on.
--- @param amount integer Amount of items to move.
--- @return integer # Amount of items that were successfully moved.
function Transaction:move(item, amount)
    if amount < 0 then
        return 0
    end
    -- Get the respective item from both sides if present.
    local fromItem, toItem
    if type(item) == "table" then
        fromItem, toItem = item, self.toIndex:getItemFromHash(item:getHash())
    else
        ---@cast item string
        fromItem, toItem = self.fromIndex:getItemFromHash(item), self.toIndex:getItemFromHash(item)
    end

    if not fromItem then
        return 0 -- If there isn't an item from which to take from, then give up
    end

    amount = math.min(amount, fromItem:getCount())
    local o = amount -- Hold the amount to subtract from when we're finished moving items
    local tfns = {} -- List for functions handling the transaction
    if toItem then   -- If there's a matching item in the index we're moving the items to
        ---@cast toItem Item
        os.pullEvent(paralyze.batch.ivalue(toItem.slots, function(toSlot) -- Fill partially filled slots first
            ---@cast toSlot Slot
            if toSlot:getCount() < toItem.nbt.maxCount then
                amount = amount - toSlot:putItem(fromItem)
            end
        end))
    end
    local slots = {}
    if amount > 0 then -- If there's still more items to be moved
        -- Get n empty slots, where n is the max amount of operations needed to fulfill the remaining move
        -- It could be less due to running out of space
        -- We represent this by returning the amount we were able to move at the end of the operation
        tfns[#tfns + 1] = function() -- move the items, and create a slot object
            local emptySlots = self.toIndex:getEmptySlots(math.ceil(amount / fromItem.nbt.maxCount))
            for _, emptySlot in ipairs(emptySlots) do
                local rawdetails = {
                    name = fromItem:getIdentifier(),
                }
                local nbt = fromItem:getHash():gsub("^.*#?", "")
                if #nbt > 0 then
                    rawdetails.nbt = nbt
                end
                if amount > 0 then                                                     -- sanity check
                    local amt = fromItem:take(emptySlot.chest, emptySlot.slot, amount) -- Take up to a stack from the item
                    local details = table.clone(rawdetails)
                    details.count = amt
                    slots[#slots + 1] = Slot:new(emptySlot.chest, emptySlot.slot, details)
                    amount = amount - amt
                end
            end
        end
    end
    os.pullEvent(paralyze.addBatch(tfns)) -- Execute calculated operations
    if not toItem then -- If there wasn't an item in the index we're transferring to, create one
        toItem = Item:new(table.remove(slots, 1))
        self.toIndex:addItem(toItem)
    end
    for _, slot in ipairs(slots) do -- Add all the new slots created by the transfer
        toItem:addSlot(slot)
    end
    if fromItem:getCount() == 0 then -- If we cleared out the item from the source, remove it from the index
        self.fromIndex:removeItem(fromItem)
    end
    self.toIndex:refreshFreeCache()
    self.fromIndex:refreshFreeCache()
    return o - amount
end

return Transaction