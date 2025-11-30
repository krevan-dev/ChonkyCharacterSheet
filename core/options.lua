local addonName, ns = ...
local L = ns.L  -- grab the localization table
local CCS = ns.CCS  -- use the shared main addon table
local GlobalSlotWidth = 169
local option = function(key) return CCS:GetOptionValue(key) end
local frame = _G["CCS_Options"] or CreateFrame("Frame", "CCS_Options", UIParent, BackdropTemplateMixin and "BackdropTemplate")
-------------------------
-- Frame Creation
-------------------------
frame:SetSize(GlobalSlotWidth*4+224, 660)
frame:SetPoint("CENTER", UIParent,"CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetFrameStrata("HIGH")
frame:SetFrameLevel(0)
frame:Hide()
frame.name = addonName

frame:SetPropagateKeyboardInput(true)
frame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        frame:Hide()
        frame:SetPropagateKeyboardInput(false)
    end

end)

local chktex = frame:CreateTexture(nil, "ARTWORK") 
chktex:SetSize(128,128)
chktex:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
chktex:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\chonky.png")

local chonkfont = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
chonkfont:SetFont(CCS:GetDefaultFontForLocale(), 12, "OUTLINE")
chonkfont:SetWordWrap(true)
chonkfont:SetSize(70, 64)
chonkfont:SetTextColor(1, 1, 1, 1) -- White
chonkfont:SetPoint("TOPLEFT", chktex, "TOPRIGHT", 3, 0)

chonkfont:SetText("Chonky Character Sheet".."\n\nv"..(C_AddOns.GetAddOnMetadata("ChonkyCharacterSheet", "Version") or ""))
chonkfont:SetJustifyH("LEFT")
chonkfont:SetJustifyV("TOP")

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
closeBtn:SetNormalTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\close.png")
closeBtn:SetHighlightTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\close-h.png")
closeBtn:SetSize(32, 32)
closeBtn:SetScale(.5)

local chkline = frame:CreateTexture(nil, "ARTWORK")
chkline:SetColorTexture(0.2, .05, 0.3, .6)
chkline:SetWidth(2)
chkline:SetHeight(frame:GetHeight())
chkline:SetPoint("TOPLEFT", frame, "TOPLEFT", 195,0)

-- Background (dark grey, 70% alpha)
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0.1, 0.1, 0.1, 0.9) -- RGB = dark grey, Alpha = 0.7

frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", -- optional background texture
    edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",        -- thin edge texture
    edgeSize = 16,                                              -- thickness of the border
    insets = { left = 3, right = 3, top = 3, bottom = 3 },      -- inset so content doesn't overlap border
})
frame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)  -- match your dark grey background
frame:SetBackdropBorderColor(0.4, .1, 0.6, .6)   -- purple border

local fontests = _G["CCS_FONT_TEST"] or frame:CreateFontString("CCS_FONT_TEST", "OVERLAY", "GameFontNormal")

local categoryScrollChildren = {}

local categoryList = {
    { name = "GENERAL",         ver=CCS.ALL},
    { name = "CHAR-SHEET",      ver=CCS.ALL },
    { name = "CHAR-FONT",       ver=CCS.ALL },
    { name = "CHAR-STATS",      ver=CCS.ALL },
    { name = "CHAR-STATS-FONT", ver=CCS.ALL },
    { name = "CHAR-MPLUS",      ver = CCS.RETAIL },
    { name = "CHAR-REWARDS",    ver = CCS.RETAIL },
    { name = "CHAR-RAID",       ver = CCS.RETAIL },
    { name = "INSPECT-SHEET",   ver=CCS.ALL },
    { name = "INSPECT-FONT",    ver=CCS.ALL },
}

-- Create scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 200, -19)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 3)

local currentVersion = CCS.GetCurrentVersion()

for _, catDef in ipairs(categoryList) do
    if bit.band(catDef.ver, currentVersion) ~= 0 then
        local child = CreateFrame("Frame", nil, scrollFrame)
        child:SetSize(600, 1000)
        child:Hide()
        categoryScrollChildren[catDef.name] = child
    end
end

local function UpdateScrollbarVisibility(scrollFrame)
    local range = scrollFrame:GetVerticalScrollRange()
    scrollFrame.ScrollBar:SetShown(range > 0)
end

-- Set initial scroll child (e.g., "GENERAL")
local initialChild = categoryScrollChildren["GENERAL"]
scrollFrame:SetScrollChild(initialChild)
initialChild:Show()

local categoryButtons = {}

local visibleCategories = {}
for _, catDef in ipairs(categoryList) do
    if bit.band(catDef.ver, currentVersion) ~= 0 then
        table.insert(visibleCategories, catDef.name)
    end
end

for i, cat in ipairs(visibleCategories) do
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(190, 20)
    btn:SetPoint("TOPLEFT", 5, -((i - 1) * 23) - 150)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetFont(CCS:GetDefaultFontForLocale(), 12)
    btn.text:SetPoint("LEFT")
    btn.text:SetTextColor(1, 1, 1, 1) -- white
    btn.text:SetText(L["CATEGORY_" .. cat] or cat)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    if cat == "GENERAL" then
        btn.bg:SetColorTexture(0.2, 0, 0.3, 1) -- selected color
    else
        btn.bg:SetColorTexture(0.1, 0.1, 0.1, 1)    
    end
    categoryButtons[cat] = btn
end


