# RoundJay
RoundJay is an in development <b>I</b>nventory <b>M</b>anagement <b>S</b>olution. 
It's goal is to be as modular and well documented as possible so the user is able to easily tailor it to their needs.
The target audience is someone that wants to program their way around their storage system. 

The server is broken up into "devices" that control one or more inventory, serving one of four functional roles:
1. `storage`: Buffer for items moving through the network. 
2. `import`: Move items from outside the network, into it.
3. `export`: Move items from within the network, out from it.
4. `convert`: Move items from within the network, out, with the intention of eventually getting back different items. These can be thought of as a volatile storage.
5. `dummy`: A device that fulfils some other purpose besides storing items. This could be something like a monitor that displays network statistics.

Out of the box it comes with:
1. The `base` module that provides some basic input and output devices on the server, and the necessary commands to take advantage of them on the client.
2. `server.lua`, Server program that handles parsing of the provided network file, and management of devices.
3. `client.lua`, A CraftOS inspired CLI client. Can be run on the same computer as the server, or a different one when using the base module.

Check out the `rj_example` directory for an explanation on configuration, and storage network setup.

## Install
Wget:
```
wget run https://p.sc3.io/FJAhzNmuqQ
```
Pastebin (SC3 exclusive):
```
pastebin run FJAhzNmuqQ
```
Note that [mbs](https://github.com/SquidDev-CC/mbs/) is also highly recommended for terminal scrollback capabilities when using the stock client. If on SwitchCraft, installation is as easy as running `mbs install` and rebooting.