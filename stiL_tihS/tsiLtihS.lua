-- Addon updated 2.5.0
-- Client - TBC Anniversary Classic
-- Created by radmeetsworld (Upgraded Version)


local addonName = ...
local ST = CreateFrame("Frame", "tsiLtihSFrame")
ST.watched = {}
ST.alerted = {}
ST.lastSeen = {}

-- DB defaults
tsiLtihSDB = tsiLtihSDB or {}
tsiLtihSDB.alertOnce = tsiLtihSDB.alertOnce ~= false
tsiLtihSDB.showIntensity = tsiLtihSDB.showIntensity ~= false
tsiLtihSDB.showArrow = tsiLtihSDB.showArrow ~= false
tsiLtihSDB.showTimer = tsiLtihSDB.showTimer ~= false
tsiLtihSDB.showFlash = tsiLtihSDB.showFlash ~= false
tsiLtihSDB.showStealthAlerts = tsiLtihSDB.showStealthAlerts ~= false
tsiLtihSDB.minimap = tsiLtihSDB.minimap or { point="BOTTOMLEFT", x=0, y=0 }
tsiLtihSDB.names = tsiLtihSDB.names or {}

-- constants
local STEALTH_CLASSES = { ROGUE=true, DRUID=true }
local RADAR_FADE_TIME = 5
local ROTATE_SPEED = math.rad(180)

-- state
ST.lastDetectedUnit = nil
ST.lastDetectedTime = 0
ST.arrowRotation = 0
ST.arrowTargetRotation = 0

-- helpers
local function Normalize(name) return name and string.lower(name) end
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98stil tihs:|r "..msg) end

local function GetArrowColor(elapsed, fadeTime)
    local ratio = math.min(elapsed/fadeTime,1)
    if ratio < 0.5 then local t=ratio/0.5 return 1, 1*t, 0 else local t=(ratio-0.5)/0.5 return 1*(1-t),1*(1-t),t end
end
local function GetTimerColor(elapsed, fadeTime) return GetArrowColor(elapsed,fadeTime) end

-- Alert system
local function Alert(name,class,unit)
    if tsiLtihSDB.showFlash then
        RaidNotice_AddMessage(RaidWarningFrame,"Watched player nearby: "..name,ChatTypeInfo["RAID_WARNING"])
        PlaySound(8959,"Master")
    end
    if tsiLtihSDB.showStealthAlerts and STEALTH_CLASSES[class] then
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

    if tsiLtihSDB.showFlash and ST.minimapButton then
        UIFrameFlash(ST.minimapButton,0.2,0.2,2,false,0,0)
    end

    ST.alerted[name] = true
    ST.lastSeen[name] = time()
end

-- Unit scanning
local function ScanUnit(unit)
    if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit,"player") then
        local name = Normalize(UnitName(unit))
        local _, class = UnitClass(unit)
        if ST.watched[name] and (not tsiLtihSDB.alertOnce or not ST.alerted[name]) then
            Alert(name,class,unit)
        end
    end
end

local function ScanAllUnits()
    -- Check target, mouseover, focus
    for _,unit in ipairs({"target","mouseover","focus"}) do
        ScanUnit(unit)
    end
    -- Scan party/raid members
    local num = IsInRaid() and GetNumGroupMembers() or (IsInGroup() and GetNumGroupMembers()-1 or 0)
    for i=1,num do
        local unit = IsInRaid() and "raid"..i or "party"..i
        ScanUnit(unit)
    end
end

-- Add/Remove watched
function ST:Add(name)
    name = Normalize(name)
    if not name then return end
    tsiLtihSDB.names[name]=true
    ST.watched[name]=true
    Print("Added "..name)
    ST:RefreshUI()
end
function ST:Remove(name)
    name = Normalize(name)
    tsiLtihSDB.names[name]=nil
    ST.watched[name]=nil
    Print("Removed "..name)
    ST:RefreshUI()
end

