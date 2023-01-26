local nMaxCoros = 127
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

local table = clone(table)

table.maxcoros = function(coros)
    nMaxCoros = coros or 255
end

table.clone = clone

local lock = false
table.aforeach = function(t, f) -- async foreach
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

table.aforeachi = function(t, f)
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

return table
