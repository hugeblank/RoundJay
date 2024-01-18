local table = require "src.common.api.tablex"
local paralyze = require "src.common.api.paralyze"
local ClassBuilder = require "src.common.api.class"
local Device = require "src.server.api.device"
local registry = require "src.server.api.registry"

--- @class PlayerInterface: Device
--- @field new fun(self: Class, playerInterfaceConfig: playerInterfaceConfig): PlayerInterface --- ⚠️ Create a new PlayerInterface.
--- @field private super Device
--- @field protected sources BasicStorage[] Compatible storages that this device can pull from
--- @field protected targets BasicStorage[] Compatible storages that this device can push to
local PlayerInterface = ClassBuilder:new(Device)

--- @class playerInterfaceConfig: deviceConfig
--- @field details playerInterfaceDetails

--- Details necessary to create an import bus
--- @class playerInterfaceDetails
--- @field inventory string Source inventory peripheral ID
--- @field source integer|nil Network ID of the device to pull items from
--- @field target integer|nil Network ID of the device to push items back to
--- @field whitelist integer[]|nil List of computer ids that can send messages to this interface when used in a local network
--- @field accepts fun(source: Device, item: Item, amount: integer, index: Index)|nil Custom accepts function, called after the device completes its accepts checks
--- @field contains fun(target: Device, item: Item|string, amount: integer, index:Index)|nil Custom contains function, called after the device completes its contains checks

--- ⚠️ Internal constructor for PlayerInterface object
-- If extending from this class, be sure to call this method in your constructor (see internals of this method as a reference).
--- @protected
--- @see PlayerInterface.new
--- @param id integer
--- @param playerInterfaceConfig playerInterfaceConfig
--- @param network Network
function PlayerInterface:__new(id, playerInterfaceConfig, network)
    assert(playerInterfaceConfig.details, "Player Interface requires additional details (<device>.details)")
    assert(playerInterfaceConfig.details.inventory, "Player Interface requires a central inventory (<device>.details.inventory)")

    self.super:__new(id, playerInterfaceConfig, network, { playerInterfaceConfig.details.inventory })
    self.details = playerInterfaceConfig.details
    self.targets = type(self.details.target) == "number" and { registry.getDevice(self.details.target) } or registry.getDevices()
    self.sources = type(self.details.source) == "number" and { registry.getDevice(self.details.source) } or registry.getDevices()
    local log = self.network:addBroadcast("log")
    self.completion_names = self.network:addBroadcast("completion_names")
    self.logger:addListener(function(entry)
        if entry.level ~= "debug" then
            os.queueEvent(log, {
                did = self.id,
                entry = entry
            })
        end
    end)
end

--- ⚠️ When given an item from a source device, returns the amount that the targetted device (self) can accept.
--- @param source Device The source device giving the items.
--- @param item Item The item to be given.
--- @param amount integer The amount to be given.
--- @return integer # The amount that this device accepts.
function PlayerInterface:accepts(source, item, amount)
    if type(item) ~= "table" then
        self.logger:log("error", "expected a table, got " .. tostring(item))
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
function PlayerInterface:contains(target, item)
    local indItem
    if type(item) == "string" then
        indItem = self.index:getItemFromHash(item)
    else
        indItem = self.index:getItemFromHash(item:getHash())
    end
    local count = indItem and indItem:getCount() or 0
    if type(self.details.contains) == "function" then
        count = self.details.contains(target, item, count, self.index) or count
    end
    return count
end

--- Run the device handler. The server takes this method and provides the device ID of this device for ease of use.
function PlayerInterface:run()
    self.network:addListener("client/base/player_interface/pull", self:wrapper(PlayerInterface.pull))
    self.network:addListener("client/base/player_interface/flush", self:wrapper(PlayerInterface.flush))
    self.network:addListener("client/base/player_interface/get_list", self:wrapper(PlayerInterface.list))
    self.network:addListener("client/base/player_interface/get_details", self:wrapper(PlayerInterface.itemDetails))
    self.network:addListener("client/base/player_interface/get_info", self:wrapper(PlayerInterface.info))
    self.network:addListener("client/base/player_interface/get_completion_names", self:wrapper(PlayerInterface.sendNames))
end

-- ## Custom Class Methods ## --

local function listTable(t, prefix)
    if not prefix then prefix = " " end
    local content = ""
    for k, v in pairs(t) do
        if type(k) == "number" then
            k = tostring(k) .. ". "
        elseif type(v) == "table" then
            k = k .. ":"
        else
            k = k .. " - "
        end
        if type(v) == "table" then
            local cs = listTable(v, "  " .. prefix)
            if #cs > 0 then
                content = content .. prefix .. k .. "\n" .. cs
            end
        elseif type(v) ~= "function" then
            content = content .. prefix .. k .. tostring(v) .. "\n"
        end
    end
    return content
end

