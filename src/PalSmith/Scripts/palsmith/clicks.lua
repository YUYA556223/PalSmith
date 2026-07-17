-- PalSmith shared click router. One hook on CommonButtonBase:HandleButtonClicked
-- dispatches to whichever callback registered the clicked button. Used by both
-- the title-menu entry and the Mod Manager's native row/toggle buttons.
local core = require("palsmith.core")

local M = {}

local handlers = {} -- fullName -> fn
local hooked = false

local function fullName(w)
    local ok, n = pcall(function() return w:GetFullName() end)
    return ok and n or nil
end

function M.install()
    if hooked then return end
    local ok = pcall(function()
        RegisterHook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", function(self)
            local name
            local ok2 = pcall(function() name = self:get():GetFullName() end)
            if not ok2 or not name then return end
            local fn = handlers[name]
            if fn then
                local oke, err = pcall(fn)
                if not oke then core.err("click handler: " .. tostring(err)) end
            end
        end)
    end)
    hooked = ok
    core.log(ok and "clicks: hook installed" or "clicks: hook FAILED")
end

-- Register a CommonButtonBase widget (the WBP_PalInvisibleButton inside a menu
-- button) so clicking it runs fn. Returns true on success.
function M.register(invButton, fn)
    if not (invButton and invButton:IsValid()) then return false end
    local name = fullName(invButton)
    if not name then return false end
    handlers[name] = fn
    return true
end

-- Forget buttons whose widgets are gone (called when a UI is rebuilt).
function M.clearStale()
    for name, _ in pairs(handlers) do
        -- cheap: we can't cheaply re-resolve the object; leave entries, they are
        -- harmless (a new button gets a new unique fullName). Periodic full reset:
    end
end

-- Drop all handlers whose key isn't in keepSet (a table of fullNames to keep).
function M.retain(keepSet)
    for name in pairs(handlers) do
        if not keepSet[name] then handlers[name] = nil end
    end
end

return M
