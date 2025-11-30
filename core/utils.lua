local addonName, ns = ...
local CCS = ns.CCS
local L = ns.L  -- grab the localization table
local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
local frame = _G["CCS_Options"] or CreateFrame("Frame", "CCS_Options", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local locale = GetLocale()
local DEBUG = false  -- set to false to silence debug prints

-- Debug print function cause I am tired of commenting and uncommenting print statements.
function CCS.dprint(...)
    if DEBUG then
        print(...)
    end
end

-- All of this tooltip code because blizzard needs to control GameTooltip and causes secret issues if a tooltip displays money... Frickin glorious...
function CCS:CreateTooltip(name)
    local tooltip = _G[name] or CreateFrame("GameTooltip", name, UIParent, "TooltipBackdropTemplate")
    tooltip:SetClampedToScreen(true)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetFrameLevel(9999)

    -- Prime font strings if not already attached
    for i = 1, 30 do
        local left = _G[name.."TextLeft"..i] or tooltip:CreateFontString(name.."TextLeft"..i, "ARTWORK", "GameTooltipText")
        local right = _G[name.."TextRight"..i] or tooltip:CreateFontString(name.."TextRight"..i, "ARTWORK", "GameTooltipText")
        tooltip:AddFontStrings(left, right)
    end

    -- Force creation and configure wrapping for internal font strings
    for i = 1, 30 do
        tooltip:AddLine(" ")
    end
    tooltip:ClearLines()

    for i = 1, 30 do
        local fs = _G[name.."TextLeft"..i]
        if fs then
            fs:SetWidth(287)
            fs:SetWordWrap(true)
        end
    end

    return tooltip
end

function CCS.RenderSafeTooltip(tooltip, link, unit)
    if not link then return end
    unit = unit or "player"

    -- Hidden parser
    local parser = _G["SafeParserTooltip"] or CreateFrame("GameTooltip", "SafeParserTooltip", nil, "GameTooltipTemplate")
    parser:SetOwner(UIParent, "ANCHOR_NONE")
    for i = 1, 30 do
        local l = _G["SafeParserTooltipTextLeft"..i] or parser:CreateFontString("SafeParserTooltipTextLeft"..i, "ARTWORK", "GameTooltipText")
        local r = _G["SafeParserTooltipTextRight"..i] or parser:CreateFontString("SafeParserTooltipTextRight"..i, "ARTWORK", "GameTooltipText")
        parser:AddFontStrings(l, r)
    end
    parser:SetHyperlink(link)

    -- Build equipped item name lookup
    local equippedItemNames = {}
    for slot = 1, 17 do
        local equippedLink = GetInventoryItemLink(unit, slot)
        if equippedLink then
            local equippedID = equippedLink:match("item:(%d+)")
            local equippedName = equippedID and C_Item.GetItemNameByID(equippedID)
            if equippedName then
                equippedItemNames[equippedName] = true
            end
        end
    end

    -- Item info
    local itemID = link:match("item:(%d+)")
    local itemName, _, _, _, _, itemType, itemSubType = GetItemInfo(itemID)
    local itemQuality = itemID and C_Item.GetItemQualityByID(itemID)
    local r, g, b = GetItemQualityColor(itemQuality or 1)

    tooltip:ClearLines()
    tooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetFrameLevel(9999)

    for i = 1, 30 do
        tooltip:AddLine(" ")
    end
    tooltip:ClearLines()

    for i = 1, 30 do
        local fs = _G[tooltip:GetName().."TextLeft"..i]
        if fs then
            fs:SetWidth(287)
            fs:SetWordWrap(true)
        end
    end

    if itemName then
        tooltip:AddLine(itemName, r, g, b)
    end

    -- Gem flavor detection (Tasty!)
    local gemTypeKeywords = {
        ["Ruby"] = { r = 1.0, g = 0.2, b = 0.2 },
        ["Garnet"] = { r = 1.0, g = 0.2, b = 0.2 },
        ["Emerald"] = { r = 0.2, g = 1.0, b = 0.2 },
        ["Peridot"] = { r = 0.2, g = 1.0, b = 0.2 },
        ["Sapphire"] = { r = 0.2, g = 0.6, b = 1.0 },
        ["Lapis"] = { r = 0.2, g = 0.6, b = 1.0 },
        ["Topaz"] = { r = 1.0, g = 0.8, b = 0.2 },
        ["Onyx"] = { r = 0.6, g = 0.2, b = 0.6 },
        ["Amethyst"] = { r = 0.6, g = 0.2, b = 0.6 },
        ["Opal"] = { r = 0.9, g = 0.9, b = 1.0 },
        ["Diamond"] = { r = 1.0, g = 1.0, b = 1.0 },
    }

    if itemType == "Gem" and itemName then
        for keyword, color in pairs(gemTypeKeywords) do
            if itemName:find("%f[%a]"..keyword.."%f[%A]") then
                tooltip:AddLine(keyword, color.r, color.g, color.b)
                break
            end
        end
    end

    -- Stat coloring
    local secondaryColor = { r = 0.0, g = 1.0, b = 0.0 }

    local strength = UnitStat("player", 1)
    local agility  = UnitStat("player", 2)
    local intellect = UnitStat("player", 4)

    local primaryStat = "Strength"
    if agility > strength and agility > intellect then
        primaryStat = "Agility"
    elseif intellect > strength and intellect > agility then
        primaryStat = "Intellect"
    end

    local armorSlots = {
        ["Head"] = true, ["Shoulder"] = true, ["Chest"] = true,
        ["Waist"] = true, ["Legs"] = true, ["Feet"] = true,
        ["Hands"] = true, ["Wrist"] = true
    }

    local weaponSlots = {
        ["Main Hand"] = true, ["Off Hand"] = true, ["Two-Hand"] = true,
        ["One-Hand"] = true, ["Ranged"] = true
    }

    local inSetBlock = false
    local lastWasSetItem = false

    for i = 1, parser:NumLines() do
        local left = _G["SafeParserTooltipTextLeft"..i]
        local text = left and left:GetText()

        if text and text:match("%S") and not text:find("|TInterface\\MoneyFrame\\UI%-GoldIcon") then
            local r, g, b = 1, 1, 1

            if text:find("^.-%(%d+/%d+%)") then
                tooltip:AddLine(" ")
                r, g, b = 1.0, 0.82, 0.0
                inSetBlock = true
                lastWasSetItem = false
            end

            if text:find("^  ") and inSetBlock then
                lastWasSetItem = true
                local trimmed = text:match("^%s*(.-)%s*$")
                if equippedItemNames[trimmed] then
                    r, g, b = 1.0, 1.0, 0.6
                else
                    r, g, b = 0.5, 0.5, 0.5
                end
            elseif inSetBlock and lastWasSetItem then
                tooltip:AddLine(" ")
                inSetBlock = false
                lastWasSetItem = false
            end

            if itemType == "Armor" and armorSlots[text] and itemSubType then
                text = itemSubType .. " " .. text
            end

            if itemType == "Weapon" and weaponSlots[text] and itemSubType then
                text = text .. " " .. itemSubType
            end

            if text:find("^Item Level") or text:find("^Upgrade Level") then
                r, g, b = 1.0, 0.82, 0.0
            end

            if text:find("Critical Strike") or text:find("Haste") or text:find("Versatility") or text:find("Mastery") then
                r, g, b = secondaryColor.r, secondaryColor.g, secondaryColor.b
            end

            if text:find("Strength") then
                r, g, b = (primaryStat == "Strength") and 1.0 or 0.5,
                          (primaryStat == "Strength") and 1.0 or 0.5,
                          (primaryStat == "Strength") and 1.0 or 0.5
            elseif text:find("Agility") then
                r, g, b = (primaryStat == "Agility") and 1.0 or 0.5,
                          (primaryStat == "Agility") and 1.0 or 0.5,
                          (primaryStat == "Agility") and 1.0 or 0.5
            elseif text:find("Intellect") then
                r, g, b = (primaryStat == "Intellect") and 1.0 or 0.5,
                          (primaryStat == "Intellect") and 1.0 or 0.5,
                          (primaryStat == "Intellect") and 1.0 or 0.5
            end

            if text:find("^Set:") then
                r, g, b = secondaryColor.r, secondaryColor.g, secondaryColor.b
            end

            if text:find("^Enchanted:") then
                text = "\n" .. text
                r, g, b = 0.4, 1.0, 1.0
            end

            if text:find("^Equip:") or text:find("^Use:") then
                r, g, b = 0.0, 1.0, 0.0
            end

            if text:find("^\"") then
                tooltip:AddLine(text, 0.8, 0.8, 0.8)
            else
                tooltip:AddLine(text, r, g, b)
            end
        end
    end

    parser:ClearLines()
    tooltip:Show()
end

-- function to determine if an item needs text facing left or right
-- Returns 1 if we want the text blocks on the right of the item
function CCS.displaytowardleft(eslot)
    if eslot == 10 or eslot == 6 or eslot == 7 or eslot == 8 or eslot == 11 or eslot == 12 or eslot == 13 or eslot == 14 or eslot == 16 then
        return true
    end
    return false
end

CCS.emptySlotTextures = {
    [1]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",
    [2]  = 136519, --"Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck", 
    [3]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder",
    [4]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",
    [5]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
    [6]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
    [7]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",
    [8]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
    [9]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",
    [10] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",
    [11] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [12] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [13] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [14] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [15] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
    [16] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
    [17] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
    [19] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",
}

function CCS.getSlotIndexName(slotIndex)
    local slotName = ""

        if slotIndex == 1 then slotName = INVTYPE_HEAD -- Head
        elseif slotIndex == 2 then slotName = INVTYPE_NECK--"Neck"
        elseif slotIndex == 3 then slotName = INVTYPE_SHOULDER--"Shoulder"
        elseif slotIndex == 4 then slotName = INVTYPE_BODY --"Shirt"    
        elseif slotIndex == 5 then slotName = INVTYPE_CHEST--"Chest"
        elseif slotIndex == 6 then slotName = INVTYPE_WAIST--"Waist"
        elseif slotIndex == 7 then slotName = INVTYPE_LEGS--"Legs"
        elseif slotIndex == 8 then slotName = INVTYPE_FEET--"Feet"
        elseif slotIndex == 9 then slotName = INVTYPE_WRIST--"Wrist"
        elseif slotIndex == 10 then slotName = INVTYPE_HAND--"Hands"
        elseif slotIndex == 11 then slotName = INVTYPE_FINGER--"Finger0"
        elseif slotIndex == 12 then slotName = INVTYPE_FINGER--"Finger1"
        elseif slotIndex == 13 then slotName = INVTYPE_TRINKET--"Trinket0"
        elseif slotIndex == 14 then slotName = INVTYPE_TRINKET--"Trinket1"
        elseif slotIndex == 15 then slotName = INVTYPE_CLOAK--"Back"
        elseif slotIndex == 16 then slotName = INVTYPE_WEAPONMAINHAND--"MainHand"
        elseif slotIndex == 17 then slotName = INVTYPE_WEAPONOFFHAND--"SecondaryHand"
        elseif slotIndex == 19 then slotName = INVTYPE_TABARD --"Tabard"
        else return ""
        end

        return slotName
end

function CCS.getSlotFrameName(slotIndex, framename)
        local slotName=""
        
        if slotIndex == 1 then slotName = "Head"
        elseif slotIndex == 2 then slotName = "Neck"
        elseif slotIndex == 3 then slotName = "Shoulder"
        elseif slotIndex == 4 then slotName = "Shirt"    
        elseif slotIndex == 5 then slotName = "Chest"
        elseif slotIndex == 6 then slotName = "Waist"
        elseif slotIndex == 7 then slotName = "Legs"
        elseif slotIndex == 8 then slotName = "Feet"
        elseif slotIndex == 9 then slotName = "Wrist"
        elseif slotIndex == 10 then slotName = "Hands"
        elseif slotIndex == 11 then slotName = "Finger0"
        elseif slotIndex == 12 then slotName = "Finger1"
        elseif slotIndex == 13 then slotName = "Trinket0"
        elseif slotIndex == 14 then slotName = "Trinket1"
        elseif slotIndex == 15 then slotName = "Back"
        elseif slotIndex == 16 then slotName = "MainHand"
        elseif slotIndex == 17 then slotName = "SecondaryHand"
        elseif slotIndex == 19 then slotName = "Tabard"
        else return nil
        end
        -- framename should be "Character", "Inspect", "CompCharacter", "CompInspect"
        return framename..slotName.."Slot"
end

function CCS.GetInspectItemLevel(unit)
    local totalIlvl, itemCount = 0, 0
    local skipSlots = {
        [4] = true,  -- Shirt
        [19] = true, -- Tabard
    }

    -- Version-aware tooltip reader
    local function GetTooltipItemLevel(unit, slot)
        if C_TooltipInfo then
            -- Retail path
            local info = C_TooltipInfo.GetInventoryItem(unit, slot)
            if not info or not info.lines then return nil end

            for _, line in ipairs(info.lines) do
                local text = line.leftText
                if text then
                    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", "")
                               :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    local ilvl = text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))
                    if ilvl then return tonumber(ilvl) end
                end
            end
        else
            -- MoP Classic path: use hidden tooltip
            CCS.ScanTooltip = CCS.ScanTooltip or CreateFrame("GameTooltip", "CCS_ScanTooltip", nil, "GameTooltipTemplate")
            local tt = CCS.ScanTooltip
            tt:SetOwner(UIParent, "ANCHOR_NONE")
            tt:SetInventoryItem(unit, slot)

            for i = 2, tt:NumLines() do
                local left = _G["CCS_ScanTooltipTextLeft"..i]
                if left then
                    local text = left:GetText()
                    if text then
                        local ilvl = text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))
                        if ilvl then return tonumber(ilvl) end
                    end
                end
            end
        end
        return nil
    end

    -- Weapon logic
    local mainIlvl = GetTooltipItemLevel(unit, 16)
    local offIlvl  = GetTooltipItemLevel(unit, 17)

    local mainLink = GetInventoryItemLink(unit, 16)
    local offLink  = GetInventoryItemLink(unit, 17)

    local _, _, mainRarity, _, _, _, _, _, mainEquipSlot = GetItemInfo(mainLink or "")
    local _, _, offRarity, _, _, _, _, _, offEquipSlot   = GetItemInfo(offLink or "")

    if not mainRarity and mainLink then
        mainRarity = select(3, GetItemInfoInstant(mainLink))
    end
    if not offRarity and offLink then
        offRarity = select(3, GetItemInfoInstant(offLink))
    end

    if mainIlvl and offIlvl and mainRarity == 6 and offRarity == 6 then
        local maxIlvl = math.max(mainIlvl, offIlvl)
        totalIlvl = totalIlvl + (maxIlvl * 2)
        itemCount = itemCount + 2
        skipSlots[16], skipSlots[17] = true, true
    elseif mainIlvl and mainEquipSlot == "INVTYPE_2HWEAPON" then
        totalIlvl = totalIlvl + (mainIlvl * 2)
        itemCount = itemCount + 2
        skipSlots[16], skipSlots[17] = true, true
    end

    -- Remaining slots
    for slot = 1, 17 do
        if not skipSlots[slot] then
            local ilvl = GetTooltipItemLevel(unit, slot)
            if ilvl then
                totalIlvl = totalIlvl + ilvl
                itemCount = itemCount + 1
            end
        end
    end

    local average = itemCount > 0 and (totalIlvl / itemCount) or 0
    return average