local selectedCategory = "GENERAL"
for cat, btn in pairs(categoryButtons) do
    btn:SetScript("OnEnter", function()
        if cat ~= selectedCategory then
            btn.bg:SetColorTexture(0.78, 0.231, 1, .6) -- hover color
        end
    end)

    btn:SetScript("OnLeave", function()
        if cat ~= selectedCategory then
            btn.bg:SetColorTexture(0.1, 0.1, 0.1, 1) -- default
        end
    end)

    btn:SetScript("OnClick", function()
        selectedCategory = cat

        for _, child in pairs(categoryScrollChildren) do child:Hide() end
        local activeChild = categoryScrollChildren[cat]
        if activeChild then
            activeChild:Show()
            scrollFrame:SetScrollChild(activeChild)
            
            -- Update scrollbar visibility
            C_Timer.After(0, function()
                scrollFrame:UpdateScrollChildRect()
                UpdateScrollbarVisibility(scrollFrame)
            end)

        end

        for name, b in pairs(categoryButtons) do
            if name == selectedCategory then
                b.bg:SetColorTexture(0.2, 0, .3, 1) -- selected color
            else
                b.bg:SetColorTexture(0.1, 0.1, 0.1, 1) -- default
            end
        end
    end)
end

-------------------------
-- End of Basic Frame Creation
-------------------------
function CCS.InitializeModules()
    local throttle = 0
    --if InCombatLockdown() then CCS.incombat = true return end
    if CCS.Throttles then throttle = CCS.Throttles.Init end
    
    if (GetTime() - throttle) >= .03 then -- throttle to 1 update every 0.3s
        for _, module in pairs(CCS.Modules) do
            if type(module.Initialize) == "function" then
                module:Initialize()
            end
        end
        CCS:FireEvent("CCS_EVENT_OPTIONS")        
        frame:SetScale(option("optionsheetscale") or 1)
    end

    if CCS.Throttles then CCS.Throttles.Init = GetTime() end
end
----------------
-- Skin/Theme Code
-- This is mostly for the future.
---------------
function SkinDropdown(dd, name)
    -- Apply backdrop
    dd:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    dd:SetBackdropColor(0.1, 0.1, 0.1, 1)
    dd:SetBackdropBorderColor(0.3, 0.1, 0.4, 1) -- purple border

    -- Hide default textures
    local left   = _G[name .. "Left"]
    local middle = _G[name .. "Middle"]
    local right  = _G[name .. "Right"]

    if left then left:Hide() end
    if middle then middle:Hide() end
    if right then right:Hide() end

    -- Style arrow
    local arrow = _G[name .. "Button"]
    if arrow then
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", dd, "RIGHT", -3, 0)
        arrow:SetNormalTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\down-arrow.png")
        arrow:SetHighlightTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\down-arrow-h.png")
        arrow:SetPushedTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\down-arrow-h.png")

        local pushed = arrow:GetPushedTexture()
        if pushed then
            pushed:SetPoint("CENTER", arrow, "CENTER", 1, -1)
        end
    end
end

function SkinCheckbox(check)
    -- Apply backdrop
    check:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    check:SetBackdropColor(0.1, 0.1, 0.1, 1)
    check:SetBackdropBorderColor(0.3, 0.1, 0.4, 1) -- purple border

    check:SetNormalTexture("")
    check:SetCheckedTexture("")
    check:SetHighlightTexture("")

    -- Apply checkmark textures (optional, theme-ready)
    check:SetCheckedTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-CheckBox-Check")
    check:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    check:GetHighlightTexture():SetVertexColor(0.78, 0.14, 0.69, 1) -- Neon purple with transparency
    
    -- Ensure checkmark is centered and sized
    local tex = check:GetCheckedTexture()
    if tex then
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", check, "CENTER", 0, 0)
        tex:SetSize(24, 24)
    end
end

function CCS.SkinButton(button)

    -- Apply custom backdrop
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    button:SetBackdropColor(0.17, 0.17, 0.17, .9)
    button:SetBackdropBorderColor(0.3, 0.1, 0.4, 1) -- default purple

    -- Hover feedback
    button:HookScript("OnEnter", function()
        button:SetBackdropBorderColor(0.78, 0.14, 0.69, 1) -- neon purple
    end)
    button:HookScript("OnLeave", function()
        button:SetBackdropBorderColor(0.3, 0.1, 0.4, 1) -- default purple
    end)

    -- Font styling
    local text = button:GetFontString()
    if text then
        text:SetFont(CCS:GetDefaultFontForLocale(), 12)
        text:SetTextColor(1, 1, 1, 1)
    end
end

-------------------------------
-- Create the confirmation dialog 
-------------------------------
StaticPopupDialogs["CCS_RESET_OPTIONS_CONFIRM"] = {
    text = L["OPTION_DEFAULT"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        CCS:ResetOptionsToDefaults()
        CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
        print(L["OPTIONS_RESET"])
        CCS.InitializeModules()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self)
        -- Set custom position: bottom center of your options frame
        self:ClearAllPoints()
        self:SetPoint("CENTER", CCS_Options, "CENTER", 0, 0)
    end,    
}

-- Custom-styled button
local defaultsBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
defaultsBtn:SetSize(190, 25)
defaultsBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
defaultsBtn:SetText(L["RESET_PROFILE"])

-- Apply your skin
CCS.SkinButton(defaultsBtn)

-- OnClick behavior
defaultsBtn:SetScript("OnClick", function()
    StaticPopup_Show("CCS_RESET_OPTIONS_CONFIRM")
end)

