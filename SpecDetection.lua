----------------------------------------------------------------------
-- LFG+ Spec Detection
-- Determines player role and spec from class + LFG comment text.
--
-- Philosophy (matching user requirement):
--   "Only filter away people that are DEFINITELY NOT the given spec."
--   Unknown / ambiguous results always pass through filters.
----------------------------------------------------------------------
local _, ns = ...

----------------------------------------------------------------------
-- TBC class → spec data
-- Each spec entry: { name, role ("TANK"|"HEALER"|"DPS"), keywords }
-- Keywords are matched case-insensitively against the comment text.
----------------------------------------------------------------------
ns.CLASS_SPECS = {
    WARRIOR = {
        { name = "Arms",       role = "DPS",  keywords = { "arms" } },
        { name = "Fury",       role = "DPS",  keywords = { "fury" } },
        { name = "Protection", role = "TANK", keywords = { "prot", "protection", "tank" } },
    },
    PALADIN = {
        { name = "Holy",       role = "HEALER", keywords = { "holy", "hpal", "hpala" } },
        { name = "Protection", role = "TANK",   keywords = { "prot", "protection", "tankadin", "tank" } },
        { name = "Retribution", role = "DPS",   keywords = { "ret", "retri", "retribution" } },
    },
    HUNTER = {
        { name = "Beast Mastery",  role = "DPS", keywords = { "bm", "beast" } },
        { name = "Marksmanship",   role = "DPS", keywords = { "mm", "marks", "marksman" } },
        { name = "Survival",       role = "DPS", keywords = { "surv", "survival" } },
    },
    ROGUE = {
        { name = "Assassination", role = "DPS", keywords = { "assa", "assassination", "mut", "mutilate" } },
        { name = "Combat",        role = "DPS", keywords = { "combat", "swords", "cbt" } },
        { name = "Subtlety",      role = "DPS", keywords = { "sub", "subtlety" } },
    },
    PRIEST = {
        { name = "Discipline", role = "HEALER", keywords = { "disc", "discipline" } },
        { name = "Holy",       role = "HEALER", keywords = { "holy", "hpriest" } },
        { name = "Shadow",     role = "DPS",    keywords = { "shadow", "spriest", "sp" } },
    },
    SHAMAN = {
        { name = "Elemental",    role = "DPS",    keywords = { "ele", "elemental" } },
        { name = "Enhancement",  role = "DPS",    keywords = { "enh", "enhance", "enhancement" } },
        { name = "Restoration",  role = "HEALER", keywords = { "resto", "restoration", "rsham" } },
    },
    MAGE = {
        { name = "Arcane", role = "DPS", keywords = { "arcane" } },
        { name = "Fire",   role = "DPS", keywords = { "fire" } },
        { name = "Frost",  role = "DPS", keywords = { "frost" } },
    },
    WARLOCK = {
        { name = "Affliction",  role = "DPS", keywords = { "aff", "affliction", "dots" } },
        { name = "Demonology",  role = "DPS", keywords = { "demo", "demonology" } },
        { name = "Destruction", role = "DPS", keywords = { "destro", "destruction" } },
    },
    DRUID = {
        { name = "Balance",       role = "DPS",    keywords = { "balance", "boomkin", "boomy", "moonkin", "owl", "laser", "boom", "oomkin" } },
        { name = "Feral (Bear)",  role = "TANK",   keywords = { "bear", "feral tank", "guardian" } },
        { name = "Feral (Cat)",   role = "DPS",    keywords = { "cat", "feral dps", "feral cat" } },
        { name = "Restoration",   role = "HEALER", keywords = { "resto", "restoration", "tree", "rdru" } },
    },
}

----------------------------------------------------------------------
-- Classes that can ONLY be DPS (no role ambiguity)
----------------------------------------------------------------------
ns.PURE_DPS_CLASSES = {
    HUNTER  = true,
    ROGUE   = true,
    MAGE    = true,
    WARLOCK = true,
}

----------------------------------------------------------------------
-- Possible roles per class (used when no spec detected)
----------------------------------------------------------------------
ns.CLASS_ROLES = {
    WARRIOR = { TANK = true, DPS = true },
    PALADIN = { TANK = true, HEALER = true, DPS = true },
    HUNTER  = { DPS = true },
    ROGUE   = { DPS = true },
    PRIEST  = { HEALER = true, DPS = true },
    SHAMAN  = { HEALER = true, DPS = true },
    MAGE    = { DPS = true },
    WARLOCK = { DPS = true },
    DRUID   = { TANK = true, HEALER = true, DPS = true },
}

