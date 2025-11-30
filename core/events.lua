-- Centralized event handling
local addonName, ns = ...
local CCS = ns.CCS
local option = function(key) return CCS:GetOptionValue(key) end
local L = ns.L  -- grab the localization table

-- Create event frame
CCS.EventsFrame = CCS.EventsFrame or CreateFrame("Frame")
CCS.RegisteredEvents = CCS.RegisteredEvents or {}

--------------------------------------------------------
-- Register event handler (supports multiple listeners, version-aware)
--------------------------------------------------------
function CCS:RegisterEvent(event, func, isBlizzardEvent, versions)
    self.RegisteredEvents[event] = self.RegisteredEvents[event] or {}

    -- Version-gated wrapper (unchanged)
    local handler
    if versions and #versions > 0 then
        handler = function(ev, ...)
            local current = CCS.GetCurrentVersion()
            for _, v in ipairs(versions) do
                if v == current then
                    return func(ev, ...)
                end
            end
            -- silently skip
        end
    else
        handler = func
    end

    table.insert(self.RegisteredEvents[event], handler)

    -- Only register with Blizzard if the event exists for the current version
    if isBlizzardEvent then
        local shouldRegister = true
        if versions and #versions > 0 then
            shouldRegister = false
            local current = CCS.GetCurrentVersion()
            for _, v in ipairs(versions) do
                if v == current then
                    shouldRegister = true
                    break
                end
            end
        end

        if shouldRegister then
            self.EventsFrame:RegisterEvent(event)
        end
    end
end

--------------------------------------------------------
-- Dispatch Blizzard events
--------------------------------------------------------
CCS.EventsFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = CCS.RegisteredEvents[event]
    if handlers then
        for _, fn in ipairs(handlers) do
            fn(event, ...)
        end
    end
end)

--------------------------------------------------------
-- Fire a custom event manually
--------------------------------------------------------
function CCS:FireEvent(event, ...)
    local handlers = self.RegisteredEvents[event]
    if handlers then
        for _, fn in ipairs(handlers) do
            fn(event, ...)
        end
    end
end