-------------------------------
-- PROFILE MANAGEMENT: COPY FROM & DELETE, plus Export/Import buttons
-------------------------------
do
    local copyFromDropdown, deleteProfileDropdown
    local exportBtn, importBtn
    local selectedCopyKey, selectedDeleteKey = nil, nil

    -- Refresh "Copy From" Dropdown
    local function RefreshCopyFromDropdown()
        if not ChonkyCharacterSheetDB then return end
        UIDropDownMenu_Initialize(copyFromDropdown, function(self, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            info.func = function(self)
                selectedCopyKey = self.value
                UIDropDownMenu_SetSelectedID(copyFromDropdown, self:GetID())

                StaticPopupDialogs["CCS_COPY_PROFILE_CONFIRM"] = {
                    text = L["COPY_SETTINGS"],
                    button1 = YES,
                    button2 = NO,
                    OnAccept = function()
                        local sourceProfile = ChonkyCharacterSheetDB.profiles[selectedCopyKey]
                        if sourceProfile then
                            for k,v in pairs(sourceProfile) do
                                if k ~= "profileName" then
                                    CCS.CurrentProfile[k] = v
                                end
                            end
                            CCS:RefreshOptionsUI()
                            print("|cff00ff00"..L["PROFILE_COPIED"].."|r")
                        end
                        selectedCopyKey = nil
                        UIDropDownMenu_SetText(copyFromDropdown, L["COPY_PROFILE_FROM"])
                    end,
                    timeout = 0,
                    whileDead = true,
                    OnShow = function(self)
                        self:ClearAllPoints()
                        self:SetPoint("CENTER", _G["CCS_Options"], "CENTER")
                    end,
                    hideOnEscape = true
                }
                StaticPopup_Show("CCS_COPY_PROFILE_CONFIRM")
            end

            for key, _ in pairs(ChonkyCharacterSheetDB.profiles or {}) do
                if key ~= CCS:GetProfileName() and key ~= "default" then
                    info.text = key
                    info.value = key
                    info.checked = (key == selectedCopyKey)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)

        UIDropDownMenu_SetText(copyFromDropdown, L["COPY_PROFILE_FROM"])
    end

    -- Refresh "Delete a Profile" Dropdown
    local function RefreshDeleteDropdown()
        if not ChonkyCharacterSheetDB then return end
        UIDropDownMenu_Initialize(deleteProfileDropdown, function(self, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            info.func = function(self)
                selectedDeleteKey = self.value
                UIDropDownMenu_SetSelectedID(deleteProfileDropdown, self:GetID())

                StaticPopupDialogs["CCS_DELETE_PROFILE_CONFIRM"] = {
                    text = L["CONFIRM_DELETE_PROFILE"],
                    button1 = YES,
                    button2 = NO,
                    OnAccept = function()
                        ChonkyCharacterSheetDB.profiles[selectedDeleteKey] = nil
                        print("|cffff0000"..L["PROFILE_DELETED"].."|r")
                        selectedDeleteKey = nil
                        RefreshDeleteDropdown()
                        RefreshCopyFromDropdown()
                    end,
                    timeout = 0,
                    whileDead = true,
                    OnShow = function(self)
                        self:ClearAllPoints()
                        self:SetPoint("CENTER", _G["CCS_Options"], "CENTER")
                    end,                    
                    hideOnEscape = true
                }
                StaticPopup_Show("CCS_DELETE_PROFILE_CONFIRM")
            end

            for key, _ in pairs(ChonkyCharacterSheetDB.profiles or {}) do
                if key ~= CCS:GetProfileName() and key ~= "default" then
                    info.text = key
                    info.value = key
                    info.checked = (key == selectedDeleteKey)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)

        UIDropDownMenu_SetText(deleteProfileDropdown, L["DELETE_PROFILE"])
    end

    -- Event handling
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonNameParam)
        if event == "ADDON_LOADED" and addonNameParam == "ChonkyCharacterSheet" then
            -- Ensure DB exists
            ChonkyCharacterSheetDB = ChonkyCharacterSheetDB or { default = {}, profiles = {} }
            ChonkyCharacterSheetDB.profiles = ChonkyCharacterSheetDB.profiles or {}

            -- Export Button
            exportBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
            exportBtn:SetSize(190, 25)
            exportBtn:SetPoint("BOTTOMLEFT", defaultsBtn, "TOPLEFT", 0, 10)

            -- Apply your skin
            exportBtn:SetText(L["EXPORT_PROFILE"])
            CCS.SkinButton(exportBtn)

            exportBtn:SetScript("OnClick", function()
                local exportStr = CCS.ExportProfile(CCS.CurrentProfile)
                if not exportStr or exportStr == "" then return end
                CCS:ShowExportFrame(exportStr)
            end)

            -- Import Button
            importBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
            importBtn:SetSize(190, 25)
            importBtn:SetPoint("BOTTOMLEFT", exportBtn, "TOPLEFT", 0, 10)
            importBtn:SetText(L["IMPORT_PROFILE"])
            CCS.SkinButton(importBtn)

            importBtn:SetScript("OnClick", function()
                CCS:ShowImportFrame()
            end)

            -- Delete Profile Dropdown
            deleteProfileDropdown = CreateFrame("Frame", "CCS_DeleteProfileDropdown", frame, "UIDropDownMenuTemplate, BackdropTemplate")
            SkinDropdown(deleteProfileDropdown, "CCS_DeleteProfileDropdown")
            deleteProfileDropdown:SetPoint("BOTTOMLEFT", importBtn, "TOPLEFT", 0, 30)
            UIDropDownMenu_SetWidth(deleteProfileDropdown, 140)
            RefreshDeleteDropdown()


            -- Copy From Dropdown
            copyFromDropdown = CreateFrame("Frame", "CCS_CopyFromDropdown", frame, "UIDropDownMenuTemplate, BackdropTemplate")
            SkinDropdown(copyFromDropdown, "CCS_CopyFromDropdown")

            
            copyFromDropdown:SetPoint("BOTTOMLEFT", deleteProfileDropdown, "TOPLEFT", 0, 10)
            UIDropDownMenu_SetWidth(copyFromDropdown, 140)
            RefreshCopyFromDropdown()

            -- Create the Discordlabel
            local discordLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            discordLabel:SetPoint("TOPRIGHT", frame, "TOP", -10, -3)
            discordLabel:SetText("|cff3399ffhttps://discord.gg/bSyqqa7RC4|r")
            discordLabel:SetFont(CCS.GetDefaultFontForLocale(), 10, "OUTLINE")
            discordLabel:SetJustifyH("CENTER")
            discordLabel:SetWidth(300)
            discordLabel:SetWordWrap(true)

            -- Create the hidden EditBox
            local discordEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            discordEditBox:SetSize(280, 20)
            discordEditBox:SetAutoFocus(true)
            discordEditBox:SetPoint("TOP", discordLabel, "BOTTOM", 0, -5)
            discordEditBox:SetText("https://discord.gg/bSyqqa7RC4")
            discordEditBox:Hide()

            -- Behavior: show EditBox on label click
            discordLabel:EnableMouse(true)
            discordLabel:SetScript("OnMouseUp", function()
                discordEditBox:Show()
                discordEditBox:SetFocus()
                discordEditBox:HighlightText()
            end)

            -- Hide EditBox when it loses focus
            discordEditBox:SetScript("OnEditFocusLost", function(self)
                self:Hide()
            end)



        end
    end)
