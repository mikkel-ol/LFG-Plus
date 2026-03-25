----------------------------------------------------------------------
-- LFG+ UI
-- Window enlargement, filter panel, display hooks.
-- Designed to be minimally invasive (Leatrix Plus style):
--   • Hooks existing frames rather than replacing them
--   • Adds controls that blend with Blizzard aesthetic
--   • Filter panel toggles on/off with a small button
----------------------------------------------------------------------
local _, ns = ...

-- Forward declarations
local filterPanel, filterButton

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local PANEL_WIDTH       = 240
local PANEL_BG_COLOUR   = { 0.05, 0.05, 0.05, 0.92 }
local PANEL_BORDER_CLR  = { 0.30, 0.30, 0.30, 1.0 }
local SECTION_SPACING   = 12
local CHECKBOX_HEIGHT   = 20
local ROLE_ORDER        = { "TANK", "HEALER", "DPS" }
local ROLE_LABELS       = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }
local ROLE_ICONS        = {
    TANK   = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t",
    DPS    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t",
}

-- Class display order
local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "DRUID", "PRIEST",
    "SHAMAN",  "ROGUE",   "HUNTER", "MAGE",
    "WARLOCK",
}

-- Class colours (Blizzard RAID_CLASS_COLORS fallback)
local CLASS_COLOURS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.25, g = 0.78, b = 0.92 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

----------------------------------------------------------------------
-- Helper: create a standard Blizzard-style checkbox
----------------------------------------------------------------------
local function CreateCheckbox(parent, label, tooltip, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb.text:SetText(label)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end

    cb:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if onClick then onClick(self, self:GetChecked()) end
    end)

    return cb
end