--- Pull items from storage -> interface
--- @param data pull_item_pie
function PlayerInterface:pull(data)
    if not self:shouldExecute(data) then
        return
    end
    self.index:reload()
    if type(data.query) == "string" then
        local itemsources = {} --- @type table<integer, { item: Item, source: BasicStorage }>
        local displayName
        for _, source in ipairs(self.sources) do
            if source:is("base/basic_storage") then
                local item = source:findItem(data.query) ---@cast item Item
                if item then
                    if not displayName then
                        displayName = item:getDisplayName()
                    end
                    itemsources[#itemsources + 1] = {
                        source = source,
                        item = item
                    }
                end
            end
        end
        local amount = 0
        local t = type(data.amount)
        if t == "string" or t == "number" and itemsources[1] then
            if t == "string" then
                if data.amount == "stack" then
                    data.amount = itemsources[1].item.nbt.maxCount
                elseif data.amount == "all" then
                    data.amount = 0
                    for _, itemsource in ipairs(itemsources) do
                        data.amount = data.amount + itemsource.item:getCount()
                    end
                end
                local res = tonumber(data.amount)
                if res then
                    amount = res
                else
                    self.logger:log("error", "Value " .. tostring(data.amount) .. " is not a valid amount")
                    return
                end
            end
        else
            self.logger:log("error", "Invalid amount value: " .. tostring(data.amount))
            return
        end
        for _, itemsource in ipairs(itemsources) do
            if amount < 0 then
                break
            end
            local moved = itemsource.source:insert(self, itemsource.item, amount)
            amount = amount - moved
        end
        if displayName and itemsources[1] then
            self.logger:log("info", "Pulled " .. (data.amount - amount) .. "x " .. displayName)
        elseif not (displayName or itemsources[1]) then
            self.logger:log("error", "Could not pull requested item.")
        else
            self.logger:log("warn", "Pulled " .. (data.amount - amount) .. "x of an unknown item.")
        end
    end
    self:sendNames()
end

function PlayerInterface:flush(data)
    if not self:shouldExecute(data) then
        return
    end
    local amount = 0
    self.index:reload()
    for key, item in pairs(self.index:get()) do
        local total = item:getCount()
        for _, target in ipairs(self.targets) do
            local moved = self:insert(target, item, total)
            amount = amount + moved
            total = total - moved
            if total == 0 then
                break
            end
        end
        if total > 0 then
            self.logger:log("warn", "Failed to transfer " .. total .. " " .. item:getDisplayName() .. " from device " .. self.id)
        end
    end
    self.logger:log("info", "Transferred " .. amount .. " items.")
    self:sendNames()
end

---
---@param data query_item_pie
function PlayerInterface:itemDetails(data)
    if not self:shouldExecute(data) then
        return
    end
    if type(data.query) == "string" then
        local deets, entries = {}, false
        for _, source in ipairs(self.sources) do
            if source:is("base/basic_storage") then
                local item = source:findItem(data.query) ---@cast item Item
                if item then
                    deets[source.id] = item.nbt
                    if item.nbt then
                        entries = true
                    end
                end
            end
        end
        if entries then
            self.logger:log("info", "Item details:\n" .. listTable(deets))
        else
            self.logger:log("warn", "Could not find item details")
        end
    end
end


---
---@param data list_item_pie
function PlayerInterface:list(data)
    if not self:shouldExecute(data) then
        return
    end
    if (not data.query or type(data.query) == "string") and (not data.limit or type(data.limit) == "number") then
        local items = {}
        for _, source in ipairs(self.sources) do
            if source:is("base/basic_storage") then
                local list = source:list(data.query)
                for hash, item in pairs(list) do
                    if items[hash] then -- Merge similar items together
                        items[hash].count = items[hash].count + item.count
                    else
                        items[hash] = item
                    end
                end
            end
        end
        local limit = data.limit or 100
        local sorted = {} -- Limit size,
        for hash, item in pairs(items) do
            sorted[#sorted + 1] = item
        end
        table.sort(sorted, function(a, b)
            return a.count > b.count
        end)
        for i, item in ipairs(sorted) do
            if limit >= i then
                sorted[i] = tostring(item.count) .. "x " .. item.name
            else
                sorted[i] = nil
            end
        end
        self.logger:log("info", "Item list:\n" .. table.concat(sorted, "\n"))
        self:sendNames() -- Send the names - client user might see something that was recently added, and may desire autocompletion.
    end
end

function PlayerInterface:info(data)
    if not self:shouldExecute(data) then
        return
    end
    local free, total = 0, 0
    for _, device in ipairs(self.sources) do
        if device:is("base/basic_storage") then
            local tfree, ttotal = device:getFreeSpace()
            free, total = free + tfree, total + ttotal
        end
    end
    local pocc = math.floor(((free/total)*100)+0.5)
    local level = "info"
    if pocc <= 10 then
        level = "error"
    elseif pocc <= 25 then
        level = "warn"
    end
    self.logger:log(level, tostring(pocc).."% storage remaining\n"..tostring(free).."/"..tostring(total).." slots remaining")
end


function PlayerInterface:sendNames()
    local added, items = {}, {} ---@type table<string, string>, string[]
    for _, source in ipairs(self.sources) do
        if source:is("base/basic_storage") then
            local list = source:list()
            for hash, item in pairs(list) do
                if not added[hash] then
                    added[hash] = item.name
                    items[#items + 1] = item.name
                end
            end
        end
    end
    os.queueEvent(self.completion_names, items)
end

function PlayerInterface:shouldExecute(data)
    if data.id ~= self.id then
        return false -- Event wasn't meant for us
    end
    if self.details and self.details.whitelist then
        if not data.cid then
            return false -- No computer id even though we expect one
        end
        local allow = false
        for _, cid in ipairs(self.details.whitelist) do
            if cid == data.cid then
                allow = true
                break
            end
        end
        if not allow then
            return false -- Not a computer id we work for
        end
    end
    return true
end

--- @private
function PlayerInterface:wrapper(callback)
    return function(data)
        return callback(self, data)
    end
end

return PlayerInterface