end
-- End of Profile Options Handling
function CCS:RefreshOptionsUI()
    local profile = CCS.CurrentProfile
    if not profile or not ns.optionDefs then return end

    for _, def in ipairs(ns.optionDefs) do
        local value = profile[def.key]
        if value == nil then value = def.default end

        if def.frame then
            
            if def.type == "slider" and def.frame.updateThumbPosition then
                local numVal = tonumber(string.format("%.2f", tonumber(value) or 0))
                def.frame.updateThumbPosition(numVal)

            elseif def.type == "checkbox" and def.frame.SetChecked then
                def.frame:SetChecked(value == true)

            elseif def.type == "dropdown" or def.type == "font" then
                -- normalize empty values
                if value == nil or value == "" then
                    value = def.default
                end

                -- always apply selection and visible text
                UIDropDownMenu_SetSelectedValue(def.frame, value)

                -- lookup localized label
                local display = CCS.fontPathsLocalized[value] or value
                UIDropDownMenu_SetText(def.frame, display)

            elseif def.type == "color" and def.frame.texture and type(value) == "table" then
                def.frame.texture:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
            end
        end
    end
end

function CCS:OnGlobalProfileToggle(newVal)
    local newKey = CCS:GetProfileName(newVal)

    if newVal == false then
        -- Capture current profile values (should be from 'default')
        local sourceProfile = ChonkyCharacterSheetDB.profiles["default"]
        if not sourceProfile then
            return
        end

        -- Create new profile and copy values from 'default'
        ChonkyCharacterSheetDB.profiles[newKey] = {}
        local targetProfile = ChonkyCharacterSheetDB.profiles[newKey]

        for key, value in pairs(sourceProfile) do
            -- Do NOT copy the globalprofile flag
            if key ~= "globalprofile" then
                targetProfile[key] = value
            end
        end

        -- Set the globalprofile flag in the new profile
        targetProfile["globalprofile"] = false

        -- Switch runtime context
        CCS.CurrentProfile = targetProfile
    else
        -- Ensure the global profile exists
        ChonkyCharacterSheetDB.profiles["default"] = ChonkyCharacterSheetDB.profiles["default"] or {}
        CCS.CurrentProfile = ChonkyCharacterSheetDB.profiles["default"]

        -- Optionally set the flag (harmless)
        CCS.CurrentProfile["globalprofile"] = true
    end

    CCS:RefreshOptionsUI()
end

-- Controls Creation Code
local function newHeader(def, parent, rowHeight)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    
    -- Set text/color/font size/options
    fs:SetText(def.label)
    fs:SetTextColor(unpack(def.color or {1,1,1}))

    local fontSize = def.fontSize or 20
    --fs:SetFont(CCS:GetDefaultFontForLocale(), fontSize)

    local outline = def.fontOutline or "NONE"  -- "NONE", "THIN", or "THICK"
    fs:SetFont(CCS:GetDefaultFontForLocale(), fontSize, outline)
    
    fs:SetJustifyH("CENTER")
    
    return fs
end

local function newCheckbox(def, parent, rowHeight)
    local slotWidth = (def.slots or 1) * GlobalSlotWidth
    local key = def.key or def.label

    -- Create checkbox frame
    local check = CreateFrame("CheckButton", "CCScb" .. key, parent, "BackdropTemplate")
    check:SetSize(24, 24)
    SkinCheckbox(check) -- applies backdrop and optional textures

    -- Initialize or retrieve value
    local value = CCS.CurrentProfile[key]
    if value == nil then
        value = def.value or false
        CCS.CurrentProfile[key] = value
    end
    check:SetChecked(value)

    -- Create label manually
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(def.label)
    label:SetWidth(slotWidth - 16 - 16) -- checkboxWidth + padding
    label:SetWordWrap(true)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", check, "RIGHT", 6, -3)

    -- Store reference for external access if needed
    check.Text = label

    -- Click handler
    check:SetScript("OnClick", function(self)
        local newVal = self:GetChecked()

        if key ~= "globalprofile" then
            CCS.CurrentProfile[key] = newVal
        end

        -- Special case: globalprofile toggle
        if key == "globalprofile" then
            CCS:OnGlobalProfileToggle(newVal)
        end

        if def.onChange then
            def.onChange(newVal)
        end
        CCS.InitializeModules()
    end)

    return check
end

