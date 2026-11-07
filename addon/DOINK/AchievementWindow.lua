local ADDON, ns = ...
local A = ns.Achievements
local selected, page, query = "summary", 1, ""
local PAGE_SIZE = 6
local categories = { {"summary", "Summary"} }
for _, category in ipairs(A.categories) do categories[#categories + 1] = category end
local icons = { levels = "Achievement_Level_10", professions = "Trade_BlackSmithing",
  playtime = "INV_Misc_PocketWatch_01", equipment = "INV_Sword_39",
  mounts = "Ability_Mount_RidingHorse", training = "Ability_DualWield", dungeons = "INV_Misc_Key_03", raids = "INV_Misc_Head_Dragon_01" }
local function Text(parent, size, color)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetFont(STANDARD_TEXT_FONT, size or 13, "")
  if color then t:SetTextColor(unpack(color)) end
  return t
end
local function Panel(parent, width, height, parchment)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(width, height)
  if f.SetBackdrop then
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = {left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(parchment and 0.62 or 0.12, parchment and 0.43 or 0.075, parchment and 0.20 or 0.035, 1)
    f:SetBackdropBorderColor(0.65,0.46,0.22,1)
  end
  if parchment then
    local t=f:CreateTexture(nil,"BACKGROUND");t:SetPoint("TOPLEFT",4,-4);t:SetPoint("BOTTOMRIGHT",-4,4)
    t:SetTexture("Interface\\QuestFrame\\QuestBG");t:SetVertexColor(0.85,0.70,0.43,1)
  end
  return f
end
local function Button(parent, label, width, click)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(width,27);b:SetText(label);b:SetScript("OnClick",click);return b
end
local function Check(parent,label,key)
  local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetSize(26,26)
  local t=Text(b,13);t:SetPoint("LEFT",b,"RIGHT",3,0);t:SetText(label)
  b:SetScript("OnClick",function(self) ns:SetOption("achievement",key,self:GetChecked() and true or false);A.Refresh() end)
  return b
end
local function Bar(parent,width,height)
  local bar=CreateFrame("StatusBar",nil,parent);bar:SetSize(width,height)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");bar:SetStatusBarColor(0.15,0.65,0.08)
  local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.08,0.10,0.04,0.95)
  bar.label=Text(bar,12,{1,0.9,0.65});bar.label:SetPoint("LEFT",7,0)
  bar.rightText=Text(bar,12,{1,1,1});bar.rightText:SetPoint("RIGHT",-7,0)
  return bar
end
local function Fits(entry)
  return query=="" or (entry.title.." "..entry.description):lower():find(query,1,true)~=nil
end
function A.Render()
  local f=A.window;if not f then return end
  local rows,recent,counts,total={}, {}, {},0
  for _,cat in ipairs(A.categories) do counts[cat[1]]={earned=0,total=0} end
  for _,e in ipairs(A.catalog) do
    local _,_,earned=A.Progress(e);local c=counts[e.category];c.total=c.total+1
    if earned then c.earned=c.earned+1;total=total+1;recent[#recent+1]=e end
    if (selected=="all" or selected==e.category or selected=="summary") and Fits(e) then rows[#rows+1]=e end
  end
  local summary=selected=="summary" and query==""
  local sharing=selected=="sharing"
  table.sort(recent,function(a,b)
    local _,_,x=A.Progress(a);local _,_,y=A.Progress(b)
    if x.at==y.at then return a.id<b.id end
    return x.at>y.at
  end)
  if summary and #recent>0 then rows=recent end
  local heading=summary and (#recent>0 and "Recent Achievements" or "Your Next Milestones") or "All Achievements"
  for _,cat in ipairs(A.categories) do if selected==cat[1] then heading=cat[2] end end
  if sharing then heading="Discord Sharing" end
  f.heading:SetText(heading)
  f.points:SetText((total*10).." / "..(#A.catalog*10))
  f.summary:SetText(total.." / "..#A.catalog.." achievements | This character")
  f.sharing:SetShown(sharing);f.overview:SetShown(summary)
  f.share:SetChecked(ns:GetOption("achievement","enabled") and true or false)
  f.photos:SetChecked(ns:GetOption("achievement","screenshot") and true or false)
  for key,check in pairs(f.categoryChecks) do check:SetChecked(ns:GetOption("achievement",key) and true or false) end
  for i,b in ipairs(f.tabs) do
    local key=categories[i][1];local c=counts[key]
    b:SetText((selected==key and "|cffb6ff70" or "|cffffd48a")..categories[i][2]..(c and ("  "..c.earned.."/"..c.total) or "").."|r")
    b.selected:SetShown(selected==key)
  end
  local pages=math.max(1,math.ceil(#rows/PAGE_SIZE));page=math.max(1,math.min(page,pages))
  local limit=summary and 4 or PAGE_SIZE
  for i,row in ipairs(f.rows) do
    local e=rows[(summary and 0 or (page-1)*PAGE_SIZE)+i]
    row:SetShown(not sharing and i<=limit and e~=nil)
    if e then
      local n,target,earned=A.Progress(e)
      row.icon:SetTexture("Interface\\Icons\\"..(icons[e.category] or "INV_Misc_Book_09"))
      row.title:SetText(e.title);row.title:SetTextColor(1,earned and 0.88 or 0.82,earned and 0.45 or 0.65)
      row.detail:SetText(e.description)
      row.badge:SetText(earned and "|cffffd16610|r" or "|cff8a765410|r")
      row.bar:SetMinMaxValues(0,target);row.bar:SetValue(n)
      local label= e.category=="playtime" and string.format("%.1f / %d hours",n/3600,target/3600) or (math.floor(n).." / "..target)
      if A.InstanceLabel and not earned then label=A.InstanceLabel(e) or label end
      if earned then label=earned.discovered and "Found on sync" or "Unlocked" end
      row.bar.label:SetText(label);row.bar.rightText:SetText(earned and date and date("%d/%m/%y",earned.at) or "")
    end
  end
  f.empty:SetShown(not sharing and #rows==0)
  f.page:SetText(page.." / "..pages);f.prev:SetEnabled(page>1);f.next:SetEnabled(page<pages)
  f.pagination:SetShown(not summary and not sharing)
  f.totalBar:SetMinMaxValues(0,#A.catalog);f.totalBar:SetValue(total)
  f.totalBar.label:SetText("Achievements Earned");f.totalBar.rightText:SetText(total.." / "..#A.catalog)
  for _,cat in ipairs(A.categories) do
    local b=f.progressBars[cat[1]];local c=counts[cat[1]]
    b:SetMinMaxValues(0,c.total);b:SetValue(c.earned);b.label:SetText(cat[2]);b.rightText:SetText(c.earned.." / "..c.total)
  end
end
function A.Toggle()
  if not A.State() then return end
  if A.window then A.window:SetShown(not A.window:IsShown());A.Refresh();return end
  local f=CreateFrame("Frame","DOINKTripleKAchievements",UIParent,"BasicFrameTemplateWithInset")
  A.window=f;f:SetSize(960,670);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
  f.TitleText:SetText("DOINK - Triple K | Achievement Journal")
  f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetClampedToScreen(true)
  f:SetScript("OnDragStart",function(self) self:StartMoving() end)
  f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  if UIParent.GetWidth and UIParent.GetHeight then f:SetScale(math.min(1,(UIParent:GetWidth()-30)/960,(UIParent:GetHeight()-30)/670)) end
  if UISpecialFrames then table.insert(UISpecialFrames,"DOINKTripleKAchievements") end
  local header=Panel(f,930,66,false);header:SetPoint("TOPLEFT",15,-28)
  local title=Text(header,18);title:SetPoint("TOP",0,-7);title:SetText("Achievement Points")
  f.points=Text(header,23,{1,0.9,0.65});f.points:SetPoint("TOP",0,-29)
  local sub=Text(header,11);sub:SetPoint("BOTTOMLEFT",12,8);sub:SetText("TRIPLE K  |  Custom achievements")
  local search=CreateFrame("EditBox",nil,header,"InputBoxTemplate");search:SetSize(210,24);search:SetPoint("RIGHT",-16,0)
  search:SetAutoFocus(false);search:SetMaxLetters(80);f.search=search
  local prompt=Text(header,11);prompt:SetPoint("BOTTOMRIGHT",-17,5);prompt:SetText("Search achievements")
  search:SetScript("OnTextChanged",function(self) query=self:GetText():lower();page=1;if query~="" then selected="all" end;A.Render() end)
  search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  local sidebar=Panel(f,218,522,true);sidebar:SetPoint("TOPLEFT",15,-99)
  local body=Panel(f,706,522,true);body:SetPoint("TOPLEFT",239,-99)
  f.heading=Text(body,19,{0.27,0.13,0.025});f.heading:SetPoint("TOP",0,-13)
  f.tabs={}
  for i,cat in ipairs(categories) do
    local key=cat[1]
    local b=Button(sidebar,cat[2],196,function() selected,page=key,1;query="";search:SetText("");A.Render() end)
    b:SetPoint("TOPLEFT",11,-14-(i-1)*37)
    b.selected=b:CreateTexture(nil,"OVERLAY");b.selected:SetAllPoints();b.selected:SetColorTexture(0.25,0.6,0.03,0.22)
    f.tabs[i]=b
  end
  local note=Text(sidebar,12,{0.28,0.16,0.06});note:SetPoint("TOPLEFT",17,-365);note:SetWidth(184);note:SetJustifyH("LEFT")
  note:SetText("Your journey, recorded.\n\n10 custom points per achievement.\n\nProgress is always saved locally.\n\nLevels stay local. Choose other categories in Sharing.")
  f.rows={}
  for i=1,PAGE_SIZE do
    local row=Panel(body,676,65,true);row:SetPoint("TOPLEFT",15,-42-(i-1)*70)
    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(46,46);row.icon:SetPoint("LEFT",10,0)
    local band=row:CreateTexture(nil,"ARTWORK");band:SetPoint("TOPLEFT",62,-5);band:SetSize(552,22);band:SetColorTexture(0.22,0.10,0.03,0.92)
    row.title=Text(row,15);row.title:SetPoint("TOPLEFT",66,-8);row.title:SetWidth(545);row.title:SetJustifyH("LEFT")
    row.detail=Text(row,11,{0.20,0.10,0.025});row.detail:SetPoint("TOPLEFT",66,-27);row.detail:SetWidth(545);row.detail:SetJustifyH("LEFT")
    row.bar=Bar(row,545,13);row.bar:SetPoint("BOTTOMLEFT",66,5)
    row.badge=Text(row,18);row.badge:SetPoint("RIGHT",-14,0)
    f.rows[i]=row
  end
  f.empty=Text(body,14,{0.30,0.15,0.04});f.empty:SetPoint("CENTER");f.empty:SetText("No matching achievements.")
  f.overview=CreateFrame("Frame",nil,body);f.overview:SetSize(676,180);f.overview:SetPoint("TOPLEFT",15,-330)
  local progress=Text(f.overview,17,{0.27,0.13,0.025});progress:SetPoint("TOP",0,0);progress:SetText("Progress Overview")
  f.totalBar=Bar(f.overview,660,23);f.totalBar:SetPoint("TOPLEFT",8,-28)
  f.progressBars={}
  for i,cat in ipairs(A.categories) do
    local b=Bar(f.overview,322,23);b:SetPoint("TOPLEFT",8+((i-1)%2)*338,-62-math.floor((i-1)/2)*32);f.progressBars[cat[1]]=b
  end
  f.pagination=CreateFrame("Frame",nil,body);f.pagination:SetSize(676,30);f.pagination:SetPoint("BOTTOM",0,12)
  f.prev=Button(f.pagination,"Previous",100,function() page=page-1;A.Render() end);f.prev:SetPoint("LEFT")
  f.next=Button(f.pagination,"Next",100,function() page=page+1;A.Render() end);f.next:SetPoint("RIGHT")
  f.page=Text(f.pagination,13,{0.27,0.13,0.025});f.page:SetPoint("CENTER")
  f.sharing=Panel(body,666,438,false);f.sharing:SetPoint("TOPLEFT",20,-53)
  f.share=Check(f.sharing,"Share new achievements on Discord","enabled");f.share:SetPoint("TOPLEFT",18,-18)
  f.categoryChecks={}
  for i,cat in ipairs(A.categories) do
    if cat[1] ~= "levels" then
      local c=Check(f.sharing,cat[2],cat[1]);c:SetPoint("TOPLEFT",36,-65-(i-2)*31);f.categoryChecks[cat[1]]=c
    end
  end
  f.photos=Check(f.sharing,"Attach screenshots to shared achievements","screenshot");f.photos:SetPoint("TOPLEFT",18,-300)
  local info=Text(f.sharing,12,{0.9,0.8,0.6});info:SetPoint("TOPLEFT",24,-344);info:SetWidth(615);info:SetJustifyH("LEFT")
  info:SetText("Sharing is off by default. Category choices apply when sharing is on.\nOnly future unlocks are shared; existing progress stays local.\nPhotos require /doink realtime on and include visible game chat and UI.")
  f.bottomTabs={}
  for i,tab in ipairs({{"summary","Summary"},{"all","Achievements"},{"sharing","Sharing"}}) do
    local key=tab[1];local b=Button(f,tab[2],135,function() selected,page=key,1;query="";search:SetText("");A.Render() end)
    b:SetPoint("BOTTOMLEFT",15+(i-1)*140,12);f.bottomTabs[i]=b
  end
  f.summary=Text(f,11);f.summary:SetPoint("BOTTOMRIGHT",-155,20)
  local sync=Button(f,"Sync progress",125,function() A.Sync() end);sync:SetPoint("BOTTOMRIGHT",-15,12)
  f:Show();A.Render()
end
