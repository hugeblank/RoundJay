local commands = require("rj.base.commands")
local renderers = require("rj.base.renderers")
local completion = require("rj.base.completion")
local rj = require("rj")
local util = require("rj.util")

rj.buildCommand("help")
  .action(commands.help)
  .renderer(renderers.help)
  .build()

rj.buildCommand("info")
  .action(commands.info)
  .renderer(renderers.info)
  .build()
  
rj.buildCommand("list")
  .action(commands.list)
  .renderer(renderers.list)
  .completion(completion.fromQuery)
  .format("list <amount=100|query>")
  .build()
  
rj.buildCommand("flush")
  .action(commands.flush)
  .renderer(renderers.flush)
  .format("flush [inventory]")
  .build()

rj.buildCommand("refresh")
  .action(commands.refresh)
  .renderer(renderers.refresh)
  .build()
  
rj.buildCommand("pull")
  .action(commands.pull)
  .renderer(renderers.pull)
  .completion(completion.pull)
  .format("pull <amount> <query>")
  .build()
  
rj.buildCommand("details")
  .action(commands.details)
  .renderer(renderers.details)
  .completion(completion.fromQuery)
  .format("details <query>")
  .build()

rj.buildCommand("addons")
  .action(commands.addons)
  .renderer(renderers.addons)
  .completion(completion.addons)
  .format("addons <\"list\"|\"add\" <path>|\"remove\" <path>>")
  .build()

return {
    name = "RoundJay Base", 
    version = "0.3.0"
}
