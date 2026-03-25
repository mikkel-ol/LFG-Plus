----------------------------------------------------------------------
-- LFG+ Filters
-- Evaluates whether LFG results should be shown based on active
-- filter settings.  Implements inclusive filtering: entries whose
-- role/spec/composition CANNOT be determined always pass through.
----------------------------------------------------------------------
local _, ns = ...

----------------------------------------------------------------------
-- Cached filtered results (indices into the raw result list)
----------------------------------------------------------------------
ns.filteredIndices = {}
ns.totalRawResults = 0

----------------------------------------------------------------------
-- LFG API abstraction
-- TBC Classic has several possible API shapes; abstract them here.
----------------------------------------------------------------------
function ns:GetNumResults()
    if SearchLFGGetNumResults then
        return SearchLFGGetNumResults()
    elseif GetNumLFGResults then
        return GetNumLFGResults()
    end
    return 0
end

--- Returns: name, level, areaName, className, comment, nMembers, isLFM
--- Additional return values vary by client version.
function ns:GetResultInfo(index)
    local apiFunc = SearchLFGGetResults or GetLFGResults
    if apiFunc then
        return apiFunc(index)
    end
    return nil
end

----------------------------------------------------------------------
-- Evaluate a SINGLE result against active filters
-- Returns true if the result should be shown, false to hide.
----------------------------------------------------------------------
function ns:ShouldShowResult(index)
    local name, level, areaName, className, comment, nMembers, isLFM = self:GetResultInfo(index)
    if not name then return true end -- safety: show if data missing

    local db = self.db
    if not db then return true end

    local classFile = self:ResolveClassFile(className)
    local detection = self:DetectSpecRole(classFile, comment)

    -- ----------------------------------------------------------------
    -- Role filter
    -- ----------------------------------------------------------------
    if db.roleFilterEnabled then
        local passesRole = self:EvaluateRoleFilter(detection)
        if not passesRole then return false end
    end

    -- ----------------------------------------------------------------
    -- Spec filter
    -- ----------------------------------------------------------------
    if db.specFilterEnabled then
        local passesSpec = self:EvaluateSpecFilter(classFile, detection)
        if not passesSpec then return false end
    end

    -- ----------------------------------------------------------------
    -- Group composition filter (only for groups / LFM listings)
    -- ----------------------------------------------------------------
    if db.compFilterEnabled and (isLFM or (nMembers and nMembers > 1)) then
        local passesComp = self:EvaluateCompFilter(comment)
        if not passesComp then return false end
    end

    return true
end

----------------------------------------------------------------------
-- Role filter evaluation
-- INCLUSIVE: If the player MIGHT be the desired role → show.
--           Only hide if ALL detected roles are unchecked.
--           Unknown roles (confidence="none") always pass.
----------------------------------------------------------------------
function ns:EvaluateRoleFilter(detection)
    local db = self.db

    -- Unknown role → always pass (inclusive filtering)
    if detection.confidence == "none" then
        return true
    end

    -- Check if ANY of the player's possible roles match the filter
    for role, detected in pairs(detection.roles) do
        if detected and db.roleFilter[role] then
            return true
        end
    end

    -- Player's detected roles are all unchecked → hide
    return false
end

----------------------------------------------------------------------
-- Spec filter evaluation
-- INCLUSIVE: If a player's possible spec is checked → show.
--           Unknown spec always passes.
----------------------------------------------------------------------
function ns:EvaluateSpecFilter(classFile, detection)
    local db = self.db

    -- No class info → can't filter → pass
    if not classFile then return true end

    -- Unknown spec → always pass
    if detection.confidence == "none" then
        return true
    end

    local classSpecFilter = db.specFilter[classFile]
    if not classSpecFilter then return true end -- no filter configured

    -- Check if ANY of the player's possible specs are checked
    for specName in pairs(detection.specs) do
        if classSpecFilter[specName] then
            return true
        end
    end

    -- All detected specs are unchecked → hide
    return false
end

----------------------------------------------------------------------
-- Group composition filter evaluation
-- For group/LFM listings, checks if the group HAS or MIGHT HAVE
-- the desired composition.
-- INCLUSIVE: Unknown composition always passes.
----------------------------------------------------------------------
function ns:EvaluateCompFilter(comment)
    local db = self.db
    local needs = self:DetectGroupNeeds(comment)

    -- Unknown composition → always pass
    if needs.confidence == "none" then
        return true
    end

    -- Check each required composition element
    if db.compFilter.hasTank and not needs.has.TANK then
        -- Group doesn't state it has a tank
        -- But if we can't determine → pass (inclusive)
        if needs.confidence == "high" then
            -- Only filter out if we're confident the group listed their comp
            -- and a tank is not mentioned
            -- Hmm, this is tricky. The group might have a tank but not
            -- mention it. Let's be generous: only filter out groups that
            -- are explicitly LOOKING for a tank (meaning they don't have one).
            if needs.lookingFor.TANK then
                return false
            end
        end
    end

    if db.compFilter.hasHealer and not needs.has.HEALER then
        if needs.confidence == "high" and needs.lookingFor.HEALER then
            return false
        end
    end

    if db.compFilter.hasDPS and not needs.has.DPS then
        if needs.confidence == "high" and needs.lookingFor.DPS then
            return false
        end
    end

    return true
end

----------------------------------------------------------------------
-- Rebuild the filtered index list from scratch
----------------------------------------------------------------------
function ns:RebuildFilteredResults()
    wipe(self.filteredIndices)
    local numResults = self:GetNumResults()
    self.totalRawResults = numResults

    local anyFilterActive = self.db
        and (self.db.roleFilterEnabled or self.db.specFilterEnabled or self.db.compFilterEnabled)

    for i = 1, numResults do
        if not anyFilterActive or self:ShouldShowResult(i) then
            self.filteredIndices[#self.filteredIndices + 1] = i
        end
    end
end

----------------------------------------------------------------------
-- Refresh: rebuild filters and update display
----------------------------------------------------------------------
function ns:RefreshFilters()
    self:RebuildFilteredResults()
    if self.UpdateBrowseDisplay then
        self:UpdateBrowseDisplay()
    end
    if self.UpdateFilterCountText then
        self:UpdateFilterCountText()
    end
end

----------------------------------------------------------------------
-- Initialise filter system (called after LFG frame found)
----------------------------------------------------------------------
function ns:InitFilters(lfgFrame)
    -- Hook LFG search result events so we re-filter when new data arrives
    local filterEventFrame = CreateFrame("Frame")
    filterEventFrame:RegisterEvent("LFG_UPDATE")
    filterEventFrame:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
    -- TBC Classic might fire these:
    if C_LFGList then
        filterEventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
        filterEventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
    end
    filterEventFrame:SetScript("OnEvent", function()
        ns:RefreshFilters()
    end)

    -- Initial build
    self:RebuildFilteredResults()
end
