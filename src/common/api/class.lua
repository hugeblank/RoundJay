local table = require "src.common.api.tablex"

--- @class ClassBuilder
-- Class building class
-- (building class building class building class)
local ClassBuilder = {}

--- Return a new class template to build from
--- @generic T: Class
--- @param super T|nil The parent class of this one
function ClassBuilder:new(super)
    --- @generic T
    --- @class Class
    --- @field __new function
    local Class = {}
    local metatable = {}
    Class.metatable = metatable

    function metatable:__index(key)
        local has = rawget(self, key)
        if Class[key] ~= nil then -- static fields and/or methods of this class
            return Class[key]
        elseif has then           -- fields of this object
            return has
        elseif super then         -- static fields and/or methods of parent class
            ---@cast super Class
            return super.metatable.__index(rawget(self, "super"), key)
        end
    end

    function metatable:__newindex(key, value)
        if super then
            return rawset(rawget(self, "super"), key, value)
        else
            return rawset(self, key, value)
        end
    end

    function Class:object(t)
        ---@cast super Class
        if super then
            local sobj = {}
            super:object(sobj)
            t.super = setmetatable(sobj, super.metatable)
        end
    end

    function Class:new(...)
        local obj = {}
        Class:object(obj)
        setmetatable(obj, self.metatable)
        if obj.__new then
            obj:__new(...)
        end
        return obj
    end

    return Class
end

return ClassBuilder