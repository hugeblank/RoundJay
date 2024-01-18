return {
    networking = {
        enabled = true, -- Whether networking is enabled. **Set this to true if your client and server are on different computers in the same network.
        server_id = 2, -- Computer ID of that server, used for validation, not security.
        side = "back",  -- Side on which modem is attached to connect through
        channel = 0, -- Optional Modem Channel on which to communicate with server. Defaults to 0
    },
    modules = { -- Configuration for individual modules running on this client
        base = { -- Configuration for roundjay:base. Only one option for now!
            interface = 2, -- roundjay:player_interface Device ID on the server that this computer asserts control over.
            -- Note that multiple clients can control the same player interface. If you want to control this see rj/server/network.lua
        }
    }
}