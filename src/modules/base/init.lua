local expect = require("cc.expect")
local index = require("src.index")
local rj = require("src")
local util = require("src.util")

local commands, renderers, completion = {}, {}, {}

--- Commands ---
do -- Collapse using arrow in IDE
    local table = require("src.tablex")
    local config = require("src.config")
    local fuzzy = require("src.fuzzy")
    local Slot = require("src.slot")

    commands.list = function(amount, ...)
        local list = {}
        local isKeyword = false
        if amount and not tonumber(amount) then
            isKeyword = true
            amount = table.concat({amount, ...}, " ")
        end
        table.foreach(index.get(), function(key, item)
            local res = {name = key.dName, count = item:getCount(), item = item}
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

    commands.pull = function(amount, ...)
        local query = table.concat({...}, " ")
        local selected = index.findItem(query)
        if not selected then
            return false, query
        end
        local count = selected:take(
                config.get("interface"), 
                util.parseAmount(selected, amount)
        )
        if selected:getCount() == 0 then
            index.removeItem(selected)
        end
        return count, selected
    end

    commands.details = function(...)
        local query = table.concat({...}, " ")
        local selected = index.findItem(query)
        if not selected then
            return false, query
        end
        return selected:details()
    end

    commands.flush = function(inv)
        local inv = inv or config.get("interface")
        local list = peripheral.call(inv, "list")
        if not list and peripheral.call(config.get("pool"), "getNameLocal"):find("turtle") and turtle then
            -- If it's a damn turtle
            list = {}
            for i = 1, 16 do
                local deets = turtle.getItemDetail(i)
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
                slots[#slots+1] = Slot.new(inv, i, slot)
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
            local item = index.getItemFromHash(slot:getHash())
            count = count + slot:getCount()
            local rinv, rslot = table.unpack(table.remove(rSlots, 1))
            local _, sli = slot:getLocation()
            if not item then
                local nSlot = util.transferAndSlot(inv, sli, slot:getBasicDetails(), rinv, rslot)
                newInPool[#newInPool+1] = nSlot
            else
                item:store(inv, sli, slot:getBasicDetails(), rinv, rslot)
            end
        end)
        local hashes = index.matchSlotHashes(newInPool)
        index.itemsFromHashmap(hashes)
        return count
    end

    commands.modules = function(...)
        local args = {...}
        expect(1, args[1], "string")
        if args[1] and args[1] ~= "list" then
            expect(2, args[2], "string")
        end
        local modules = rj.getModules()
        if not args[1] or args[1] == "list" then
            return "list", modules
        elseif args[1] == "add" then
            local exists = false
            table.foreachi(modules, function(_, module)
                if module.path == args[2] then
                    exists = true
                end
            end)
            if not exists then
                local s, e = rj.addModule(args[2])
                if not s then
                    error(e)
                end
                return "added", args[2]
            else 
                error("Module "..args[2].." already loaded!")
            end
        elseif args[1] == "remove" then
            if not rj.removeModule(args[2]) then
                error("No such module "..args[2]..".")
            end
            return "removed", args[2]
        else
            error("Subcommand "..args[1].." not found.")
        end
    end

    commands.help = function()
        return require("src.modules.base.help")
    end
end

--- Renderers ---
do
    local logger = require("src.client.logger")

    renderers.help = function(htext)
        logger.info(htext)
    end
        
    renderers.info = function(free, total) 
        local pocc = math.floor(((free/total)*100)+0.5)
        local f = logger.info
        if pocc <= 10 then
            f = logger.error
        elseif pocc <= 25 then
            f = logger.warn
        end
        f(tostring(pocc).."% storage remaining")
        f(tostring(free).."/"..tostring(total).." slots remaining")
    end
    
    renderers.list = function(items, amount)
        for i = amount, 1, -1 do
            logger.info(items[i].count.." - "..items[i].name)
        end
    end
    
    local function listTable(t, prefix)
        local content = ""
        for k, v in pairs(t) do
            if type(k) == "number" then
                k = tostring(k)..". "
            elseif type(v) == "table" then
                k = k..":"
            else
                k = k.." - "
            end
            if type(v) == "table" then
                local cs = listTable(v, "  "..prefix)
                if #cs > 0 then
                    content = content..prefix..k.."\n"..cs
                end
            elseif type(v) ~= "function" then
                content = content..prefix..k..tostring(v).."\n"
            end
        end
        return content
    end
    
    renderers.pull = function(amount, item)
        if amount then
            logger.info("Pulled "..item:getKey().dName.." x"..amount)
        else
            logger.warn("No item found matching "..item)
        end
    end
    
    renderers.details = function(d, q)
        if d then
            logger.info(listTable(d, " "))
        else
            logger.warn("No item found matching "..q)
        end
    end
    
    renderers.flush = function(count)
        logger.info(count.." items returned to storage.")
    end
    
    renderers.modules = function(action, path)
        if action then
            if action == "list" then
                table.foreachi(path, function(i, v)
                    if v.loaded then
                        logger.info(v.path..": "..v.name.." "..v.version)
                    else
                        logger.warn(v.path..": "..v.error)
                    end
                end)
                return
            end
            logger.info("Addon "..path.." "..action..".")
        end
    end
    
    renderers.refresh = function()
        logger.info("Pool index refreshed.")
    end
end

--- Completion ---
do
    local ccCompletion = require("cc.completion")

    completion.fromQuery = function(words)
        return index.completeItemName(table.concat(words, " "))
    end
    
    completion.pull = function(words)
        if #words == 0 then
            return
        elseif #words == 1 then
            return ccCompletion.choice(words[1], {"all", "stack"})
        else
            table.remove(words, 1)
            return index.completeItemName(table.concat(words, " "))
        end
    end
    
    completion.modules = function(words)
        if #words == 0 then
            return
        elseif #words == 1 then
            return ccCompletion.choice(words[1], {"list", "add", "remove"})
        elseif #words > 1 and words[1] ~= "list" then
            table.remove(words, 1)
            local prefix = table.concat(words, " ")
            -- I don't *think* is this the right way to complete a require path, 
            -- but I genuinely don't know what the alternative is. require() is WACK.
            local runPath = shell.getRunningProgram():gsub("[^/]*%.lua$", "")
            local paths = fs.complete(prefix:gsub("%.", "/"), runPath)
            local completions = {}
            table.foreachi(paths, function(_, path)
                local rpath = path:gsub("%..*", ""):gsub("/", "%.")
                if rpath:sub(-1,-1) == "." and fs.exists(fs.combine(prefix..path, "init.lua")) then
                    completions[#completions+1] = rpath:sub(1, -2)
                end
                completions[#completions+1] = rpath
            end)
            return completions
        end
    end
end

--- Registering Commands ---

rj.addCommand("help", commands.help, renderers.help)
rj.addCommand("info", util.getFreeSpace, renderers.info)
rj.addCommand("list", commands.list, renderers.list, completion.fromQuery, "list <amount=100|query>")
rj.addCommand("flush", commands.flush, renderers.flush, nil, "flush [inventory]")
rj.addCommand("refresh", index.reload, renderers.refresh)
rj.addCommand("pull", commands.pull, renderers.pull, completion.pull, "pull <amount> <query>")
rj.addCommand("details", commands.details, renderers.details, completion.fromQuery, "details <query>")
rj.addCommand("modules", commands.modules, renderers.modules, completion.modules, "modules <\"list\"|\"add\" <path>|\"remove\" <path>>")

return {
    name = "RoundJay Base", 
    version = "0.3.0"
}
