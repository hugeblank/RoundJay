local expect = require("cc.expect")
local table = require("rj.table")
return function(inventory, slot, lDetails)
    expect(1, inventory, "string")
    expect(2, slot, "number")
    expect(3, lDetails, "table")

    local out = {}
    
    out.getHash = function()
        local s = ""
        if lDetails.nbt then
            s = " "..lDetails.nbt
        end
        return lDetails.name..s
    end
    
    out.hasNbt = function()
        if lDetails.nbt then
            return true
        else
            return false
        end
    end
    
    out.getNbtDetails = function()
        local details = peripheral.call(inventory, "getItemDetail", slot)
        details.count = nil
        return table.clone(details)
    end
    
    out.getBasicDetails = function()
        return table.clone(lDetails) 
    end
    
    out.getLocation = function()
        return inventory, slot
    end
        
    out.take = function(to, amount, tSlot)
        local c = peripheral.call(inventory, "pushItems", to, slot, amount, tSlot)
        lDetails.count = lDetails.count-c
        return c
    end
        
    out.put = function(from, fSlot)
        -- Assumes the max stack size for any item is 64.
        local c = peripheral.call(inventory, "pullItems", from, fSlot, 64, slot)
        lDetails.count = lDetails.count+c
        return c
    end
        
    out.getCount = function()
        return lDetails.count
    end
        
    return out
end