local function newDropdown(def, parent, rowHeight)
    local slotWidth = (def.slots or 2) * GlobalSlotWidth
    
    -- Container frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(slotWidth, rowHeight)

    -- Label
    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetText(def.label)
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 3)

    -- Key for SavedVariables
    local key = def.key or def.label

    -- Ensure CurrentProfile value exists
    local currentValue = CCS.CurrentProfile[key]
    if currentValue == nil then
        currentValue = def.value or def.values[1]
        CCS.CurrentProfile[key] = currentValue
    end

    local dd = CreateFrame("Frame", "CCSdd"..def.key, parent, "UIDropDownMenuTemplate, BackdropTemplate")
    SkinDropdown(dd, "CCSdd"..def.key)

    UIDropDownMenu_SetWidth(dd, slotWidth - 75)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -10, -2)
    dd:SetScale(.75)
    _G[dd:GetName().."Text"]:SetFont(CCS:GetDefaultFontForLocale(), 14)

    
    UIDropDownMenu_Initialize(dd, function(self)
        for _, v in ipairs(def.values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[v]
            info.value = v
            info.func = function()
                CCS.CurrentProfile[key] = v
                UIDropDownMenu_SetSelectedValue(dd, v)
                if def.onChange then
                    def.onChange(v)
                end
                CCS.InitializeModules()
            end
            UIDropDownMenu_AddButton(info)

        end
    
    
    end)

    -- Set initial selected value
    UIDropDownMenu_SetSelectedValue(dd, currentValue)

    return frame, dd
end

local function newFontSelector(def, parent, rowHeight)
    local slotWidth = (def.slots or 2) * GlobalSlotWidth
    local locale = GetLocale()

--Testing info
--locale = "enUS" --	English (United States) enGB clients return enUS
--locale = "koKR" --	Korean (Korea)
--locale = "frFR" --	French (France)
--locale = "deDE" --	German (Germany)
--locale = "zhCN" --	Chinese (Simplified, PRC)
--locale = "esES" --	Spanish (Spain)
--locale = "zhTW" --	Chinese (Traditional, Taiwan)
--locale = "esMX" --	Spanish (Mexico)
--locale = "ruRU" --	Russian (Russia)
--locale = "ptBR" --	Portuguese (Brazil)
--locale = "itIT" --	Italian (Italy)
    
    -- Container frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(slotWidth, rowHeight)

    -- Label
    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
    lbl:SetFont(CCS:GetDefaultFontForLocale(), 11, "OUTLINE")
    lbl:SetText(def.label)

    -- Key for SavedVariables
    local key = def.key or def.label

    -- Reverse mapping: path -> name
    local pathToName = {}
    for name, path in pairs(CCS.fonts) do
        pathToName[path] = name
    end

    -- Initialize value
    local currentValue = CCS.CurrentProfile[key]
    if currentValue == nil or not pathToName[currentValue] then
        currentValue = def.value or next(CCS.fonts)
        CCS.CurrentProfile[key] = currentValue
    end

    -- Dropdown
    local dd = CreateFrame("Frame", "CCSfdd"..def.key, parent, "UIDropDownMenuTemplate, BackdropTemplate")
    SkinDropdown(dd, "CCSfdd"..def.key)
    
    UIDropDownMenu_SetWidth(dd, slotWidth - 75)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -10, -2)
    dd:SetScale(.75)
    _G[dd:GetName().."Text"]:SetFont(CCS:GetDefaultFontForLocale(), 14)
    
    UIDropDownMenu_Initialize(dd, function(self)
        -- Extract and sort font names
        local sortedNames = {}
        for fontName in pairs(CCS.fonts) do
            table.insert(sortedNames, fontName)
        end
        --table.sort(sortedNames)
        --table.sort(sortedNames, function(a, b) return (L[a] or a) < (L[b] or b) end)
        
        table.sort(sortedNames, function(a, b)
            local la = CCS.fontLabels[a] and CCS.fontLabels[a][locale] or a
            local lb = CCS.fontLabels[b] and CCS.fontLabels[b][locale] or b
            return la < lb
        end)    

        -- Add fonts to dropdown in alphabetical order
        for _, fontName in ipairs(sortedNames) do
            local fontPath = CCS.fonts[fontName]
            local displayName = CCS.fontLabels[fontName] and CCS.fontLabels[fontName][locale] or fontName
            local info = UIDropDownMenu_CreateInfo()
            if fontPath == def.default then
                info.text = "|cFF00FF00("..CHAT_DEFAULT..") " .. displayName .. " |r"
            else
                info.text = displayName
            end
            info.value = fontPath
            info.func = function()
                CCS.CurrentProfile[key] = fontPath
                UIDropDownMenu_SetSelectedValue(dd, fontPath)
                if def.onChange then
                    def.onChange(fontPath)
                end

                CCS.fontname = CCS:GetDefaultFontForLocale() or CCS:GetOptionValue("default_font") or "Fonts\\FRIZQT__.TTF"
                CCS.InitializeModules()

            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial selection
    UIDropDownMenu_SetSelectedValue(dd, currentValue)

    return frame, dd
end


local function newColorPicker(def, parent, rowHeight)
    local slotWidth = (def.slots or 2) * GlobalSlotWidth

    -- Container frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(slotWidth, rowHeight)

    -- Key for SavedVariables
    local key = def.key or def.label

    -- Initialize current color
    local currentColor = CCS.CurrentProfile[key]
    if not currentColor then
        currentColor = def.value or {1, 1, 1, 1}
        CCS.CurrentProfile[key] = {unpack(currentColor)}
    end
    local r, g, b, a = unpack(currentColor)

    -- Color swatch button
    local swatch = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    swatch:SetSize(24, 24)
    swatch:SetPoint("LEFT", frame, "LEFT", 3, 0)

    local tex = swatch:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(r, g, b, a)
    swatch.texture = tex

    -- Border
    swatch:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(1, 1, 1, 1)

    -- Label
    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    lbl:SetPoint("RIGHT", frame, "RIGHT", -10, 0) -- constrain to frame width
    lbl:SetJustifyH("LEFT")
    lbl:SetJustifyV("MIDDLE")
    lbl:SetWordWrap(true)
    lbl:SetText(def.label)

    -- Click handler to open ColorPicker
    swatch:SetScript("OnClick", function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
            LoadAddOn("Blizzard_ColorPicker")
        end

        local r0, g0, b0, a0 = unpack(CCS.CurrentProfile[key] or {r, g, b, a})

        local function OnColorChanged()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame:GetColorAlpha() or 1
            CCS.CurrentProfile[key] = {nr, ng, nb, na}
            tex:SetColorTexture(nr, ng, nb, na)
            if def.onChange then def.onChange(nr, ng, nb, na) end
            CCS.InitializeModules()
        end

        local function OnCancel()
            local pr, pg, pb, pa = ColorPickerFrame:GetPreviousValues()
            pr, pg, pb, pa = pr or r0, pg or g0, pb or b0, pa or a0
            CCS.CurrentProfile[key] = {pr, pg, pb, pa}
            tex:SetColorTexture(pr, pg, pb, pa)
            if def.onChange then def.onChange(pr, pg, pb, pa) end
            CCS.InitializeModules()
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc  = OnColorChanged,
            opacityFunc = OnColorChanged,
            cancelFunc  = OnCancel,
            hasOpacity  = true,
            opacity     = a0,
            r           = r0,
            g           = g0,
            b           = b0,
        })
    end)

    return frame, swatch
