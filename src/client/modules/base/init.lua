
local out = {}
local commands ---@type Command[]?

local get_completion_names

--- Function that loads the module
---@param config table
---@param network Network
---@param logger Logger
out.load = function(config, network, logger)
    if config.interface then
        local interface = config.interface ---@type integer
        pinet = network:subnet("player_interface")
        get_completion_names = pinet:addBroadcast("get_completion_names")
        commands = {
            (require "src.client.modules.base.commands.details"):new(pinet, interface),
            (require "src.client.modules.base.commands.flush"):new(pinet, interface),
            (require "src.client.modules.base.commands.pull"):new(pinet, interface),
            (require "src.client.modules.base.commands.list"):new(pinet, interface),
            (require "src.client.modules.base.commands.info"):new(pinet, interface),
        }
        return commands
    else
        logger:log("error", "No player interface configured. Module 'base' will be skipped.")
    end
end

---Function that executes module logic in parallel with other modules
---@param config table
---@param network Network
---@param logger Logger
out.run = function(config, network, logger)
    os.queueEvent(get_completion_names, {
        id = config.interface
    })
    network:addListener("server/base/player_interface/log", function(data)
        if data.did == config.interface then
            logger.pushGlobalEntry(data.entry)
        end
    end)
    network:addListener("server/base/player_interface/completion_names", function(data)
        if commands then
            for _, command in ipairs(commands) do ---@cast command QueryCommand
                if command.setNames then
                    command:setNames(data)
                end
            end
        end
    end)
end

return out