-- UI creation
function ST:CreateUI()
    local f = CreateFrame("Frame","tsiLtihSUI",UIParent,"BackdropTemplate")
    f:SetSize(300,400)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background"})
    f:SetBackdropColor(0,0,0,0.9)
    f:Hide()
    ST.ui=f

    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    f.title:SetPoint("TOP",0,-10)
    f.title:SetText("stiL tihS")

    -- Make it draggable
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)

    -- Feature checkboxes
    local function CreateCheck(name,y,dbKey)
        local c = CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
        c:SetPoint("BOTTOMLEFT",15,y)
        c.text:SetText(name)
        c:SetChecked(tsiLtihSDB[dbKey])
        c:SetScript("OnClick",function(self) tsiLtihSDB[dbKey]=self:GetChecked() end)
        return c
    end

    f.checkAlertOnce = CreateCheck("Only Alert Once",15,"alertOnce")
    f.checkIntensity = CreateCheck("Arrow Intensity",40,"showIntensity")
    f.checkShowArrow = CreateCheck("Show Arrow",65,"showArrow")
    f.checkShowTimer = CreateCheck("Show Last Seen Timer",90,"showTimer")
    f.checkShowFlash = CreateCheck("Show Flash Alerts",115,"showFlash")
    f.checkShowStealth = CreateCheck("Stealth Class Alerts",140,"showStealthAlerts")

    -- Add/Remove buttons
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 25)
    addBtn:SetPoint("BOTTOMLEFT", 15, 180)
    addBtn:SetText("Add Target")
    addBtn:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ST:Add(UnitName("target"))
        else Print("No valid player target selected") end
    end)

    local removeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    removeBtn:SetSize(120, 25)
    removeBtn:SetPoint("BOTTOMLEFT", 150, 180)
    removeBtn:SetText("Remove Target")
    removeBtn:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ST:Remove(UnitName("target"))
        else Print("No valid player target selected") end
    end)

    -- Scrollable watched list
    local scrollFrame = CreateFrame("ScrollFrame", "tsiLtihSScrollFrame", f, "UIPanelScrollFrameTemplate")
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

-- Refresh UI
function ST:RefreshUI()
    if not ST.ui or not ST.ui.scrollContent then return end
    local content = ST.ui.scrollContent
    for _,btn in ipairs(ST.ui.playerButtons) do btn:Hide(); btn:SetParent(nil) end
    ST.ui.playerButtons = {}

    local sortedList = {}
    for name in pairs(ST.watched) do
        table.insert(sortedList,{name=name,lastSeen=ST.lastSeen[name] or 0})
    end
    table.sort(sortedList,function(a,b) return a.lastSeen > b.lastSeen end)

   local yOffset = -5
    for _,entry in ipairs(sortedList) do
        local name = entry.name
        local btn = CreateFrame("Button", nil, content)
        btn:SetSize(260,20)
        btn:SetPoint("TOPLEFT",0,yOffset)
        btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight","ADD")
        -- btn:SetScript("OnClick",function() ST:Remove(name) end)
        TargetByName(name, true)
                Print("Targeting "..name)
        local text = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetPoint("LEFT",btn,"LEFT",0,0)
        text:SetText(name .. (ST.lastSeen[name] and (" ("..SecondsToTime(time()-ST.lastSeen[name]).." ago)") or ""))
        btn.text = text
        yOffset = yOffset - 22
        table.insert(ST.ui.playerButtons,btn)
    end
    content:SetHeight(math.max(-yOffset + 5,220))
end

