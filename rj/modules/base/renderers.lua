local logger = require("rj.client.logger")
local table = require("rj.table")

local function help(out)
    logger.info(out)
end
    
local function info(free, total) 
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

local function list(items, amount)
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

local function pull(amount, item)
    if amount then
        logger.info("Pulled "..item.getKey().dName.." x"..amount)
    else
        logger.warn("No item found matching "..item)
    end
end

local function details(d, q)
    if d then
        logger.info(listTable(d, " "))
    else
        logger.warn("No item found matching "..q)
    end
end

local function flush(count)
    logger.info(count.." items returned to storage.")
end

local function addons(action, path)
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

local function refresh()
    logger.info("Pool index refreshed.")
end

return {
    help = help,
    info = info,
    list = list,
    pull = pull,
    details = details,
    flush = flush,
    refresh = refresh,
    addons = addons
}
