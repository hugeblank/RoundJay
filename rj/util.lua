local config = require("rj.config")
local table = require("rj.table")
local Slot = require("rj.slot")

local out = {}

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
        -- out[i] = slots[i]
    end
    
    return out
end

out.getRandomEmptySlot = function()
    local slot = out.getRandomEmptySlots(1)[1]
    return slot.chest, slot.slot
end

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

-- Transfers items to a slot, then allocates
-- a new Slot object for them
out.transferAndSlot = function(from, fslot, details, to, tslot)
    -- to the pool, push the items from the
    -- interface into tslot from fslot
    local c = peripheral.call(to, "pullItems", from, fslot, 64, tslot)
    return Slot(to, tslot, details)
end

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

out.parseAmount = function(item, amount)
    local a = tonumber(amount)
    if a then
        amount = a
    elseif amount == "all" then
        amount = item.getCount()
    elseif amount == "stack" then
        amount = item.details().metadata.maxCount
    else
        error("Invalid amount value: "..amount)
    end
    return amount
end

return out
