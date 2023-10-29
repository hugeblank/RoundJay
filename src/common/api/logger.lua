local ClassBuilder = require "src.common.api.class"
local table = require "src.common.api.tablex"

--- @class Logger: Class
-- Common logger class used throughout RoundJay
--- @field new fun(self: Class, source: string): Logger --- Create a new Logger.
local Logger = ClassBuilder:new()

local names = { "debug", "info", "warn", "error", "crit" }
local global_listeners = {}

--- Internal constructor for Logger object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see Logger.new
--- @param source string
function Logger:__new(source)
    self.source = source
    self.history = {}
    self.levels = {}
    self.listeners = {}
    for _, level in ipairs(names) do
        self.levels[level] = {
            name = level,
            history = {},
            listeners = {}
        }
    end
end

---@param callback fun(entry: loggerEntry)
---@param level string?
function Logger:addListener(callback, level)
    if not level then
        self.listeners[#self.listeners + 1] = callback
    else
        local t = self.levels[level].listeners
        t[#t + 1] = callback
    end
end

---@class loggerEntry
---@field source string
---@field level string
---@field message string
---@field timestamp string
---@field epoch integer

--- @param level "debug"|"info"|"warn"|"error"|"crit"
function Logger:log(level, ...)
    level = self.levels[level]
    assert(level, "Invalid level "..tostring(level))
    local packedmsg = table.pack(...)
    for i = 1, packedmsg.n do
        packedmsg[i] = tostring(packedmsg[i])
    end
    local entry = {
        source = self.source,
        level = level.name,
        message = table.concat(packedmsg, " "),
        timestamp = os.date("*t"),
        epoch = os.epoch("utc")
    }
    level.history[#level.history + 1] = entry
    self.history[#self.history + 1] = entry
    for _, callback in ipairs(self.listeners) do
        callback(table.clone(entry))
    end
    for _, callback in ipairs(level.listeners) do
        callback(table.clone(entry))
    end
    for _, callback in ipairs(global_listeners) do
        callback(table.clone(entry))
    end
end

--- Get logged entries, most recent first.
---@param level "debug"|"info"|"warn"|"error"|"crit"? Optional level to filter on
---@param limit integer? Optional integer limit. Default: 25
---@return table|unknown
function Logger:getEntries(level, limit)
    limit = limit or 25
    local ret = {}
    local source = self.history
    if level then
        assert(self.levels[level], "level " .. tostring(level) .. " does not exist")
        source = self.levels[level].history
    end
    for i = #source - limit, #source do
        if i > 0 then
            ret[#ret + 1] = source[i]
        end
    end
    return table.clone(ret)
end

--- Pushes an entry from an external source onto the global listeners.
---@param entry loggerEntry
function Logger.pushGlobalEntry(entry)
    for _, callback in ipairs(global_listeners) do
        callback(table.clone(entry))
    end
end

---@param callback fun(entry: loggerEntry)
function Logger.addGlobalListener(callback)
    global_listeners[#global_listeners+1] = callback
end

local levelcolors = {
    debug = colors.lightGray,
    info = colors.lightBlue,
    warn = colors.yellow,
    error = colors.pink,
    crit = colors.red
}

Logger.renderEntry = function(entry)
    write("[")
    term.setTextColor(levelcolors[entry.level])
    write(entry.level)
    term.setTextColor(colors.white)
    print("]", entry.message)
end

return Logger