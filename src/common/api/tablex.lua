---Internal clone function.
-- Holds onto a map of tables in the original table to properly replicate self-containing tables.
---@generic T: table
---@param t T
---@param map table<table, table>
---@return T
local function cloneInternal(t, map)
    if type(t) ~= "table" then
        return t
    end

    local mt = getmetatable(t)
    if mt then
        setmetatable(t, nil)
    end

    local out = {}
    if map[t] then
        return map[t]
    else
        map[t] = out
    end

    for k, v in pairs(t) do
        if type(k) == "table" then
            k = cloneInternal(k, map)
        end
        if type(v) == "table" then
            out[k] = cloneInternal(v, map)
        else
            out[k] = v
        end
    end

    if mt then
        setmetatable(t, mt)
        mt = cloneInternal(mt, map)
        out = setmetatable(out, mt)
    end

    return out
end

--- @class tablex: tablelib
--- Supplementary table API.
-- Wraps the existing lua table API and adds a couple more useful functions.
local tablex = cloneInternal(table, {})

--- Deep clone a table, including keys, values, and self-containing tables.
---@generic T: table
---@param t T
---@return T
tablex.clone = function(t) return cloneInternal(t, {}) end

--- Return a new table whose keys and values are inverted from the input table.
---@generic K, V
---@param t { [K]: V }
---@return { [V]: K }
tablex.mirror = function(t)
    local out = {}
    for k, v in pairs(t) do
        out[v] = k
    end
    return out
end

return tablex