----------------------------------------------------------------------
-- Helper: create a section header label
----------------------------------------------------------------------
local function CreateSectionHeader(parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cff33ff99" .. text .. "|r")
    header:SetJustifyH("LEFT")
    return header
end

----------------------------------------------------------------------
-- Helper: create a collapsible section toggle
----------------------------------------------------------------------
local function CreateSectionToggle(parent, label, tooltip, onToggle)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(PANEL_WIDTH - 20, 18)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.arrow:SetPoint("LEFT", 0, 0)
    btn.arrow:SetText("|cffcccccc▶|r")

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetPoint("LEFT", btn.arrow, "RIGHT", 4, 0)
    btn.label:SetText(label)

    btn.expanded = false

    btn:SetScript("OnClick", function(self)
        self.expanded = not self.expanded
        self.arrow:SetText(self.expanded and "|cffcccccc▼|r" or "|cffcccccc▶|r")
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if onToggle then onToggle(self.expanded) end
    end)

    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end

    return btn
end

----------------------------------------------------------------------
-- Apply window scale to the LFG frame
----------------------------------------------------------------------
function ns:ApplyWindowScale()
    local lfgFrame = self:FindLFGFrame()
    if not lfgFrame then return end

    if self.db.windowScaleEnabled then
        local scale = self.db.windowScale or 1.5
        lfgFrame:SetScale(scale)
    else
        lfgFrame:SetScale(1.0)
    end
end

----------------------------------------------------------------------
-- Build the filter panel (anchored to right side of LFG frame)
----------------------------------------------------------------------
local function BuildFilterPanel(lfgFrame)
    -- Main panel frame
    filterPanel = CreateFrame("Frame", "LFGPlusFilterPanel", lfgFrame, "BackdropTemplate")
    filterPanel:SetSize(PANEL_WIDTH, 500)
    filterPanel:SetPoint("TOPLEFT", lfgFrame, "TOPRIGHT", 2, 0)
    filterPanel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    filterPanel:SetBackdropColor(unpack(PANEL_BG_COLOUR))
    filterPanel:SetBackdropBorderColor(unpack(PANEL_BORDER_CLR))
    filterPanel:SetFrameStrata("DIALOG")
    filterPanel:EnableMouse(true)
    filterPanel:Hide()

    -- Scroll frame for panel content
    local scrollFrame = CreateFrame("ScrollFrame", nil, filterPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 40, 1) -- height set dynamically
    scrollFrame:SetScrollChild(content)

    local yOffset = 0
    local function NextY(height)
        local y = yOffset
        yOffset = yOffset - height
        return y
    end

    ----------------------------------------------------------------
    -- Title
    ----------------------------------------------------------------
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, NextY(22))
    title:SetText("|cff33ff99LFG+ Filters|r")
    NextY(SECTION_SPACING)

    ----------------------------------------------------------------
    -- Status / count text
    ----------------------------------------------------------------
    local countText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", 0, NextY(16))
    countText:SetText("Showing all results")
    countText:SetTextColor(0.7, 0.7, 0.7)
    ns.filterCountText = countText
    NextY(SECTION_SPACING)

    ----------------------------------------------------------------
    -- ROLE FILTER SECTION
    ----------------------------------------------------------------
    local roleHeader = CreateSectionHeader(content, "Role Filter")
    roleHeader:SetPoint("TOPLEFT", 0, NextY(16))
    NextY(4)

    local roleEnable = CreateCheckbox(content, "Enable role filter",
        "When enabled, only show players that match (or might match) the selected roles.",
        function(_, checked)
            ns.db.roleFilterEnabled = checked and true or false
            ns:RefreshFilters()
        end)
    roleEnable:SetPoint("TOPLEFT", 0, NextY(CHECKBOX_HEIGHT + 2))
    roleEnable:SetChecked(ns.db.roleFilterEnabled)
    ns._roleEnableCB = roleEnable

    local roleCheckboxes = {}
    for _, role in ipairs(ROLE_ORDER) do
        local icon = ROLE_ICONS[role] or ""
        local cb = CreateCheckbox(content, icon .. " " .. ROLE_LABELS[role], nil,
            function(_, checked)
                ns.db.roleFilter[role] = checked and true or false
                ns:RefreshFilters()
            end)
        cb:SetPoint("TOPLEFT", 16, NextY(CHECKBOX_HEIGHT))
        cb:SetChecked(ns.db.roleFilter[role])
        roleCheckboxes[role] = cb
    end
    ns._roleCheckboxes = roleCheckboxes

    NextY(SECTION_SPACING)

    ----------------------------------------------------------------
    -- SPEC FILTER SECTION
    ----------------------------------------------------------------
    local specHeader = CreateSectionHeader(content, "Spec Filter")
    specHeader:SetPoint("TOPLEFT", 0, NextY(16))
    NextY(4)

    local specEnable = CreateCheckbox(content, "Enable spec filter",
        "When enabled, only show players whose detected spec matches selections.\n"
        .. "Players with unknown spec always show (inclusive filtering).",
        function(_, checked)
            ns.db.specFilterEnabled = checked and true or false
            ns:RefreshFilters()
        end)
    specEnable:SetPoint("TOPLEFT", 0, NextY(CHECKBOX_HEIGHT + 2))
    specEnable:SetChecked(ns.db.specFilterEnabled)
    ns._specEnableCB = specEnable

    -- Per-class collapsible spec sections
    ns._specCheckboxes = {}
    for _, classFile in ipairs(CLASS_ORDER) do
        local specs = ns.CLASS_SPECS[classFile]
        if specs then
            local clr = CLASS_COLOURS[classFile] or { r = 1, g = 1, b = 1 }
            local className = classFile:sub(1, 1) .. classFile:sub(2):lower()
            local specFrames = {}

            -- Create spec checkboxes (initially hidden)
            local specContainer = CreateFrame("Frame", nil, content)
            specContainer:SetSize(PANEL_WIDTH - 40, #specs * CHECKBOX_HEIGHT)
            specContainer:Hide()

            for si, spec in ipairs(specs) do
                local cb = CreateCheckbox(specContainer, spec.name,
                    spec.role .. " spec",
                    function(_, checked)
                        if not ns.db.specFilter[classFile] then
                            ns.db.specFilter[classFile] = {}
                        end
                        ns.db.specFilter[classFile][spec.name] = checked and true or false
                        ns:RefreshFilters()
                    end)
                cb:SetPoint("TOPLEFT", 16, -(si - 1) * CHECKBOX_HEIGHT)
                local isChecked = ns.db.specFilter[classFile]
                    and ns.db.specFilter[classFile][spec.name]
                cb:SetChecked(isChecked ~= false) -- default true
                specFrames[spec.name] = cb
            end

            -- Class toggle button
            local colourHex = string.format("|cff%02x%02x%02x",
                clr.r * 255, clr.g * 255, clr.b * 255)
            local toggle = CreateSectionToggle(content,
                colourHex .. className .. "|r",
                "Click to expand " .. className .. " spec options",
                function(expanded)
                    if expanded then
                        specContainer:Show()
                    else
                        specContainer:Hide()
                    end
                    ns:LayoutFilterPanel()
                end)
            toggle:SetPoint("TOPLEFT", 8, NextY(20))
            toggle._specContainer = specContainer
            toggle._classFile = classFile

            specContainer:SetPoint("TOPLEFT", 16, NextY(0))
            -- Reserve space only when expanded (layout adjusts dynamically)

            ns._specCheckboxes[classFile] = specFrames
        end
    end

    NextY(SECTION_SPACING)

    ----------------------------------------------------------------
    -- GROUP COMPOSITION FILTER SECTION
    ----------------------------------------------------------------
    local compHeader = CreateSectionHeader(content, "Group Composition")
    compHeader:SetPoint("TOPLEFT", 0, NextY(16))
    NextY(4)

    local compEnable = CreateCheckbox(content, "Enable composition filter",
        "When enabled, filter group listings by their stated composition.\n"
        .. "Groups with unknown composition always show.",
        function(_, checked)
            ns.db.compFilterEnabled = checked and true or false
            ns:RefreshFilters()
        end)
    compEnable:SetPoint("TOPLEFT", 0, NextY(CHECKBOX_HEIGHT + 2))
    compEnable:SetChecked(ns.db.compFilterEnabled)
    ns._compEnableCB = compEnable

    local compNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    compNote:SetPoint("TOPLEFT", 16, NextY(28))
    compNote:SetText("|cffaaaaaaHide groups that are\nLOOKING FOR these roles\n(meaning they lack them):|r")
    compNote:SetJustifyH("LEFT")
    compNote:SetWidth(PANEL_WIDTH - 60)
    NextY(12)

    local compCheckboxes = {}
    local compKeys = { { key = "hasTank", label = "Has Tank" }, { key = "hasHealer", label = "Has Healer" }, { key = "hasDPS", label = "Has DPS" } }
    for _, entry in ipairs(compKeys) do
        local cb = CreateCheckbox(content, entry.label, nil,
            function(_, checked)
                ns.db.compFilter[entry.key] = checked and true or false
                ns:RefreshFilters()
            end)
        cb:SetPoint("TOPLEFT", 16, NextY(CHECKBOX_HEIGHT))
        cb:SetChecked(ns.db.compFilter[entry.key])
        compCheckboxes[entry.key] = cb
    end
    ns._compCheckboxes = compCheckboxes

    NextY(SECTION_SPACING + 8)

    ----------------------------------------------------------------
    -- WINDOW SCALE SECTION
    ----------------------------------------------------------------
    local scaleHeader = CreateSectionHeader(content, "Window Scale")
    scaleHeader:SetPoint("TOPLEFT", 0, NextY(16))
    NextY(4)

    local scaleCB = CreateCheckbox(content, "Enlarge LFG window (1.5x)",
        "Scale the LFG window to be 50% larger, like Leatrix Plus larger windows.",
        function(_, checked)
            ns.db.windowScaleEnabled = checked and true or false
            ns:ApplyWindowScale()
        end)
    scaleCB:SetPoint("TOPLEFT", 0, NextY(CHECKBOX_HEIGHT + 2))
    scaleCB:SetChecked(ns.db.windowScaleEnabled)
    ns._scaleCB = scaleCB

    -- Scale slider
    local slider = CreateFrame("Slider", "LFGPlusScaleSlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, NextY(40))
    slider:SetSize(PANEL_WIDTH - 60, 16)
    slider:SetMinMaxValues(1.0, 2.0)
    slider:SetValueStep(0.1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(ns.db.windowScale or 1.5)

    if LFGPlusScaleSliderLow then
        LFGPlusScaleSliderLow:SetText("1.0x")
    end
    if LFGPlusScaleSliderHigh then
        LFGPlusScaleSliderHigh:SetText("2.0x")
    end
    if LFGPlusScaleSliderText then
        LFGPlusScaleSliderText:SetText(string.format("%.1fx", ns.db.windowScale or 1.5))
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10 -- round to 0.1
        ns.db.windowScale = value
        if LFGPlusScaleSliderText then
            LFGPlusScaleSliderText:SetText(string.format("%.1fx", value))
        end
        if ns.db.windowScaleEnabled then
            ns:ApplyWindowScale()
        end
    end)
    ns._scaleSlider = slider

    NextY(SECTION_SPACING + 8)

    ----------------------------------------------------------------
    -- RESET BUTTON
    ----------------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 0, NextY(30))
    resetBtn:SetSize(120, 24)
    resetBtn:SetText("Reset Filters")
    resetBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 857)
        ns:ResetAllFilters()
    end)

    NextY(16)

    -- Set content height
    content:SetHeight(math.abs(yOffset) + 20)
    filterPanel._content = content
    filterPanel._yOffset = yOffset

    return filterPanel