----------------------------------------------------------------------
-- Build reverse lookup: localized class name → classFile
-- Works with WoW's LOCALIZED_CLASS_NAMES_MALE global (when available)
----------------------------------------------------------------------
ns.CLASS_FROM_LOCALIZED = {}

function ns:BuildClassLookup()
    -- WoW global table: LOCALIZED_CLASS_NAMES_MALE["WARRIOR"] = "Warrior" (en)
    if LOCALIZED_CLASS_NAMES_MALE then
        for classFile, localizedName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            self.CLASS_FROM_LOCALIZED[localizedName] = classFile
            self.CLASS_FROM_LOCALIZED[localizedName:upper()] = classFile
            self.CLASS_FROM_LOCALIZED[localizedName:lower()] = classFile
        end
    end

    -- Hardcoded English fallbacks (always available)
    local english = {
        Warrior = "WARRIOR", Paladin = "PALADIN", Hunter = "HUNTER",
        Rogue = "ROGUE", Priest = "PRIEST", Shaman = "SHAMAN",
        Mage = "MAGE", Warlock = "WARLOCK", Druid = "DRUID",
    }
    for name, file in pairs(english) do
        self.CLASS_FROM_LOCALIZED[name]            = file
        self.CLASS_FROM_LOCALIZED[name:upper()]    = file
        self.CLASS_FROM_LOCALIZED[name:lower()]    = file
    end
end

----------------------------------------------------------------------
-- Resolve a class identifier (localized name or classFile) to classFile
----------------------------------------------------------------------
function ns:ResolveClassFile(classInput)
    if not classInput or classInput == "" then return nil end
    -- Already uppercase classFile?
    if self.CLASS_SPECS[classInput:upper()] then
        return classInput:upper()
    end
    return self.CLASS_FROM_LOCALIZED[classInput]
        or self.CLASS_FROM_LOCALIZED[classInput:lower()]
        or nil
end

