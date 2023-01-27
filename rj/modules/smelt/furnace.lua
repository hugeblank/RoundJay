local config = require("rj.config")
local fuelmap = require("rj.modules.smelt.fuelmap")
local index = require("rj.index")
local util = require("rj.util")
return function(name)
    local out = peripheral.wrap(name)
    
    out.canSmelt = function(item)
        -- To do
        return true
    end
    
    out.smelt = function(item, amount, fuel, famount)
        item.take(name, amount, 1)
        fuel.take(name, famount, 2)
    end
end