end

-- Tricking Blizzard into loading the fonts instead of lazy loading them.  That way they are immediately available.
function CCS:PrimeFontsAndTextures()
    if CCS.FontsPrimed then return end

    local preloadFrame = CCS.FontPreloadFrame or CreateFrame("Frame", nil, UIParent)
    CCS.FontPreloadFrame = preloadFrame
    preloadFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -2000)
    preloadFrame:SetSize(1, 1)
    preloadFrame:Show()
    
    for _, path in pairs(CCS.fonts) do
        local fs = preloadFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFont(path, 1)
        fs:SetPoint("CENTER", preloadFrame, "CENTER")
        fs:SetText(".") -- force render
        fs:Show()
    end
       -- Optional cleanup
    C_Timer.After(1, function()
        preloadFrame:Hide()
    end)

    local tex = preloadFrame:CreateTexture(nil, "ARTWORK", nil)
    tex:SetPoint("CENTER", preloadFrame, "CENTER", 0 ,0);
    tex:SetSize(1, 1)
    tex:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\lock.png")
    tex:Show()

    local tex2 = preloadFrame:CreateTexture(nil, "ARTWORK", nil)
    tex2:SetPoint("CENTER", preloadFrame, "CENTER", 0 ,0);
    tex2:SetSize(1, 1)
    tex2:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\shieldcheck.png")
    tex2:Show()
    
    local tex3 = preloadFrame:CreateTexture(nil, "ARTWORK", nil)
    tex3:SetPoint("CENTER", preloadFrame, "CENTER", 0 ,0);
    tex3:SetSize(1, 1)
    tex3:Show()
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\steelboxbg.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\rightarrow.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\rightarrow_hi.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\close.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\close-h.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\settings.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\settings-h.png")
    tex3:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\MOTHERtalenttree.BLP")    
    CCS.FontsPrimed = true
end

function CCS:LoadBlizzardAddOns()
    if self.BlizzardLoaded then return end

    local function safeLoad(addonName)
        if not C_AddOns.IsAddOnLoaded(addonName) then
            local loaded, reason = AddOnUtil.LoadAddOn(addonName)
            if not loaded then
                return false
            end
        end
        return true
    end

    -- Load required Blizzard UI addons
    local addons = {
        "Blizzard_CharacterFrame",
        "Blizzard_TokenUI",
        "Blizzard_ChallengesUI",
        "Blizzard_WeeklyRewards",
        "Blizzard_EncounterJournal"
    }

    for _, addon in ipairs(addons) do
        safeLoad(addon)
    end

    -- Initialize WeeklyRewards UI if available
    if type(WeeklyRewards_LoadUI) == "function" then
        WeeklyRewards_LoadUI()
    end
    TokenFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
    TokenFrame:SetPoint("BOTTOMRIGHT", CharacterFrameBg, "BOTTOMRIGHT", 0, 0)

    -- Safely configure WeeklyRewardsFrame
    if WeeklyRewardsFrame and WeeklyRewardsFrame.PVPFrame and WeeklyRewardsFrame.WorldFrame then
        WeeklyRewardsFrame:SetActivityShown(false, WeeklyRewardsFrame.PVPFrame, Enum.WeeklyRewardChestThresholdType.RankedPvP)
        WeeklyRewardsFrame:SetActivityShown(true, WeeklyRewardsFrame.WorldFrame, Enum.WeeklyRewardChestThresholdType.World)
        WeeklyRewardsFrame:SetUpActivity(
            WeeklyRewardsFrame.WorldFrame,
            WORLD,
            "evergreen-weeklyrewards-category-world",
            Enum.WeeklyRewardChestThresholdType.World
        )
        WeeklyRewardsFrame:FullRefresh()
    end
    if C_MythicPlus ~= nil then
        C_MythicPlus.RequestCurrentAffixes();
        C_MythicPlus.RequestMapInfo();
    end

    self.BlizzardLoaded = true
end


-- Check if an option applies for a given version (or current by default)
function CCS.IsVersion(option, flag)
    local ver = option.ver or CCS.ALL
    if ver == CCS.ALL then return true end
    return bit.band(ver, flag) ~= 0
end

local function dumpTable(t, prefix)
    prefix = prefix or ""
    for k,v in pairs(t) do
        local path = prefix .. "." .. tostring(k)
        if type(v) == "table" then
            print("[Dump] " .. path .. " = (table)")
            dumpTable(v, path)
        else
            print("[Dump] " .. path .. " = " .. tostring(v))
        end
    end
end

---------------------------
-- LibDeflate Initialization
---------------------------
--local LibDeflate = LibStub and LibStub:GetLibrary("LibDeflate")
if not LibDeflate then
    error("LibDeflate not found. Make sure LibStub and LibDeflate are loaded in your .toc before utils.lua")
end

---------------------------
-- Table Serialization
---------------------------
function CCS.SerializeTable(t)
    local function serializeValue(v)
        if type(v) == "number" then
            return tostring(v)
        elseif type(v) == "boolean" then
            return v and "true" or "false"
        elseif type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "table" then
            return CCS.SerializeTable(v)
        else
            return "nil"
        end
    end

    local result = "{"
    for k,v in pairs(t) do
        -- Debug print for every key/value being serialized
       -- print(string.format("[S] key=%s, value=%s", tostring(k), tostring(v)))
    
        local key
        if type(k) == "string" and k:match("^%a[%w_]*$") then
            key = k .. "="
        else
            key = "[" .. serializeValue(k) .. "]="
        end
        result = result .. key .. serializeValue(v) .. ","
    end
    result = result .. "}"
    return result
