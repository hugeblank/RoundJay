--- @meta

---@class player_interface_event
---@field id integer The id of the interface device that this event is for
---@field cid integer? Computer to reply back to if this event was queued in the local network

---@class query_item_pie: player_interface_event
---@field query string Query string of requested item, might be a partial name

---@class pull_item_pie: query_item_pie
---@field amount string|integer Amount of items requested. A number, "stack", or "all"

---@class list_item_pie: player_interface_event
---@field query? string Query string of requested item to list, might be a partial name
---@field limit? integer Optional item limit