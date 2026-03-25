----------------------------------------------------------------------
-- LFG+ Filters
-- Evaluates whether LFG browse results should be shown based on
-- active filter settings.
--
-- Inclusive filtering: entries whose role/spec/composition CANNOT
-- be determined always pass through. Only definite mismatches hide.
----------------------------------------------------------------------
local _, ns = ...

----------------------------------------------------------------------
-- Cached state
----------------------------------------------------------------------
ns.filteredIndices = {}
ns.totalRawResults = 0

----------------------------------------------------------------------
-- TBC Classic LFG browse API wrappers.
-- SearchLFGGetNumResults() and SearchLFGGetResults(index) are the
-- concrete APIs from Blizzard_LookingForGroupUI in 2.5.x.
----------------------------------------------------------------------
function ns:GetNumResults()
    if SearchLFGGetNumResults then
        return SearchLFGGetNumResults()
    end
    return 0
end

function ns:GetResultInfo(index)
    if SearchLFGGetResults then
        return SearchLFGGetResults(index)
    end
    return nil
end

----------------------------------------------------------------------
-- Evaluate a single browse result against active filters.
-- Returns true to show, false to hide.
----------------------------------------------------------------------
function ns:ShouldShowResult(index)
    local name, level, areaName, className, comment, nMembers, isLFM =
        self:GetResultInfo(index)
    if not name then return true end

    local db = self.db
    if not db then return true end

    local classFile = self:ResolveClassFile(className)
    local detection = self:DetectSpecRole(classFile, comment)

    -- Role filter
    if db.roleFilterEnabled then
        if not self:EvaluateRoleFilter(detection) then return false end
    end

    -- Spec filter
    if db.specFilterEnabled then
        if not self:EvaluateSpecFilter(classFile, detection) then return false end
    end

    -- Group composition filter (only applies to groups / LFM)
    if db.compFilterEnabled and (isLFM or (nMembers and nMembers > 1)) then
        if not self:EvaluateCompFilter(comment) then return false end
    end

    return true
end

----------------------------------------------------------------------
-- Role filter: inclusive – unknown roles always pass
----------------------------------------------------------------------
function ns:EvaluateRoleFilter(detection)
    if detection.confidence == "none" then return true end
    for role, detected in pairs(detection.roles) do
        if detected and self.db.roleFilter[role] then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Spec filter: inclusive – unknown spec always passes
----------------------------------------------------------------------
function ns:EvaluateSpecFilter(classFile, detection)
    if not classFile then return true end
    if detection.confidence == "none" then return true end
    local classSpecFilter = self.db.specFilter[classFile]
    if not classSpecFilter then return true end
    for specName in pairs(detection.specs) do
        if classSpecFilter[specName] then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Composition filter: inclusive – unknown comp always passes.
-- Hides groups that explicitly LOOK FOR a role you require
-- (meaning the group does NOT have that role).
----------------------------------------------------------------------
function ns:EvaluateCompFilter(comment)
    local needs = self:DetectGroupNeeds(comment)
    if needs.confidence == "none" then return true end
    local cf = self.db.compFilter
    if cf.hasTank   and needs.lookingFor.TANK   then return false end
    if cf.hasHealer and needs.lookingFor.HEALER then return false end
    if cf.hasDPS    and needs.lookingFor.DPS    then return false end
    return true
end

----------------------------------------------------------------------
-- Rebuild the filtered index list
----------------------------------------------------------------------
function ns:RebuildFilteredResults()
    wipe(self.filteredIndices)
    local numResults = self:GetNumResults()
    self.totalRawResults = numResults

    local active = self.db and
        (self.db.roleFilterEnabled or self.db.specFilterEnabled or self.db.compFilterEnabled)

    for i = 1, numResults do
        if not active or self:ShouldShowResult(i) then
            self.filteredIndices[#self.filteredIndices + 1] = i
        end
    end
end

----------------------------------------------------------------------
-- Refresh: rebuild + update display
----------------------------------------------------------------------
function ns:RefreshFilters()
    self:RebuildFilteredResults()
    self:ApplyBrowseFilter()
    self:UpdateCountText()
end

----------------------------------------------------------------------
-- Initialise filter hooks (called once after LFG frame is found)
----------------------------------------------------------------------
function ns:InitFilters()
    -- Re-filter whenever the browse list data changes
    local f = CreateFrame("Frame")
    f:RegisterEvent("LFG_UPDATE")
    f:SetScript("OnEvent", function()
        -- Small delay so Blizzard can finish populating the list
        C_Timer.After(0.05, function() ns:RefreshFilters() end)
    end)

    -- Hook the Blizzard list update function so we post-process after
    -- each scroll / data refresh
    if LFGBrowseFrameList_Update then
        hooksecurefunc("LFGBrowseFrameList_Update", function()
            ns:ApplyBrowseFilter()
        end)
    end

    -- Hook scroll events on the browse scroll frame
    if LFGBrowseFrameListScrollFrame then
        LFGBrowseFrameListScrollFrame:HookScript("OnVerticalScroll", function()
            C_Timer.After(0.01, function() ns:ApplyBrowseFilter() end)
        end)
    end

    self:RebuildFilteredResults()
end

----------------------------------------------------------------------
-- Post-process the browse list buttons: hide filtered-out entries,
-- compact remaining entries upward so there are no gaps.
----------------------------------------------------------------------
function ns:ApplyBrowseFilter()
    local db = self.db
    if not db then return end
    local active = db.roleFilterEnabled or db.specFilterEnabled or db.compFilterEnabled
    if not active then return end

    -- Collect visible browse buttons (LFGBrowseFrameListButton1..N)
    local visible, hidden = {}, {}
    for i = 1, 20 do
        local btn = _G["LFGBrowseFrameListButton" .. i]
        if not btn then break end
        if btn:IsShown() then
            local idx = btn.index or btn:GetID() or i
            if idx > 0 and not self:ShouldShowResult(idx) then
                hidden[#hidden + 1] = btn
            else
                visible[#visible + 1] = btn
            end
        end
    end

    for _, btn in ipairs(hidden) do btn:Hide() end

    -- Re-anchor visible buttons to fill gaps
    if #visible > 0 and #hidden > 0 then
        for i = 2, #visible do
            visible[i]:ClearAllPoints()
            visible[i]:SetPoint("TOPLEFT",  visible[i-1], "BOTTOMLEFT",  0, -1)
            visible[i]:SetPoint("TOPRIGHT", visible[i-1], "BOTTOMRIGHT", 0, -1)
        end
    end
end

----------------------------------------------------------------------
-- Update the count text in the embedded filter area
----------------------------------------------------------------------
function ns:UpdateCountText()
    if not ns._countText then return end
    local total = ns.totalRawResults or 0
    local shown = #ns.filteredIndices
    if total == 0 then
        ns._countText:SetText("")
    elseif shown == total then
        ns._countText:SetText("|cff999999" .. total .. " results|r")
    else
        ns._countText:SetText(string.format("|cffffcc00%d|r|cff999999 / %d results|r", shown, total))
    end
end
