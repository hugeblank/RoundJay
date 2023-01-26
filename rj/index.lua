local util = require("rj.util")
local fuzzy = require("rj.fuzzy")
local table = require("rj.table")
local Slot = require("rj.slot")
local Item = require("rj.item")

local out = {}
local items -- call reload if nil

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
    table.sort(matches, function(a, b)
        local fa, fb = fuzzy(input, a), fuzzy(input, b)
        if fa and fb then
            return fa > fb
        elseif fa then
            return true
        end
    end)
    return matches
end

out.getItemFromName = function(name, dName)
    for k, item in pairs(items) do
        if k.name == name and (dName == k.dName or not dName) then
            return it
        end
    end
end

out.getItemFromHash = function(hash)
    for k, v in pairs(items) do
        if k.hash == hash then
            return v
        end
    end
end

out.addItem = function(item)
    items[item.getKey()] = item
end

out.removeItem = function(item)
    items[item.getKey()] = nil
end

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

out.get = function()
    return items
end

-- Whenever creating new items, the following two
-- functions come in handy. match on slot hashes
-- before adding to item so duplicate entries are
-- avoided. Then asynchronously create new items/
-- insert into existing ones where possible.
out.matchSlotHashes = function(slots)
    local hashmap = {}
    table.foreach(slots, function(_, slot)
        local common = hashmap[slot.getHash()]
        if common then
            common[#common+1] = slot
        else
            hashmap[slot.getHash()] = {slot}
        end
    end)
    return hashmap
end

out.itemsFromHashmap = function(hashmap)
    table.aforeach(hashmap, function(hash, slots)
        local item = out.getItemFromHash(hash)
        if not item then
            local slot = table.remove(slots, 1)
            item = Item(slot)
        end
        table.foreachi(slots, function(_, slot)
            item.addSlot(slot)
        end)
        out.addItem(item)
    end)
end

-- Because items remove themselves when empty
-- Reload should only ever be used on startup.
out.reload = function()
    items = {}
    local slots = {}
    local names = util.getNames()
    table.aforeachi(names, function(_, name)
        local list = peripheral.call(name, "list")
        table.foreach(list, function(k, basic)
            slots[#slots+1] = Slot(name, k, basic)
        end)
    end)
    local hashes = out.matchSlotHashes(slots)
    out.itemsFromHashmap(hashes)
end

return out
