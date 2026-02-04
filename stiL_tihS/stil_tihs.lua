-- Addon updated 2.4.26
-- Addon Version 1.0
-- Created by radmeetsworld

local addonName = ...
local ST = CreateFrame("Frame", "StilTihsFrame")
ST.watched = {}
ST.alerted = {}
ST.lastSeen = {}

-- DB defaults
StilTihsDB = StilTihsDB or {}
StilTihsDB.alertOnce = StilTihsDB.alertOnce ~= false
StilTihsDB.showIntensity = StilTihsDB.showIntensity ~= false
StilTihsDB.showArrow = StilTihsDB.showArrow ~= false
StilTihsDB.showTimer = StilTihsDB.showTimer ~= false
StilTihsDB.showFlash = StilTihsDB.showFlash ~= false
StilTihsDB.showStealthAlerts = StilTihsDB.showStealthAlerts ~= false
StilTihsDB.minimap = StilTihsDB.minimap or { point="TOPLEFT", x=0, y=0 }
StilTihsDB.names = StilTihsDB.names or {}

-- constants
local STEALTH_CLASSES = { ROGUE=true, DRUID=true }
local RADAR_FADE_TIME = 5
local ROTATE_SPEED = math.rad(180)

-- state
ST.lastDetectedUnit = nil
ST.lastDetectedTime = 0
ST.arrowRotation = 0
ST.arrowTargetRotation = 0

local function Normalize(name) if not name then return end return string.lower(name) end
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98stil tihs:|r "..msg) end

-- gradient helpers
local function GetArrowColor(elapsed, fadeTime)
    local ratio = math.min(elapsed/fadeTime,1)
    if ratio<0.5 then local t=ratio/0.5 return 1,1*t,0 else local t=(ratio-0.5)/0.5 return 1*(1-t),1*(1-t),t end
end
local function GetTimerColor(elapsed, fadeTime) return GetArrowColor(elapsed,fadeTime) end

-- Alert function
local function Alert(name,class,unit)
    if StilTihsDB.showFlash then
        RaidNotice_AddMessage(RaidWarningFrame,"Watched player nearby: "..name,ChatTypeInfo["RAID_WARNING"])
        PlaySound(8959,"Master")
    end
    if StilTihsDB.showStealthAlerts and STEALTH_CLASSES[class] then
        RaidNotice_AddMessage(RaidWarningFrame,"STEALTH CLASS: "..name,ChatTypeInfo["RAID_WARNING"])
    end

    ST.lastDetectedUnit = unit
    ST.lastDetectedTime = time()

    if UnitExists(unit) then
        local px,py = UnitPosition("player")
        local ux,uy = UnitPosition(unit)
        if px and py and ux and uy then
            ST.arrowTargetRotation = math.atan2(uy-py, ux-px)
        else
            ST.arrowTargetRotation = GetPlayerFacing() or 0
        end
    else
        ST.arrowTargetRotation = GetPlayerFacing() or 0
    end
    ST.arrowRotation = ST.arrowRotation or ST.arrowTargetRotation

    if StilTihsDB.showFlash and ST.minimapButton then
        UIFrameFlash(ST.minimapButton,0.2,0.2,2,false,0,0)
    end

    ST.alerted[name] = true
    ST.lastSeen[name] = time()
end

-- Scan units
local function ScanUnits()
    local units = {"target","mouseover","focus"}
    for _,unit in ipairs(units) do
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit,"player") then
            local name = Normalize(UnitName(unit))
            local _, class = UnitClass(unit)
            if ST.watched[name] then
                if not StilTihsDB.alertOnce or not ST.alerted[name] then
                    Alert(name,class,unit)
                end
            end
        end
    end
end

-- Add/Remove
function ST:Add(name)
    name=Normalize(name)
    if not name then return end
    StilTihsDB.names[name]=true
    ST.watched[name]=true
    Print("Added "..name)
    ST:RefreshUI()
end
function ST:Remove(name)
    name=Normalize(name)
    StilTihsDB.names[name]=nil
    ST.watched[name]=nil
    Print("Removed "..name)
    ST:RefreshUI()
end

