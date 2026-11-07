local ADDON, ns = ...
local A=ns.Achievements
function A.AttachCharacterButton()
  if A.characterButton or not CharacterFrame then return end
  local b=CreateFrame("Button","DOINKTripleKCharacterAchievementButton",CharacterFrame)
  A.characterButton=b
  b:SetSize(48,48)
  -- Extend the character window's right-hand column without replacing game tabs.
  b:SetPoint("TOPLEFT",CharacterFrame,"BOTTOMRIGHT",3,40)
  b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(32,32);icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Icons\\Achievement_General")
  b:SetScript("OnClick",function() A.Toggle() end)
  b:SetScript("OnEnter",function(self)
    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("DOINK - Triple K");GameTooltip:AddLine("Achievements",1,0.82,0);GameTooltip:Show() end
  end)
  b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
end
local loader=CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED");loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent",function() A.AttachCharacterButton() end)