----------------------------------------------------------------------
-- Detect spec and role from class + comment
--
-- Returns: {
--   roles      = { TANK = bool, HEALER = bool, DPS = bool },
--   specs      = { ["specName"] = true, ... },
--   confidence = "high" | "medium" | "low" | "none"
-- }
--
-- confidence = "none" means we couldn't determine anything;
-- the entry should PASS through inclusive filters.
----------------------------------------------------------------------
function ns:DetectSpecRole(classInput, comment)
    local result = {
        roles      = { TANK = false, HEALER = false, DPS = false },
        specs      = {},
        confidence = "none",
    }

    local classFile = self:ResolveClassFile(classInput)
    if not classFile then return result end

    local classSpecs = self.CLASS_SPECS[classFile]
    if not classSpecs then return result end

    -- Pure DPS classes: always DPS, try to narrow spec from comment
    if self.PURE_DPS_CLASSES[classFile] then
        result.roles.DPS = true
        result.confidence = "high" -- role is certain even without comment
        if comment and comment ~= "" then
            local lower = comment:lower()
            for _, spec in ipairs(classSpecs) do
                for _, kw in ipairs(spec.keywords) do
                    if lower:find(kw, 1, true) then
                        result.specs[spec.name] = true
                        break
                    end
                end
            end
        end
        -- If no specific spec found, all are possible
        if not next(result.specs) then
            for _, spec in ipairs(classSpecs) do
                result.specs[spec.name] = true
            end
        end
        return result
    end

    -- Hybrid class: try to detect from comment
    if comment and comment ~= "" then
        local lower = comment:lower()
        local matched = {}

        -- Multi-word keywords first (longer matches take priority)
        local sortedSpecs = {}
        for _, spec in ipairs(classSpecs) do
            for _, kw in ipairs(spec.keywords) do
                sortedSpecs[#sortedSpecs + 1] = { spec = spec, kw = kw }
            end
        end
        table.sort(sortedSpecs, function(a, b) return #a.kw > #b.kw end)

        for _, entry in ipairs(sortedSpecs) do
            if lower:find(entry.kw, 1, true) then
                matched[entry.spec.name] = entry.spec
            end
        end

        -- Special handling: bare "feral" for Druids (ambiguous tank/dps)
        if classFile == "DRUID" and lower:find("feral", 1, true)
            and not matched["Feral (Bear)"] and not matched["Feral (Cat)"] then
            matched["Feral (Bear)"] = { name = "Feral (Bear)", role = "TANK" }
            matched["Feral (Cat)"]  = { name = "Feral (Cat)",  role = "DPS" }
        end

        -- Special handling: bare "heal" / "healer" for hybrid classes
        if lower:find("heal") and not next(matched) then
            for _, spec in ipairs(classSpecs) do
                if spec.role == "HEALER" then
                    matched[spec.name] = spec
                end
            end
        end

        -- Special handling: bare "tank" for hybrid classes
        if lower:find("tank") and not next(matched) then
            for _, spec in ipairs(classSpecs) do
                if spec.role == "TANK" then
                    matched[spec.name] = spec
                end
            end
        end

        -- Special handling: bare "dps" for hybrid classes
        if lower:find("dps") and not next(matched) then
            for _, spec in ipairs(classSpecs) do
                if spec.role == "DPS" then
                    matched[spec.name] = spec
                end
            end
        end

        if next(matched) then
            for specName, spec in pairs(matched) do
                result.roles[spec.role] = true
                result.specs[specName] = true
            end
            local count = 0
            for _ in pairs(matched) do count = count + 1 end
            result.confidence = count == 1 and "high" or "medium"
            return result
        end
    end

    -- No comment or nothing detected → mark ALL possible roles/specs
    local classRoles = self.CLASS_ROLES[classFile] or {}
    for role, val in pairs(classRoles) do
        result.roles[role] = val
    end
    for _, spec in ipairs(classSpecs) do
        result.specs[spec.name] = true
    end
    result.confidence = "none"
    return result
end

----------------------------------------------------------------------
-- Detect what a GROUP listing is looking for / already has
-- Parses "LF1M tank", "need healer", "have tank and healer", etc.
--
-- Returns: {
--   lookingFor = { TANK = bool, HEALER = bool, DPS = bool },
--   has        = { TANK = bool, HEALER = bool, DPS = bool },
--   confidence = "high" | "low" | "none"
-- }
----------------------------------------------------------------------
local ROLE_KEYWORDS = {
    TANK   = { "tank", "prot", "bear", "mt", "ot" },
    HEALER = { "heal", "healer", "resto", "holy", "disc" },
    DPS    = { "dps", "damage", "dd" },
}

local function MatchesAnyRole(text)
    local found = {}
    for role, keywords in pairs(ROLE_KEYWORDS) do
        for _, kw in ipairs(keywords) do
            if text:find(kw, 1, true) then
                found[role] = true
                break
            end
        end
    end
    return found
end

function ns:DetectGroupNeeds(comment)
    local result = {
        lookingFor = { TANK = false, HEALER = false, DPS = false },
        has        = { TANK = false, HEALER = false, DPS = false },
        confidence = "none",
    }
    if not comment or comment == "" then return result end

    local lower = comment:lower()

    -- "Looking for" patterns
    local lfPatterns = {
        "lf%d*m?%s+(.+)",           -- "lf1m tank and healer"
        "looking%s+for%s+(.+)",      -- "looking for tank"
        "need%s+(.+)",               -- "need healer"
        "searching%s+for%s+(.+)",    -- "searching for dps"
        "seeking%s+(.+)",            -- "seeking tank"
    }
    for _, pattern in ipairs(lfPatterns) do
        local capture = lower:match(pattern)
        if capture then
            local roles = MatchesAnyRole(capture)
            for role in pairs(roles) do
                result.lookingFor[role] = true
            end
        end
    end

    -- "Have / got" patterns
    local havePatterns = {
        "have%s+(.+)",
        "got%s+(.+)",
        "with%s+(.+)",
        "(.+)%s+ready",
    }
    for _, pattern in ipairs(havePatterns) do
        local capture = lower:match(pattern)
        if capture then
            local roles = MatchesAnyRole(capture)
            for role in pairs(roles) do
                result.has[role] = true
            end
        end
    end

    -- Group composition from shorthand: "3/5", "4/5" etc.
    local current, total = lower:match("(%d+)/(%d+)")
    if current and total then
        result.has._memberCount = tonumber(current)
        result.has._totalSlots  = tonumber(total)
    end

    -- Determine confidence
    local foundAnything = false
    for _, role in pairs(result.lookingFor) do
        if role then foundAnything = true; break end
    end
    if not foundAnything then
        for _, role in pairs(result.has) do
            if type(role) == "boolean" and role then foundAnything = true; break end
        end
    end
    result.confidence = foundAnything and "high" or "none"

    return result
end

----------------------------------------------------------------------
-- Build class lookup on file load
----------------------------------------------------------------------
ns:BuildClassLookup()
