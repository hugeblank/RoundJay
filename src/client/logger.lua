--- Logger module.
-- Loggers for RoundJay. Intended use is for renderer methods. action methods should not output anything, only error().
-- @author hugeblank
-- @license MIT
-- @module src.client.logger

local expect = require("cc.expect").expect
local maxLevel = 1
local function logger(level, color, f)
    return function(...)
        if maxLevel > level then
            return
        end
        local oc = term.getTextColor()
        term.setTextColor(color)
        f(...)
        term.setTextColor(oc)
    end
end

--- Print a debug message
-- @see print
-- @tparam ?string message A message, can be broken apart like print messages.
-- @function debug

--- Print an info message
-- @see print
-- @tparam ?string message A message, can be broken apart like print messages.
-- @function info

--- Print a warning message
-- @see print
-- @tparam ?string message A message, can be broken apart like print messages.
-- @function warn

--- Print an error message
-- @see print
-- @tparam ?string message A message, can be broken apart like print messages.
-- @function error

--- Set the level to log messages at. 
-- Default is 1.
-- @tparam number level Level messages are logged.
-- @function setLevel

return {
    debug = logger(0, colors.lightGray, print),
    info = logger(1, colors.lightBlue, print),
    warn = logger(2, colors.yellow, print),
    error = logger(3, colors.red, printError),
    setLevel = function(level)
        expect(1, level, "number")
        maxLevel = level
    end
}