-- UI
function ST:CreateUI()
    local f = CreateFrame("Frame","StilTihsUI",UIParent,"BackdropTemplate")
    f:SetSize(300,400)
    f:SetPoint("CENTER")
    f:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background"})
    f:SetBackdropColor(0,0,0,0.9)
    f:Hide()
    ST.ui=f

    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    f.title:SetPoint("TOP",0,-10)
    f.title:SetText("stil tihs")

    -- Feature checkboxes
    local function CreateCheck(name,y,dbKey)
        local c = CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
        c:SetPoint("BOTTOMLEFT",15,y)
        c.text:SetText(name)
        c:SetChecked(StilTihsDB[dbKey])
        c:SetScript("OnClick",function(self) StilTihsDB[dbKey]=self:GetChecked() end)
        return c
    end

    f.checkAlertOnce = CreateCheck("Alert Once",15,"alertOnce")
    f.checkIntensity = CreateCheck("Arrow Intensity",40,"showIntensity")
    f.checkShowArrow = CreateCheck("Show Arrow",65,"showArrow")
    f.checkShowTimer = CreateCheck("Show Timer",90,"showTimer")
    f.checkShowFlash = CreateCheck("Show Flash Alerts",115,"showFlash")
    f.checkShowStealth = CreateCheck("Stealth Alerts",140,"showStealthAlerts")

    -- Add / Remove Target buttons
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 25)
    addBtn:SetPoint("BOTTOMLEFT", 15, 180)
    addBtn:SetText("Add Target")
    addBtn:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ST:Add(UnitName("target"))
        else
            Print("No valid player target selected")
        end
    end)

    local removeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    removeBtn:SetSize(120, 25)
    removeBtn:SetPoint("BOTTOMLEFT", 150, 180)
    removeBtn:SetText("Remove Target")
    removeBtn:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ST:Remove(UnitName("target"))
        else
            Print("No valid player target selected")
        end
    end)

    -- Reset UI Button
    local resetBtn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    resetBtn:SetSize(100,25)
    resetBtn:SetPoint("BOTTOMRIGHT",-15,15)
    resetBtn:SetText("Reset UI")
    resetBtn:SetScript("OnClick",function()
        StilTihsDB.alertOnce=true
        StilTihsDB.showIntensity=true
        StilTihsDB.showArrow=true
        StilTihsDB.showTimer=true
        StilTihsDB.showFlash=true
        StilTihsDB.showStealthAlerts=true
        StilTihsDB.minimap.point="TOPLEFT"
        StilTihsDB.minimap.x=0
        StilTihsDB.minimap.y=0
        if ST.minimapButton then
            ST.minimapButton:ClearAllPoints()
            ST.minimapButton:SetPoint("TOPLEFT",0,0)
        end
        f.checkAlertOnce:SetChecked(StilTihsDB.alertOnce)
        f.checkIntensity:SetChecked(StilTihsDB.showIntensity)
        f.checkShowArrow:SetChecked(StilTihsDB.showArrow)
        f.checkShowTimer:SetChecked(StilTihsDB.showTimer)
        f.checkShowFlash:SetChecked(StilTihsDB.showFlash)
        f.checkShowStealth:SetChecked(StilTihsDB.showStealthAlerts)
        ST:RefreshUI()
        Print("UI and Minimap Reset to Default")
    end)

    -- Scrollable watched list
    local scrollFrame = CreateFrame("ScrollFrame", "StilTihsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(270, 220)
    scrollFrame:SetPoint("TOPLEFT", 15, -70)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(270,1)
    scrollFrame:SetScrollChild(content)
    ST.ui.scrollContent = content
    ST.ui.scrollFrame = scrollFrame
    ST.ui.playerButtons = {}

    ST:RefreshUI()
end

-- Refresh UI with clickable, scrollable, sorted list
function ST:RefreshUI()
    if not ST.ui or not ST.ui.scrollContent then return end
    local content = ST.ui.scrollContent
    for _,btn in ipairs(ST.ui.playerButtons) do btn:Hide(); btn:SetParent(nil) end
    ST.ui.playerButtons = {}

    local sortedList = {}
    for name in pairs(ST.watched) do
        local last = ST.lastSeen[name] or 0
        table.insert(sortedList, {name=name,lastSeen=last})
    end
    table.sort(sortedList, function(a,b) return a.lastSeen > b.lastSeen end)

    local yOffset = -5
    for _,entry in ipairs(sortedList) do
        local name = entry.name
        local btn = CreateFrame("Button", nil, content)
        btn:SetSize(260, 20)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
        btn:SetScript("OnClick", function() ST:Remove(name) end)
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 0, 0)
        text:SetText(name .. (ST.lastSeen[name] and (" ("..SecondsToTime(time()-ST.lastSeen[name]).." ago)") or ""))
        btn.text = text
        yOffset = yOffset - 22
        table.insert(ST.ui.playerButtons, btn)
    end
    content:SetHeight(math.max(-yOffset + 5, 220))