end

local function newSlider(def, parent, rowHeight)
    local slotWidth = (def.slots or 2) * GlobalSlotWidth
    local trackHeight = 8
    local thumbWidth = 12

    -- Container frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(slotWidth, rowHeight)

    -- Key for SavedVariables
    local key = def.key or def.label
    local min, max = def.min, def.max
    local step = def.step or 1
    local range = max - min


    -- Initialize value
    local initialVal = CCS.CurrentProfile[key] or def.value or min
    CCS.CurrentProfile[key] = initialVal

    local function getDecimalPlaces(step)
        local s = tostring(step)
        local dot = string.find(s, ".", 1, true)
        if not dot then return 0 end
        return #s - dot
    end

    -- Track
    local track = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    track:SetSize(slotWidth - 75, trackHeight)
    track:SetPoint("LEFT", frame, "LEFT", 0, 0)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    track:SetBackdropColor(0.3, 0.3, 0.3, 1)

    -- Thumb
    local thumb = CreateFrame("Button", nil, track, BackdropTemplateMixin and "BackdropTemplate")
    thumb:SetSize(thumbWidth, trackHeight + 4)
    thumb:SetHitRectInsets(-4, -4, -4, -4)
    thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    thumb:SetBackdropColor(0.8, .2, 1, 1)
    thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    -- Label
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(def.label)
    label:SetPoint("BOTTOMLEFT", track, "TOPLEFT", 0, 4)

    -- Value display
    local valueText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    --valueText:SetPoint("BOTTOM", track, "TOP", 0, 20)
    valueText:SetText(initialVal)

    -- Edit box
    --local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
   
    local name = "CCSib"..def.key
    local edit = CreateFrame("EditBox", name, frame, "InputBoxTemplate, BackdropTemplate")

    edit.Left:Hide()
    edit.Middle:Hide()
    edit.Right:Hide()

    edit:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    edit:SetBackdropColor(0.1, 0.1, 0.1, 1)
    edit:SetBackdropBorderColor(0.3, 0.1, 0.4, 1) -- purple border
    
    edit:SetSize(50, 20)
    edit:SetAutoFocus(false)
    edit:SetText(initialVal)
    edit:SetJustifyH("CENTER")
    edit:SetPoint("LEFT", track, "RIGHT", 10, 0)

    -- Position thumb
    local function updateThumbPosition(val)
        local percent = (val - min) / range
        local xOffset = percent * track:GetWidth()
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", track, "LEFT", xOffset - thumbWidth / 2, 0)

        local decimals = getDecimalPlaces(step)
        local formatted = string.format("%." .. decimals .. "f", val)
        if valueText then valueText:SetText(formatted) end
        edit:SetText(formatted)
    end

    updateThumbPosition(initialVal)

    -- Apply value
    local function applyValue(val)
        -- Snap to step
        val = math.floor(val / step + 0.5) * step
        val = math.max(min, math.min(max, val))
        frame.lastValue = val
        CCS.CurrentProfile[key] = val

        -- Format based on step precision
        local function getDecimalPlaces(s)
            local str = tostring(s)
            local dot = string.find(str, ".", 1, true)
            if not dot then return 0 end
            return #str - dot
        end

        local decimals = getDecimalPlaces(step)
        local formatted = string.format("%." .. decimals .. "f", val)

        -- Update UI
        if frame.editBox then
            frame.editBox:SetText(formatted)
        end
        if frame.Value then
            frame.Value:SetText(formatted)
        end

        updateThumbPosition(val)
        CCS:UpdateOption(def, val)
        if def.onChange then def.onChange(val) end
        CCS.InitializeModules()
    end

    -- Drag logic
    thumb:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", function()
            local cursorX = GetCursorPosition()
            local uiScale = thumb:GetEffectiveScale()
            local localX = (cursorX / uiScale) - track:GetLeft()
            local percent = math.max(0, math.min(1, localX / track:GetWidth()))
            local rawValue = min + percent * range

            local snapped = math.floor(rawValue / step + 0.5) * step
            updateThumbPosition(snapped)
        end)
    end)

    thumb:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)

        local cursorX = GetCursorPosition()
        local uiScale = thumb:GetEffectiveScale()
        local localX = (cursorX / uiScale) - track:GetLeft()
        local percent = math.max(0, math.min(1, localX / track:GetWidth()))
        local rawValue = min + percent * range
        applyValue(rawValue)

        ClearCursor()
    end)
    -- Edit box input
    edit:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then applyValue(val) end
        self:ClearFocus()
    end)

    -- Safety net: persist last value if thumb release didn't fire cleanly
    frame:SetScript("OnHide", function()
        if frame.lastValue ~= nil then
            -- normalize once before persisting
            local decimals = getDecimalPlaces(step)
            local val = tonumber(string.format("%." .. decimals .. "f", frame.lastValue))
            CCS:UpdateOption(def, val)
        end
    end)

    -- Return container and control
    frame.Value = valueText
    frame.editBox = edit
    frame.updateThumbPosition = updateThumbPosition
    return frame, frame  -- frame acts as the control
