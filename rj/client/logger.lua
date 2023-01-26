-- logger for rj. Intended use is for render
-- methods. action methods should not output
-- anything, only error().

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


