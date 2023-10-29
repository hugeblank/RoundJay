local Logger = require "src.common.api.logger"
local ClassBuilder= require "src.common.api.class"

--- @class Command: Class
local Command = ClassBuilder:new()

--- Internal constructor for Command object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see Command.new
--- @param name string
function Command:__new(name)
    self.name = name
    self.logger = Logger:new(name)
end

--- @param params string[]
function Command:execute(params)
    error(self.name .. " must implement execute method")
end

--- @param short boolean?
function Command:getName(short)
    return short and self.name:gsub(".*:", "") or self.name
end

--- @param words string[]
--- @return string[]?
function Command:completion(words)
    return {}
end

return Command