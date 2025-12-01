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

local function WrapHandler(eventName, handlerFn)
    return function(...)
        if CCS.EventStatsEnabled then
            local now = debugprofilestop()
            local stats = CCS.EventStats[eventName]
            if not stats then
                stats = {count=0, lastTime=nil, avgInterval=nil, minInterval=nil, maxInterval=nil}
                CCS.EventStats[eventName] = stats
            end
            stats.count = stats.count + 1
            if stats.lastTime then
                local interval = now - stats.lastTime
                if stats.avgInterval then
                    stats.avgInterval = ((stats.avgInterval * (stats.count-1)) + interval) / stats.count
                else
                    stats.avgInterval = interval
                end
                stats.minInterval = not stats.minInterval and interval or math.min(stats.minInterval, interval)
                stats.maxInterval = not stats.maxInterval and interval or math.max(stats.maxInterval, interval)
            end
            stats.lastTime = now
        end
        return handlerFn(...)
    end
end

function CCS:PrintEventStats()
    print("=== CCS Event Stats ===")
    for eventName, stats in pairs(CCS.EventStats) do
        print(string.format(
            "Event: %s | Count=%d | AvgInt=%.2fms | MinInt=%.2fms | MaxInt=%.2fms",
            eventName,
            stats.count,
            stats.avgInterval or 0,
            stats.minInterval or 0,
            stats.maxInterval or 0
        ))

        -- Handler-level breakdown
        if stats.handlers then
            for hkey, hstats in pairs(stats.handlers) do
                print(string.format(
                    "   Handler: %s | Count=%d | AvgInt=%.2fms | MinInt=%.2fms | MaxInt=%.2fms",
                    hkey,
                    hstats.count,
                    hstats.avgInterval or 0,
                    hstats.minInterval or 0,
                    hstats.maxInterval or 0
                ))
            end
        end
    end
    print("=== End Stats ===")
end

