-- PalSmith PoC-F : chat-as-transport protocol prototype (server-side).
-- Verifies that "smith://" prefixed chat messages can act as a client->server RPC
-- channel, and experiments with suppressing them from the public chat.
-- Built on the verified BroadcastChatMessage hook (see __knowledges). Logs: [SmithProto].

local PROTO = "smith://"

local function log(msg) print("[SmithProto] " .. tostring(msg) .. "\n") end

-- Reply to (ideally) the sender via system announce. Sender resolution from
-- FPalChatMessage is still an open item (__knowledges TODO), so fall back to
-- the first player character — fine for a single-tester PoC.
local function reply(text)
    local ok = pcall(function()
        local util = StaticFindObject("/Script/Pal.Default__PalUtility")
        local p = FindFirstOf("PalPlayerCharacter")
        if util and util:IsValid() and p and p:IsValid() then
            util:SendSystemAnnounce(p, text)
        end
    end)
    log("reply: " .. tostring(text) .. (ok and "" or " (send failed)"))
end

-- Parse "smith://verb/payload" -> verb, payload (payload may be empty).
local function parse(text)
    local rest = text:sub(#PROTO + 1)
    local verb, payload = rest:match("^([^/]+)/?(.*)$")
    return verb, payload
end

RegisterHook("/Script/Pal.PalGameStateInGame:BroadcastChatMessage", function(self, ChatMessageParam)
    local ok, err = pcall(function()
        local msg = ChatMessageParam:get()
        local text = msg.Message:ToString()
        if text:sub(1, #PROTO) ~= PROTO then return end

        local verb, payload = parse(text)
        log("received verb=" .. tostring(verb) .. " payload=" .. tostring(payload))

        if verb == "ping" then
            reply("smith://pong/" .. tostring(payload))
        elseif verb == "hello" then
            -- Future handshake (F5): client announces version + pack list.
            reply("smith://hello-ack/poc-f")
        else
            reply("smith://err/unknown-verb")
        end

        -- Suppression experiment: try to blank the message so it doesn't reach
        -- other clients' chat windows. Whether this works (and whether it also
        -- suppresses the sender's local echo) is exactly what PoC-F measures.
        local okSet = pcall(function() msg.Message = FString("") end)
        log("suppression attempt (msg.Message = \"\"): " .. (okSet and "no error" or "errored"))
    end)
    if not ok then log("hook error: " .. tostring(err)) end
end)

log("smith:// protocol probe ready (send 'smith://ping/hello' in chat)")
