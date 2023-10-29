local fuzzy = require "src.server.api.fuzzy"
local Index = require "src.server.api.index"
local ClassBuilder = require "src.common.api.class"
local Logger = require "src.common.api.logger"

--- Roundjay's vanilla implementation of a basic storage device.
-- <p><b>Note:</b> functions marked with ⚠️ may yield.</p>
--- @class BasicStorage: Device
--- @field new fun(self: Class, basicStorageConfig: basicStorageConfig): BasicStorage --- ⚠️ Create a new BasicStorage.
--- @field private super Device
local BasicStorage = ClassBuilder:new(require("src.server.api.device"))

--- @class basicStorageConfig: deviceConfig
--- @field details basicStorageDetails

--- Details necessary to create a storage pool
--- @class basicStorageDetails
--- @field inventories string[] List of inventories from which to create the storage pool
--- @field accepts fun(source: Device, item: Item, amount: integer, index: Index)|nil Custom accepts function, called after the device completes its accepts checks
--- @field contains fun(target: Device, item: Item|string, amount: integer, index:Index)|nil Custom contains function, called after the device completes its contains checks

--- ⚠️ Internal constructor for BasicStorage object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see BasicStorage.new
--- @param id integer
--- @param basicStorageConfig basicStorageConfig
function BasicStorage:__new(id, basicStorageConfig)
    assert(basicStorageConfig.details, "Basic Storage requires additional details (<device>.details)")
    assert(basicStorageConfig.details.inventories,
        "Basic Storage requires a source inventories (<device>.details.inventories)")
    self.logger = Logger:new(basicStorageConfig.type .. "/" .. id)
    self.super:__new(id, "storage", basicStorageConfig.type, Index:new(basicStorageConfig.side, basicStorageConfig.details.inventories, self.logger))
    self.details = basicStorageConfig.details
end

--- ⚠️ When given an item from a source device, returns the amount that the targetted device (self) can accept.
--- @param source Device The source device giving the items.
--- @param item Item The item to be given.
--- @param amount integer The amount to be given.
--- @return integer # The amount that this device accepts.
function BasicStorage:accepts(source, item, amount)
    if type(item) ~= "table" then
        self.logger:log("error", "expected an item table, got "..tostring(item))
        return 0
    end
    local remaining = self.index:getFreeSpace()
    if remaining < math.ceil(amount / item.nbt.maxCount) then
        -- Return the most we can accept, running into the limit of space given.
        local left = 0
        local indItem = self.index:getItemFromHash(item:getHash())
        if indItem then
            left = item.nbt.maxCount - (indItem:getCount() % item.nbt.maxCount)
        end
        amount = (item.nbt.maxCount * remaining) + left
    end
    if type(self.details.accepts) == "function" then
        amount = self.details.accepts(source, item, amount, self.index) or amount
    end
    return amount
end

--- ⚠️ The target device is making a request for the given item (or item hash). Return the amount that may be allocated.
--- @param target Device The device making the request.
--- @param item Item|string The item or item hash requested.
--- @return integer # The amount of the item this device is making available for the target device.
function BasicStorage:contains(target, item)
    local indItem
    if type(item) == "table" then
        indItem = self.index:getItemFromHash(item:getHash())
    else
        --- @cast item string
        indItem = self.index:getItemFromHash(item)
    end
    if not indItem then
        return 0
    end
    local count = indItem:getCount()
    if type(self.details.contains) == "function" then
        count = self.details.contains(target, item, count, self.index) or count
    end
    return count
end

--- Find an item in the index using fuzzy matching.
--- @param query string The query to fuzzy match on.
--- @return Item # The closest item that matched the query, if one exists.
function BasicStorage:findItem(query)
    local lquery = query:lower()
    local match, max
    for hash, item in pairs(self.index:get()) do
        -- If there's an exact match (minus the namespace)
        if item:getIdentifier():lower():gsub(".+:", "") == lquery then
            return item
        end
        local score = fuzzy(item:getDisplayName():lower(), query)
        -- Fuzzy match first
        if not max or (score and score > max) then
            match, max = item, score
            -- If matches are equal then favor the
            -- item the pool has more of
        elseif not max or (score and score == max) then
            if match:getCount() < item:getCount() then
                match = item
            end
        end
    end
    return match
end


function BasicStorage:getFreeSpace()
    return self.index:getFreeSpace()
end

--- Get a list of all items matching a query, or up to a given limit
---@param query string? Optional query string to filter items on
---@return table<string, { name: string, count: integer }>
function BasicStorage:list(query)
    local list = {}
    for key, item in pairs(self.index:get()) do
        local res = { name = item:getDisplayName(), count = item:getCount()}
        if not query or (query and (fuzzy(res.name, query) or fuzzy(item:getIdentifier():gsub(".*:", ""), query))) then
            list[item:getHash()] = res
        end
    end
    return list
end

--- Get a list of read-friendly completion strings.
-- Given an input string will return a list of all matches based on both Minecraft Identifier and display name. Case-insensitive.
--- @param input string An input string, expected to be a partially complete item name.
--- @return string[] # Matches containing the input string, with the part of the string that matched up to input cut off.
function BasicStorage:completeQuery(input)
    local matches = {}
    for hash, item in pairs(self.index:get()) do
        local keyname = item:getIdentifier():gsub(".*:", "")
        local ns, ne = keyname:find(input)
        local displayName = item:getDisplayName()
        local ds, de = displayName:lower():find(input:lower())
        if input and ns == 1 then
            matches[#matches + 1] = keyname:sub(ne + 1, -1)
        elseif input and ds == 1 then
            matches[#matches + 1] = displayName:sub(de + 1, -1)
        end
    end
    table.sort(matches, function(a, b) -- This is moderately atrocious.
        local fa, fb = fuzzy(a, input), fuzzy(b, input)
        if fa and fb then
            return fa > fb
        elseif fa then
            return true
        end
        return false
    end)
    return matches
end

function BasicStorage:run()
    --[[while true do
        local out = {"----------"}
        for _, item in pairs(self.index:get()) do
            out[#out+1] = table.concat({item:getIdentifier(), item:getCount(), "#slots", #item.slots}, " ")
        end
        out[#out + 1] = "----------"
        self.logger:log("debug", table.concat(out, "\n"))
        sleep(5)
    end]]
end

return BasicStorage