--- Table supplementary module.
-- Wraps the existing lua table API and adds a couple more useful functions.
-- <p><b>Note:</b> functions marked with ⚠️ are yielding</p>
-- @see table
-- @author hugeblank
-- @license MIT
-- @module rj.tablex
-- @alias tab

local nMaxCoros = 128
local function clone(t)
    local out = {}
    for k, v in pairs(t) do
        if type(k) == "table" then
            k = clone(k)
        end
        if type(v) == "table" then
            out[k] = clone(v)
        else
            out[k] = v
        end
    end
    return out
end

local tab = clone(table)

--- Set the maximum number of coroutines run in parallel by async table handlers.
-- @see tablex.aforeach
-- @see tablex.aforeachi
-- @tparam[opt=128] int coros The new maximum number of coroutines
tab.maxcoros = function(coros)
    nMaxCoros = coros or 128
end

--- Deep clone a table
-- @tparam table t The table to be cloned
-- @treturn table The resulting cloned table
-- @function clone
tab.clone = clone

local lock = false

--- ⚠️ Asynchronously iterate over each key-value pair in the provided table.
-- Parameters are identical to <a href=https://www.lua.org/manual/5.0/manual.html#5.4>table.foreach</a>, 
-- however unlike its sister equivalent, it does not handle returning.
-- This function will error if nested with itself, or its sibling.
-- @see tablex.aforeachi
-- @tparam table t The table to be iterated over.
-- @tparam function(k,v) f The function to use on each key-value pair.
tab.aforeach = function(t, f) 
    assert(not lock, "Locked!\n"..debug.traceback())
    lock = true
    local tt = {}
    for k, v in pairs(t) do
        local tmax = #tt+1
        tt[tmax] = function()
            f(k, v)
        end
        if tmax % nMaxCoros == 0 then
            parallel.waitForAll(table.unpack(tt))
            tt = {}
        end
    end
    parallel.waitForAll(table.unpack(tt))
    lock = false
end

--- ⚠️ Asynchronously iterate over each index-value pair in the provided table.
-- Parameters are identical to <a href=https://www.lua.org/manual/5.0/manual.html#5.4>table.foreachi</a>, 
-- however unlike its sister equivalent, it does not handle returning.
-- This function will error if nested with itself, or its sibling.
-- @see tablex.aforeach
-- @tparam table t The table to be iterated over.
-- @tparam function(i,v) f The function to use on each index-value pair.
tab.aforeachi = function(t, f)
    assert(not lock, "Locked!\n"..debug.traceback())
    lock = true
    if #t == 0 then return end
    local max = #t
    local tt = {}
    for i = 1, max do
        tt[#tt+1] = function() 
            f(i, t[i])
        end
        if i % nMaxCoros == 0 then
            parallel.waitForAll(table.unpack(tt))
            tt = {}
        end
    end
    parallel.waitForAll(table.unpack(tt))
    lock = false
end

return tab