end

local function newDivider(def, parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.4, .1, 0.6, .6)  -- white and semi-transparent
    line:SetHeight(2)
    -- Width will be based on slots * slotWidth
    local width = (def.slots or 1) * 200
    line:SetWidth(width)
    return line
end

-- Build controls and populate UI elements with runtime profile settings
frame:SetScript("OnShow", function(self)
    if self.optionsLoaded then return end
    self.optionsLoaded = true
    self:SetScale(option("optionsheetscale") or 1)


    -- Ensure profile exists
    CCS.CurrentProfile = CCS.CurrentProfile or (function()
        local charKey = CCS:GetProfileName()
        ChonkyCharacterSheetDB.profiles[charKey] = ChonkyCharacterSheetDB.profiles[charKey] or {}
        return ChonkyCharacterSheetDB.profiles[charKey]
    end)()

    local fontPath = CCS:GetDefaultFontForLocale()
    _G["CCS_FONT_TEST"]:SetFont(fontPath, 30)

    local slotWidth = GlobalSlotWidth or 200
    local maxSlots = 4

    -- Control creators & default heights
    local controlCreators = {
        header = newHeader,
        divider = newDivider,
        checkbox = newCheckbox,
        dropdown = newDropdown,
        slider = newSlider,
        font = newFontSelector,
        color = newColorPicker,
    }
    local controlHeights = {
        header = 30, divider = 10, checkbox = 45, dropdown = 45,
        slider = 45, font = 45, color = 45
    }

    -- Layout state per category
    local layoutState = {}
    for cat, scrollChild in pairs(categoryScrollChildren) do
        layoutState[cat] = {
            currentX = 0,
            currentY = -20,
            rowControls = {},
            scrollChild = scrollChild
        }
    end

    -- Row placement per category
    local function placeRow(cat)
        local state = layoutState[cat]
        if #state.rowControls == 0 then return end
        local rowHeight = 0
        for _, ctrl in ipairs(state.rowControls) do
            rowHeight = math.max(rowHeight, ctrl.height)
        end
        for _, ctrl in ipairs(state.rowControls) do
            local yOffset = state.currentY - (rowHeight - ctrl.height)/2
            ctrl.container:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", ctrl.x, yOffset)
        end
        state.currentY = state.currentY - rowHeight
        state.currentX = 0
        state.rowControls = {}
    end

    -- Iterate over optionDefs
    for _, def in ipairs(ns.optionDefs) do
        if def.ver and bit.band(def.ver, currentVersion) == 0 then
            -- skip this option
        else
            if def.cat == "IGNORE" then -- Check to see if these are option frame options so we handle them differently.
                local frameContainer, ctrlWidget = controlCreators[def.type](def, _G["CCS_Options"], 12)
                def.container = frameContainer
                def.frame = ctrlWidget or frameContainer
                
                if def.key == "optionsheetscale" then
                    def.frame:SetPoint("TOPRIGHT", _G["CCS_Options"], "TOPRIGHT", -25, -3)
                    def.frame:Show()
                elseif def.key == "globalprofile" then
                                def.frame:SetPoint("TOPLEFT", _G["CCS_DeleteProfileDropdown"], "BOTTOMLEFT", 0, -2)
                                def.frame.Text:SetFont(CCS:GetDefaultFontForLocale(), 10, "OUTLINE")
                    def.frame:Show()            
                end
                
            else -- otherwise, create a normal option control.
                local cat = (def.cat and categoryScrollChildren[def.cat]) and def.cat or "GENERAL"
                local state = layoutState[cat]
                local scrollChild = state.scrollChild
                local wSlots = def.slots or 1
                local controlHeight = controlHeights[def.type] or 50

                if def.type == "header" or def.type == "divider" or state.currentX + wSlots > maxSlots then
                    placeRow(cat)
                end

                -- Create control
                local frameContainer, ctrlWidget = controlCreators[def.type](def, scrollChild, controlHeight)
                def.container = frameContainer

                -- Explicitly handle dropdown/font so def.frame is the actual widget
                if def.type == "dropdown" or def.type == "font" then
                    def.frame = ctrlWidget or frameContainer.dropdown or frameContainer
                else
                    def.frame = ctrlWidget or frameContainer
                end

                -- Load value from profile
                local value = (CCS.CurrentProfile[def.key] == nil) and def.default or CCS.CurrentProfile[def.key]

                if type(def.default) == "table" then
                    local defaultTbl = def.default
                    local savedTbl = type(value) == "table" and value or {}
                    local valueToUse = {}
                    for i = 1, #defaultTbl do
                        valueToUse[i] = savedTbl[i] ~= nil and savedTbl[i] or defaultTbl[i]
                    end
                    value = valueToUse
                    if def.type == "color" then
                        value[4] = value[4] or 1
                    end
                elseif def.type == "dropdown" or def.type == "font" then
                    if value == nil or value == "" then
                        value = def.default
                    end
                end

                -- Update runtime profile
                CCS:UpdateOption(def, value)

                -- Populate control
                if def.type == "slider" and ctrlWidget and ctrlWidget.updateThumbPosition then
                    local numVal = tonumber(string.format("%.2f", tonumber(value) or 0))
                    ctrlWidget.updateThumbPosition(numVal)
                elseif def.type == "checkbox" and def.frame.SetChecked then
                    def.frame:SetChecked(CCS.CurrentProfile[def.key] == true)
                elseif (def.type == "dropdown" or def.type == "font") and def.frame.SetSelectedValue then
                    UIDropDownMenu_SetSelectedValue(def.frame, value)
                    UIDropDownMenu_SetText(def.frame, value)
                elseif def.type == "color" and def.frame.texture and type(value) == "table" then
                    def.frame.texture:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
                end

                table.insert(state.rowControls, {
                    container = frameContainer,
                    height = controlHeight,
                    x = state.currentX * slotWidth
                })
                state.currentX = state.currentX + wSlots

                if state.currentX >= maxSlots or def.type == "header" or def.type == "divider" then
                    placeRow(cat)
                end
            end

        end
    end

    -- Finalize each scrollChild
    for cat, state in pairs(layoutState) do
        placeRow(cat)
        state.scrollChild:SetHeight(math.abs(state.currentY))
    end

    CCS:RefreshOptionsUI()
    UpdateScrollbarVisibility(scrollFrame)
end)