end


function CCS.DeserializeTable(s)
    local func, err = loadstring("return " .. s)
    if func then
        local ok, result = pcall(func)
        if ok and type(result) == "table" then
            -- Debug print for every key/value being deserialized
            for k,v in pairs(result) do
               -- print(string.format("[D] key=%s, value=%s", tostring(k), tostring(v)))
            end
            return result
        end
    end
    return nil
end

---------------------------
-- Profile Export/Import Using LibDeflate
---------------------------
function CCS.ExportProfile(profile)
    local serialized = CCS.SerializeTable(profile)
    --local serializedSize = #serialized

    local compressed = LibDeflate:CompressDeflate(serialized)
    --local compressedSize = #compressed

    local encoded = LibDeflate:EncodeForPrint(compressed)
    --local encodedSize = #encoded

    -- Calculate efficiency
    --local compressionRatio = (1 - (compressedSize / serializedSize)) * 100
    --local totalRatio = (1 - (encodedSize / serializedSize)) * 100

    return encoded
end


-- Import: Decode -> Decompress -> Deserialize
function CCS.ImportProfile(str)
    if type(str) ~= "string" then return nil, "Input is not a string" end

    local decoded = LibDeflate:DecodeForPrint(str)
    if not decoded then
        return nil, "Failed to decode string"
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "Failed to decompress string"
    end

    local tbl = CCS.DeserializeTable(decompressed)
    if not tbl then
        return nil, "Failed to deserialize table"
    end

    return tbl
end

---------------------------------
-- Deep comparison helper
---------------------------------
function CCS.deepCompare(t1, t2, path)
	path = path or ""
	if t1 == t2 then return true end
	if type(t1) ~= type(t2) then
		print(("Type mismatch at %s: %s vs %s"):format(path, type(t1), type(t2)))
		return false
	end
	if type(t1) ~= "table" then return t1 == t2 end

	for k, v in pairs(t1) do
		if not CCS.deepCompare(v, t2[k], path .. "." .. tostring(k)) then
			return false
		end
	end
	for k in pairs(t2) do
		if t1[k] == nil then
			print(("Extra key in imported at %s.%s"):format(path, tostring(k)))
			return false
		end
	end
	return true
end

---------------------------------
-- Simple hash generator
---------------------------------
function CCS.tableHash(tbl)
	if type(tbl) ~= "table" then return tostring(tbl) end
	local concat = {}
	for k, v in pairs(tbl) do
		table.insert(concat, tostring(k) .. "=" .. tableHash(v))
	end
	table.sort(concat)
	return table.concat(concat, ";")
end

---------------------------------
-- Validate profile structure
---------------------------------
function CCS.validateProfileStructure(profile)
	if type(profile) ~= "table" then
		return false, "Profile is not a table"
	end

	-- basic test structure
	local expectedKeys = {
		"show_attack_stats", "fontsize_cilvl", "fontsize_levelclass",
		"fontsize_mplus", "bgtype", "bgcolor", "round", "setitemcolor"
	}
	local hasExpected = false
	for _, key in ipairs(expectedKeys) do
		if profile[key] ~= nil then
			hasExpected = true
			break
		end
	end

	if not hasExpected then
		return false, "Missing expected settings keys (profile appears empty or malformed)"
	end

	-- Optional metadata checks
	if profile.profileName and type(profile.profileName) ~= "string" then
		return false, "profileName is invalid (should be string)"
	end
	if profile.version and type(profile.version) ~= "number" then
		return false, "version is invalid (should be number)"
	end
	return true
end


function CCS:ShowExportFrame(exportStr)

    if _G["CCS_ExportBox"] == nil then
            local f = CreateFrame("Frame", "CCS_ExportBox", UIParent, "BasicFrameTemplateWithInset")
            f:SetSize(600, 330)
            f:SetPoint("BOTTOM", _G["CCS_Options"], "BOTTOM", 0, 80 )
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
            f:SetFrameStrata("DIALOG")
            f:SetFrameLevel(200)

            f.title = f:CreateFontString(nil, "OVERLAY")
            f.title:SetFontObject(GameFontHighlight)
            f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
            f.title:SetText(L["EXPORT_PROFILE"])

            local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 10, -30)
            scroll:SetPoint("BOTTOMRIGHT", -30, 40)

            local editBox = CreateFrame("EditBox", nil, scroll)
            editBox:SetMultiLine(true)
            editBox:SetFontObject(ChatFontNormal)
            editBox:SetWidth(560)
            editBox:SetHeight(250)
            editBox:SetAutoFocus(false)
            editBox:SetText(exportStr)
            scroll:SetScrollChild(editBox)

            -- Automatically highlight and focus the text
            editBox:SetFocus()
            editBox:HighlightText()

            -- Escape closes frame when EditBox is focused
            editBox:SetScript("OnEscapePressed", function()
                f:Hide()
            end)
            
            -- Close frame with Escape key
            f:EnableKeyboard(true)
            --f:SetPropagateKeyboardInput(true)
            f:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    f:Hide()
                end
            end)
    end
        _G["CCS_ExportBox"]:Show()
end

function CCS:ShowImportFrame()

    if _G["CCS_ImportBox"] == nil then
        local f = CreateFrame("Frame", "CCS_ImportBox", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(600, 360)
        f:SetPoint("BOTTOM", _G["CCS_Options"], "BOTTOM", 0, 80 )
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(200)

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetFontObject(GameFontHighlight)
        f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
        f.title:SetText(L["IMPORT_PROFILE"])

       -- Feedback text at bottom (wrapped)
        local feedbackText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        feedbackText:SetPoint("BOTTOMLEFT", 10, 50)
        feedbackText:SetPoint("BOTTOMRIGHT", -10, 50)
        feedbackText:SetJustifyH("LEFT")
        feedbackText:SetJustifyV("TOP")
        feedbackText:SetText("")
        feedbackText:SetWidth(580)
        feedbackText:SetWordWrap(true)

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -30)
        scroll:SetPoint("BOTTOMRIGHT", -30, 80)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(560)
        editBox:SetHeight(260)
        editBox:SetAutoFocus(true)
        editBox:SetText("")
        editBox:HighlightText()
        scroll:SetScrollChild(editBox)

        -- Escape closes frame when EditBox is focused
        editBox:SetScript("OnEscapePressed", function()
            f:Hide()
        end)

        local validateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        validateBtn:SetSize(120, 25)
        validateBtn:SetPoint("BOTTOMLEFT", 10, 15)
        validateBtn:SetText(L["VALIDATE"])

        local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        applyBtn:SetSize(120, 25)
        applyBtn:SetPoint("BOTTOMRIGHT", -10, 15)
        applyBtn:SetText(APPLY)

        -- Clear feedback when frame is opened
        feedbackText:SetText("")

        -- Validation logic
        validateBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                feedbackText:SetText("|cffff0000".. L["NO_IMPORT_STRING"] .."|r")
                return
            end

            local success, result = pcall(CCS.ImportProfile, text)
            if not success then
                feedbackText:SetText("|cffff0000"..L["IMPORT_ERROR"]..":|r " .. tostring(result))
                return
            end
            if type(result) ~= "table" then
                feedbackText:SetText("|cffff0000"..L["INVALID_FORMAT_IMPORT"].."|r")
                return
            end

            local valid, err = CCS.validateProfileStructure(result)
            if valid then
                feedbackText:SetText("|cff00ff00"..L["PROFILE_VALID_IMPORT"].."|r")
            else
                feedbackText:SetText("|cffff0000"..L["INVALID_PROFILE_FORMAT"]..":|r " .. tostring(err))
            end
        end)

        -- Deep copy helper: overwrite dest with src values
        function CCS.DeepCopyInto(dest, src)
            -- clear existing keys
            for k in pairs(dest) do
                dest[k] = nil
            end
            -- copy new keys
            for k,v in pairs(src) do
                if type(v) == "table" then
                    dest[k] = CCS.DeepCopyInto({}, v)
                else
                    dest[k] = v
                end
            end
            return dest
        end

        local function dumpTable(t, prefix)
            prefix = prefix or "Profile"
            for k,v in pairs(t) do
                local path = prefix .. "." .. tostring(k)
                if type(v) == "table" then
                    print(path .. " = (table)")
                    dumpTable(v, path)
                else
                    print(path .. " = " .. tostring(v))
                end
            end
        end

        -- Apply logic
        applyBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                feedbackText:SetText("|cffff0000"..L["NO_IMPORT_STRING"].."|r")
                return
            end

            local success, result = pcall(CCS.ImportProfile, text)
            if not success then
                feedbackText:SetText("|cffff0000"..L["IMPORT_ERROR"]..":|r " .. tostring(result))
                return
            end
            if type(result) ~= "table" then
                feedbackText:SetText("|cffff0000"..L["INVALID_FORMAT_IMPORT"].."|r")
                return
            end

            local valid, err = CCS.validateProfileStructure(result)
            if not valid then
                feedbackText:SetText("|cffff0000"..L["IMPORT_FAILED"]..":|r " .. err)
                return
            end

            -- Deep copy into the existing profile table
            CCS.DeepCopyInto(CCS.CurrentProfile, result)

            --dumpTable(CCS.CurrentProfile, "CurrentProfile")

            -- Permanently save imported profile
            local charKey = CCS:GetProfileName()
            ChonkyCharacterSheetDB.profiles[charKey] = CCS.CurrentProfile

            -- Refresh options/UI
            CCS:LoadOptions()
            CCS:RefreshOptionsUI()
            --dumpTable(CCS.CurrentProfile, "CurrentProfile")

            feedbackText:SetText("|cff00ff00"..L["PROFILE_IMPORT_SUCCESS"].."|r")
            CCS.InitializeModules()
        end)

        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                f:Hide()
            end
        end)
    end
    _G["CCS_ImportBox"]:Show()
end

