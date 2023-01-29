--- Miscellaneous utility functions used throughout RoundJay.
-- <p><b>Note:</b> functions marked with ⚠️ are yielding</p>
-- @author hugeblank
-- @license MIT
-- @module rj.util
-- @alias out

local config = require("rj.config")
local table = require("rj.tablex")
local Slot = require("rj.slot")

local out = {}

--- ⚠️ Get a list of peripheral names on the pool network that can act as storage for items.
-- Does not contain interface chest, blacklisted inventories, as well as any non-chest/non-shulker box inventories.
-- @treturn {string,...} Valid inventory peripheral names.
out.getNames = function()
    local names = peripheral.call(config.get("pool"), "getNamesRemote")
    --local names = peripheral.getNames()
    local blacklist = config.get("blacklist")
    for i, name in ipairs(names) do
        local type, generic = peripheral.getType(name)
        if blacklist then
            table.foreachi(blacklist, function(j, bname)
                if name == bname then
                    names[i] = nil
                end
            end)
        end
        -- Cannot be interface, or non-inventory,
        -- or non-chest/shulker box
        if name == config.get("interface") or generic ~= "inventory" or not (type:find("chest") or type:find("shulker_box")) then
            names[i] = nil
        end
    end
    local out = {}
    table.foreach(names, function(_, v)
        out[#out+1] = v
    end)
    return out
end

--- ⚠️ Get a list of random empty slots.
-- @tparam int amount The amount of slots to return.
-- @treturn {emptySlot,...}
out.getRandomEmptySlots = function(amount)
    local chests = out.getNames()
    local slots = {}
    table.aforeachi(chests, function(_, chest)
        local li = peripheral.call(chest, "list")
        local max = peripheral.call(chest, "size")
        for j = 1, max do
            if not li[j] then
                slots[#slots+1] = {chest = chest, slot = j}
            end
        end
    end)
    local out = {}
    local used = {}
    for i = 1, amount do
        local max = #slots
        local k
        while not k do
            if #used == max then
                error("Out of space!")
            end
            local nk = math.random(1, max)
            if not used[nk] then
                k = nk
            end
        end
        out[i] = slots[k]
        used[k] = true
    end
    
    return out
end

--- A table representing an empty slot in the storage pool.
-- This is the precursor to what will eventually become a proper slot. 
-- We use this as an intermediary index to push the items, <i>then</i> we turn it into a slot object.
-- @see rj.slot
-- @tfield string chest The inventory to which this slot belongs.
-- @tfield int slot The index of this slot within the inventory.
-- @table emptySlot

--- ⚠️ Get a singular random empty slot.
-- @treturn string The inventory to which this slot belongs.
-- @treturn int The index of this slot within the inventory.
out.getRandomEmptySlot = function()
    local slot = out.getRandomEmptySlots(1)[1]
    return slot.chest, slot.slot
end

--- ⚠️ Get a total of the remaining free slots in the storage pool, and the total slots in the system.
-- @treturn int empty The total number of free slots remaining in the system.
-- @treturn int slots The total number of all slots in the system.
out.getFreeSpace = function()
    local names = out.getNames()
    local slots, empty = 0, 0
    table.aforeachi(names, function(_, chest)
        local list = peripheral.call(chest, "list")
        local free = peripheral.call(chest, "size")
        slots = slots + free
        for _ in pairs(list) do
            free = free - 1
        end
        empty = empty + free
    end)
    return empty, slots
end

--- ⚠️ Transfers items to a slot, then allocates a new Slot object for them.
-- Parameters are identical to item objects store method.
-- @see rj.item.store
-- @tparam string from The inventory from which to pull items from.
-- @tparam string fslot The slot in `from`.
-- @tparam rj.slot.basicDetails details The basic information about the slot being pulled from.
-- @tparam ?string to The inventory to put the items into.
-- @tparam ?int tslot The slot in `to`.
-- @treturn rj.slot.slot The slot that the items were stored into.
out.transferAndSlot = function(from, fslot, details, to, tslot)
    -- to the pool, push the items from the
    -- interface into tslot from fslot
    peripheral.call(to, "pullItems", from, fslot, 64, tslot)
    return Slot.new(to, tslot, details)
end

--- Get the value of the closest match of a query against keys in a table.
-- @tparam string query A query string to compare to the keys of the data table.
-- @tparam {string=any} data A table containing string keys.
-- @treturn any The value of the string that was found to be the closest match in the data table.
out.closestMatch = function(query, data)
    local match, max
    for k, v in pairs(data) do
        if k == query then
            return v
        end
        local a, b = k:find(query)
        if a == 1 and ( not max or b > max) then
            match, max = v, b
        end
    end
    return match
end

--- Parses an amount string to determine the intended amount of items from a given item to handle.
-- If the string "stack" is passed into amount, then the stack size of the item will be used for amount.
-- If the string "all" is passed into amount, then the total amount of items will be used for amount.
-- @tparam rj.item.item item The item to parse amount on, if necessary.
-- @tparam string amount The numerical amount of items, "stack", or "all".
-- @treturn int The amount of items to be used.
out.parseAmount = function(item, amount)
    local a = tonumber(amount)
    if a then
        amount = a
    elseif amount == "all" then
        amount = item:getCount()
    elseif amount == "stack" then
        amount = item:details().metadata.maxCount
    else
        error("Invalid amount value: "..amount)
    end
    return amount
end

return out