frame:SetScript("OnHide", function(self)
    if not ns.optionDefs or not CCS.CurrentProfile then return end

    for _, def in ipairs(ns.optionDefs) do
        if not def.key then
            -- skip options without a key
        else
            local currentValue

            if def.type == "slider" then
                -- Custom slider: use lastValue or fallback to profile/default
                if def.frame and def.frame.lastValue then
                    currentValue = def.frame.lastValue
                else
                    currentValue = CCS.CurrentProfile[def.key] or def.default
                end

            elseif def.type == "checkbox" then
                -- Make sure def.frame exists and is a CheckButton
                if def.frame and def.frame.GetChecked then
                    currentValue = def.frame:GetChecked()
                else
                    currentValue = CCS.CurrentProfile[def.key] or false
                end

            elseif def.type == "dropdown" or def.type == "font" then
                if def.frame then
                    local val = UIDropDownMenu_GetSelectedValue(def.frame)
                    currentValue = val ~= nil and val or def.default

                else
                    currentValue = def.value ~= nil and def.value or def.default
                end

            elseif def.type == "color" then
                currentValue = CCS.CurrentProfile[def.key] or {1, 1, 1, 1}

                for i = 1, 4 do
                    if not currentValue[i] then
                        currentValue[i] = (i == 4) and 1 or 1
                    end
                end

            else
                if type(def.default) == "table" then
                    currentValue = {}
                    for i = 1, #def.default do
                        currentValue[i] = def.value and def.value[i] or def.default[i]
                    end
                else
                    currentValue = def.value ~= nil and def.value or def.default
                end
            end

            CCS:UpdateOption(def, currentValue)
        end
    end
        if _G["ccsrf_sf"] ~= nil then
            ccsrf_sf:Hide()
        end
end)

-- Launcher frame for Blizzard Option AddOns panel
do
    local launcherFrame = CreateFrame("Frame")
    launcherFrame.name = addonName

    local desc = launcherFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    desc:SetPoint("TOP", 16, -16)
    desc:SetText(L["CLICK_OPTIONS"])

    local cbtn = CreateFrame("Button", nil, launcherFrame)
    cbtn:SetSize(256,256)
    cbtn:SetPoint("TOP", launcherFrame, "TOP", 0, -35)

    local launchtex = cbtn:CreateTexture(nil, "ARTWORK") 
    launchtex:SetSize(256,256)
    launchtex:SetAllPoints(cbtn)
    launchtex:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\chonky.png")


    cbtn:SetScript("OnClick", function()
        -- Close Blizzard Interface Options
        if IsOptionFrameOpen() then
           ToggleFrame(SettingsPanel)
        end
        
        if not frame:IsShown() then
            frame:Show()
            frame:SetPropagateKeyboardInput(true)
        end
    end)

    local btn = CreateFrame("Button", nil, launcherFrame, "BackdropTemplate")
    btn:SetSize(190, 24)
    btn:SetPoint("TOP", launchtex, "BOTTOM", 0, -25)
    btn:SetText(L["OPEN_OPTIONS"])
    CCS.SkinButton(btn)
    btn:SetScript("OnClick", function()
        -- Close Blizzard Interface Options
        if IsOptionFrameOpen() then
           ToggleFrame(SettingsPanel)
        end
        
        if not frame:IsShown() then
            frame:Show()
            frame:SetPropagateKeyboardInput(true)
        end
    end)

    -- Create the label
    local discordLabel = launcherFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    discordLabel:SetPoint("TOP", btn, "BOTTOM", 0, -25)
    discordLabel:SetText("|cff3399ffhttps://discord.gg/bSyqqa7RC4|r")
    discordLabel:SetJustifyH("CENTER")
    discordLabel:SetWidth(300)
    discordLabel:SetWordWrap(true)

    -- Create the hidden EditBox
    local discordEditBox = CreateFrame("EditBox", nil, launcherFrame, "InputBoxTemplate")
    discordEditBox:SetSize(280, 20)
    discordEditBox:SetAutoFocus(true)
    discordEditBox:SetPoint("TOP", discordLabel, "BOTTOM", 0, -5)
    discordEditBox:SetText("https://discord.gg/bSyqqa7RC4")
    discordEditBox:Hide()

    -- Behavior: show EditBox on label click
    discordLabel:EnableMouse(true)
    discordLabel:SetScript("OnMouseUp", function()
        discordEditBox:Show()
        discordEditBox:SetFocus()
        discordEditBox:HighlightText()
    end)

    -- Hide EditBox when it loses focus
    discordEditBox:SetScript("OnEditFocusLost", function(self)
        self:Hide()
    end)


    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(launcherFrame)
    else
        local category, layout = Settings.RegisterCanvasLayoutCategory(launcherFrame, launcherFrame.name)
        Settings.RegisterAddOnCategory(category)
    end
end
