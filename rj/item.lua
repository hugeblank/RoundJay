local table = require("rj.table")
local util = require("rj.util")
local Slot = require("rj.slot")
local config = require("rj.config")
return function(s)
    local out, key, slots = {}, {}, {s}
    -- yielding
    local details = s.getNbtDetails()
    do
        local basic = s.getBasicDetails()
        key.hash = s.getHash()
        key.name = basic.name
        key.dName = details.displayName
        local enc = details.enchantments
        if s.hasNbt() and enc then
            for i = 1, #enc do
                key.dName = enc[i].displayName.." "..key.dName
            end
        end
    end

    out.getKey = function()
        return key
    end
    
    out.addSlot = function(slot)
        assert(slot.getHash() == key.hash, "hash mismatch! expected "..key.hash.." got "..slot.getHash())
        table.insert(slots, slot)
    end

    out.getCount = function()
        local amount = 0
        table.foreachi(slots, function(_, slot)
            local c = slot.getCount()
            amount = amount + c
        end)
        return amount
    end
        
    out.details = function()
        local o = s.getBasicDetails()
        o.count = nil
        local sinfo = {}
        table.foreachi(slots, function(_, slot)
            local chest, sl = slot.getLocation()
            local s = {
                chest = chest,
                slot = sl,
                count = slot.getCount()
            }
            sinfo[#sinfo+1] = s
        end)
        o.total = out.getCount()
        o.locations = sinfo
        o.metadata = details
        return o
    end

    out.take = function(location, count, slot)
        local count = math.min(count, out.getCount())
        local o = count
        while count > 0 do
            count = count - slots[1].take(location, count, slot)
            if slots[1].getCount() == 0 then
                table.remove(slots, 1)
            end
        end
        return o
    end
        
    out.store = function(from, fslot, fdetails, to, tslot)
        -- If repeatedly calling consider
        -- allocating empty slots using:
        -- util.getRandomEmptySlots
        if not to or not tslot then
            to, tslot = util.getRandomEmptySlot()
        end
        
        local function newSlot()
            local slot = util.transferAndSlot(from, fslot, fdetails, to, tslot)
            out.addSlot(slot)
        end
        
        local count = fdetails.count
        if fdetails.count == details.maxCount then
            newSlot()
        else
            table.foreachi(slots, function(i, slot)
                if slot.getCount() < details.maxCount then
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
end
