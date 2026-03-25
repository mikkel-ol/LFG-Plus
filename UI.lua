----------------------------------------------------------------------
-- LFG+ UI
-- Enlarges the built-in LFG window and embeds filter controls
-- directly inside it. Nothing external — everything lives within
-- the same frame the player opens with "I".
--
-- Leatrix Plus style: hooks existing frames, never replaces them;
-- added controls use the standard Blizzard visual language.
----------------------------------------------------------------------
local _, ns = ...

----------------------------------------------------------------------
-- Layout constants
----------------------------------------------------------------------
local EXTRA_WIDTH     = 225     -- pixels added to the right for filters
local FILTER_PAD      = 10      -- inner padding
local CHECKBOX_SIZE   = 22
local CHECKBOX_GAP    = 1
local SECTION_GAP     = 8
local ROLE_ORDER      = { "TANK", "HEALER", "DPS" }
local ROLE_LABELS     = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }
local ROLE_ICONS      = {
    TANK   = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DPS    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}
local CLASS_ORDER = {
    "WARRIOR","PALADIN","DRUID","PRIEST",
    "SHAMAN","ROGUE","HUNTER","MAGE","WARLOCK",
}
local CLASS_COLOURS = {
    WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER  = "abd473",
    ROGUE   = "fff569", PRIEST  = "ffffff", SHAMAN  = "0070de",
    MAGE    = "40c7eb", WARLOCK = "8787ed", DRUID   = "ff7d0a",
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function Checkbox(parent, size, label, tooltip, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(size, size)
    if label then
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 1, 0)
        cb.Text:SetText(label)
    end
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil,nil,nil,nil,true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    cb:SetScript("OnClick", function(self)
        local snd = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856
        PlaySound(snd)
        if onClick then onClick(self, self:GetChecked()) end
    end)
    return cb
end

local function SectionLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText("|cff33ff99" .. text .. "|r")
    fs:SetJustifyH("LEFT")
    return fs
end

local function Divider(parent, width)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    t:SetSize(width, 1)
    return t
end

----------------------------------------------------------------------
-- Apply window scale (Leatrix Plus style)
----------------------------------------------------------------------
function ns:ApplyWindowScale()
    if not LFGParentFrame then return end
    if self.db and self.db.windowScaleEnabled then
        LFGParentFrame:SetScale(self.db.windowScale or 1.4)
    else
        LFGParentFrame:SetScale(1.0)
    end
end

----------------------------------------------------------------------
-- Initialise UI — called once from Core after LFGParentFrame exists
----------------------------------------------------------------------
function ns:InitUI()
    local parent = LFGParentFrame
    if not parent then return end

    -- ─── 1. Widen the LFG frame ──────────────────────────────────
    local origW, origH = parent:GetSize()
    parent:SetWidth(origW + EXTRA_WIDTH)
    -- The Blizzard frame is user-movable; keep it that way
    parent:SetClampedToScreen(true)

    -- ─── 2. Apply saved scale ────────────────────────────────────
    self:ApplyWindowScale()

    -- ─── 3. Create the filter area (right strip inside frame) ────
    local filterArea = CreateFrame("Frame", "LFGPlusFilterArea", parent)
    filterArea:SetPoint("TOPLEFT", parent, "TOPLEFT", origW - 6, -60)
    filterArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 32)
    filterArea:EnableMouse(true) -- block clicks through to the parent

    -- Subtle background so the filter area is visually distinct
    local bg = filterArea:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)

    -- Separator line on the left edge
    local sep = filterArea:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    sep:SetWidth(1)
    sep:SetPoint("TOPLEFT", filterArea, "TOPLEFT", 0, 0)
    sep:SetPoint("BOTTOMLEFT", filterArea, "BOTTOMLEFT", 0, 0)

    -- We use a scrolling child so the filters never overflow
    local scroll = CreateFrame("ScrollFrame", nil, filterArea, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",  4,  -2)
    scroll:SetPoint("BOTTOMRIGHT", -22, 2)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(EXTRA_WIDTH - 34)
    content:SetHeight(1) -- set later
    scroll:SetScrollChild(content)
    self._filterContent = content

    -- Cursor for vertical layout
    local y = 0
    local cw = EXTRA_WIDTH - 34 -- content width

    ----------------------------------------------------------------
    -- Title
    ----------------------------------------------------------------
    local titleFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", 0, -y)
    titleFS:SetText("|cff33ff99LFG+ Filters|r")
    y = y + 16

    -- Count text
    local countFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countFS:SetPoint("TOPLEFT", 0, -y)
    countFS:SetText("")
    ns._countText = countFS
    y = y + 14 + SECTION_GAP

    ----------------------------------------------------------------
    -- ROLE FILTER
    ----------------------------------------------------------------
    local d1 = Divider(content, cw)
    d1:SetPoint("TOPLEFT", 0, -y); y = y + 4

    local roleEn = Checkbox(content, CHECKBOX_SIZE, "Role Filter",
        "Only show players matching checked roles.\nUnknown roles always pass.",
        function(_, c) ns.db.roleFilterEnabled = (c and true or false); ns:RefreshFilters() end)
    roleEn:SetPoint("TOPLEFT", 0, -y)
    roleEn:SetChecked(ns.db.roleFilterEnabled)
    ns._ui_roleEn = roleEn
    y = y + CHECKBOX_SIZE + CHECKBOX_GAP

    local roleBoxes = {}
    for _, role in ipairs(ROLE_ORDER) do
        local cb = Checkbox(content, CHECKBOX_SIZE,
            ROLE_ICONS[role] .. " " .. ROLE_LABELS[role], nil,
            function(_, c) ns.db.roleFilter[role] = (c and true or false); ns:RefreshFilters() end)
        cb:SetPoint("TOPLEFT", 14, -y)
        cb:SetChecked(ns.db.roleFilter[role])
        roleBoxes[role] = cb
        y = y + CHECKBOX_SIZE + CHECKBOX_GAP
    end
    ns._ui_roleBoxes = roleBoxes
    y = y + SECTION_GAP

    ----------------------------------------------------------------
    -- SPEC FILTER
    ----------------------------------------------------------------
    local d2 = Divider(content, cw)
    d2:SetPoint("TOPLEFT", 0, -y); y = y + 4

    local specEn = Checkbox(content, CHECKBOX_SIZE, "Spec Filter",
        "Only show players whose detected spec is checked.\n"
        .. "Unknown spec always passes (inclusive filtering).",
        function(_, c) ns.db.specFilterEnabled = (c and true or false); ns:RefreshFilters() end)
    specEn:SetPoint("TOPLEFT", 0, -y)
    specEn:SetChecked(ns.db.specFilterEnabled)
    ns._ui_specEn = specEn
    y = y + CHECKBOX_SIZE + CHECKBOX_GAP + 2

    -- Per-class collapsible rows
    ns._ui_specBoxes = {}
    ns._ui_specContainers = {}
    for _, classFile in ipairs(CLASS_ORDER) do
        local specs = ns.CLASS_SPECS[classFile]
        if specs then
            local clrHex = CLASS_COLOURS[classFile] or "ffffff"
            local niceName = classFile:sub(1,1) .. classFile:sub(2):lower()

            -- Toggle row (clicking expands / collapses the specs below)
            local toggle = CreateFrame("Button", nil, content)
            toggle:SetSize(cw, 16)
            toggle:SetPoint("TOPLEFT", 4, -y)
            toggle:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")

            toggle.arrow = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            toggle.arrow:SetPoint("LEFT", 0, 0)
            toggle.arrow:SetText("|cffaaaaaa\226\150\182|r") -- ▶

            toggle.label = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            toggle.label:SetPoint("LEFT", toggle.arrow, "RIGHT", 3, 0)
            toggle.label:SetText("|cff" .. clrHex .. niceName .. "|r")

            y = y + 18

            -- Spec checkbox container (hidden by default)
            local specCont = CreateFrame("Frame", nil, content)
            specCont:SetSize(cw - 16, #specs * (CHECKBOX_SIZE + CHECKBOX_GAP))
            specCont:SetPoint("TOPLEFT", 16, -y)
            specCont:Hide()
            ns._ui_specContainers[classFile] = { container = specCont, startY = y }

            local specBoxes = {}
            for si, spec in ipairs(specs) do
                local scb = Checkbox(specCont, CHECKBOX_SIZE, spec.name,
                    spec.role, function(_, c)
                        if not ns.db.specFilter[classFile] then ns.db.specFilter[classFile] = {} end
                        ns.db.specFilter[classFile][spec.name] = (c and true or false)
                        ns:RefreshFilters()
                    end)
                scb:SetPoint("TOPLEFT", 0, -(si - 1) * (CHECKBOX_SIZE + CHECKBOX_GAP))
                local checked = ns.db.specFilter[classFile] and ns.db.specFilter[classFile][spec.name]
                scb:SetChecked(checked ~= false)
                specBoxes[spec.name] = scb
            end
            ns._ui_specBoxes[classFile] = specBoxes

            toggle.expanded = false
            toggle:SetScript("OnClick", function(self)
                self.expanded = not self.expanded
                self.arrow:SetText(self.expanded and "|cffaaaaaa\226\150\188|r" or "|cffaaaaaa\226\150\182|r")
                PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                if self.expanded then specCont:Show() else specCont:Hide() end
                ns:RelayoutFilterContent()
            end)
            toggle._specCont = specCont
            toggle._classFile = classFile
        end
    end
    y = y + SECTION_GAP

    ----------------------------------------------------------------
    -- GROUP COMPOSITION FILTER
    ----------------------------------------------------------------
    local d3 = Divider(content, cw)
    d3:SetPoint("TOPLEFT", 0, -y); y = y + 4

    local compEn = Checkbox(content, CHECKBOX_SIZE, "Composition",
        "Hide groups that are LOOKING FOR a role (meaning they lack it).\n"
        .. "Groups with unknown composition always show.",
        function(_, c) ns.db.compFilterEnabled = (c and true or false); ns:RefreshFilters() end)
    compEn:SetPoint("TOPLEFT", 0, -y)
    compEn:SetChecked(ns.db.compFilterEnabled)
    ns._ui_compEn = compEn
    y = y + CHECKBOX_SIZE + CHECKBOX_GAP

    local compBoxes = {}
    local compKeys = {
        { key = "hasTank",   label = "Must have Tank" },
        { key = "hasHealer", label = "Must have Healer" },
        { key = "hasDPS",    label = "Must have DPS" },
    }
    for _, entry in ipairs(compKeys) do
        local cb = Checkbox(content, CHECKBOX_SIZE, entry.label, nil,
            function(_, c) ns.db.compFilter[entry.key] = (c and true or false); ns:RefreshFilters() end)
        cb:SetPoint("TOPLEFT", 14, -y)
        cb:SetChecked(ns.db.compFilter[entry.key])
        compBoxes[entry.key] = cb
        y = y + CHECKBOX_SIZE + CHECKBOX_GAP
    end
    ns._ui_compBoxes = compBoxes
    y = y + SECTION_GAP

    ----------------------------------------------------------------
    -- WINDOW SCALE
    ----------------------------------------------------------------
    local d4 = Divider(content, cw)
    d4:SetPoint("TOPLEFT", 0, -y); y = y + 4

    local scaleEn = Checkbox(content, CHECKBOX_SIZE, "Larger Window",
        "Scale the LFG window up, Leatrix Plus style.",
        function(_, c) ns.db.windowScaleEnabled = (c and true or false); ns:ApplyWindowScale() end)
    scaleEn:SetPoint("TOPLEFT", 0, -y)
    scaleEn:SetChecked(ns.db.windowScaleEnabled)
    ns._ui_scaleEn = scaleEn
    y = y + CHECKBOX_SIZE + 4

    -- Scale slider
    local slider = CreateFrame("Slider", "LFGPlusScaleSlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 8, -(y + 6))
    slider:SetSize(cw - 20, 14)
    slider:SetMinMaxValues(1.0, 2.0)
    slider:SetValueStep(0.1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(ns.db.windowScale or 1.4)
    if _G["LFGPlusScaleSliderLow"]  then _G["LFGPlusScaleSliderLow"]:SetText("1x")  end
    if _G["LFGPlusScaleSliderHigh"] then _G["LFGPlusScaleSliderHigh"]:SetText("2x") end
    if _G["LFGPlusScaleSliderText"] then _G["LFGPlusScaleSliderText"]:SetText(string.format("%.1fx", ns.db.windowScale or 1.4)) end
    slider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val * 10 + 0.5) / 10
        ns.db.windowScale = val
        if _G["LFGPlusScaleSliderText"] then
            _G["LFGPlusScaleSliderText"]:SetText(string.format("%.1fx", val))
        end
        if ns.db.windowScaleEnabled then ns:ApplyWindowScale() end
    end)
    ns._ui_slider = slider
    y = y + 40 + SECTION_GAP

    ----------------------------------------------------------------
    -- RESET BUTTON
    ----------------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 0, -y)
    resetBtn:SetSize(100, 20)
    resetBtn:SetText("Reset All")
    resetBtn:SetNormalFontObject("GameFontNormalSmall")
    resetBtn:SetHighlightFontObject("GameFontHighlightSmall")
    resetBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 857)
        ns:ResetAllFilters()
    end)
    y = y + 28

    -- Final content height
    content:SetHeight(y + 16)
    ns._filterContentHeight = y + 16
    ns._filterBaseY = y

    -- Store UI refs
    ns._filterArea = filterArea