--------------------------------------------------------
-- EVENT HANDLER MAPPING (version-aware declarations)
--------------------------------------------------------
local eventHandlers = {
    -- Blizzard events
    ["ACTIVE_TALENT_GROUP_CHANGED"] = {
        { fn = WrapHandler("ACTIVE_TALENT_GROUP_CHANGED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["ACTIVE_PLAYER_SPECIALIZATION_CHANGED"] = {
        { fn = WrapHandler("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
    },

    ["ADDON_LOADED"] = WrapHandler("ADDON_LOADED", function(event, loadedAddon)
        if loadedAddon ~= addonName then return end
        CCS:InitSavedVariables()
        CCS:LoadOptions()
    end),

    ["AVOIDANCE_UPDATE"] = {
        { fn = WrapHandler("AVOIDANCE_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["ITEM_PUSH"] = {
        { fn = WrapHandler("ITEM_PUSH", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["BOSS_KILL"] = {
        { fn = WrapHandler("BOSS_KILL", CCS.RaidProgressEventHandler), versions = { CCS.RETAIL } },
    },

    ["CHALLENGE_MODE_COMPLETED"] = {
        { fn = WrapHandler("CHALLENGE_MODE_COMPLETED", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["CHALLENGE_MODE_MAPS_UPDATE"] = {
        { fn = WrapHandler("CHALLENGE_MODE_MAPS_UPDATE", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["CHARACTER_ITEM_FIXUP_NOTIFICATION"] = {
        { fn = WrapHandler("CHARACTER_ITEM_FIXUP_NOTIFICATION", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["CHARACTER_POINTS_CHANGED"] = {
        { fn = WrapHandler("CHARACTER_POINTS_CHANGED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["COMBAT_RATING_UPDATE"] = {
        { fn = WrapHandler("COMBAT_RATING_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["GOSSIP_CLOSED"] = {
        { fn = WrapHandler("GOSSIP_CLOSED", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["INSPECT_READY"] = {
        { fn = WrapHandler("INSPECT_READY", CCS.InspectSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("INSPECT_READY", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
    },

    ["INSTANCE_ENCOUNTER_OBJECTIVE_UPDATE"] = {
        { fn = WrapHandler("INSTANCE_ENCOUNTER_OBJECTIVE_UPDATE", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["ITEM_CHANGED"] = {
        { fn = WrapHandler("ITEM_CHANGED", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["LIFESTEAL_UPDATE"] = {
        { fn = WrapHandler("LIFESTEAL_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["LOOT_READY"] = {
        { fn = WrapHandler("LOOT_READY", CCS.RaidProgressEventHandler), versions = { CCS.RETAIL } },
    },

    ["MASTERY_UPDATE"] = {
        { fn = WrapHandler("MASTERY_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["MYTHIC_PLUS_CURRENT_AFFIX_UPDATE"] = {
        { fn = WrapHandler("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["MYTHIC_PLUS_NEW_WEEKLY_RECORD"] = {
        { fn = WrapHandler("MYTHIC_PLUS_NEW_WEEKLY_RECORD", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_AVG_ITEM_LEVEL_UPDATE"] = {
        { fn = WrapHandler("PLAYER_AVG_ITEM_LEVEL_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_ENTERING_WORLD"] = {
        { fn = WrapHandler("PLAYER_ENTERING_WORLD", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("PLAYER_ENTERING_WORLD", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
        { fn = WrapHandler("PLAYER_ENTERING_WORLD", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("PLAYER_ENTERING_WORLD", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_EQUIPMENT_CHANGED"] = {
        { fn = WrapHandler("PLAYER_EQUIPMENT_CHANGED", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("PLAYER_EQUIPMENT_CHANGED", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
        { fn = WrapHandler("PLAYER_EQUIPMENT_CHANGED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_LEAVE_COMBAT"] = {
        --{ fn = WrapHandler("PLAYER_LEAVE_COMBAT", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("PLAYER_LEAVE_COMBAT", CCS.RaidProgressEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_LEVEL_UP"] = {
        { fn = WrapHandler("PLAYER_LEVEL_UP", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("PLAYER_LEVEL_UP", CCS.RaidProgressEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_LOGIN"] = WrapHandler("PLAYER_LOGIN", function()
        for _, def in ipairs(ns.optionDefs or {}) do
            if def.key then
                CCS:UpdateOption(def, CCS.CurrentProfile[def.key])
            end
        end
        CCS:Initialize()
        CCS:LoadBlizzardAddOns()
        C_Timer.After(0.1, function()
            CCS:PrimeFontsAndTextures()
            CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
            CCS.textoutline = "OUTLINE"
        end)
        CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
        CCS.textoutline = CCS:GetOptionValue("textoutline") or ""
        for _, module in pairs(CCS.Modules) do
            if type(module.Initialize) == "function" then
                C_Timer.After(0.1, function() module:Initialize() end)
            end
        end
    end),

    ["PLAYER_LOOT_SPEC_UPDATED"] = {
        { fn = WrapHandler("PLAYER_LOOT_SPEC_UPDATED", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_REGEN_ENABLED"] = WrapHandler("PLAYER_REGEN_ENABLED", function()
        if CCS.incombat == true then
            for _, module in pairs(CCS.Modules) do
                if type(module.Initialize) == "function" then
                   -- module:Initialize()
                end
            end
            CCS:FireEvent("CCS_EVENT_OPTIONS")
            CCS.incombat = false
        end
    end),

    ["PLAYER_REGEN_DISABLED"] = WrapHandler("PLAYER_REGEN_DISABLED", function()
        local optionsFrame = _G["CCS_Options"]
        if optionsFrame and optionsFrame:IsShown() then
            optionsFrame:Hide()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
    end),

    ["PLAYER_SPECIALIZATION_CHANGED"] = {
        { fn = WrapHandler("PLAYER_SPECIALIZATION_CHANGED", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_STARTED_LOOKING"] = {
        { fn = WrapHandler("PLAYER_STARTED_LOOKING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["PLAYER_STARTED_MOVING"] = {
        { fn = WrapHandler("PLAYER_STARTED_MOVING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["PLAYER_STARTED_TURNING"] = {
        { fn = WrapHandler("PLAYER_STARTED_TURNING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_LOOKING"] = {
        { fn = WrapHandler("PLAYER_STOPPED_LOOKING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_MOVING"] = {
        { fn = WrapHandler("PLAYER_STOPPED_MOVING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["PLAYER_STOPPED_TURNING"] = {
        { fn = WrapHandler("PLAYER_STOPPED_TURNING", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["PLAYER_TALENT_UPDATE"] = {
        { fn = WrapHandler("PLAYER_TALENT_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["QUEST_ACCEPTED"] = {
        { fn = WrapHandler("QUEST_ACCEPTED", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
    },

    ["SPEED_UPDATE"] = {
        { fn = WrapHandler("SPEED_UPDATE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["TRAIT_CONFIG_UPDATED"] = {
        { fn = WrapHandler("TRAIT_CONFIG_UPDATED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["SPELL_POWER_CHANGED"] = {
        { fn = WrapHandler("SPELL_POWER_CHANGED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["UNIT_ATTACK"] = {
        { fn = WrapHandler("UNIT_ATTACK", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_ATTACK_POWER"] = {
        { fn = WrapHandler("UNIT_ATTACK_POWER", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_ATTACK_SPEED"] = {
        { fn = WrapHandler("UNIT_ATTACK_SPEED", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_DAMAGE"] = {
        { fn = WrapHandler("UNIT_DAMAGE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_LEVEL"] = {
        { fn = WrapHandler("UNIT_LEVEL", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_MAXHEALTH"] = {
        { fn = WrapHandler("UNIT_MAXHEALTH", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_MAXPOWER"] = {
        { fn = WrapHandler("UNIT_MAXPOWER", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_RANGED_ATTACK_POWER"] = {
        { fn = WrapHandler("UNIT_RANGED_ATTACK_POWER", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_RANGEDDAMAGE"] = {
        { fn = WrapHandler("UNIT_RANGEDDAMAGE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_SPELL_HASTE"] = {
        { fn = WrapHandler("UNIT_SPELL_HASTE", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["UNIT_STATS"] = {
        { fn = WrapHandler("UNIT_STATS", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },

    ["UPDATE_INVENTORY_DURABILITY"] = {
        { fn = WrapHandler("UPDATE_INVENTORY_DURABILITY", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("UPDATE_INVENTORY_DURABILITY", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
    },

    ["WEEKLY_REWARDS_ITEM_CHANGED"] = {
        { fn = WrapHandler("WEEKLY_REWARDS_ITEM_CHANGED", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },
    ["WEEKLY_REWARDS_UPDATE"] = {
        { fn = WrapHandler("WEEKLY_REWARDS_UPDATE", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
    },

    -- Custom events (manually fired)
    ["CCS_EVENT_CSHOW"] = {
        { fn = WrapHandler("CCS_EVENT_CSHOW", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("CCS_EVENT_CSHOW", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
    },

    ["CCS_STATS"] = {
        { fn = WrapHandler("CCS_STATS", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
    },
    ["CCS_EVENT_OPTIONS"] = {
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.CharacterSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.MOPCharacterSheetEventHandler), versions = { CCS.MOP } },
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.InspectSheetEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.RaidProgressEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.MythicPlusEventHandler), versions = { CCS.RETAIL } },
        { fn = WrapHandler("CCS_EVENT_OPTIONS", CCS.CharacterStatsEventHandler), versions = { CCS.RETAIL } },
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