function CCS.testExportImport()
        local originalProfile = CCS.CurrentProfile
        if type(originalProfile) ~= "table" then
            print("|cffff0000Test failed! CurrentProfile is not a table.|r")
            return
        end

        print("|cff9999ffStarting export/import validation test...|r")

        -- Step 1: Export
        local exportStr = CCS.ExportProfile(originalProfile)
        if type(exportStr) ~= "string" then
            print("|cffff0000Test failed! ExportProfile did not return a string.|r")
            return
        end
        print("|cff00ff00Export successful.|r")

        -- Step 2: Compression check
        local LibDeflate = LibDeflate
        if LibDeflate then
            local decoded = LibDeflate:DecodeForPrint(exportStr)
            if not decoded then
                print("|cffff0000DecodeForPrint failed!|r")
            else
                local decompressed = LibDeflate:DecompressDeflate(decoded)
                if decompressed then
                    print("|cff00ff00Compression integrity verified.|r")
                else
                    print("|cffff0000DecompressDeflate failed!|r")
                end
            end
        else
            print("|cffffff00Warning: LibDeflate not found, skipping compression test.|r")
        end

        -- Step 3: Import
        local success, imported = pcall(CCS.ImportProfile, exportStr)
        if not success then
            print("|cffff0000ImportProfile threw an error:|r " .. tostring(imported))
            return
        end
        if type(imported) ~= "table" then
            print("|cffff0000ImportProfile did not return a table.|r")
            return
        end

        -- Step 4: Schema validation
        local valid, err = CCS.validateProfileStructure(imported)
        if not valid then
            print("|cffff0000Test failed! Schema invalid:|r " .. err)
            return
        end
        print("|cff00ff00Profile schema validation passed.|r")

        -- Step 5: Deep equality check
        if CCS.deepCompare(originalProfile, imported) then
            print("|cff00ff00Table structure identical after import.|r")
        else
            print("|cffffff00Differences detected — comparing hashes...|r")
            local hash1 = CCS.tableHash(originalProfile)
            local hash2 = CCS.tableHash(imported)
            if hash1 == hash2 then
                print("|cff00ff00Hashes match — tables equivalent by content.|r")
            else
                print("|cffff0000Hashes differ! Export/import mismatch detected.|r")
            end
        end
end

---------------------------
-- SavedVariables Setup
---------------------------
function CCS:InitSavedVariables()
    ChonkyCharacterSheetDB = ChonkyCharacterSheetDB or { default = {}, profiles = {} }
    ChonkyCharacterSheetDB.profiles = ChonkyCharacterSheetDB.profiles or {}

    local charKey = CCS:GetProfileName()
    local localeFontPath = CCS:GetDefaultFontForLocale()
    
    -- Always point CurrentProfile to the saved profile
    CCS.CurrentProfile = ChonkyCharacterSheetDB.profiles[charKey]
    if not CCS.CurrentProfile then
        CCS.CurrentProfile = {}
        ChonkyCharacterSheetDB.profiles[charKey] = CCS.CurrentProfile
    end

    local savedProfile = CCS.CurrentProfile

    for _, def in ipairs(ns.optionDefs or {}) do
        if def.key then
            local saved = savedProfile[def.key]
            local default = ChonkyCharacterSheetDB.default[def.key] or def.default

            if type(default) == "table" then
                -- Ensure table exists
                savedProfile[def.key] = savedProfile[def.key] or {}
                for i = 1, #default do
                    if type(saved) == "table" and saved[i] ~= nil then
                        savedProfile[def.key][i] = saved[i]
                    else
                        savedProfile[def.key][i] = default[i]
                    end
                end
            else
                -- Explicitly respect false values
                if saved == nil then
                    if def.type == "font" and localeFontPath then
                        savedProfile[def.key] = localeFontPath
                    else
                        savedProfile[def.key] = default
                    end
                else
                    savedProfile[def.key] = saved
                end
            end

        end
    end
end

---------------------------
-- Option Frame Updates
---------------------------
function CCS:UpdateOption(def, newValue)
    if not def or not def.key then return end
    CCS.CurrentProfile[def.key] = newValue
    def.value = newValue

    local profileKey = CCS:GetProfileName()
    ChonkyCharacterSheetDB.profiles[profileKey] = ChonkyCharacterSheetDB.profiles[profileKey] or {}
    ChonkyCharacterSheetDB.profiles[profileKey][def.key] = newValue
end

function CCS:GetOptionValue(key)
    if key == nil then return nil end
    if CCS.CurrentProfile[key] ~= nil then
        return CCS.CurrentProfile[key]
    end
    return ChonkyCharacterSheetDB.default[key]
end
local option = function(key) return CCS:GetOptionValue(key) end

function CCS:GetOptionDefByKey(key)
    if not key then return nil end
    for _, def in ipairs(ns.optionDefs or {}) do
        if def.key == key then
            return def
        end
    end
    return nil
end

function CCS:GetRawOptionValue(profileKey, key)
    if ChonkyCharacterSheetDB and ChonkyCharacterSheetDB.profiles and ChonkyCharacterSheetDB.profiles[profileKey] then
        return ChonkyCharacterSheetDB.profiles[profileKey][key]
    end
    return ChonkyCharacterSheetDB.default and ChonkyCharacterSheetDB.default[key]
end

function CCS:GetProfileName(overrideGlobal)
    local defaultKey = "default"
    local playerKey = UnitName("player") .. "-" .. GetRealmName()

    -- Use override if provided
    local useGlobal = overrideGlobal

    -- If not overridden, read directly from SavedVariables
    if useGlobal == nil then
        if ChonkyCharacterSheetDB and ChonkyCharacterSheetDB.profiles and ChonkyCharacterSheetDB.profiles[playerKey] then
            useGlobal = ChonkyCharacterSheetDB.profiles[playerKey]["globalprofile"]
        end
    end

    if useGlobal == false then
        return playerKey
    end
    return defaultKey
end

function CCS:ResetProfileToDefaults()
    for _, def in ipairs(ns.optionDefs or {}) do
        if def.key then
            self:UpdateOption(def, def.default)
        end
    end
end

---------------------------
-- Load Options
---------------------------
function CCS:LoadOptions()
    for _, def in ipairs(ns.optionDefs or {}) do
        local key = def.key
        if key then
            local savedValue = CCS.CurrentProfile[key]
            local defaultValue = def.default
            local valueToUse

            if type(defaultValue) == "table" then
                -- Handle tables (like color pickers)
                valueToUse = {}
                if type(savedValue) == "table" then
                    for i = 1, #defaultValue do
                        if savedValue[i] ~= nil then
                            valueToUse[i] = savedValue[i]
                        else
                            valueToUse[i] = defaultValue[i]
                        end
                    end
                else
                    for i = 1, #defaultValue do
                        valueToUse[i] = defaultValue[i]
                    end
                end
            else
                -- Handle scalars
                if savedValue ~= nil then
                    valueToUse = savedValue
                else
                    valueToUse = defaultValue
                end
            end

            -- Special handling for control types that require valid values
            if def.type == "dropdown" or def.type == "font" then
                if not valueToUse or valueToUse == "" then
                    valueToUse = defaultValue
                end
            elseif def.type == "color" then
                if type(valueToUse) ~= "table" or #valueToUse < 3 then
                    local c = defaultValue or {1,1,1,1}
                    valueToUse = {c[1], c[2], c[3], c[4] or 1}
                else
                    valueToUse[4] = valueToUse[4] or 1
                end
            end

            -- Update runtime profile
            self:UpdateOption(def, valueToUse)
            
            -- **Populate the UI control**
            if def.type == "checkbox" and def.frame and def.frame.SetChecked then
                def.frame:SetChecked(valueToUse == true)
            elseif (def.type == "dropdown" or def.type == "font") and def.frame and def.frame.SetSelectedValue then
                UIDropDownMenu_SetSelectedValue(def.frame, valueToUse)
            elseif def.type == "slider" and def.frame and def.frame.SetValue then
                def.frame:SetValue(tonumber(valueToUse) or 0)
            elseif def.type == "color" and def.frame and def.frame.texture and type(valueToUse) == "table" then
                def.frame.texture:SetColorTexture(valueToUse[1], valueToUse[2], valueToUse[3], valueToUse[4] or 1)
            end

        end
    end
end

---------------------------
-- Initialization
---------------------------
function CCS:Initialize()
    self:CallVersionHook("OnLogin")
end

---------------------------
-- Reset all options to their defaults and update controls
---------------------------
function CCS:ResetOptionsToDefaults()
    for _, def in ipairs(ns.optionDefs or {}) do
        if def.key and def.default ~= nil then
            local key = def.key
            local defaultValue = def.default

            -- Update runtime value and SavedVariables
            CCS.CurrentProfile[key] = defaultValue
            ChonkyCharacterSheetDB.profiles[CCS:GetProfileName()][key] = defaultValue

            -- Update the control itself if the options frame exists
            if def.frame then
                    if def.type == "slider" and def.frame then
                        local numVal = tonumber(defaultValue) or 0

                        -- Use custom update logic
                        if def.frame.updateThumbPosition then
                            def.frame.updateThumbPosition(numVal)
                        end

                        -- Format edit box based on step precision
                        local function getDecimalPlaces(s)
                            local str = tostring(s)
                            local dot = string.find(str, ".", 1, true)
                            if not dot then return 0 end
                            return #str - dot
                        end

                        local decimals = getDecimalPlaces(def.step or 1)
                        local formatted = string.format("%." .. decimals .. "f", numVal)

                        if def.frame.editBox then
                            def.frame.editBox:SetText(formatted)
                        end
                elseif def.type == "checkbox" and def.frame.SetChecked then
                    def.frame:SetChecked(defaultValue == true or tonumber(defaultValue) == 1)
                elseif def.type == "dropdown" then 
                    UIDropDownMenu_SetSelectedValue(def.frame, defaultValue)
                elseif def.type == "font" then
                    local fontname = CCS:GetDefaultFontForLocale()
                    UIDropDownMenu_SetSelectedValue(def.frame, fontname)
                elseif def.type == "color" and def.frame.texture then
                    local c = defaultValue
                    if type(c) == "table" and #c >= 3 then
                        def.frame.texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
                    end
                end
            end
        end
    end
end

