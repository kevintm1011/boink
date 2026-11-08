local ADDON, ns = ...
local A = ns.Achievements
local selected, page, query = "summary", 1, ""
local PAGE_SIZE = 6
local categories = { {"summary", "Summary"} }
for _, category in ipairs(A.categories) do categories[#categories + 1] = category end
categories[#categories+1]={"leaderboard","Leaderboard"}
local WIDTH,HEIGHT=1200,860
local function ScaleWindow()
  if not A.window then return end
  local scale=(ns.char and ns.char.journalScale) or 1
  if UIParent.GetWidth and UIParent.GetHeight then
    scale=math.min(scale,(UIParent:GetWidth()-24)/WIDTH,(UIParent:GetHeight()-24)/HEIGHT)
  end
  A.window:SetScale(math.max(0.4,scale))
end
local function Text(parent, size, color)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetFont(STANDARD_TEXT_FONT, size or 15, "")
  if color then t:SetTextColor(unpack(color)) end
  return t
end
local function Panel(parent, width, height, parchment)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(width, height)
  if f.SetBackdrop then
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = {left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(parchment and 0.50 or 0.12, parchment and 0.32 or 0.075, parchment and 0.13 or 0.035, parchment and 0.15 or 0.94)
    f:SetBackdropBorderColor(0.65,0.46,0.22,1)
  end
  return f
end
local function Button(parent, label, width, click)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(width,31);b:SetText(label);b:SetScript("OnClick",click);return b
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
  bar.label=Text(bar,14,{1,0.9,0.65});bar.label:SetPoint("LEFT",7,0)
  bar.rightText=Text(bar,13,{1,1,1});bar.rightText:SetPoint("RIGHT",-7,0)
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
    
  end
  rows=A.VisibleEntries(selected=="history" and "all" or selected,query,selected=="history")
  local board=selected=="leaderboard"
  local boardRows=board and A.Leaderboard.Rows(query) or {}
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
  if selected=="history" then heading="Completed Milestones" end
  if board then heading="Character Leaderboard" end
  f.heading:SetText(heading)
  f.points:SetText((total*10).." / "..(#A.catalog*10))
  f.summary:SetText(total.." / "..#A.catalog.." achievements | This character")
  f.sharing:SetShown(sharing);f.overview:SetShown(summary);f.board:SetShown(board)
  f.boardEnabled:SetChecked(A.Leaderboard.Enabled() and true or false)
  f.share:SetChecked(ns:GetOption("achievement","enabled") and true or false)
  f.photos:SetChecked(ns:GetOption("achievement","screenshot") and true or false)
  for key,check in pairs(f.categoryChecks) do check:SetChecked(ns:GetOption("achievement",key) and true or false) end
  for i,b in ipairs(f.tabs) do
    local key=categories[i][1];local c=counts[key]
    b:SetText((selected==key and "|cffb6ff70" or "|cffffd48a")..categories[i][2]..(c and ("  "..c.earned.."/"..c.total) or "").."|r")
    b.selected:SetShown(selected==key)
  end
  local pages=math.max(1,math.ceil((board and #boardRows or #rows)/(board and 8 or PAGE_SIZE)));page=math.max(1,math.min(page,pages))
  local limit=summary and 4 or PAGE_SIZE
  for i,row in ipairs(f.rows) do
    local e=rows[(summary and 0 or (page-1)*PAGE_SIZE)+i]
    row:SetShown(not sharing and not board and i<=limit and e~=nil);row.entry=e
    if e then
      local n,target,earned=A.Progress(e)
      row.icon:SetTexture(A.Icon(e))
      row.title:SetText(e.title);row.title:SetTextColor(1,earned and 0.88 or 0.82,earned and 0.45 or 0.65)
      row.detail:SetText((e.recommendedLevel and ("Recommended level "..e.recommendedLevel.."+  |  ") or "")..e.description)
      row.badge:SetText(earned and "|cffffd16610|r" or "|cff8a765410|r")
      row.bar:SetMinMaxValues(0,target);row.bar:SetValue(n)
      local label= e.category=="playtime" and string.format("%.1f / %d hours",n/3600,target/3600) or (math.floor(n).." / "..target)
      if A.InstanceLabel and not earned then label=A.InstanceLabel(e) or label end
      if earned then label=earned.discovered and "Found on sync" or "Unlocked" end
      if e.tiers and e.tiers>1 then label="Tier "..e.tier.."/"..e.tiers.."  |  "..label end
      row.bar.label:SetText(label);row.bar.rightText:SetText(earned and date and date("%d/%m/%y",earned.at) or "")
    end
  end
  for i,line in ipairs(f.boardRows) do
    local r=boardRows[(page-1)*8+i];line:SetShown(board and r~=nil)
    if r then
      line.rank:SetText(r.rank..".")
      line.name:SetText((r.self and "|cff26751e" or "|cff44280f")..r.name..(r.self and " (you)" or "").."|r")
      line.meta:SetText("Level "..r.level.." "..r.class.."  |  "..r.earned.." / "..r.total.." earned")
      line.points:SetText(r.points.." points")
      local age=math.max(0,time()-r.at)
      line.seen:SetText(r.self and "This character" or (age<60 and "Just seen" or age<3600 and (math.floor(age/60).."m ago") or age<86400 and (math.floor(age/3600).."h ago") or (math.floor(age/86400).."d ago")))
    end
  end
  f.empty:SetShown(not sharing and not board and #rows==0)
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
  local f=CreateFrame("Frame","DOINKTripleKAchievements",UIParent,"BackdropTemplate")
  A.window=f;f:SetSize(WIDTH,HEIGHT);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
  local parchment=f:CreateTexture(nil,"BACKGROUND",nil,-8);parchment:SetAllPoints(f)
  parchment:SetTexture("Interface\\AddOns\\DOINK\\Media\\AchievementParchment")
  local frameTitle=Text(f,20,{0.23,0.10,0.025});frameTitle:SetPoint("TOP",0,-35);frameTitle:SetText("DOINK - TRIPLE K  |  ACHIEVEMENTS")
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-19,-17)
  close:SetScript("OnClick",function() f:Hide() end)
  f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetClampedToScreen(true)
  f:SetScript("OnDragStart",function(self) self:StartMoving() end)
  f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  ScaleWindow()
  if UISpecialFrames then table.insert(UISpecialFrames,"DOINKTripleKAchievements") end
  local header=Panel(f,1136,68,false);header:SetPoint("TOPLEFT",32,-66)
  local title=Text(header,20);title:SetPoint("TOP",0,-7);title:SetText("Achievement Points")
  f.points=Text(header,25,{1,0.9,0.65});f.points:SetPoint("TOP",0,-29)
  local sub=Text(header,11);sub:SetPoint("BOTTOMLEFT",12,8);sub:SetText("YOUR JOURNEY THROUGH AZEROTH")
  local search=CreateFrame("EditBox",nil,header,"InputBoxTemplate");search:SetSize(210,24);search:SetPoint("RIGHT",-16,0)
  search:SetAutoFocus(false);search:SetMaxLetters(80);f.search=search
  local prompt=Text(header,11);prompt:SetPoint("BOTTOMRIGHT",-17,5);prompt:SetText("Search achievements")
  search:SetScript("OnTextChanged",function(self) query=self:GetText():lower();page=1;if query~="" and selected~="leaderboard" and selected~="history" then selected="all" end;A.Render() end)
  search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  local sidebar=Panel(f,224,652,true);sidebar:SetPoint("TOPLEFT",32,-140)
  local body=Panel(f,904,652,true);body:SetPoint("TOPLEFT",264,-140)
  f.heading=Text(body,22,{0.27,0.13,0.025});f.heading:SetPoint("TOP",0,-13)
  f.tabs={}
  for i,cat in ipairs(categories) do
    local key=cat[1]
    local b=Button(sidebar,cat[2],202,function() selected,page=key,1;query="";search:SetText("");A.Render() end)
    b:SetPoint("TOPLEFT",11,-14-(i-1)*39)
    b.selected=b:CreateTexture(nil,"OVERLAY");b.selected:SetAllPoints();b.selected:SetColorTexture(0.25,0.6,0.03,0.22)
    f.tabs[i]=b
  end
  local note=Text(sidebar,14,{0.28,0.16,0.06});note:SetPoint("TOPLEFT",17,-432);note:SetWidth(184);note:SetJustifyH("LEFT")
  note:SetText("One milestone at a time.\n\nThe next tier appears when you unlock this one.\n\nCompleted tiers remain in History.\n\n10 points per achievement.")
  f.rows={}
  for i=1,PAGE_SIZE do
    local row=Panel(body,872,82,true);row:SetPoint("TOPLEFT",16,-49-(i-1)*90)
    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(58,58);row.icon:SetPoint("LEFT",10,0)
    local band=row:CreateTexture(nil,"ARTWORK");band:SetPoint("TOPLEFT",77,-5);band:SetSize(722,25);band:SetColorTexture(0.22,0.10,0.03,0.92)
    row.title=Text(row,18);row.title:SetPoint("TOPLEFT",83,-8);row.title:SetWidth(706);row.title:SetJustifyH("LEFT")
    row.detail=Text(row,13,{0.20,0.10,0.025});row.detail:SetPoint("TOPLEFT",83,-33);row.detail:SetWidth(706);row.detail:SetJustifyH("LEFT")
    row.bar=Bar(row,706,18);row.bar:SetPoint("BOTTOMLEFT",83,5)
    row.badge=Text(row,22);row.badge:SetPoint("RIGHT",-14,0)
    f.rows[i]=row
  end
  f.empty=Text(body,14,{0.30,0.15,0.04});f.empty:SetPoint("CENTER");f.empty:SetText("No matching achievements.")
  f.overview=CreateFrame("Frame",nil,body);f.overview:SetSize(872,194);f.overview:SetPoint("TOPLEFT",16,-428)
  local progress=Text(f.overview,17,{0.27,0.13,0.025});progress:SetPoint("TOP",0,0);progress:SetText("Progress Overview")
  f.totalBar=Bar(f.overview,856,26);f.totalBar:SetPoint("TOPLEFT",8,-28)
  f.progressBars={}
  for i,cat in ipairs(A.categories) do
    local b=Bar(f.overview,420,26);b:SetPoint("TOPLEFT",8+((i-1)%2)*436,-62-math.floor((i-1)/2)*32);f.progressBars[cat[1]]=b
  end
  f.pagination=CreateFrame("Frame",nil,body);f.pagination:SetSize(864,30);f.pagination:SetPoint("BOTTOM",0,12)
  f.prev=Button(f.pagination,"Previous",100,function() page=page-1;A.Render() end);f.prev:SetPoint("LEFT")
  f.next=Button(f.pagination,"Next",100,function() page=page+1;A.Render() end);f.next:SetPoint("RIGHT")
  f.page=Text(f.pagination,13,{0.27,0.13,0.025});f.page:SetPoint("CENTER")
  f.sharing=Panel(body,864,558,false);f.sharing:SetPoint("TOPLEFT",20,-53)
  f.share=Check(f.sharing,"Share new achievements on Discord","enabled");f.share:SetPoint("TOPLEFT",18,-18)
  f.categoryChecks={}
  for i,cat in ipairs(A.categories) do
    if cat[1] ~= "levels" then
      local c=Check(f.sharing,cat[2],cat[1]);c:SetPoint("TOPLEFT",36,-65-(i-2)*31);f.categoryChecks[cat[1]]=c
    end
  end
  f.photos=Check(f.sharing,"Attach screenshots to shared achievements","screenshot");f.photos:SetPoint("TOPLEFT",18,-320)
  local info=Text(f.sharing,15,{0.9,0.8,0.6});info:SetPoint("TOPLEFT",24,-370);info:SetWidth(800);info:SetJustifyH("LEFT")
  info:SetText("Sharing is off by default. Category choices apply when sharing is on.\nOnly future unlocks are shared; existing progress stays local.\nPhotos require /doink realtime on and include visible game chat and UI.")
  f.board=CreateFrame("Frame",nil,body);f.board:SetAllPoints(body)
  local boardInfo=Text(f.board,14,{0.28,0.15,0.04});boardInfo:SetPoint("TOPLEFT",22,-45);boardInfo:SetWidth(850);boardInfo:SetJustifyH("LEFT")
  boardInfo:SetText("Guild & group characters · self-reported scores · last-seen snapshots, not live online status")
  f.boardEnabled=CreateFrame("CheckButton",nil,f.board,"UICheckButtonTemplate");f.boardEnabled:SetSize(26,26);f.boardEnabled:SetPoint("TOPLEFT",19,-73)
  local enabledLabel=Text(f.board,14,{0.28,0.15,0.04});enabledLabel:SetPoint("LEFT",f.boardEnabled,"RIGHT",4,0);enabledLabel:SetText("Share my score with guild and group addon users")
  f.boardEnabled:SetScript("OnClick",function(self) A.Leaderboard.SetEnabled(self:GetChecked()) end)
  local refresh=Button(f.board,"Refresh scores",145,function() A.Leaderboard.Request();A.Render() end);refresh:SetPoint("TOPRIGHT",-22,-72)
  f.boardRows={}
  for i=1,8 do
    local line=Panel(f.board,860,55,true);line:SetPoint("TOPLEFT",22,-116-(i-1)*59)
    line.rank=Text(line,20,{0.36,0.20,0.05});line.rank:SetPoint("LEFT",12,0)
    line.name=Text(line,17);line.name:SetPoint("TOPLEFT",58,-8);line.name:SetWidth(560);line.name:SetJustifyH("LEFT")
    line.meta=Text(line,12,{0.30,0.20,0.10});line.meta:SetPoint("BOTTOMLEFT",58,8)
    line.points=Text(line,18,{0.32,0.16,0.015});line.points:SetPoint("TOPRIGHT",-14,-7)
    line.seen=Text(line,12,{0.35,0.25,0.14});line.seen:SetPoint("BOTTOMRIGHT",-14,8)
    f.boardRows[i]=line
  end
  f.bottomTabs={}
  for i,tab in ipairs({{"summary","Summary"},{"all","Achievements"},{"sharing","Sharing"},{"history","History"},{"leaderboard","Leaderboard"}}) do
    local key=tab[1];local b=Button(f,tab[2],130,function() selected,page=key,1;query="";search:SetText("");A.Render() end)
    b:SetPoint("BOTTOMLEFT",32+(i-1)*134,24);f.bottomTabs[i]=b
  end
  f.summary=Text(f,11);f.summary:SetPoint("BOTTOMRIGHT",-177,68)
  local sync=Button(f,"Sync progress",125,function() A.Sync() end);sync:SetPoint("BOTTOMRIGHT",-32,24)
  for i,delta in ipairs({-0.1,0.1}) do
    local resize=Button(f,delta<0 and "-" or "+",30,function()
      ns.char.journalScale=math.max(0.7,math.min(1.4,(ns.char.journalScale or 1)+delta));ScaleWindow()
    end);resize:SetPoint("BOTTOMRIGHT",-166-(2-i)*34,24)
  end
  local scaleWatcher=CreateFrame("Frame",nil,f);scaleWatcher:RegisterEvent("UI_SCALE_CHANGED");scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
  scaleWatcher:SetScript("OnEvent",ScaleWindow)
  f:Show();A.Render()
end