end

----------------------------------------------------------------------
-- Relayout filter content when collapsible sections change
----------------------------------------------------------------------
function ns:RelayoutFilterContent()
    -- Simple approach: iterate containers and adjust visibility;
    -- the scroll frame handles overflow.
    if not self._filterContent then return end
    self._filterContent:GetParent():UpdateScrollChildRect()
end

----------------------------------------------------------------------
-- Sync UI checkboxes to current saved settings
-- (called after /lfgplus reset)
----------------------------------------------------------------------
function ns:SyncUIToSettings()
    local db = self.db
    if not db then return end

    if ns._ui_roleEn then ns._ui_roleEn:SetChecked(db.roleFilterEnabled) end
    if ns._ui_specEn then ns._ui_specEn:SetChecked(db.specFilterEnabled) end
    if ns._ui_compEn then ns._ui_compEn:SetChecked(db.compFilterEnabled) end
    if ns._ui_scaleEn then ns._ui_scaleEn:SetChecked(db.windowScaleEnabled) end

    if ns._ui_roleBoxes then
        for role, cb in pairs(ns._ui_roleBoxes) do cb:SetChecked(db.roleFilter[role]) end
    end
    if ns._ui_compBoxes then
        for key, cb in pairs(ns._ui_compBoxes) do cb:SetChecked(db.compFilter[key]) end
    end
    if ns._ui_specBoxes then
        for classFile, specCBs in pairs(ns._ui_specBoxes) do
            for specName, cb in pairs(specCBs) do
                cb:SetChecked(db.specFilter[classFile] and db.specFilter[classFile][specName] ~= false)
            end
        end
    end
    if ns._ui_slider then ns._ui_slider:SetValue(db.windowScale or 1.4) end

    self:ApplyWindowScale()
end

----------------------------------------------------------------------
-- Reset all filters to defaults
----------------------------------------------------------------------
function ns:ResetAllFilters()
    local db = self.db
    db.roleFilterEnabled = false
    db.specFilterEnabled = false
    db.compFilterEnabled = false
    db.roleFilter = { TANK = true, HEALER = true, DPS = true }
    db.compFilter = { hasTank = false, hasHealer = false, hasDPS = false }
    for classFile, specs in pairs(self.CLASS_SPECS) do
        db.specFilter[classFile] = {}
        for _, spec in ipairs(specs) do
            db.specFilter[classFile][spec.name] = true
        end
    end
    self:SyncUIToSettings()
    self:RefreshFilters()
    print("|cff33ff99LFG+|r: Filters reset.")
end
