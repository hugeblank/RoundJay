--- Paralyze - queue based task manager, wrapper for the parallel api
-- hugeblank, Oct 2023

local logger = require("src.common.api.logger"):new("paralyze")

local paralyze = { batch = {} }
local bifurcate_event_id, batch_event_id = 0, 0
local tasks, maxTasks = {}, 200 ---@type function[], integer

-- Create two processes, producer immediately creates data, only yielding once.
-- The consumer takes its time munching through the data supplied by the producer.
paralyze.bifurcate = function(producer, consumer)
    local supply, event = {}, "paralyze:bifurcate_" .. bifurcate_event_id
    bifurcate_event_id = bifurcate_event_id + 1
    parallel.waitForAll(function()
        while true do
            local data = table.pack(producer())
            if data.n > 0 then
                supply[#supply + 1] = data
                os.queueEvent(event)
            end
        end
    end, function()
        while true do
            os.pullEvent(event)
            while #supply > 0 do
                consumer(table.unpack(table.remove(supply, 1)))
            end
        end
    end)
end

paralyze.await = function(callback, timeout)
    local success = false
    parallel.waitForAny(function()
        while true do
            if callback() then
                success = true
                return
            end
        end
    end, function()
        sleep(timeout)
    end)
    return success
end

--- Create a batch of tasks for each keypair in a table
--- @see pairs
--- @generic K
--- @generic V
--- @param t { [K]: V }
--- @param func fun(key:K, value:V)
--- @return string
paralyze.batch.pairs = function(t, func)
    local batch = {}
    for k, v in pairs(t) do
        batch[#batch + 1] = function()
            func(k, v)
        end
    end
    return paralyze.addBatch(batch)
end

--- Create a batch of tasks for each keypair in a table with integer keys
--- @see ipairs
--- @generic K
--- @generic V
--- @param t { [integer]: V }
--- @param func fun(key:integer, value:V)
--- @return string
paralyze.batch.ipairs = function(t, func)
    local batch = {}
    for i, v in ipairs(t) do
        batch[#batch + 1] = function()
            func(i, v)
        end
    end
    return paralyze.addBatch(batch)
end

--- Create a batch of tasks for each keypair in a table
-- Only pass the value to the function
--- @see pairs
--- @generic K
--- @generic V
--- @param t { [K]: V }
--- @param func fun(value:V)
--- @return string
paralyze.batch.value = function(t, func)
    local batch = {}
    for _, v in pairs(t) do
        batch[#batch + 1] = function()
            func(v)
        end
    end
    return paralyze.addBatch(batch)
end

--- Create a batch of tasks for each keypair in a table with integer keys
-- Only pass the value to the function
--- @see ipairs
--- @generic K
--- @generic V
--- @param t { [integer]: V }
--- @param func fun(value:V)
--- @return string
paralyze.batch.ivalue = function(t, func)
    local batch = {}
    for _, v in ipairs(t) do
        batch[#batch + 1] = function()
            func(v)
        end
    end
    return paralyze.addBatch(batch)
end

--- add a batch of unbounded size to be processed
--- @param batch function[] functions to be added to the queue for processing. 
--- @return string # event ID to listen for if awaiting results
paralyze.addBatch = function(batch)
    assert(type(batch) == "table", "Batch must be a table of functions")
    local id = "paralyze:batch_complete_" .. batch_event_id
    batch_event_id = batch_event_id + 1
    local done = 0
    for _, func in ipairs(batch) do
        tasks[#tasks + 1] = function()
            func()
            done = done + 1
        end
    end
    tasks[#tasks + 1] = function()
        while true do
            if done == #batch then
                os.queueEvent(id)
                return
            end
            os.pullEvent()
        end
    end
    os.queueEvent("paralyze:run")
    --logger:log("debug", "add batch", id)
    return id
end

--- Consume tasks added by addBatch
--- @param t any
local function consumeTasks(t)
    local tt = {}
    while #t > 0 do
        tt[#tt+1] = table.remove(t, 1)
        if #tt % maxTasks == 0 then
            parallel.waitForAll(table.unpack(tt))
            tt = {}
        end
    end
    parallel.waitForAll(table.unpack(tt))
end

--- Paralyze runner.
-- Functions provided by this API will not work without this running in parallel with functions that call it
paralyze.run = function()
    while true do
        os.pullEvent("paralyze:run")
        consumeTasks(tasks)
    end
end

return paralyze