local ADDON,ns=...
local A=ns.Achievements
local L={};A.Leaderboard=L
local PREFIX,REV="DOINKTKLB","020"
local dirty=true
local lastSend=-math.huge
local lastRequest=-math.huge
local nextSend=0
local watcher
local classes={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
local function Key(sender)
  if type(sender)~="string" or ns.IsSecret(sender) or #sender>120 or sender:find("[|\n\r\t]") then return end
  if not sender:find("-",1,true) then sender=sender.."-"..(GetRealmName() or "") end
  return sender:lower():gsub("%s", "")
end
local function Store()
  if not ns.db then return end
  ns.db.leaderboard=ns.db.leaderboard or {}
  return ns.db.leaderboard
end
function L.Enabled() return ns.char and ns.char.leaderboardEnabled~=false end
local function Own()
  if not ns.player or not A.State() then return end
  local bits,earned={},0
  for i,e in ipairs(A.catalog) do
    local _,_,unlocked=A.Progress(e)
    bits[i]=unlocked and "1" or "0";if unlocked then earned=earned+1 end
  end
  return {name=ns.player.key,level=UnitLevel("player"),class=ns.player.class,
    earned=earned,points=earned*10,total=#A.catalog,at=time(),self=true},table.concat(bits)
end
local function Channels()
  local out={}
  if IsInGuild and IsInGuild() then out[#out+1]="GUILD" end
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then out[#out+1]="INSTANCE_CHAT"
  elseif IsInRaid and IsInRaid() then out[#out+1]="RAID"
  elseif IsInGroup and IsInGroup() then out[#out+1]="PARTY" end
  return out
end
local function Send(message)
  local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
  if not fn then return end
  for _,channel in ipairs(Channels()) do pcall(fn,PREFIX,message,channel) end
end
function L.MarkDirty() dirty=true end
function L.SetEnabled(enabled)
  if not ns.char then return end
  if not enabled and L.Enabled() then Send("X1") end
  ns.char.leaderboardEnabled=enabled and true or false
  dirty=true
  if enabled then L.Request() end
  A.Refresh()
end
function L.Request()
  if not L.Enabled() or GetTime()-lastRequest<30 then return end
  lastRequest=GetTime();Send("Q1");dirty=true
end
function L.Tick()
  if not L.Enabled() then return end
  local now=GetTime()
  if now<nextSend or now-lastSend<30 then return end
  if not dirty and now-lastSend<300 then return end
  local row,bits=Own();if not row then return end
  Send("S1|"..REV.."|"..row.level.."|"..row.class.."|"..bits)
  dirty=false;lastSend=now
end
local function Trim(entries)
  local keys={};for key,row in pairs(entries) do
    if type(row)~="table" or type(row.at)~="number" or time()-row.at>90*86400 then entries[key]=nil
    else keys[#keys+1]=key end
  end
  if #keys>500 then
    table.sort(keys,function(a,b) return entries[a].at>entries[b].at end)
    for i=501,#keys do entries[keys[i]]=nil end
  end
end
function L.Receive(prefix,message,channel,sender)
  if prefix~=PREFIX or not L.Enabled() or not ({GUILD=true,PARTY=true,RAID=true,INSTANCE_CHAT=true})[channel] then return end
  if type(message)~="string" or ns.IsSecret(message) or #message>255 then return end
  local key=Key(sender);if not key then return end
  if ns.player and (key==Key(ns.player.key) or key==Key(ns.player.name.."-"..ns.player.realm)) then return end
  if message=="Q1" then
    if not dirty then nextSend=GetTime()+math.random(1,5) end
    dirty=true;return
  end
  local entries=Store();if not entries then return end
  if message=="X1" then entries[key]=nil;A.Refresh();return end
  local rev,level,class,bits=message:match("^S1|(%d+)|(%d+)|([A-Z]+)|([01]+)$")
  level=tonumber(level)
  if rev~=REV or not level or level<1 or level>60 or not classes[class] or #bits~=#A.catalog then return end
  -- Each server-delivered sender can update only their own row. Scores are
  -- self-reported; this is a social leaderboard, not an anti-cheat system.
  local _,earned=bits:gsub("1","")
  entries[key]={name=sender,level=level,class=class,earned=earned,points=earned*10,total=#A.catalog,at=time(),revision=REV}
  Trim(entries);A.Refresh()
end
function L.Rows(query)
  local rows={};local own=Own();if own then rows[#rows+1]=own end
  local entries=Store()
  if entries then
    Trim(entries)
    for key,row in pairs(entries) do
      if row.revision==REV and (not own or key~=Key(own.name)) then rows[#rows+1]=row end
    end
  end
  table.sort(rows,function(a,b)
    if a.points~=b.points then return a.points>b.points end
    if a.level~=b.level then return a.level>b.level end
    return a.name<b.name
  end)
  local filtered={}
  for rank,row in ipairs(rows) do
    row.rank=rank
    if not query or query=="" or row.name:lower():find(query:lower(),1,true) then filtered[#filtered+1]=row end
  end
  return filtered
end
function L.Init()
  Store();dirty=true;nextSend=GetTime()+math.random(2,5)
  local register=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
  if register then pcall(register,PREFIX) end
  if not watcher then
    watcher=CreateFrame("Frame")
    watcher:RegisterEvent("CHAT_MSG_ADDON");watcher:RegisterEvent("GROUP_ROSTER_UPDATE");watcher:RegisterEvent("PLAYER_GUILD_UPDATE")
    watcher:SetScript("OnEvent",function(_,event,...)
      if event=="CHAT_MSG_ADDON" then L.Receive(...) else L.Request() end
    end)
    local elapsed=0
    watcher:SetScript("OnUpdate",function(_,seconds) elapsed=elapsed+seconds;if elapsed>=1 then elapsed=0;L.Tick() end end)
  end
  L.Request()
end
L.Key=Key
L.Revision=REV
L.Prefix=PREFIX
