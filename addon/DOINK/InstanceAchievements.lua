local ADDON, ns = ...
local A = ns.Achievements
-- Client encounter rosters are authoritative: never guess new Forever boss IDs.
-- Every listed encounter must have a successful ENCOUNTER_END observed locally.
-- Progress can span visits; joining someone else's cleared lockout grants nothing.
local instances = {
  {"rfc", "Ragefire Chasm", 389}, {"wc", "Wailing Caverns", 43},
  {"deadmines", "The Deadmines", 36}, {"sfk", "Shadowfang Keep", 33},
  {"bfd", "Blackfathom Deeps", 48}, {"stockades", "The Stockade", 34},
  {"gnomeregan", "Gnomeregan", 90}, {"rfk", "Razorfen Kraul", 47},
  {"sm", "Scarlet Monastery", 189}, {"rfd", "Razorfen Downs", 129},
  {"uldaman", "Uldaman", 70}, {"zf", "Zul'Farrak", 209},
  {"maraudon", "Maraudon", 349}, {"st", "The Temple of Atal'Hakkar", 109},
  {"brd", "Blackrock Depths", 230}, {"brs", "Blackrock Spire", 229},
  {"diremaul", "Dire Maul", 429}, {"scholomance", "Scholomance", 289},
  {"stratholme", "Stratholme", 329},
  {"thanes", "Hall of Thanes"}, {"lordaeron", "Ruins of Lordaeron"},
  {"excavation", "Excavation Site"}, {"dalaran", "City of Dalaran"},
  {"drowned", "The Drowned City"}, {"kroldok", "Krol'dok Stronghold"},
  {"alcaz", "Alcaz Prison"}, {"blackmaw", "Blackmaw Hold"},
  {"shapers", "Shaper's Terrace"},
  {"barrow", "Barrow Deeps", nil, true}, {"hyjal", "Hyjal Summit", nil, true},
  {"onyxia", "Onyxia's Lair", 249, true},
}
local byKey, byMap, byName = {}, {}, {}
local function Normalize(s)
  if type(s)~="string" or ns.IsSecret(s) then return "" end
  return s:lower():gsub("’", "'"):gsub("^the ", ""):gsub("[^%w]", "")
end
for _,v in ipairs(instances) do
  local key="instance_"..v[1]
  A.Add(key, v[4] and "raids" or "dungeons", v[2].." — full clear",
    v[4] and "Opens Dec 9, 2026. Defeat every client-listed boss; visits can be combined."
      or "Defeat every client-listed boss, including all wings. Visits can be combined.",key,1)
  byKey[key]=v;v.key=key
  if v[3] then byMap[v[3]]=v end
  byName[Normalize(v[2])]=v
end
byName.stockades=byName.stockade
byName.sunkentemple=byName.templeofatalhakkar
byName.lowerblackrockspire=byName.blackrockspire
byName.upperblackrockspire=byName.blackrockspire
local function Find(name, map)
  if byMap[map] then return byMap[map] end
  local n=Normalize(name)
  if byName[n] then return byName[n] end
  for prefix,v in pairs(byName) do
    if n:sub(1,#prefix)==prefix then return v end
  end
end
local function Safe(fn,...)
  if type(fn)~="function" then return end
  local function Pack(...) return {n=select("#",...),...} end
  local results=Pack(pcall(fn,...))
  if not results[1] then return end
  for i=2,results.n do if ns.IsSecret(results[i]) then return end end
  return unpack(results,2,results.n)
end
local rosters, ready = {}, {}
local function State(v)
  local db=A.State(); if not db then return end
  db.instances=db.instances or {}
  db.instances[v.key]=db.instances[v.key] or {kills={}}
  return db.instances[v.key]
end
function A.LoadInstanceRosters()
  rosters,ready={},{}
  local ids={}
  for _,list in ipairs({LFDDungeonList or {}, LFRRaidList or {}}) do
    for _,id in pairs(list) do if type(id)=="number" and id>0 then ids[id]=true end end
  end
  if C_LFGInfo and C_LFGInfo.GetAllEntriesForCategory then
    for _,category in ipairs({1,3}) do
      local list=Safe(C_LFGInfo.GetAllEntriesForCategory,category)
      if type(list)=="table" then for _,id in ipairs(list) do ids[id]=true end end
    end
  end
  local invalid={}
  for id in pairs(ids) do
    local name=Safe(GetLFGDungeonInfo,id)
    if not name and C_LFGInfo then
      local info=Safe(C_LFGInfo.GetDungeonInfo,id);name=type(info)=="table" and info.name
    end
    local v=Find(name)
    if v then
      local count=Safe(GetLFGDungeonNumEncounters,id)
      if type(count)~="number" or count<1 or count>100 then invalid[v.key]=true
      else
        rosters[v.key]=rosters[v.key] or {}
        for i=1,count do
          local boss=Safe(GetLFGDungeonEncounterInfo,id,i)
          if type(boss)=="string" and boss~="" then rosters[v.key][boss]=true
          else invalid[v.key]=true end
        end
      end
    end
  end
  for key in pairs(rosters) do ready[key]=not invalid[key] end
end
local function Progress(v)
  local state=State(v); local n,total=0,0
  if state then for boss in pairs(rosters[v.key] or {}) do
    total=total+1;if state.kills[boss] then n=n+1 end
  end end
  return n,total
end
function A.InstanceLabel(entry)
  local v=byKey[entry.id];if not v then return end
  local n,total=Progress(v)
  if not ready[v.key] then return "Awaiting complete client boss roster" end
  return n.." / "..total.." bosses defeated"
end
function A.InstanceEvent(event, encounterID, boss, difficulty, size, success)
  if event~="ENCOUNTER_END" then A.LoadInstanceRosters();A.Refresh();return end
  if ns.IsSecret(success) or (success~=1 and success~=true) or ns.IsSecret(boss) or type(boss)~="string" then return end
  local name,kind,_,_,_,_,_,map=Safe(GetInstanceInfo)
  if kind~="party" and kind~="raid" then return end
  local v=Find(name,map);if not v then return end
  local state=State(v);if not state then return end
  state.kills[boss]=true
  A.LoadInstanceRosters()
  local n,total=Progress(v)
  if ready[v.key] and total>0 and n==total then A.Advance(v.key,1,false) end
  A.Refresh()
end
local watcher
function A.InitInstances()
  A.LoadInstanceRosters()
  if watcher then return end
  watcher=CreateFrame("Frame")
  watcher:SetScript("OnEvent",function(_,...) A.InstanceEvent(...) end)
  for _,event in ipairs({"ENCOUNTER_END","PLAYER_ENTERING_WORLD","LFG_UPDATE","LFG_LOCK_INFO_RECEIVED"}) do
    pcall(watcher.RegisterEvent,watcher,event)
  end
end
