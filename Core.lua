----------------------------------------------------------------------
-- LFG+ Core
-- Initialization, saved variables, event handling, utilities
----------------------------------------------------------------------
local addonName, ns = ...
ns.addonName = addonName
ns.version = "1.0.0"

----------------------------------------------------------------------
-- Default settings
----------------------------------------------------------------------
ns.defaults = {
    -- Window
    windowScale = 1.5,
    windowScaleEnabled = true,

    -- Role filter (inclusive: checked = show that role)
    roleFilterEnabled = false,
    roleFilter = {
        TANK = true,
        HEALER = true,
        DPS = true,
    },

    -- Spec filter (per-class spec toggles)
    specFilterEnabled = false,
    specFilter = {}, -- populated from CLASS_SPECS on first load

    -- Group composition filter
    compFilterEnabled = false,
    compFilter = {
        hasTank = false,
        hasHealer = false,
        hasDPS = false,
    },
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
    if not LFGPlusDB then
        LFGPlusDB = {}
    end
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
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:InitDB()
        print("|cff33ff99LFG+|r v" .. ns.version .. " loaded. Type |cff33ff99/lfgplus|r to toggle filters.")
    elseif event == "PLAYER_LOGIN" then
        -- LFG frames may be demand-loaded; try to hook now or wait
        ns:TryHookLFG()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

----------------------------------------------------------------------
-- Watch for Blizzard LFG UI loading (demand-loaded addons)
----------------------------------------------------------------------
function ns:TryHookLFG()
    -- Attempt to find the LFG frame and initialise UI/hooks
    local lfgFrame = self:FindLFGFrame()
    if lfgFrame then
        self:InitUI(lfgFrame)
        self:InitFilters(lfgFrame)
        return true
    end

    -- If not available yet, watch for it
    if not ns._lfgWatcher then
        ns._lfgWatcher = CreateFrame("Frame")
        ns._lfgWatcher:RegisterEvent("ADDON_LOADED")
        ns._lfgWatcher:SetScript("OnEvent", function(_, _, loadedAddon)
            -- Common Blizzard LFG addon names
            if loadedAddon == "Blizzard_LookingForGroupUI"
                or loadedAddon == "Blizzard_PVPUI"
                or loadedAddon == "Blizzard_LFGFrame"
                or loadedAddon == "Blizzard_LFGBrowseFrame" then
                C_Timer.After(0.1, function()
                    if ns:TryHookLFG() then
                        ns._lfgWatcher:UnregisterEvent("ADDON_LOADED")
                        ns._lfgWatcher = nil
                    end
                end)
            end
        end)
    end
    return false
end

----------------------------------------------------------------------
-- Find the built-in LFG parent frame
----------------------------------------------------------------------
function ns:FindLFGFrame()
    -- Try common frame names across TBC Classic variants
    local candidates = {
        "LFGParentFrame",
        "LFGBrowseFrame",
        "LFGListFrame",
        "GroupFinderFrame",
        "PVEFrame",
    }
    for _, name in ipairs(candidates) do
        local frame = _G[name]
        if frame and type(frame) == "table" and frame.GetName then
            ns.lfgFrameName = name
            return frame
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Find the browse/search result scroll area inside the LFG frame
----------------------------------------------------------------------
function ns:FindBrowseScrollFrame(lfgFrame)
    -- Try known child names
    local names = {
        "LFGBrowseFrameListScrollFrame",
        "LFGParentFrameListScrollFrame",
        "LFGListFrameScrollFrame",
    }
    for _, name in ipairs(names) do
        local f = _G[name]
        if f then return f end
    end

    -- Fallback: search children for a ScrollFrame
    for _, child in ipairs({lfgFrame:GetChildren()}) do
        if child:GetObjectType() == "ScrollFrame" then
            return child
        end
        -- One level deeper
        if child.GetChildren then
            for _, grandchild in ipairs({child:GetChildren()}) do
                if grandchild:GetObjectType() == "ScrollFrame" then
                    return grandchild
                end
            end
        end
    end
    return nil
end

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
        ns:RefreshUI()
        print("|cff33ff99LFG+|r: Settings reset to defaults.")
    elseif msg == "scale" then
        ns.db.windowScaleEnabled = not ns.db.windowScaleEnabled
        ns:ApplyWindowScale()
        print("|cff33ff99LFG+|r: Window scaling " .. (ns.db.windowScaleEnabled and "enabled" or "disabled") .. ".")
    elseif msg == "status" then
        print("|cff33ff99LFG+|r: Version " .. ns.version)
        print("  LFG frame: " .. (ns.lfgFrameName or "not found"))
        print("  Filters: " .. (ns.db.roleFilterEnabled and "role" or "") .. " "
            .. (ns.db.specFilterEnabled and "spec" or "") .. " "
            .. (ns.db.compFilterEnabled and "comp" or ""))
    else
        ns:ToggleFilterPanel()
    end
end

----------------------------------------------------------------------
-- Colour utilities
----------------------------------------------------------------------
ns.COLOURS = {
    TANK    = { r = 0.20, g = 0.59, b = 0.93 },  -- blue
    HEALER  = { r = 0.00, g = 0.80, b = 0.40 },  -- green
    DPS     = { r = 0.90, g = 0.30, b = 0.25 },  -- red
    TITLE   = { r = 0.20, g = 1.00, b = 0.60 },  -- addon green
    MUTED   = { r = 0.50, g = 0.50, b = 0.50 },  -- grey
}
