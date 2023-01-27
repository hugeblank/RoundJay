return [[
---- RoundJay Help ----

Pooled Inventory management CUI.
All arguments have shortcuts denoted in parentheses.
mbs is recommended when using RoundJay, for
scrollback capabilities.

--- Setup ---

To use RoundJay, a chest network, called the 
storage pool, and an interface chest are required.
The storage pool is the wired modem network from 
which all chests will be accessed. The interface 
is a chest on the pool network that will be the 
interaction point for input and output to and from
the storage pool. Note that the interface chest 
MUST be on the same network as the storage pool and can NOT be on
one of the sides of the computer. Once you are
ready, launch RoundJay CUI, and follow the
auto-setup prompts.

--- Usage ---

(r)efresh - Refreshes inventory index. May take a 
while.
(i)nfo - Get information on the capacity and health
of the storage pool
(d)etails <query> - Get details about itemstacks in 
<query> item.
(p)ull <amount> <query> - Pull <amount> of <query>
items from inventory pool.
(f)lush [inventory] - Flush all items in 
[inventory] back into pool. Defaults to interface chest.
(l)ist [amount|query] - Lists the top 100 (or [amount]) 
most common items in the system. If a non number
input is provided, list elements not containing
query are filtered out.
(a)ddons <"add" <path>|"remove" <path>> - 
  Manage addons. Providing no arguments lists
  loaded addons.
  add <path> - Add an addon on path <path>. Uses
  "require()" format.
  remove <path> - Removes addon on path <path>.
  Uses "require()" format.
(e)xit - Quits RoundJay

--- Optional Plugins ---

In addition to the basic functionality, RoundJay
comes bundled with optional features that may
become essential as you expand your RoundJay setup.

rj.multi - Daemon for communication with multiple
RJ instances. Suppresses RJ from flushing to 
other clients interface inventories. Adds command
(b)lacklist to view all blacklisted inventories.


--- Quick Tips ---

Commands in RoundJay only search for the first
character, meaning that 'select turtle' is 
interpreted the same as 's turtle'

Commands can be chained in one line using 
semicolons For example, to quickly pull a stack 
of cobblestone out of your storage you could run: 
'select cobblestone pull 64; exit'

Default shell commands can be accessed by prefixing
them with an !. Ex: '!ls'

Commands can also be run directly on the CraftOS
command line by writing them in the same way you
otherwise would in the RoundJay interface. Ex:
'rjclient s stone pull 8;s redstone dust pull 1;e'
would put the ingredients for one wired modem in
the interface chest, then exit.

made with <3 on SwitchCraft
(c) hugeblank December, 2022
]]