end

-- Minimap button with arrow and timer
function ST:CreateMinimap()
    local b = CreateFrame("Button","StilTihsMiniBtn",Minimap)
    b:SetSize(31,31)
    b:SetNormalTexture("Interface\\AddOns\\stil_tihs\\icon")
    local p = StilTihsDB.minimap
    b:SetPoint(p.point,p.x,p.y)
    b:SetScript("OnClick",function() ST.ui:SetShown(not ST.ui:IsShown()) end)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart",function(self) self:StartMoving() end)
    b:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = self:GetPoint()
        StilTihsDB.minimap.point=point
        StilTihsDB.minimap.x=xOfs
        StilTihsDB.minimap.y=yOfs
    end)
    ST.minimapButton=b

    -- Arrow overlay
    local arrow=b:CreateTexture(nil,"OVERLAY")
    arrow:SetSize(16,16)
    arrow:SetTexture("Interface\\AddOns\\stil_tihs\\icon_arrow")
    arrow:SetPoint("CENTER")
    arrow:Hide()
    ST.arrow=arrow

    -- Timer overlay
    local timerText=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    timerText:SetPoint("CENTER",arrow,"CENTER",0,-10)
    timerText:SetText("")
    ST.arrowTimer=timerText
end

-- OnUpdate logic
ST:SetScript("OnUpdate",function(self,elapsed)
    self.t=(self.t or 0)+elapsed
    if self.t>1 then ScanUnits() self.t=0 end

    if ST.arrow then
        local showArrow=false
        local alpha=1
        local r,g,b=1,1,1
        if ST.lastDetectedTime and time()-ST.lastDetectedTime<=RADAR_FADE_TIME and StilTihsDB.showArrow then
            showArrow=true
            local elapsedTime=time()-ST.lastDetectedTime
            if StilTihsDB.showIntensity then
                alpha=1-(elapsedTime/RADAR_FADE_TIME)
                r,g,b=GetArrowColor(elapsedTime,RADAR_FADE_TIME)
            end
        end

        if showArrow then
            ST.arrow:Show()
            ST.arrow:SetAlpha(alpha)
            ST.arrow:SetVertexColor(r,g,b)

            if ST.lastDetectedUnit and UnitExists(ST.lastDetectedUnit) then
                local px,py=UnitPosition("player")
                local ux,uy=UnitPosition(ST.lastDetectedUnit)
                if px and py and ux and uy then
                    ST.arrowTargetRotation=math.atan2(uy-py, ux-px)
                end
            end

            local current=ST.arrowRotation
            local target=ST.arrowTargetRotation or 0
            local diff=(target-current+math.pi)%(2*math.pi)-math.pi
            local step=ROTATE_SPEED*elapsed
            if math.abs(diff)<=step then ST.arrowRotation=target else ST.arrowRotation=current + step*(diff>0 and 1 or -1) end
            ST.arrow:SetRotation(ST.arrowRotation)

            if ST.arrowTimer and StilTihsDB.showTimer then
                local secondsAgo=math.floor(time()-ST.lastDetectedTime+0.5)
                ST.arrowTimer:SetText(secondsAgo.."s")
                ST.arrowTimer:SetAlpha(alpha)
                ST.arrowTimer:SetTextColor(GetTimerColor(time()-ST.lastDetectedTime,RADAR_FADE_TIME))
            else
                ST.arrowTimer:SetText("")
            end
        else
            ST.arrow:Hide()
            if ST.arrowTimer then ST.arrowTimer:SetText("") end
        end
    end
end)

-- Load DB
for name,_ in pairs(StilTihsDB.names) do ST.watched[name]=true end

-- Events
ST:RegisterEvent("ADDON_LOADED")
ST:SetScript("OnEvent",function(self,event,arg)
    if event=="ADDON_LOADED" and arg==addonName then
        ST:CreateUI()
        ST:CreateMinimap()
        Print("Loaded. Use /stwc to control")
    end
end)

-- Slash commands
SLASH_STILTIHS1="/stwc"
SlashCmdList["STILTIHS"]=function(msg)
    local cmd,name=msg:match("^(%S*)%s*(.-)$")
    cmd=(cmd or ""):lower()
    if cmd=="add" and name~="" then ST:Add(name)
    elseif cmd=="remove" and name~="" then ST:Remove(name)
    elseif cmd=="show" then ST.ui:Show()
    else
        Print("/stwc add Name")
        Print("/stwc remove Name")
        Print("/stwc show")
    end
end