--------------------------------------------------------
-- EVENT HANDLER MAPPING (version-aware declarations)
--------------------------------------------------------
local eventHandlers = {
    -- Blizzard events
    ["ACTIVE_TALENT_GROUP_CHANGED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    
    ["ACTIVE_PLAYER_SPECIALIZATION_CHANGED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
    },

    ["ADDON_LOADED"] = function(event, loadedAddon)
        if loadedAddon ~= addonName then return end
        CCS:InitSavedVariables()
        CCS:LoadOptions()
    end,

    ["AVOIDANCE_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["BAG_UPDATE"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["BOSS_KILL"] = {
        { fn = CCS.RaidProgressEventHandler, versions = { CCS.RETAIL } },
    },

    ["CHALLENGE_MODE_COMPLETED"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["CHALLENGE_MODE_MAPS_UPDATE"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["CHARACTER_ITEM_FIXUP_NOTIFICATION"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["CHARACTER_POINTS_CHANGED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["COMBAT_RATING_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["GOSSIP_CLOSED"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["INSPECT_READY"] = {
        { fn = CCS.InspectSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },

    },

    ["INSTANCE_ENCOUNTER_OBJECTIVE_UPDATE"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["ITEM_CHANGED"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["LIFESTEAL_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["LOOT_READY"] = {
        { fn = CCS.RaidProgressEventHandler, versions = { CCS.RETAIL } },
    },

    ["MASTERY_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["MYTHIC_PLUS_CURRENT_AFFIX_UPDATE"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["MYTHIC_PLUS_NEW_WEEKLY_RECORD"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_AVG_ITEM_LEVEL_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_ENTERING_WORLD"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_EQUIPMENT_CHANGED"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_LEAVE_COMBAT"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.RaidProgressEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_LEVEL_UP"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.RaidProgressEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_LOGIN"] = function()
        -- Apply saved options
        for _, def in ipairs(ns.optionDefs or {}) do
            if def.key then
                CCS:UpdateOption(def, CCS.CurrentProfile[def.key])
            end
        end

        -- Core initialization
        CCS:Initialize()
        CCS:LoadBlizzardAddOns()

        C_Timer.After(0.1, function()
            CCS:PrimeFontsAndTextures()
            CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
            CCS.textoutline = "OUTLINE"
        end)

        CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
        CCS.textoutline = CCS:GetOptionValue("textoutline") or ""

        -- Delayed Initialize all registered modules automatically
        for _, module in pairs(CCS.Modules) do
            if type(module.Initialize) == "function" then
                C_Timer.After(0.15, function() module:Initialize() end)
            end
        end
    end,

    ["PLAYER_LOOT_SPEC_UPDATED"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_REGEN_ENABLED"] = function()
        if CCS.incombat == true then
            for _, module in pairs(CCS.Modules) do
                if type(module.Initialize) == "function" then
                    module:Initialize()
                end
            end
            CCS:FireEvent("CCS_EVENT_OPTIONS")
            CCS.incombat = false
        end
    end,

    ["PLAYER_REGEN_DISABLED"] = function()
        local optionsFrame = _G["CCS_Options"]
        if optionsFrame and optionsFrame:IsShown() then
            optionsFrame:Hide()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
    end,

    ["PLAYER_SPECIALIZATION_CHANGED"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_STARTED_LOOKING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["PLAYER_STARTED_MOVING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["PLAYER_STARTED_TURNING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_LOOKING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_MOVING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_TURNING"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["PLAYER_TALENT_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["QUEST_ACCEPTED"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
    },

    ["SPEED_UPDATE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["TRAIT_CONFIG_UPDATED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["SPELL_POWER_CHANGED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["UNIT_ATTACK"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_ATTACK_POWER"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_ATTACK_SPEED"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_DAMAGE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_LEVEL"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_MAXHEALTH"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_MAXPOWER"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_RANGED_ATTACK_POWER"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_RANGEDDAMAGE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_SPELL_HASTE"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["UNIT_STATS"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },

    ["UPDATE_INVENTORY_DURABILITY"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },
    },

    ["WEEKLY_REWARDS_ITEM_CHANGED"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },
    ["WEEKLY_REWARDS_UPDATE"] = {
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
    },

    -- Custom events (manually fired)
    ["CCS_EVENT_CSHOW"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },
    },

    ["CCS_STATS"] = {
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
    ["CCS_EVENT_OPTIONS"] = {
        { fn = CCS.CharacterSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MOPCharacterSheetEventHandler, versions = { CCS.MOP } },
        { fn = CCS.InspectSheetEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.RaidProgressEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.MythicPlusEventHandler, versions = { CCS.RETAIL } },
        { fn = CCS.CharacterStatsEventHandler, versions = { CCS.RETAIL } },
    },
}

--------------------------------------------------------
-- REGISTER ALL EVENTS DIRECTLY (Blizzard only)
--------------------------------------------------------
for event, handlers in pairs(eventHandlers) do
    if event ~= "CCS_EVENT_CSHOW" and event ~= "CCS_STATS" and event ~= "CCS_EVENT_OPTIONS" then
        if type(handlers) == "function" then
            CCS:RegisterEvent(event, handlers, true)
        else
            for _, h in ipairs(handlers) do
                CCS:RegisterEvent(event, h.fn, true, h.versions)
            end
        end
    else
        -- Custom events: just store in RegisteredEvents
        CCS.RegisteredEvents[event] = {}
        if type(handlers) == "function" then
            table.insert(CCS.RegisteredEvents[event], handlers)
        else
            for _, h in ipairs(handlers) do
                CCS:RegisterEvent(event, h.fn, false, h.versions)
            end
        end
    end
end