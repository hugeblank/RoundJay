local network = require "src.common.api.network"

local out = {}
local commands ---@type Command[]?

out.load = function(config, logger)
    if config.interface then
        local interface = config.interface ---@type integer
        network.addListener("roundjay:base/player_interface/log")
        network.addListener("roundjay:base/player_interface/completion_names")
        network.addBroadcast("roundjay:base/player_interface/get_completion_names")
        commands = {
            (require "src.client.modules.base.commands.details"):new(interface),
            (require "src.client.modules.base.commands.flush"):new(interface),
            (require "src.client.modules.base.commands.pull"):new(interface),
            (require "src.client.modules.base.commands.list"):new(interface),
            (require "src.client.modules.base.commands.info"):new(interface),
        }
        return commands
    else
        logger:log("error", "No player interface configured. roundjay:base will be skipped.")
    end
end

---Function that executes module logic in parallel with other modules
---@param config any
---@param logger Logger
out.run = function(config, logger)
    os.queueEvent("roundjay:base/player_interface/get_completion_names", {
        id = config.interface
    })
    while true do
        local event, data = os.pullEvent()
        if event == "roundjay:base/player_interface/log" and data.did == config.interface then -- Only push entries coming from the entry we've configured
            logger.pushGlobalEntry(data.entry)
        elseif event == "roundjay:base/player_interface/completion_names" then
            if commands then
                for _, command in ipairs(commands) do ---@cast command QueryCommand
                    if command.setNames then
                        command:setNames(data)
                    end
                end
            end
        end
    end
end

return out