-- Minimap
function ST:CreateMinimap()
    local b = CreateFrame("Button","tsiLtihSMiniBtn",Minimap)
    b:SetSize(31,31)
    b:SetNormalTexture("Interface\\AddOns\\stil_tihs\\icon")
    local p = tsiLtihSDB.minimap
    b:SetPoint(p.point,p.x,p.y)
    b:SetScript("OnClick",function() ST.ui:SetShown(not ST.ui:IsShown()) end)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart",function(self) self:StartMoving() end)
    b:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = self:GetPoint()
        tsiLtihSDB.minimap.point=point
        tsiLtihSDB.minimap.x=xOfs
        tsiLtihSDB.minimap.y=yOfs
    end)
    ST.minimapButton=b

    local arrow=b:CreateTexture(nil,"OVERLAY")
    arrow:SetSize(16,16)
    arrow:SetTexture("Interface\\AddOns\\stil_tihs\\icon_arrow")
    arrow:SetPoint("CENTER")
    arrow:Hide()
    ST.arrow=arrow

    local timerText=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    timerText:SetPoint("CENTER",arrow,"CENTER",0,-10)
    timerText:SetText("")
    ST.arrowTimer=timerText
end

-- OnUpdate
ST:SetScript("OnUpdate",function(self,elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t > 1 then ScanAllUnits() self.t=0 end

    if ST.arrow then
        local showArrow=false
        local alpha=1
        local r,g,b=1,1,1
        if ST.lastDetectedTime and time()-ST.lastDetectedTime<=RADAR_FADE_TIME and tsiLtihSDB.showArrow then
            showArrow=true
            local elapsedTime=time()-ST.lastDetectedTime
            if tsiLtihSDB.showIntensity then
                alpha=1-(elapsedTime/RADAR_FADE_TIME)
                r,g,b=GetArrowColor(elapsedTime,RADAR_FADE_TIME)
            end
        end

        if showArrow then
            ST.arrow:Show()
            ST.arrow:SetAlpha(alpha)
            ST.arrow:SetVertexColor(r,g,b)

            if ST.lastDetectedUnit and UnitExists(ST.lastDetectedUnit) then
                local px,py = UnitPosition("player")
                local ux,uy = UnitPosition(ST.lastDetectedUnit)
                if px and py and ux and uy then
                    ST.arrowTargetRotation = math.atan2(uy-py, ux-px)
                    local distance = math.sqrt((ux-px)^2 + (uy-py)^2)
                    ST.arrowTimer:SetText(math.floor(distance).."y")
                    ST.arrowTimer:SetAlpha(alpha)
                    ST.arrowTimer:SetTextColor(GetTimerColor(time()-ST.lastDetectedTime,RADAR_FADE_TIME))
                end
            end

            local current=ST.arrowRotation
            local target=ST.arrowTargetRotation or 0
            local diff=(target-current+math.pi)%(2*math.pi)-math.pi
            local step=ROTATE_SPEED*elapsed
            if math.abs(diff)<=step then ST.arrowRotation=target else ST.arrowRotation=current + step*(diff>0 and 1 or -1) end
            ST.arrow:SetRotation(ST.arrowRotation)
        else
            ST.arrow:Hide()
            ST.arrowTimer:SetText("")
        end
    end
end)

-- Load DB
for name,_ in pairs(tsiLtihSDB.names) do ST.watched[name]=true end

-- Events
ST:RegisterEvent("ADDON_LOADED")
ST:SetScript("OnEvent",function(self,event,arg)
    if event=="ADDON_LOADED" and arg==addonName then
        ST:CreateUI()
        ST:CreateMinimap()
        Print("Loaded. Use /slpvp to control")
    end
end)

-- Slash commands
SLASH_tsiLtihS1="/slpvp"
SlashCmdList["tsiLtihS"]=function(msg)
    local cmd,name=msg:match("^(%S*)%s*(.-)$")
    cmd=(cmd or ""):lower()
    if cmd=="add" and name~="" then ST:Add(name)
    elseif cmd=="remove" and name~="" then ST:Remove(name)
    elseif cmd=="list" then
        Print("Watched Players:")
        for n,_ in pairs(ST.watched) do Print(" - "..n) end
    elseif cmd=="clear" then
        for n,_ in pairs(ST.watched) do ST:Remove(n) end
        Print("Cleared watched list")
    elseif cmd=="show" then ST.ui:Show()
    elseif cmd=="hide" then ST.ui:Hide()
    else
        Print("/slpvp add Name | remove Name | list | clear | show | hide")
    end
end
