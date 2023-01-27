local index = require("rj.index")
local completion = require("cc.completion")

local out = {}

out.fromQuery = function(words)
    return index.completeItemName(table.concat(words, " "))
end

out.pull = function(words)
    if #words == 0 then
        return
    elseif #words == 1 then
        return completion.choice(words[1], {"all", "stack"})
    else
        table.remove(words, 1)
        return index.completeItemName(table.concat(words, " "))
    end
end

out.addons = function(words)
    if #words == 0 then
        return
    elseif #words == 1 then
        return completion.choice(words[1], {"list", "add", "remove"})
    elseif #words > 1 and words[1] ~= "list" then
        table.remove(words, 1)
        local prefix = table.concat(words, " ")
        local paths = fs.complete(prefix:gsub("%.", "/"), "/")
        local out = {}
        table.foreachi(paths, function(_, path)
            local rpath = path:gsub("%..*", ""):gsub("/", "%.")
            if rpath:sub(-1,-1) == "." and fs.exists(fs.combine(prefix..path, "init.lua")) then
                out[#out+1] = rpath:sub(1, -2)
            end
            out[#out+1] = rpath
        end)
        return out
    end
end

return out
