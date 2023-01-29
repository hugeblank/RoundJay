--- Generates and operates on an entire index of items.
-- <p><b>Note:</b> functions marked with ⚠️ are yielding</p>
-- @author hugeblank
-- @license MIT
-- @module src.index
-- @alias out

local util = require("src.util")
local fuzzy = require("src.fuzzy")
local table = require("src.tablex")
local Slot = require("src.slot")
local Item = require("src.item")

local out = {}
local items -- call reload if nil

--- Gets the entire item index
-- @treturn ?{rj.item.keytable=rj.item.item,...} The list of items internally used by index
out.get = function()
    return items
end


--- Gets an item from a given Minecraft identifier, and an optional display name.
-- @tparam string name The minecraft identifier of the item to get.
-- @tparam ?string dName The display name of the item to get.
-- @treturn ?rj.item.item The corresponding item to the given hash, if one exists.
out.getItemFromName = function(name, dName)
    for k, item in pairs(items) do
        if k.name == name and (dName == k.dName or not dName) then
            return it
        end
    end
end

--- Gets an item that matches the common slot hash of the passed hash string.
-- @see src.slot:getHash
-- @tparam string hash The slot hash of the item to get.
-- @treturn ?rj.item.item The corresponding item to the given hash, if one exists.
out.getItemFromHash = function(hash)
    for k, v in pairs(items) do
        if k.hash == hash then
            return v
        end
    end
end

--- Find an item in the index using fuzzy matching.
-- @tparam string query The query to fuzzy match on.
-- @treturn ?rj.item.item The closest item that matched the query, if one exists.
out.findItem = function(query)
    local lquery = query:lower()
    local match, max
    for k, v in pairs(items) do
        if k.name:lower():gsub(".+:", "") == lquery then
            return v
        end
        local c = fuzzy(k.dName, query)
        -- Fuzzy match first
        if not max or (c and c < max) then
            match, max = v, c
        -- If matches are equal then favor the
        -- item the pool has more of
        elseif not max or (c and c == max) then
            if match.getCount() < v.getCount() then
                match = v
            end
        end
    end
    return match
end

--- Add an item to the index.
-- @tparam rj.item.item item The item to add.
out.addItem = function(item)
    items[item:getKey()] = item
end

--- Remove an item from the index.
-- This should generally be used whenever an item has a count of 0, so those items do not display in any listings.
-- @tparam rj.item.item item The item to remove.
out.removeItem = function(item)
    items[item:getKey()] = nil
end

-- Whenever creating new items, the following two
-- functions come in handy. match on slot hashes
-- before adding to item so duplicate entries are
-- avoided. Then asynchronously create new items/
-- insert into existing ones where possible.

--- From a list of slots, create a hashmap of slots whose keys match.
-- @see src.slot.slot:getHash
-- @tparam {rj.slot.slot,...} slots An unorganized list of slots.
-- @treturn {string={rj.slot.slot,...},...} A map of slots organized on their hash.
out.matchSlotHashes = function(slots)
    local hashmap = {}
    table.foreach(slots, function(_, slot)
        local common = hashmap[slot:getHash()]
        if common then
            common[#common+1] = slot
        else
            hashmap[slot:getHash()] = {slot}
        end
    end)
    return hashmap
end

--- ⚠️ Create items out of a map of slots.
-- This is intended to be used in combination with the above function.
-- Items created by this method directly get added to the index.
-- @see matchSlotHashes
-- @tparam {string={rj.slot.slot,...},...} hashmap A map of slots organized on their hash.
out.itemsFromHashmap = function(hashmap)
    table.aforeach(hashmap, function(hash, slots)
        local item = out.getItemFromHash(hash)
        if not item then
            local slot = table.remove(slots, 1)
            item = Item.new(slot)
        end
        table.foreachi(slots, function(_, slot)
            item:addSlot(slot)
        end)
        out.addItem(item)
    end)
end

--- ⚠️ Reload the item index
out.reload = function()
    items = {}
    local slots = {}
    local names = util.getNames()
    table.aforeachi(names, function(_, name)
        local list = peripheral.call(name, "list")
        table.foreach(list, function(k, basic)
            slots[#slots+1] = Slot.new(name, k, basic)
        end)
    end)
    local hashes = out.matchSlotHashes(slots)
    out.itemsFromHashmap(hashes)
end

--- Get a list of read-friendly completion strings.
-- Given an input string will return a list of all matches based on both Minecraft Identifier and display name. Case-insensitive.
-- @tparam string input An input string, expected to be a partially complete item name.
-- @treturn {string,...} Matches containing the input string, with the part of the string that matched up to input cut off.
out.completeItemName = function(input)
    if not input then 
        input = "" 
    end
    local matches = {}
    for key in pairs(items) do
        local keyname = key.name:gsub(".*:", "")
        local ns, ne = keyname:find(input)
        local ds, de = key.dName:lower():find(input:lower())
        if input and ns == 1 then
            matches[#matches+1] = keyname:sub(ne+1, -1)
        elseif input and ds == 1 then
            matches[#matches+1] = key.dName:sub(de+1, -1)
        end
    end
    table.sort(matches, function(a, b) -- This is moderately atrocious.
        local fa, fb = fuzzy(input, a), fuzzy(input, b)
        if fa and fb then
            return fa > fb
        elseif fa then
            return true
        end
    end)
    return matches
end

return out