function CCS:GetAverageEquippedRarityHex(unit)
    unit = unit or "player"
    local totalRarity = 0
    local itemCount = 0

    for slot = 1, 17 do
        if slot ~= 4 and slot ~= 19 then -- Skip shirt and tabard
            local rarity = GetInventoryItemQuality(unit, slot) or 1 -- Default to Common
            local itemLink = GetInventoryItemLink(unit, slot)

            -- Treat Heirlooms as Rare
            if itemLink and itemLink:find("item:") then
                local _, _, itemRarity = GetItemInfo(itemLink)
                if itemRarity == 7 then
                    rarity = 3
                end
            end

            -- Check if it's a two-handed weapon
            local isTwoHander = false
            if slot == 16 and itemLink then
                local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(itemLink)
                if equipSlot == "INVTYPE_2HWEAPON" then
                    isTwoHander = true
                end
            end

            if slot == 16 and isTwoHander then
                totalRarity = totalRarity + (rarity * 2)
                itemCount = itemCount + 2
            elseif slot ~= 17 then -- Skip offhand if two-hander is equipped
                totalRarity = totalRarity + rarity
                itemCount = itemCount + 1
            end
        end
    end

    if itemCount == 0 then return CCS.rarityHexColors[1] end -- fallback to Common
    local avgRarity = math.floor((totalRarity / itemCount) + 0.5)
    local hexcolor = CCS.rarityHexColors[avgRarity] or CCS.rarityHexColors[1]
    return hexcolor
end

CCS.HiddenTooltip = CreateFrame("GameTooltip", "CCSHiddenTooltip", nil, "GameTooltipTemplate")
CCS.HiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")

function CCS.PreloadEquippedItemInfo(unit)
    for slot = 1, 17 do
        if slot ~= 4 and slot ~= 19 then
            local itemLink = GetInventoryItemLink(unit, slot)
            if itemLink then
                CCS.HiddenTooltip:SetHyperlink(itemLink)
            end
        end
    end
end

