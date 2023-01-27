local rj = require("rj")
local table = require("rj.table")
local config = require("rj.config")
local index = require("rj.index")
local util = require("rj.util")
local Furnace = require("rj.modules.smelt.furnace")
local fuelmap = require("rj.modules.smelt.fuelmap")

local function isWhole(num)
    return num == math.floor(num)
end

local function coerceWhole(num)
    for i = 1, 9 do
        local factor = num*i
        if isWhole(factor) then
            return factor, i
        end
    end
end

local function sortFuels()
    local out = {}
    local valid = config.get("fuels") or {}
    table.foreach(fuelmap, function(name, value)
        table.foreachi(valid, function(_, vname)
            if name == vname then
                local item = index.getItemfromName(name)
                if item then
                    out[#out+1] = {
                        name = name,
                        smelts = value,
                        item = item,
                        count = item.getCount(),
                    }
                end
            end
        end)
    end)
    table.sort(out, function(a, b)
        return a.smelts > b.smelts
    end)
    assert(#out > 0, "No fuels configured.")
    return out
end

local furnaces = {}
do
    local names = peripheral.call(config.get("pool"), "getNamesRemote")
    for i = 1, #names do
        local type, generic = peripheral.getType(names[i])
        if generic ~= "inventory" or not (type:find("furnace") or type:find("smoker")) then
            names[i] = nil
        end
    end
    table.foreach(names, function(_, name)
        furnaces[#furnaces+1] = Furnace(name)
    end)
    assert(#furnaces == 0, "No furnaces attached to network.")
end

local function canSmelt(item)
    local out = {}
    table.foreachi(furnaces, function(_, furnace)
        if furnace.canSmelt(item) then
            out[#out+1] = furnace
        end
    end)
    return out
end

rj.buildCommand("smelt")
  .action(function(amount, ...)
      if amount == "jobs" then
          -- list all jobs
      elseif amount == "mode" then
          -- fast or efficient
      elseif amount == "stop" then
          
      else
          local name = table.concat({...}, " ")
          local item = index.findItem(name)
          if item then
              amount = util.parseAmount(item, amount)
              local fuels = sortFuels()
              local cfg = config.get("smelt")
              if not cfg then
                  cfg = {
                      mode = "efficient",
                  }
                  config.set("smelt", cfg)
                  config.flush()
              end
              if config.get("smelt").mode == "efficient" then
                  local jobs = {}
                  while amount > 0 do
                      local pass = false
                      for i = 1, #fuels do
                          local fuel = fuels[i]
                          if isWhole(fuel.smelts) and amount >= fuel.smelts then
                              jobs[#jobs+1] = {
                                  itemAmount = fuel.smelts,
                                  fuel = fuel,
                                  fuelAmount = 1,
                              }
                              amount = amount-fuel.smelts
                              pass = true
                              break
                          end
                      end
                      if not pass then
                          local closest, utiliz
                          for i = 1, #fuels do
                              local fuel = fuels[i]
                              local smelts, fuelAmount = coerceWhole(fuel.smelts)
                              local u = amount/smelts
                              if u == 1 or amount > smelts then
                                  jobs[#jobs+1] = {
                                      itemAmount = smelts,
                                      fuel = fuel,
                                      fuelAmount = fuelAmount,
                                  }
                                  amount = amount-smelts
                                  pass = true
                                  break
                              elseif not closest or u > utiliz then
                                  utiliz = u
                                  closest = {
                                      itemAmount = smelts,
                                      fuel = fuel,
                                      fuelAmount = fuelAmount,
                                  }
                              end
                          end
                          if not pass then
                              jobs[#jobs+1] = closest
                              amount = amount - closest.itemAmount
                          end
                      end
                  end
                  -- To do: rest of the fucking owl
                  -- May not be enough fuel.
              else
                  error("fast mode NYI")
              end
          else
              error("no item matching "..name)
          end
      end
  end)
  .renderer(function() end)
  .completion(function() end)
  .format("smelt <<amount> <query> |\"jobs\"|\"stop\" <jobid>>")
  .build()

--[[rj.buildCommand("fuel")
  .action()
  .renderer()
  .completion()
  .format("fuel <\"set\"|\"unset\"> <query> [smeltAmount]")
  .build()]]
  
return {
    name = "RoundJay Auto-Smelt Addon",
    version = "0.1.0"
}