end

----------------------------------------------------------------------
-- Dynamic re-layout (called when collapsible sections expand/collapse)
----------------------------------------------------------------------
function ns:LayoutFilterPanel()
    -- The panel uses a scroll frame, so content overflow is handled.
    -- We just need to recalculate content height.
    if not filterPanel or not filterPanel._content then return end
    -- Force scroll frame to update
    filterPanel._content:GetParent():UpdateScrollChildRect()
end

----------------------------------------------------------------------
-- Build the filter toggle button on the LFG frame
----------------------------------------------------------------------
local function BuildFilterButton(lfgFrame)
    filterButton = CreateFrame("Button", "LFGPlusFilterButton", lfgFrame, "UIPanelButtonTemplate")
    filterButton:SetSize(70, 22)
    filterButton:SetText("LFG+")
    filterButton:SetNormalFontObject("GameFontNormalSmall")
    filterButton:SetHighlightFontObject("GameFontHighlightSmall")

    -- Position near top-right of the LFG frame, but inside the border
    filterButton:SetPoint("TOPRIGHT", lfgFrame, "TOPRIGHT", -30, -4)
    filterButton:SetFrameStrata("DIALOG")

    filterButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 857)
        ns:ToggleFilterPanel()
    end)

    filterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("LFG+ Filters", 0.2, 1.0, 0.6)
        GameTooltip:AddLine("Click to toggle the filter panel.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    filterButton:SetScript("OnLeave", GameTooltip_Hide)

    return filterButton
end

----------------------------------------------------------------------
-- Toggle filter panel visibility
----------------------------------------------------------------------
function ns:ToggleFilterPanel()
    if not filterPanel then
        local lfgFrame = self:FindLFGFrame()
        if not lfgFrame then
            print("|cff33ff99LFG+|r: LFG window not found. Open the LFG tool first.")
            return
        end
        BuildFilterPanel(lfgFrame)
    end
    if filterPanel:IsShown() then
        filterPanel:Hide()
    else
        filterPanel:Show()
    end
end

----------------------------------------------------------------------
-- Reset all filters to default
----------------------------------------------------------------------
function ns:ResetAllFilters()
    local db = self.db
    db.roleFilterEnabled = false
    db.specFilterEnabled = false
    db.compFilterEnabled = false
    db.roleFilter = { TANK = true, HEALER = true, DPS = true }
    db.compFilter = { hasTank = false, hasHealer = false, hasDPS = false }

    -- Reset all spec filters to true
    for classFile, specs in pairs(self.CLASS_SPECS) do
        db.specFilter[classFile] = {}
        for _, spec in ipairs(specs) do
            db.specFilter[classFile][spec.name] = true
        end
    end

    -- Update UI checkboxes
    if self._roleEnableCB then self._roleEnableCB:SetChecked(false) end
    if self._specEnableCB then self._specEnableCB:SetChecked(false) end
    if self._compEnableCB then self._compEnableCB:SetChecked(false) end

    if self._roleCheckboxes then
        for _, cb in pairs(self._roleCheckboxes) do cb:SetChecked(true) end
    end
    if self._specCheckboxes then
        for classFile, specCBs in pairs(self._specCheckboxes) do
            for _, cb in pairs(specCBs) do cb:SetChecked(true) end
        end
    end
    if self._compCheckboxes then
        for _, cb in pairs(self._compCheckboxes) do cb:SetChecked(false) end
    end

    self:RefreshFilters()
    print("|cff33ff99LFG+|r: All filters reset.")
end

----------------------------------------------------------------------
-- Refresh the UI state (called after settings load/reset)
----------------------------------------------------------------------
function ns:RefreshUI()
    self:ApplyWindowScale()
    self:RefreshFilters()
end

----------------------------------------------------------------------
-- Update the filter count display text
----------------------------------------------------------------------
function ns:UpdateFilterCountText()
    if not ns.filterCountText then return end
    local total = ns.totalRawResults or 0
    local shown = #ns.filteredIndices
    if total == 0 then
        ns.filterCountText:SetText("No results")
    elseif shown == total then
        ns.filterCountText:SetText("Showing all " .. total .. " results")
    else
        ns.filterCountText:SetText(string.format("Showing %d / %d results", shown, total))
        ns.filterCountText:SetTextColor(1, 0.8, 0.2)
    end
end

----------------------------------------------------------------------
-- Hook: override the LFG browse list display to use filtered indices
----------------------------------------------------------------------
local browseButtons = {}
local browseScrollFrame = nil
local originalUpdateFunc = nil

local function GetBrowseButtons(lfgFrame)
    if #browseButtons > 0 then return browseButtons end

    -- Try to find browse list buttons by known name patterns
    local patterns = {
        "LFGBrowseFrameListButton%d+",
        "LFGParentFrameListButton%d+",
        "LFGListFrameButton%d+",
        "LFGBrowseSearchEntry%d+",
    }
    for _, pattern in ipairs(patterns) do
        for i = 1, 30 do
            local name = pattern:gsub("%%d+", tostring(i))
            local btn = _G[name]
            if btn then
                browseButtons[#browseButtons + 1] = btn
            else
                if i > 1 then break end -- no more buttons in this pattern
            end
        end
        if #browseButtons > 0 then break end
    end

    -- Fallback: search children for buttons with a .name field (common result entry pattern)
    if #browseButtons == 0 then
        local function SearchChildren(frame, depth)
            if depth > 3 then return end
            for _, child in ipairs({frame:GetChildren()}) do
                local objType = child:GetObjectType()
                if objType == "Button" and child.Name or
                   (objType == "Button" and child:GetName() and child:GetName():find("Entry")) then
                    browseButtons[#browseButtons + 1] = child
                end
                SearchChildren(child, depth + 1)
            end
        end
        SearchChildren(lfgFrame, 0)
    end

    return browseButtons
end

----------------------------------------------------------------------
-- Post-hook: after the original update function runs, compact visible
-- buttons to only show filtered results.
-- (This is the minimally invasive approach – works regardless of
-- the exact browse frame implementation.)
----------------------------------------------------------------------
local function PostHookBrowseUpdate()
    if not ns.db then return end
    local anyFilter = ns.db.roleFilterEnabled or ns.db.specFilterEnabled or ns.db.compFilterEnabled
    if not anyFilter then return end

    local buttons = GetBrowseButtons(ns:FindLFGFrame())
    if #buttons == 0 then return end

    -- Walk through visible buttons; hide ones that fail filters
    -- Then compact remaining buttons upward to fill gaps
    local visibleButtons = {}
    local hiddenButtons = {}

    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            -- Try to get the result index stored on the button
            local resultIndex = btn.resultIndex or btn.index or btn:GetID()
            if resultIndex and resultIndex > 0 then
                if ns:ShouldShowResult(resultIndex) then
                    visibleButtons[#visibleButtons + 1] = btn
                else
                    hiddenButtons[#hiddenButtons + 1] = btn
                end
            else
                visibleButtons[#visibleButtons + 1] = btn
            end
        end
    end

    -- Hide filtered-out buttons
    for _, btn in ipairs(hiddenButtons) do
        btn:Hide()
    end

    -- Re-anchor visible buttons to remove gaps
    if #visibleButtons > 0 and #hiddenButtons > 0 then
        local firstBtn = visibleButtons[1]
        local _, _, _, _, firstY = firstBtn:GetPoint(1)
        local btnHeight = firstBtn:GetHeight()
        local spacing = 1

        for i, btn in ipairs(visibleButtons) do
            if i > 1 then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", visibleButtons[i - 1], "BOTTOMLEFT", 0, -spacing)
                btn:SetPoint("TOPRIGHT", visibleButtons[i - 1], "BOTTOMRIGHT", 0, -spacing)
            end
        end
    end

    -- Update count display
    ns:UpdateFilterCountText()
end

----------------------------------------------------------------------
-- Hook known LFG update functions
----------------------------------------------------------------------
local function HookUpdateFunctions()
    -- Try to hook known update function names
    local funcNames = {
        "LFGBrowseFrameList_Update",
        "LFGParentFrame_UpdateList",
        "LFGParentFrame_Update",
        "LFGBrowseFrame_Update",
        "LFGFrame_Update",
        "LFGListFrame_Update",
    }
    local hooked = false
    for _, funcName in ipairs(funcNames) do
        if _G[funcName] and type(_G[funcName]) == "function" then
            hooksecurefunc(funcName, PostHookBrowseUpdate)
            hooked = true
        end
    end

    -- Also try to hook via frame scripts
    local scrollFrame = ns:FindBrowseScrollFrame(ns:FindLFGFrame())
    if scrollFrame and scrollFrame:GetScript("OnVerticalScroll") then
        scrollFrame:HookScript("OnVerticalScroll", function()
            C_Timer.After(0.01, PostHookBrowseUpdate)
        end)
        hooked = true
    end

    if not hooked then
        -- Fallback: use a repeating timer to apply filters
        -- (less efficient but ensures compatibility)
        C_Timer.NewTicker(0.5, function()
            if ns.db and (ns.db.roleFilterEnabled or ns.db.specFilterEnabled or ns.db.compFilterEnabled) then
                local lfgFrame = ns:FindLFGFrame()
                if lfgFrame and lfgFrame:IsShown() then
                    PostHookBrowseUpdate()
                end
            end
        end)
    end

    return hooked
end

----------------------------------------------------------------------
-- Store the display update reference so Filters.lua can call it
----------------------------------------------------------------------
function ns:UpdateBrowseDisplay()
    PostHookBrowseUpdate()
end

----------------------------------------------------------------------
-- Initialise UI (called once when LFG frame is found)
----------------------------------------------------------------------
function ns:InitUI(lfgFrame)
    -- Apply window scaling
    self:ApplyWindowScale()

    -- Add the filter toggle button to the LFG frame
    BuildFilterButton(lfgFrame)

    -- Hook the browse list update function
    HookUpdateFunctions()

    -- Build filter panel (hidden by default)
    BuildFilterPanel(lfgFrame)
end