function CCS.WaitForItemInfoReady(unit, callback)
    local retries = 10
    local function check()
        for slot = 1, 17 do
            if slot ~= 4 and slot ~= 19 then
                local itemLink = GetInventoryItemLink(unit, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    if not name then
                        retries = retries - 1
                        if retries > 0 then
                            C_Timer.After(0.1, check)
                        end
                        return
                    end
                end
            end
        end
        callback()
    end
    check()
end

function CCS.parseItemLink(itemLink)
    -- Extract payload between |Hitem: and |h
    local payload = itemLink:match("|Hitem:([^|]+)|h")
    if not payload then return end
    local fields = { strsplit(":", payload) }

    -- Positional indices (Retail Dragonflight+ typical layout)
    local idx = 1
    local itemID          = tonumber(fields[idx]); idx = idx + 1
    local enchantID       = tonumber(fields[idx]); idx = idx + 1
    local gem1            = tonumber(fields[idx]); idx = idx + 1
    local gem2            = tonumber(fields[idx]); idx = idx + 1
    local gem3            = tonumber(fields[idx]); idx = idx + 1
    local gem4            = tonumber(fields[idx]); idx = idx + 1
    local suffixID        = tonumber(fields[idx]); idx = idx + 1
    local uniqueID        = tonumber(fields[idx]); idx = idx + 1
    local linkLevel       = tonumber(fields[idx]); idx = idx + 1
    local specialization  = tonumber(fields[idx]); idx = idx + 1
    local modifiersMask   = tonumber(fields[idx]); idx = idx + 1 -- often present (can be empty)
    local itemContext     = tonumber(fields[idx]); idx = idx + 1 -- context (crafting, dungeon, etc.)

    local numBonusIDs     = tonumber(fields[idx]); idx = idx + 1
    local bonusIDs = {}
    for i = 1, (numBonusIDs or 0) do
        local b = tonumber(fields[idx]); idx = idx + 1
        if b then bonusIDs[#bonusIDs+1] = b end
    end

    -- After bonusIDs, modern links have field:value pairs
    local pairs = {}
    while idx <= #fields do
        local key = tonumber(fields[idx]);   idx = idx + 1
        local val = tonumber(fields[idx]);   idx = idx + 1
        if not key or not val then break end
        pairs[key] = val
    end

    return {
        itemID = itemID, enchantID = enchantID,
        gems = { gem1, gem2, gem3, gem4 },
        bonusIDs = bonusIDs,
        pairs = pairs,
        meta = {
            suffixID = suffixID, uniqueID = uniqueID, linkLevel = linkLevel,
            specialization = specialization, modifiersMask = modifiersMask, itemContext = itemContext,
        }
    }
end


function CCS:GetUnitEquipmentStats(unit)
        local statTotals = {
            CRIT_RATING = 0,
            HASTE_RATING = 0,
            MASTERY_RATING = 0,
            VERSATILITY = 0,
            LEECH = 0,
            AVOIDANCE = 0,
            SPEED = 0,
            STRENGTH = 0,
            AGILITY = 0,
            INTELLECT = 0,
            STAMINA = 0,
        }
        
    local statKeywords = {
        [ITEM_MOD_CRIT_RATING_SHORT] = "CRIT_RATING",
        [RAID_BUFF_6] = "CRIT_RATING",
        ["к скорости передвижения"] = "SPEED",
        [ITEM_MOD_HASTE_RATING_SHORT] = "HASTE_RATING",
        [ITEM_MOD_MASTERY_RATING_SHORT] = "MASTERY_RATING",
        [ITEM_MOD_CR_UNUSED_9_SHORT] = "VERSATILITY",
        [ITEM_MOD_VERSATILITY] = "VERSATILITY",
        [ITEM_MOD_CR_LIFESTEAL_SHORT] = "LEECH",
        [ITEM_MOD_CR_AVOIDANCE_SHORT] = "AVOIDANCE",
        [ITEM_MOD_CR_SPEED_SHORT] = "SPEED",
        [ITEM_MOD_STRENGTH_SHORT] = "STRENGTH",
        [ITEM_MOD_AGILITY_SHORT] = "AGILITY",
        [ITEM_MOD_INTELLECT_SHORT] = "INTELLECT",
        [ITEM_MOD_STAMINA_SHORT] = "STAMINA",
        ["к вероятности критического удара"] = "CRIT_RATING", -- No clue why Blizzrd used a non-global string for this.
        ["kritischer Trefferwert"] = "CRIT_RATING", -- German too.
        ["au score de Coup critique"] =  "CRIT_RATING", -- hack french
        ["coup critique"] = "CRIT_RATING", -- more french
        ["score de coup critique"] = "CRIT_RATING", -- and even more french
        ["Score de coup"] = "CRIT_RATING", -- and even more french
        ["score de crit"] = "CRIT_RATING",

    }

    local skipSlots = {
        [4] = true,  -- shirt
        [19] = true, -- tabard
    }
    
    local function escapePattern(s)
        return (s:gsub("(%W)", "%%%1"))
    end

    local function applyStat(value, keyword)
        -- Trim and collapse spaces
        keyword = keyword:gsub("^%s+", ""):gsub("%s+$", "")
        keyword = keyword:gsub("%s+", " ")

        -- 1) Exact match (case preserving)
        local mapped = statKeywords[keyword]
        if mapped then
            statTotals[mapped] = (statTotals[mapped] or 0) + tonumber(value)
            CCS.dprint("    Found stat (exact):", keyword, "→", mapped, "+", value, "→ Total:", statTotals[mapped])
            return
        end

        -- 2) Case-insensitive substring match, longest keys first
        local normalized = keyword:lower()

        -- Build sorted list of keys by length
        local keys = {}
        for k,v in pairs(statKeywords) do
            table.insert(keys, {k,v})
        end
        table.sort(keys, function(a,b) return #a[1] > #b[1] end)

        for _,entry in ipairs(keys) do
            local keyNorm = entry[1]:lower()
            -- plain substring search
            if normalized:find(keyNorm, 1, true) then
                local mappedVal = entry[2]
                statTotals[mappedVal] = (statTotals[mappedVal] or 0) + tonumber(value)
                CCS.dprint("    Found stat (substring):", keyword, "≈", entry[1], "→", mappedVal, "+", value, "→ Total:", statTotals[mappedVal])
                return
            end
        end

        -- 3) Unmapped
        CCS.dprint("    Unmapped keyword:", "[" .. keyword .. "]", "(value:", value, ")")
    end

    
    local andWord = L["and"]
    local enchantedPrefix = L["Enchanted:"]

    local scanner = CCSStatScannerTooltip or CreateFrame("GameTooltip", "CCSStatScannerTooltip", nil, "GameTooltipTemplate")
    scanner:SetOwner(UIParent, "ANCHOR_NONE")

    for slot = 1, 17 do
        if not skipSlots[slot] then
          local enchantProcessed = false
            CCS.dprint(string.format("Scanning slot: %d (%s)", slot, CCS.slotNames[slot] or "Unknown"))
            local itemLink = GetInventoryItemLink(unit, slot)
            if itemLink then
                CCS.dprint("  ItemLink:", itemLink)
                scanner:ClearLines()
                scanner:SetInventoryItem(unit, slot)
                
                -- Parse link for bonus IDs and key:value pairs
                local parsed = CCS.parseItemLink(itemLink)
                if parsed then

                    local enchantID = parsed.enchantID
                    local ench = CCS.enchantLookup[enchantID]

                    if ench then
                        for _, entry in ipairs(ench) do
                            local statvalue = entry.value
                            -- Temporary due to stat squish.
                            if enchantID < 7700 and CCS.tocversion >= 120000 then statvalue = statvalue/15 end
                            
                            if enchantID >= 7469 and enchantID <= 7479 and CCS.tocversion >= 120000 then
                                if entry.value < 0 then statvalue = math.ceil(entry.value / 100)
                               else statvalue = math.floor (entry.value / 100) end
                            end
                            if entry.stat == "CRIT_RATING" then CCS.dprint("CRIT_RATING", statvalue) end
                            statTotals[entry.stat] = statTotals[entry.stat] + math.floor(statvalue)
                            CCS.dprint(("Enchant %d → %s +%d"):format(enchantID, entry.stat, entry.value))
                        end
                        enchantProcessed = true
                    end
               
                    -- 1) Check the raw bonusIDs list (older/other systems sometimes encode here)
                    for _, b in ipairs(parsed.bonusIDs) do
                        local e = CCS.embellishmentBonus[b]

                        if e then
                            local statvalue = e.value
                            if CCS.tocversion >= 120000 then statvalue = 6 end
                            statTotals[e.stat] = statTotals[e.stat] + math.floor(statvalue)
                            CCS.dprint(("Embellishment via bonusID list %d → %s +%d"):format(b, e.stat, e.value))
                        end
                    end

                    -- 2) Check the key:value pairs section (modern crafted embellishments live here)
                    for key, val in pairs(parsed.pairs) do
                        local e = CCS.embellishmentBonus[key]   -- use key, not val
                        if e then
                            local statvalue = e.value
                            if CCS.tocversion >= 120000 then statvalue = 6 end
                            statTotals[e.stat] = statTotals[e.stat] + math.floor(statvalue)
                            CCS.dprint(("Embellishment via pair %d:%d → %s +%d"):format(key, val, e.stat, e.value))
                        end
                    end
                end
                -- Start looping lines
                for i = 1, scanner:NumLines() do
                    local line = _G["CCSStatScannerTooltipTextLeft" .. i]
                    if line then
                        local text = line:GetText()

                    -- Grab the enchant line before normalization destroys it.
                    local enchant = text:match(ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)"))
                    CCS.dprint("text before", i, ":", text)
                    -- Normalize tooltip line
                    text = text
                        :gsub("|A.-|a", "")
                        :gsub("|c%x%x%x%x%x%x%x%x", "")
                        :gsub("|r", "")
                        :gsub(",", "")
                        :gsub("%.", "")
                        :gsub("\239\187\191", "")      -- BOM
                        :gsub("\194\160", " ")         -- NBSP U+00A0
                        :gsub("\226\128\139", " ")     -- ZWSP U+200B
                        :gsub("\226\128\128", " ")     -- Ideographic space U+3000
                        :gsub("\226\128\131", "")      -- Zero-width non-joiner U+200C (rare)
                        :gsub("\226\128\141", "")      -- Zero-width no-break space U+FEFF (variation select)
                        :gsub("%c", "")
                        :gsub("%z", "")
                        :gsub("%s+", " ")              -- collapse any weird spacing to single space
                        :gsub("%s+$", "")
                        :gsub("^%s+", "")
                    CCS.dprint("text after", i, ":", text)
                        
                        if text then
                            local matched = false
        -- Start of Multi-stat Gems

                    -- Escape non-alphanumeric for Lua patterns
                    local function escapePattern(s) return (s and s:gsub("(%W)", "%%%1")) or "" end

                    -- Trim helper
                    local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

                    -- Parse a token in both orientations
                    local function parseToken(tok)
                        CCS.dprint("        [parseToken] raw token:", tok)
                        tok = trim(tok)
                        tok = tok:gsub("＋","+")  -- normalize fullwidth plus
                        tok = tok:gsub("[０-９]", function(d)
                            return ({["０"]="0",["１"]="1",["２"]="2",["３"]="3",["４"]="4",
                                     ["５"]="5",["６"]="6",["７"]="7",["８"]="8",["９"]="9"})[d] or d
                        end)
                        CCS.dprint("        [parseToken] normalized token:", tok)

                        -- Value-first: +value keyword (EN/FR/DE/RU/ZH/JA)
                        local v1, k1 = tok:match("^%+(%d+)%s*(.+)$")
                        if v1 and k1 then
                            k1 = k1:gsub("[%.。]+$","")
                            CCS.dprint("        [parseToken] value-first match:", v1, k1)
                            return v1, trim(k1)
                        end

                        -- Keyword-first: keyword +value (KO)
                        local k2, v2 = tok:match("^(.-)%s*%+(%d+)$")
                        if k2 and v2 then
                            k2 = k2:gsub("[%.。]+$","")
                            CCS.dprint("        [parseToken] keyword-first match:", v2, k2)
                            return v2, trim(k2)
                        end

                        CCS.dprint("        [parseToken] no match for token:", tok)
                        return nil,nil
                    end

                    -- Pre-checks
                    local hasTwoPlus = text:match("%+%d+") and text:match("^.*%+%d+.*%+%d+.*$")
                    local hasSlash   = text:find("/", 1, true) or text:find("／", 1, true) or text:find("、", 1, true)
                    local hasConj    = andWord and text:find(andWord, 1, true)

                    CCS.dprint("[DEBUG] hasTwoPlus:", hasTwoPlus, "hasSlash:", hasSlash, "hasConj:", hasConj, "locale:", locale)

                    if not matched and not enchant and hasTwoPlus and (hasSlash or hasConj) then
                        CCS.dprint("    Gem line detected (multi-stat):", text)

                        local token1, token2

                        if hasSlash then
                            CCS.dprint("[DEBUG] splitting on slash")
                            token1, token2 = text:match("^(.-%+%d+.-)%s*[/／、]%s*(.-%+%d+.-)$")
                        elseif locale == "ruRU" then
                            CCS.dprint("[DEBUG] splitting Russian on 'и'")
                            token1, token2 = text:match("^(%+%d+.-)%s+и%s+(%+%d+.-)$")
                        elseif locale == "koKR" then
                            CCS.dprint("[DEBUG] splitting Korean on '및/과'")
                            token1, token2 = text:match("^(.-%+%d+)%s*[및과]%s*(.-%+%d+)$")
                        elseif locale == "ptBR" or locale == "itIT" then
                            CCS.dprint("[DEBUG] splitting default on andWord:", andWord)
                            local andPat = "%s*" .. escapePattern(andWord or "") .. "%s*"
                            token1, token2 = text:match("^(%+%d+.-)%s+e%s+(%+%d+.-)$")
                        else
                            CCS.dprint("[DEBUG] splitting default on andWord:", andWord)
                            local andPat = "%s*" .. escapePattern(andWord or "") .. "%s*"
                            token1, token2 = text:match("^(.-%+%d+.-)" .. andPat .. "(.-%+%d+.-)$")
                        end

                        CCS.dprint("[DEBUG] token1:", token1 or "nil")
                        CCS.dprint("[DEBUG] token2:", token2 or "nil")

                        local ok1, ok2 = false, false

                        if token1 then
                            CCS.dprint("      Token 1:", token1)
                            local v1,k1 = parseToken(token1)
                            if v1 and k1 then
                                CCS.dprint("        Parsed gem stat:", v1, k1)
                                applyStat(v1, k1)
                                ok1 = true
                            else
                                CCS.dprint("        Failed to parse token 1:", token1)
                            end
                        end

                        if token2 then
                            CCS.dprint("      Token 2:", token2)
                            local v2,k2 = parseToken(token2)
                            if v2 and k2 then
                                CCS.dprint("        Parsed gem stat:", v2, k2)
                                applyStat(v2, k2)
                                ok2 = true
                            else
                                CCS.dprint("        Failed to parse token 2:", token2)
                            end
                        end

                        if ok1 and ok2 then
                            CCS.dprint("[DEBUG] both tokens parsed successfully")
                            matched = true
                        else
                            CCS.dprint("[DEBUG] parsing failed, ok1:", ok1, "ok2:", ok2)
                            CCS.dprint("    Multi-stat detection did not fully parse; deferring to other patterns.")
                        end
                    end
            -- End of Multi-stat Gems
                            -- Match formats
                            -- Allow optional space between value and keyword
                            -- Enchant line (captured before normalization)
                            local value3, keyword3
                            if enchant then
                                value3, keyword3 = enchant:match("^%+(%d+)%s*(.+)$")
                                
                                if not value3 or not keyword3 then
                                    value3, keyword3 = enchant:match("^(.+)%s*%+(%d+)$")
                                end
                                CCS.dprint("enchantv1", value3, keyword3, enchantProcessed)
                            end
                            
                            if enchantProcessed == true and enchant then
                                CCS.dprint("enchantProcessed")
                                matched = true
                            end
                            
                            if value3 and keyword3 and not matched  then
                                CCS.dprint("v3, k3")
                                applyStat(value3, keyword3)
                                matched = true
                            end                           
                            
                            local value1, keyword1 = text:match("^%+(%d+)%s*(.+)$")

                            -- Handle "Keyword: Value" or "Keyword：Value" formats (colon or fullwidth colon)
                            local keyword2, value2 = text:match("^(.+)[%:%：]%s*(%d+)$")

                            -- Socket bonus line (still English-only string, but allow optional space.  Inverted in Blizzard is screwing around with stats again.)
                            local value4, keyword4 = text:match("^Socket Bonus:%s*%+(%d+)%s*(.+)$")
                                                        
                            -- Korean style: keyword +value
                            local keywordKR, valueKR = text:match("^(.+)%s*%+(%d+)$")
                            
                            if value1 and keyword1 and not matched then
                                CCS.dprint("v1, k1")
                                applyStat(value1, keyword1)
                                matched = true
                            end
                            if value2 and keyword2 and not matched  then
                                CCS.dprint("v2, k2")                            
                                applyStat(value2, keyword2)
                                matched = true
                            end

                            if value4 and keyword4 and not matched  then
                                CCS.dprint("v4, k4")                            
                                applyStat(value4, keyword4)
                                matched = true
                            end

                            if keywordKR and valueKR and not matched then
                                CCS.dprint("vKR, kKR")                        
                                applyStat(valueKR, keywordKR); matched = true
                            end

                        end
                    end
                end
            else
              CCS.dprint("  No itemLink found for slot", slot)
            end
        else
            CCS.dprint("Skipping slot:", slot)
        end
    end

    return statTotals
end


