-- Move this file to your /startup directory to alias /roundjay/client.lua -> rj, and add shell completion.
local completion = require("cc.shell.completion")
shell.setAlias("rj", "roundjay/client.lua")
shell.setCompletionFunction("roundjay/client.lua", function(shell, index, text)
    if index == 1 then
        local completions = completion.file(shell, text)
        local out = {}
        for i, partial in ipairs(completions) do
            if (text..partial):find(".rj") then
                out[#out+1] = partial
            end
        end
        return out
    end
end)
