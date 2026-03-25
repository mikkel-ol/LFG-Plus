----------------------------------------------------------------------
-- LFG+ Core
-- Initialization, saved variables, event handling, frame discovery.
-- Designed to be minimally invasive (Leatrix Plus style).
----------------------------------------------------------------------
local addonName, ns = ...
ns.addonName = addonName
ns.version   = "1.0.0"
ns.hooked    = false   -- true once we've modified the LFG frame

----------------------------------------------------------------------
-- Default settings
----------------------------------------------------------------------
ns.defaults = {
    -- Window scale
    windowScale        = 1.4,
    windowScaleEnabled = true,

    -- Role filter (inclusive: checked = show that role)
    roleFilterEnabled = false,
    roleFilter = { TANK = true, HEALER = true, DPS = true },

    -- Spec filter (per-class spec toggles, populated on first load)
    specFilterEnabled = false,
    specFilter = {},

    -- Group composition filter
    compFilterEnabled = false,
    compFilter = { hasTank = false, hasHealer = false, hasDPS = false },
}

----------------------------------------------------------------------
-- Utility: deep-copy missing keys from src into dst
----------------------------------------------------------------------
local function EnsureDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            EnsureDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

----------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------
function ns:InitDB()
    if not LFGPlusDB then LFGPlusDB = {} end
    EnsureDefaults(self.defaults, LFGPlusDB)
    self.db = LFGPlusDB

    -- Populate spec filter defaults for every class/spec combo
    if not self.db.specFilter then self.db.specFilter = {} end
    for classFile, specs in pairs(self.CLASS_SPECS or {}) do
        if not self.db.specFilter[classFile] then
            self.db.specFilter[classFile] = {}
        end
        for _, spec in ipairs(specs) do
            if self.db.specFilter[classFile][spec.name] == nil then
                self.db.specFilter[classFile][spec.name] = true
            end
        end
    end
end

----------------------------------------------------------------------
-- Try to hook the Blizzard LFG frame (called repeatedly until it
-- succeeds; the Blizzard addon is demand-loaded when "I" is pressed)
----------------------------------------------------------------------
function ns:TryHook()
    if self.hooked then return true end

    -- LFGParentFrame is the main frame created by
    -- Blizzard_LookingForGroupUI in TBC Classic.
    local parent = LFGParentFrame
    if not parent then return false end

    self.hooked = true
    self:InitUI()          -- UI.lua – resize frame, embed filters
    self:InitFilters()     -- Filters.lua – hook update functions
    return true
end

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            ns:InitDB()
            print("|cff33ff99LFG+|r v" .. ns.version .. " loaded.")
        end
        -- On ANY addon load, check if the LFG frames appeared.
        -- This catches Blizzard_LookingForGroupUI regardless of its
        -- exact name across client versions.
        ns:TryHook()
    elseif event == "PLAYER_LOGIN" then
        -- Attempt to eagerly load the Blizzard LFG addon so our hook
        -- fires even before the player presses "I" for the first time.
        if LoadAddOn then
            pcall(LoadAddOn, "Blizzard_LookingForGroupUI")
            pcall(LoadAddOn, "Blizzard_LFGFrame")
        end
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_LookingForGroupUI")
            pcall(C_AddOns.LoadAddOn, "Blizzard_LFGFrame")
        end
        ns:TryHook()

        -- If still not found, also hook ToggleLFGParentFrame (the
        -- function WoW calls when the player presses "I").
        if not ns.hooked then
            if ToggleLFGParentFrame then
                hooksecurefunc("ToggleLFGParentFrame", function()
                    C_Timer.After(0, function() ns:TryHook() end)
                end)
            end
            -- Last resort: poll a few times
            local attempts = 0
            C_Timer.NewTicker(1, function(ticker)
                attempts = attempts + 1
                if ns:TryHook() or attempts > 15 then
                    ticker:Cancel()
                end
            end)
        end

        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_LFGPLUS1 = "/lfgplus"
SLASH_LFGPLUS2 = "/lfg+"
SlashCmdList["LFGPLUS"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        LFGPlusDB = nil
        ns:InitDB()
        if ns.hooked then ns:SyncUIToSettings() end
        ns:RefreshFilters()
        print("|cff33ff99LFG+|r: Settings reset to defaults.")
    elseif msg == "status" then
        print("|cff33ff99LFG+|r v" .. ns.version)
        print("  Hooked: " .. tostring(ns.hooked))
        print("  LFGParentFrame: " .. (LFGParentFrame and "found" or "NOT found"))
    else
        -- Open the LFG window (triggers our hook if needed)
        if ToggleLFGParentFrame then
            ToggleLFGParentFrame()
        else
            print("|cff33ff99LFG+|r: Open the LFG tool with 'I' first.")
        end
    end
end

----------------------------------------------------------------------
-- Colour utilities
----------------------------------------------------------------------
ns.COLOURS = {
    TANK    = { r = 0.20, g = 0.59, b = 0.93 },
    HEALER  = { r = 0.00, g = 0.80, b = 0.40 },
    DPS     = { r = 0.90, g = 0.30, b = 0.25 },
    TITLE   = { r = 0.20, g = 1.00, b = 0.60 },
    MUTED   = { r = 0.50, g = 0.50, b = 0.50 },
}