function CCS.updateLocationInfo(unit, slotIndex, framename)
    if slotIndex == 18 then return end -- skip ranged slot

    local isPlayer = (unit == "player")
    local isInspect = not isPlayer

    if isInspect and not option("show_inspect") then return end

    local suffix = isPlayer and "" or "_inspect"
    local slotFrameName = CCS.getSlotFrameName(slotIndex, framename)
    if not slotFrameName then return end

    -- Determine display direction
	local displaytoleft = CCS.displaytowardleft(slotIndex)
    
	if framename == "CompCharacter" then
		displaytoleft = true
	elseif framename == "CompInspect" then
		displaytoleft = false
	end
	
    local SubElementSetPoint = "LEFT"
    local SubElementSetPoint2 = "RIGHT"
    local neg = 1
    
    if displaytoleft then 
        SubElementSetPoint = "RIGHT" 
        SubElementSetPoint2 = "LEFT" 
        neg = -1
    end
	
    -- Get item link and info
    local link = GetInventoryItemLink(unit, slotIndex)
    local itemLoc = isPlayer and ItemLocation:CreateFromEquipmentSlot(slotIndex) or nil

    -- Create or reuse UI elements
    _G[slotFrameName]:SetFrameStrata("HIGH")
    local nameTxt = _G[slotFrameName.."namefs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."namefs")
    local ilvlTxt = _G[slotFrameName.."ilvlfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."ilvlfs")
    local enchantTxt = _G[slotFrameName.."enchantfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."enchantfs")
    local bgfader = _G[slotFrameName.."bgfader"] or CreateFrame("Frame", slotFrameName.."bgfader", _G[slotFrameName])
    local bgfadertex = _G[bgfader:GetName().."tex"] or bgfader:CreateTexture(bgfader:GetName().."tex", "BACKGROUND", nil, 1)

    -- Optional: durability for player only
    local durabilityTxt, durbar, durbartex
    if isPlayer then
        durabilityTxt = _G[slotFrameName.."durabilityfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."durabilityfs")
        durbar = _G[slotFrameName.."durbar"] or CreateFrame("Frame", slotFrameName.."durbar", _G[slotFrameName])
        durbartex = _G[durbar:GetName().."tex"] or durbar:CreateTexture(durbar:GetName().."tex", "BACKGROUND", nil, 2)
    end

    -- Gem frames
    local gemIconframe1 = _G[slotFrameName.."gemtex1"] or CreateFrame("Button", slotFrameName.."gemtex1", _G[slotFrameName], "UIPanelButtonTemplate")
    local gemIconframe2 = _G[slotFrameName.."gemtex2"] or CreateFrame("Button", slotFrameName.."gemtex2", _G[slotFrameName], "UIPanelButtonTemplate")
    local gemIconframe3 = _G[slotFrameName.."gemtex3"] or CreateFrame("Button", slotFrameName.."gemtex3", _G[slotFrameName], "UIPanelButtonTemplate")

    -- Positioning and font setup
    nameTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, 13)
    nameTxt:SetFont(option("fontname_iname"..suffix) or CCS.fontname, option("fontsize_iname"..suffix) or 12, "OUTLINE")

    ilvlTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, 0)
    ilvlTxt:SetFont(option("fontname_iilvl"..suffix) or CCS.fontname, option("fontsize_iilvl"..suffix) or 10, "OUTLINE")
    ilvlTxt:SetTextColor(
        option("fontcolor_iilvl"..suffix)[1] or 1,
        option("fontcolor_iilvl"..suffix)[2] or 1,
        option("fontcolor_iilvl"..suffix)[3] or 1,
        option("fontcolor_iilvl"..suffix)[4] or 1
    )

    enchantTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, -13)
    enchantTxt:SetFont(option("fontname_enchant"..suffix) or CCS.fontname, option("fontsize_enchant"..suffix) or 10, "OUTLINE")
    enchantTxt:SetTextColor(
        option("fontcolor_enchant"..suffix)[1] or 1,
        option("fontcolor_enchant"..suffix)[2] or 1,
        option("fontcolor_enchant"..suffix)[3] or 1,
        option("fontcolor_enchant"..suffix)[4] or 1
    )

    -- Optional: durability positioning
    if isPlayer and durabilityTxt then
        durabilityTxt:SetPoint("CENTER", _G[slotFrameName], "CENTER", 0, 0)
        durabilityTxt:SetFont(option("fontname_durability") or CCS.fontname, option("fontsize_durability") or 10, CCS.textoutline)
    end

    bgfader:SetSize(240, 39) -- fader size (scales with the character frame)
    bgfader:SetPoint(SubElementSetPoint, slotFrameName, SubElementSetPoint2, -38 * neg, 0)        
    bgfader:SetFrameLevel(1)
    bgfadertex:SetAllPoints()
    bgfadertex:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\Square_AlphaGradient.tga") -- last remnant from WeakAuras.
    
    gemIconframe1:SetSize(15, 15)
    gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, 6)
    gemIconframe1:SetFrameStrata("HIGH")
    
    gemIconframe2:SetSize(15, 15)
    gemIconframe2:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
    gemIconframe2:SetFrameStrata("HIGH")
    
    gemIconframe3:SetSize(15, 15)
    gemIconframe3:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, -6)
    gemIconframe3:SetFrameStrata("HIGH")


    -- Hide all elements by default
    nameTxt:Hide()
    ilvlTxt:Hide()
    enchantTxt:Hide()
    if durabilityTxt then durabilityTxt:Hide() end
    gemIconframe1:Hide()
    gemIconframe2:Hide()
    gemIconframe3:Hide()
    bgfader:Hide()
    if durbar then durbar:Hide() end

    -- Bail early if no item
    if link == nil then
        nameTxt:SetText("")
        ilvlTxt:SetText("")
        enchantTxt:SetText("")
        if durabilityTxt then durabilityTxt:SetText("") end
        return
	else 
        local durCur, durMax = GetInventoryItemDurability(slotIndex)
        local _, _, _, _, _, _, Gem1, Gem2, Gem3, _, _, _, _, _, _ = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
        local itemName, _, itemRarity, itemiLevel, _, itemType, _, _, _, _, _, _, _, _, expacID, setID, _ = C_Item.GetItemInfo(link)
        local Color = "ffffffff"

        local itemID = tonumber(link:match("item:(%d+)"))
        if not C_Item.IsItemDataCachedByID(itemID) then
            C_Item.RequestLoadItemDataByID(itemID)
        end

        if itemRarity and itemRarity >= 1 and itemRarity <= 7 then
            Color = select(4, C_Item.GetItemQualityColor(itemRarity))
        end
        
        local ItemTip = _G["CCS_Scanningtooltip"] or CreateFrame('GameTooltip', 'CCS_Scanningtooltip', WorldFrame, 'GameTooltipTemplate')
        local EmptySocket = false
        local SocketCount = 0;
        local Enchant = ""
        local ItemUpgradeLevel = ""
        
        ItemTip:SetOwner(WorldFrame, 'ANCHOR_NONE');
        ItemTip:ClearLines()
        _G["CCS_ScanningtooltipTexture1"]:SetTexture(nil) -- Gem1
        _G["CCS_ScanningtooltipTexture2"]:SetTexture(nil) -- Gem2
        _G["CCS_ScanningtooltipTexture3"]:SetTexture(nil) -- Gem3
        ItemTip:SetHyperlink(link) 

        local info = C_TooltipInfo.GetInventoryItem(unit, slotIndex)
               
        if info and info.lines then
            for _, line in ipairs(info.lines) do
                local text = line.leftText
                if text then
                    -- Enchant line
                    local enchant = text:match(ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)"))
                    if enchant then
                        Enchant = enchant
                    end
                    
                    -- Base item level
                    local ilvl = text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))
                    if ilvl and (tonumber(ilvl) ~= tonumber(itemiLevel or 0)) then
                        itemiLevel = ilvl
                    end
                    
                    -- PvP item level (if enabled)
                    if option("showpvpilvl"..suffix) then
                        local pvp_ilvl = text:match(PVP_ITEM_LEVEL_TOOLTIP:gsub("%%d", "(%%d+)"))
                        if pvp_ilvl and itemiLevel then
                            itemiLevel = itemiLevel .. " (" .. PVP .. " " .. pvp_ilvl .. ")"
                        end
                    end
                    
                    -- Empty socket
                    
                    if text:match(EMPTY_SOCKET_PRISMATIC) then
                        EmptySocket = true
                        SocketCount = SocketCount + 1
                    end
                    
                    -- Upgrade level (track + current/max)
                    local track, current, max = text:match(": (.+)%s+(%d+)%s*/%s*(%d+)")
                    if current and max then
                        ItemUpgradeLevel = track .. " " .. current .. "/" .. max
                    end
                end
            end
        end
        
        local _, gem1Link = C_Item.GetItemGem(link, 1); 
        local _, gem2Link = C_Item.GetItemGem(link, 2); 
        local _, gem3Link = C_Item.GetItemGem(link, 3); 

        local Gemtex1 = _G["CCS_ScanningtooltipTexture1"]:GetTexture() or nil
        local Gemtex2 = _G["CCS_ScanningtooltipTexture2"]:GetTexture() or nil
        local Gemtex3 = _G["CCS_ScanningtooltipTexture3"]:GetTexture() or nil
        local MISSING_SOCKET = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\missing-socket.png"

        -- Show Missing sockets
        if option("showenchantgemerrors"..suffix) then
            if slotIndex == INVSLOT_HEAD or slotIndex == INVSLOT_WRIST or slotIndex == INVSLOT_WAIST then
                Gemtex1 = Gemtex1 or MISSING_SOCKET
            elseif slotIndex == INVSLOT_NECK or slotIndex == INVSLOT_FINGER1 or slotIndex == INVSLOT_FINGER2 then
                Gemtex1 = Gemtex1 or MISSING_SOCKET
                Gemtex2 = Gemtex2 or MISSING_SOCKET
            end
        end
 
        -- Item name info (item name in white as well) [White or Rarity Color, 12]
        if option("showitemname"..suffix) == true then
            if option("itemcolorwhite"..suffix) then Color = "ffffffff" end
            if itemName ~= nil then
                if (string.len(Color) < 8) then Color = "FF"..Color end
                if strlen(itemName) > option("itemnamelength"..suffix) then itemName = format("%." .. option("itemnamelength"..suffix) .. "s", itemName) .. "..." end                
                nameTxt:SetText("|c".. Color .. itemName .. "|r") 
            end
            nameTxt:Show()
        end
        
        -- iLvl information [White] 
        if option("showilvl"..suffix) == true then
            if option("showitemupgrade"..suffix) then 
                if string.len(ItemUpgradeLevel) > 0 then
                    local upr, upg, upb, upalpha = option("itemupgradecolor"..suffix)[1], option("itemupgradecolor"..suffix)[2], option("itemupgradecolor"..suffix)[3], option("itemupgradecolor"..suffix)[4];
                    ItemUpgradeLevel = WrapTextInColor("(" .. ItemUpgradeLevel .. ")", CreateColor(upr, upg, upb, upalpha))
                end
            else
                ItemUpgradeLevel = ""
            end
            
            if displaytoleft and itemiLevel ~= nil then
                ilvlTxt:SetText(ItemUpgradeLevel .." ".. itemiLevel) 
                --ilvlTxt:SetText(ItemUpgradeLevel .. " |cFFffffff" .. itemiLevel .. "|r") 
            elseif itemiLevel ~= nil then
                --ilvlTxt:SetText("|cFFffffff" .. itemiLevel .. " " .. ItemUpgradeLevel .. "|r")
                ilvlTxt:SetText(itemiLevel .." ".. ItemUpgradeLevel) 
            end
            ilvlTxt:Show()
        end
        
        -- Enchant Info [Mint/Red, 10]  (Mint #2afab5)
        if option("showenchants"..suffix) == true then
           
            if Enchant == "" and option("showenchantgemerrors"..suffix) == true then
            
                enchantTxt:SetTextColor(1,0,0,1)
            
                -- See if an enchant is missing from a slot. Extra code is to allow us to turn on/off the slots each time blizzard makes a change.
                if slotIndex == 1 then --  "Head" -
                    --Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"                            
                elseif slotIndex == 2 then --  "Neck" !
                elseif slotIndex == 3 then --  "Shoulder"
                elseif slotIndex == 5 then --  "Chest" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 6 then --  "Waist" -
                    --Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 7 then --  "Legs" -
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 8 then --  "Feet" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 9 then --  "Wrist" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 10 then --  "Hands" !
                elseif slotIndex == 11 then --  "Finger0" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 12 then --  "Finger1" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 15 then --  "Back" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 16 then --  "MainHand" !
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                elseif slotIndex == 17 and itemType == "Weapon" then --  "SecondaryHand" -
                    Enchant = "<" .. ENSCRIBE .. ": " .. ADDON_MISSING .. ">"            
                end
            end
            if strlen(Enchant) > 100 then Enchant = format("%.75s", Enchant) .. "..." end
            enchantTxt:SetText(Enchant)
            enchantTxt:Show()
        end
        
        -- Display Durability text (white)
        if isPlayer and option("showdurability") == true and durMax ~= nil and durCur ~= nil and durMax > 0 and durCur ~= durMax then
            local DurPercent = string.format("%.f", durCur/durMax*100)
            durabilityTxt:SetText(DurPercent.."%")
            durabilityTxt:Show()
        end
        
        if isPlayer and option("showdurabilitybar") == true and durMax ~= nil and durCur ~= nil and durMax > 0 and durCur ~= durMax then
            local DurPercent = durCur/durMax
            
            if DurPercent > 0.66 then durbartex:SetColorTexture(0, 1, 0) -- green
            elseif DurPercent > 0.33 then durbartex:SetColorTexture(1, 1, 0) -- yellow
            elseif DurPercent > 0.10 then durbartex:SetColorTexture(1, 0, 0) -- red
            else durbartex:SetColorTexture(1, 0, 0, 0.10) 
            end
            
            durbar:SetHeight(30*DurPercent)
            durbar:Show()
        end
        
        if option("showgems"..suffix) == true then
            local tooltip, tooltip2, tooltip3 = "", "", ""
            local gemCount = 0
            
            if Gem1 ~= "" or Gemtex1 then gemCount= gemCount+1 end
            if Gem2 ~= "" or Gemtex2 then gemCount= gemCount+1 end
            if Gem3 ~= "" or Gemtex3 then gemCount= gemCount+1 end
            
            if slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT then
                gemCount = 3
            end
            
            if gemCount == 1 then
                gemIconframe1:ClearAllPoints()
                gemIconframe1:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
            elseif gemCount == 2 then
                gemIconframe1:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, -2)
                gemIconframe2:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, 2)
            elseif gemCount == 3 then
                gemIconframe1:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe3:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, 4)
                gemIconframe2:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
                gemIconframe3:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, -4)
            end
            
            local Gem1type, Gem2type, Gem3type = 0,0,0
            
            if Gem1 ~= "" then
                local icon = C_Item.GetItemIconByID(Gem1)
                gemIconframe1:SetNormalTexture(icon)
                gemIconframe1:Show()
            elseif Gemtex1 then
                gemIconframe1:SetNormalTexture(Gemtex1)
                if CCS.GemInfo[Gemtex1] then tooltip = CCS.GemInfo[Gemtex1].text else tooltip = ADDON_MISSING end
                gemIconframe1:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe1:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe1:Show()
            end
            
            if Gem2 ~= "" then
                local icon = C_Item.GetItemIconByID(Gem2)
                gemIconframe2:SetNormalTexture(icon)
                gemIconframe2:Show()
            elseif Gemtex2 then
                gemIconframe2:SetNormalTexture(Gemtex2)
                if CCS.GemInfo[Gemtex2] then tooltip2 = CCS.GemInfo[Gemtex2].text else tooltip2 = ADDON_MISSING end
                gemIconframe2:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe2:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip2 = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe2:Show()
            end
            
            if Gem3 ~= "" then
                local icon = C_Item.GetItemIconByID(Gem3)
                gemIconframe3:SetNormalTexture(icon)
                gemIconframe3:Show()
            elseif Gemtex3 then
                gemIconframe3:SetNormalTexture(Gemtex3)
                if CCS.GemInfo[Gemtex3] then tooltip3 = CCS.GemInfo[Gemtex3].text else tooltip3 = ADDON_MISSING end
                gemIconframe3:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe3:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip3 = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe3:Show()
            end
            local GemToolTip = CCS:CreateTooltip("CCSGemTooltip")
            gemIconframe1:SetScript("OnEnter", function() 
                    if gem1Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem1Link, "player")
                    end
            end)
            gemIconframe1:SetScript("OnLeave", function() GemToolTip:Hide() end)
            gemIconframe2:SetScript("OnEnter", function() 
                    if gem2Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem2Link, "player")
                    end
            end)
            gemIconframe2:SetScript("OnLeave", function()  GemToolTip:Hide() end)
            gemIconframe2:SetScript("OnClick", function()  end)
            
            gemIconframe3:SetScript("OnEnter", function() 
                    if gem3Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem3Link, "player")
                    end

            end)
            gemIconframe3:SetScript("OnLeave", function() GemToolTip:Hide() end)
            gemIconframe3:SetScript("OnClick", function()  end) 
        end
        
        if option("showitemcolor"..suffix) then
            local setr, setg, setb, setalpha = option("setitemcolor"..suffix)[1], option("setitemcolor"..suffix)[2], option("setitemcolor"..suffix)[3], option("setitemcolor"..suffix)[4];
            
            if displaytoleft then 
                bgfadertex:SetTexCoord(1,0,0,1)
                
                if itemRarity == 1 then bgfadertex:SetGradient("Horizontal", CreateColor(.5, .5, .5, .4), CreateColor(1, 1, 1, 1))  -- white (Common)
                elseif itemRarity == 2 then bgfadertex:SetGradient("Horizontal", CreateColor(.06, .5, 0, .4), CreateColor(0.12, 1, 0, 1))  -- green (Uncommon)
                elseif itemRarity == 3 then bgfadertex:SetGradient("Horizontal", CreateColor(0, .22, .435, .4), CreateColor(0, 0.44, 0.87, 1)) -- Blue (Rare)
                elseif itemRarity == 4 then bgfadertex:SetGradient("Horizontal", CreateColor(.32, .105, .465, .4), CreateColor(0.64, 0.21, 0.93, 1)) -- Purple (Epic)
                elseif itemRarity == 5 then bgfadertex:SetGradient("Horizontal", CreateColor(.5, .25, 0, .4), CreateColor(1, 0.5, 0, 1)) -- Orange (Legendary)
                elseif itemRarity == 6 then bgfadertex:SetGradient("Horizontal", CreateColor(.45, .4, .25, .4), CreateColor(0.9, 0.8, 0.5, 1)) -- Tan (Artifact)
                elseif itemRarity == 7 then bgfadertex:SetGradient("Horizontal", CreateColor(0, .4, .5, .4), CreateColor(0, 0.8, 1, 1)) -- Light Blue (Heirloom)   
                else bgfadertex:SetGradient("Horizontal", CreateColor(.31, .31, .31, .4), CreateColor(0.62, 0.62, 0.62, 1)) -- gray / poor    
                end
                
                if option("showsetitems"..suffix) and setID then 
                    if option("showsetclasscolor"..suffix) then
                        setr, setg, setb = GetClassColor(select(2, UnitClass(unit)))
                        setalpha = .8
                    end
                    bgfadertex:SetGradient("Horizontal", CreateColor(setr/2, setg/2, setb/2, .4), CreateColor(setr, setg, setb, setalpha)) -- Set Item Color Left Display
                end
                
            else
                if itemRarity == 1 then bgfadertex:SetGradient("Horizontal", CreateColor(1, 1, 1, 1), CreateColor(.5, .5, .5, .4))  -- white (Common)
                elseif itemRarity == 2 then bgfadertex:SetGradient("Horizontal", CreateColor(0.12, 1, 0, 1), CreateColor(.06, .5, 0, .4))  -- green (Uncommon)
                elseif itemRarity == 3 then bgfadertex:SetGradient("Horizontal", CreateColor(0, 0.44, 0.87, 1), CreateColor(0, .22, .435, .4)) -- Blue (Rare)
                elseif itemRarity == 4 then bgfadertex:SetGradient("Horizontal", CreateColor(0.64, 0.21, 0.93, 1), CreateColor(.32, .105, .465, .4)) -- Purple (Epic)
                elseif itemRarity == 5 then bgfadertex:SetGradient("Horizontal", CreateColor(1, 0.5, 0, 1), CreateColor(.5, .25, 0, .4)) -- Orange (Legendary)
                elseif itemRarity == 6 then bgfadertex:SetGradient("Horizontal", CreateColor(0.9, 0.8, 0.5, 1), CreateColor(.45, .4, .25, .4)) -- Tan (Artifact)
                elseif itemRarity == 7 then bgfadertex:SetGradient("Horizontal", CreateColor(0, 0.8, 1, 1), CreateColor(0, .4, .5, .4)) -- Light Blue (Heirloom)   
                else bgfadertex:SetGradient("Horizontal", CreateColor(0.62, 0.62, 0.62, 1), CreateColor(0.62, 0.62, 0.62, .4)) -- gray / poor    
                end
                
                if option("showsetitems"..suffix) and setID then 
                    if option("showsetclasscolor"..suffix) then
                        setr, setg, setb = GetClassColor(select(2, UnitClass(unit)))
                        setalpha = .8
                    end
                    bgfadertex:SetGradient("Horizontal", CreateColor(setr, setg, setb, setalpha), CreateColor(0, 0, 0, .4)) -- Set Item Color Right Display
                end
            end
            bgfader:Show()
        end 
    end

end