local ADDON, ns = ...
local A=ns.Achievements
-- Follow the actual right-hand character tabs instead of hard-coding a
-- quickslot (whose transparent texture padding made the old icon tiny).
local function NativeTab()
  if not CharacterFrame or not CharacterFrame.GetRight then return end
  local right=CharacterFrame:GetRight();if not right then return end
  local candidates={}
  local function Visit(frame,depth)
    if depth>3 or not frame.GetChildren then return end
    for _,child in ipairs({frame:GetChildren()}) do
      if child~=A.characterButton then
        if child.IsObjectType and child:IsObjectType("Button") and child.GetCenter and child:IsShown() then
          local w,h=child:GetWidth(),child:GetHeight();local x,y=child:GetCenter()
          if x and y and w>=44 and w<=95 and h>=44 and h<=95 and x>=right-25 and x<=right+90 then
            candidates[#candidates+1]={frame=child,x=x,y=y,w=w,h=h}
          end
        end
        Visit(child,depth+1)
      end
    end
  end
  Visit(CharacterFrame,0)
  table.sort(candidates,function(a,b) return a.y<b.y end)
  for _,v in ipairs(candidates) do
    for _,other in ipairs(candidates) do
      if other~=v and math.abs(other.x-v.x)<8 and math.abs(other.w-v.w)<8 then return v.frame end
    end
  end
end
function A.LayoutCharacterButton()
  local b=A.characterButton;if not b then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local reference=NativeTab()
  b:ClearAllPoints()
  if reference then
    b:SetSize(reference:GetWidth(),reference:GetHeight())
    b:SetPoint("TOP",reference,"BOTTOM",0,-4)
  else
    b:SetSize(64,64);b:SetPoint("TOPLEFT",CharacterFrame,"BOTTOMRIGHT",2,40)
  end
  local w,h=b:GetSize();b.icon:SetSize(w-12,h-12)
end
function A.AttachCharacterButton()
  if A.characterButton or not CharacterFrame then return end
  local b=CreateFrame("Button","DOINKTripleKCharacterAchievementButton",CharacterFrame,"BackdropTemplate")
  A.characterButton=b
  b:SetSize(64,64)
  if b.SetBackdrop then
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
    b:SetBackdropColor(0.08,0.045,0.02,1);b:SetBackdropBorderColor(0.85,0.65,0.28,1)
  end
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local icon=b:CreateTexture(nil,"ARTWORK");b.icon=icon;icon:SetSize(52,52);icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\AddOns\\DOINK\\Media\\AchievementTrophy")
  b:SetScript("OnClick",function() A.Toggle() end)
  b:SetScript("OnShow",function() A.LayoutCharacterButton() end)
  b:SetScript("OnEnter",function(self)
    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("DOINK - Triple K");GameTooltip:AddLine("Achievements & Leaderboard",1,0.82,0);GameTooltip:Show() end
  end)
  b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  if CharacterFrame.HookScript then CharacterFrame:HookScript("OnShow",function() A.LayoutCharacterButton() end) end
  A.LayoutCharacterButton()
end
local loader=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED"}) do loader:RegisterEvent(event) end
loader:SetScript("OnEvent",function() A.AttachCharacterButton();A.LayoutCharacterButton() end)
