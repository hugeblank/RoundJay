local expect = require("cc.expect").expect
local rj = require("rj")
local config = require("rj.config")
local index = require("rj.index")
local util = require("rj.util")
local fuzzy = require("rj.fuzzy")
local table = require("rj.table")
local Slot = require("rj.slot")
local Item = require("rj.item")

local function list(amount, ...)
    local list = {}
    local isKeyword = false
    if amount and not tonumber(amount) then
        isKeyword = true
        amount = table.concat({amount, ...}, " ")
    end
    table.foreach(index.get(), function(key, item)
        local res = {name = key.dName, count = item.getCount(), item = item}
            if not isKeyword or (isKeyword and fuzzy(key.dName, amount) or key.name:find(amount)) then
            list[#list+1] = res
        end
    end)
    amount = tonumber(amount)
    if not amount then
        amount = 100
    end
    amount = math.min(#list, amount)
    table.sort(list, function(a, b) return a.count > b.count end)
    return list, amount
end

local function pull(amount, ...)
    local query = table.concat({...}, " ")
    local selected = index.findItem(query)
    if not selected then
        return false, query
    end
    local out = selected.take(
            config.get("interface"), 
            util.parseAmount(selected, amount)
    )
    if selected.getCount() == 0 then
        index.removeItem(selected)
    end
    return out, selected
end

local function details(...)
    local query = table.concat({...}, " ")
    local selected = index.findItem(query)
    if not selected then
        return false, query
    end
    return index.findItem(query).details()
end

local function flush(inv)
    local inv = inv or config.get("interface")
    local list = peripheral.call(inv, "list")
    if not list and peripheral.call(config.get("pool"), "getNameLocal"):find("turtle") and turtle then
        -- If it's a damn turtle
        list = {}
        for i = 1, 16 do
            local deets = turtle.getItemDetail(i, true)
            if deets then
                list[i] = {
                    name = deets.name,
                    count = deets.count,
                    nbt = deets.nbt
                }
            end
        end
    end
    local slots = {}
    local rSlots = {}
    do -- reserve random free slots
        local nSlots = 0
        table.foreach(list, function(i, slot)
            nSlots = nSlots+1
            -- also create temp slots
            slots[#slots+1] = Slot(inv, i, slot)
        end)
        table.foreachi(util.getRandomEmptySlots(nSlots), function(i, sdata)
            rSlots[i] = {sdata.chest, sdata.slot}
        end)
    end
    if #slots == 0 then
        return 0
    end
    local count = 0
    local newInPool = {}
    table.aforeachi(slots, function(i, slot)
        local item = index.getItemFromHash(slot.getHash())
        count = count + slot.getCount()
        local rinv, rslot = table.unpack(table.remove(rSlots, 1))
        local _, sli = slot.getLocation()
        if not item then
            local nSlot = util.transferAndSlot(inv, sli, slot.getBasicDetails(), rinv, rslot)
            newInPool[#newInPool+1] = nSlot
        else
            item.store(inv, sli, slot.getBasicDetails(), rinv, rslot)
        end
    end)
    local hashes = index.matchSlotHashes(newInPool)
    index.itemsFromHashmap(hashes)
    return count
end

local function addons(...)
    local args = {...}
    expect(1, args[1], "string")
    if args[1] and args[1] ~= "list" then
        expect(2, args[2], "string")
    end
    local plugins = rj.getPlugins()
    if not args[1] or args[1] == "list" then
        return "list", plugins
    elseif args[1] == "add" then
        local exists = false
        table.foreachi(plugins, function()
            if plugins.path == args[2] then
                exists = true
            end
        end)
        if not exists then
            local s, e = rj.addPlugin(args[2])
            if not s then
                error(e)
            end
            return "added", args[2]
        else
            error("Addon "..args[2].." already loaded!")
        end
    elseif args[1] == "remove" then
        if not rj.removePlugin(args[2]) then
            error("No such addon "..args[2]..".")
        end
        return "removed", args[2]
    else
        error("Subcommand "..args[1].." not found.")
    end
end

local function help()
    return require("rj.base.modules.help")
end

return {
    list = list,
    pull = pull,
    details = details,
    refresh = index.reload,
    flush = flush,
    info = util.getFreeSpace,
    addons = addons,
    help = help
}
