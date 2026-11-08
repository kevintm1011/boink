local ADDON, ns = ...

-- Local progress is independent of notifier/Discord filters. Never infer
-- purchase history: training achievements mean the skill is known.
local A = { catalog = {}, byID = {}, categories = {
  { "levels", "Levels" }, { "professions", "Professions" },
  { "playtime", "Playtime" }, { "equipment", "Equipment" },
  { "mounts", "Mounts" }, { "training", "Training" },
  { "dungeons", "Dungeons" }, { "raids", "Raids" },
} }
ns.Achievements = A
local function Add(id, category, title, description, key, target)
  local entry = { id = id, category = category, title = title,
    description = description, key = key, target = target }
  A.catalog[#A.catalog + 1], A.byID[id] = entry, entry
  return entry
end
for _, n in ipairs({ 5, 10, 20, 30, 40, 50, 60 }) do
  Add("level_" .. n, "levels", "Level " .. n, "Reach character level " .. n .. ".", "level", n)
end
local professions = {
  {171, "Alchemy", 2259}, {164, "Blacksmithing", 2018}, {333, "Enchanting", 7411},
  {202, "Engineering", 4036}, {182, "Herbalism", 2366}, {165, "Leatherworking", 2108},
  {186, "Mining", 2575}, {393, "Skinning", 8613}, {197, "Tailoring", 3908},
  {185, "Cooking", 2550}, {129, "First Aid", 3273}, {356, "Fishing", 7620},
}
for _, prof in ipairs(professions) do
  for _, rank in ipairs({75, 150, 225, 300}) do
    Add("profession_" .. prof[1] .. "_" .. rank, "professions", prof[2] .. " " .. rank,
      "Reach " .. rank .. " skill in " .. prof[2] .. ".", "profession_" .. prof[1], rank)
  end
end
for _, hours in ipairs({1, 5, 10, 24, 72, 100, 168, 250, 500, 1000}) do
  Add("played_" .. hours, "playtime", hours .. " hours of adventure",
    "Accumulate " .. hours .. " hours of /played time on this character.", "played", hours * 3600)
end
Add("epic", "equipment", "Epic find", "Acquire an epic weapon or armor piece (quality 4).", "epic", 1)
Add("legendary", "equipment", "Legendary find", "Acquire a legendary weapon or armor piece (quality 5).", "legendary", 1)
Add("mount", "mounts", "My first mount", "Own a mount item or a collected mount in the journal.", "mount", 1)
Add("riding", "training", "Ready to ride", "Learn riding (skill rank 75 or Apprentice Riding).", "riding", 1)
Add("riding_fast", "training", "A faster ride", "Learn riding rank 150 or Journeyman Riding.", "riding_fast", 1)
Add("dual_wield", "training", "Two hands, two weapons", "Learn Dual Wield. Only available to eligible classes.", "dual_wield", 1)

Add("mounts_10", "mounts", "A stable of my own", "Collect 10 distinct mounts.", "mount_count", 10)
Add("unarmed_300", "training", "Master of bare hands", "Reach 300 base skill in Unarmed (level 60 maximum).", "unarmed", 300)
A.Add = Add

local db, elapsed, playedAnchor, playedAt, awaitingPlayedBaseline
local pending = {} -- item ID -> true for baseline, false for a new acquisition
local watcher, inventoryDirty, baselineUntil
local function Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local function Pack(...) return { n = select("#", ...), ... } end
  local result = Pack(pcall(fn, ...))
  if not result[1] then return nil end
  for i = 2, result.n do if ns.IsSecret(result[i]) then return nil end end
  return unpack(result, 2, result.n)
end
local function Number(n) return type(n) == "number" and not ns.IsSecret(n) and n >= 0 end
function A.Refresh()
  if A.window and A.window:IsShown() then A.Render() end
end
function A.Advance(key, value, baseline)
  if not db or not Number(value) then return end
  db.values[key] = math.max(db.values[key] or 0, value)
  for _, entry in ipairs(A.catalog) do
    if entry.key == key and db.values[key] >= entry.target and not db.unlocked[entry.id] then
      db.unlocked[entry.id] = { at = time(), discovered = baseline and true or false }
      if A.Leaderboard then A.Leaderboard.MarkDirty() end
      if not baseline and entry.category ~= "levels" then
        ns:Print("|cffffd166Achievement unlocked: %s|r", entry.title)
        if ns:GetOption("achievement", "enabled") and ns:GetOption("achievement", entry.category) then
          ns:Emit("achievement", { id = entry.id, title = entry.title,
            description = entry.description, category = entry.category })
        end
      end
    end
  end
end
function A.Progress(entry)
  return math.min((db and db.values[entry.key]) or 0, entry.target), entry.target,
    db and db.unlocked[entry.id]
end
function A.State() return db end

local function SpellKnown(id)
  if Safe(IsPlayerSpell, id) or Safe(IsSpellKnown, id) then return true end
  if C_SpellBook and Safe(C_SpellBook.IsSpellKnown, id) then return true end
  return false
end
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = Safe(C_Spell.GetSpellInfo, id)
    if type(info) == "table" and not ns.IsSecret(info.name) then return info.name end
  end
  return Safe(GetSpellInfo, id)
end
local function ProfessionID(name)
  for _, prof in ipairs(professions) do
    if name == prof[2] or name == SpellName(prof[3]) then return prof[1] end
  end
end
local function Skill(name, rank, id, baseline)
  if not Number(rank) then return end
  if id == 162 or name == "Unarmed" or name == SpellName(203) then
    A.Advance("unarmed", rank, baseline); return
  end
  local recognized = id == 762
  for _, prof in ipairs(professions) do if id == prof[1] then recognized = true; break end end
  if not recognized then id = ProfessionID(name) end
  if id then A.Advance("profession_" .. id, rank, baseline) end
  if id == 762 or name == SpellName(33388) or name == "Riding" then
    if rank >= 75 then A.Advance("riding", 1, baseline) end
    if rank >= 150 then A.Advance("riding_fast", 1, baseline) end
  end
end
function A.ScanSkills(baseline)
  if GetProfessions and GetProfessionInfo then
    local indices = { Safe(GetProfessions) }
    -- Profession slots can have holes (e.g. Fishing with no primary profession).
    for i = 1, 6 do
      if indices[i] then
        local name, _, rank, _, _, _, skillID = Safe(GetProfessionInfo, indices[i])
        Skill(name, rank, skillID, baseline)
      end
    end
  end
  local count = Safe(GetNumSkillLines)
  if Number(count) and GetSkillLineInfo then
    for i = 1, math.min(count, 500) do
      local name, header, _, rank = Safe(GetSkillLineInfo, i)
      if not header then Skill(name, rank, nil, baseline) end
    end
  end
  if SpellKnown(674) then A.Advance("dual_wield", 1, baseline) end
  if SpellKnown(33388) or SpellKnown(33391) then A.Advance("riding", 1, baseline) end
  if SpellKnown(33391) then A.Advance("riding_fast", 1, baseline) end
end
function A.CheckItem(item, baseline)
  local id = tonumber(item) or (type(item) == "string" and tonumber(item:match("item:(%d+)")))
  if id and pending[id] == true then baseline = true end
  local info = C_Item and C_Item.GetItemInfo or GetItemInfo
  local name, _, quality, _, _, _, _, _, _, _, _, classID, subclassID = Safe(info, item)
  if not name then
    if id then
      if pending[id] == nil then pending[id] = baseline and true or false end
      if C_Item and C_Item.RequestLoadItemDataByID then Safe(C_Item.RequestLoadItemDataByID, id) end
    end
    return
  end
  if id then pending[id] = nil end
  if not classID then
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local _, _, _, _, _, c, sub = Safe(instant, item)
    classID, subclassID = c, sub
  end
  if classID == 2 or classID == 4 then
    if quality == 4 then A.Advance("epic", 1, baseline) end
    if quality == 5 then A.Advance("legendary", 1, baseline) end
  end
  if classID == 15 and subclassID == 5 then
    A.Advance("mount", 1, baseline)
    -- Journal is authoritative where present; never count its mount twice as an item.
    if id and not (C_MountJournal and C_MountJournal.GetMountIDs) then
      db.mountItems = db.mountItems or {}; db.mountItems[id] = true
      local n=0; for _ in pairs(db.mountItems) do n=n+1 end
      A.Advance("mount_count", n, baseline)
    end
  end
end
function A.ScanInventory(baseline)
  for slot = 1, 19 do
    local link = Safe(GetInventoryItemLink, "player", slot)
    if link then A.CheckItem(link, baseline) end
  end
  local size = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
  local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
  for bag = 0, 4 do
    local n = Safe(size, bag)
    if Number(n) then
      for slot = 1, math.min(n, 100) do
        local link = Safe(getLink, bag, slot)
        if link then A.CheckItem(link, baseline) end
      end
    end
  end
  if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
    local ids = Safe(C_MountJournal.GetMountIDs)
    if type(ids) == "table" then
      local count=0
      for _, id in ipairs(ids) do
        local _, _, _, _, _, _, _, _, _, _, collected = Safe(C_MountJournal.GetMountInfoByID, id)
        if collected then count=count+1 end
      end
      if count>0 then A.Advance("mount", 1, baseline) end
      A.Advance("mount_count", count, baseline)
    end
  end
end
function A.Sync()
  A.Advance("level", math.max(Safe(UnitLevel, "player") or 0, ns.knownLevel or 0), true)
  A.ScanSkills(true)
  A.ScanInventory(true)
  if RequestTimePlayed then Safe(RequestTimePlayed) end
  A.Refresh()
end
local patterns = {}
for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
  if type(_G[name]) == "string" then patterns[#patterns + 1] = ns.FormatToPattern(_G[name]) end
end
local skillPattern = SKILL_RANK_UP and ns.FormatToPattern(SKILL_RANK_UP)
function A.Event(event, ...)
  if not db then return end
  if event == "PLAYER_LEVEL_UP" then
    A.Advance("level", ..., false)
  elseif event == "TIME_PLAYED_MSG" then
    local total = ...
    if Number(total) then
      playedAnchor, playedAt = total, GetTime()
      A.Advance("played", total, awaitingPlayedBaseline)
      awaitingPlayedBaseline = false
    end
  elseif event == "CHAT_MSG_SKILL" then
    local message = ...
    if skillPattern and type(message) == "string" and not ns.IsSecret(message) then
      local name, rank = message:match(skillPattern)
      if name then Skill(name, tonumber(rank), nil, false) end
    end
    A.ScanSkills(false)
  elseif event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
    A.ScanSkills(false)
  elseif event == "CHAT_MSG_LOOT" then
    local message = ...
    if type(message) == "string" and not ns.IsSecret(message) then
      for _, pattern in ipairs(patterns) do
        local link = message:match(pattern)
        if link then A.CheckItem(link, false); break end
      end
    end
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    local id, success = ...
    if pending[id] ~= nil then
      local baseline = pending[id]; pending[id] = nil
      if success then A.CheckItem(id, baseline) end
    end
  elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    inventoryDirty = true
  elseif event == "NEW_MOUNT_ADDED" then
    A.ScanInventory(false)
  end
  A.Refresh()
end
function A.Tick(seconds)
  if not db then return end
  elapsed = (elapsed or 0) + seconds
  if inventoryDirty and elapsed >= 1 then
    inventoryDirty = false
    A.ScanInventory(GetTime() < (baselineUntil or 0)); A.Refresh()
  end
  if elapsed < 10 then return end
  elapsed = 0
  if playedAnchor then A.Advance("played", playedAnchor + math.max(0, GetTime() - playedAt), false) end
  A.Refresh()
end
function A.Init()
  ns.char.achievements = ns.char.achievements or { values = {}, unlocked = {} }
  db = ns.char.achievements
  db.values, db.unlocked = db.values or {}, db.unlocked or {}
  playedAnchor, playedAt, elapsed, awaitingPlayedBaseline = nil, nil, 0, true
  pending = {}
  inventoryDirty, baselineUntil = false, GetTime() + 5
  A.Sync()
  if A.InitInstances then A.InitInstances() end
  if A.AttachCharacterButton then A.AttachCharacterButton() end
  if A.Leaderboard then A.Leaderboard.Init() end
  if not watcher then
    watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", function(_, event, ...) A.Event(event, ...) end)
    watcher:SetScript("OnUpdate", function(_, seconds) A.Tick(seconds) end)
    for _, event in ipairs({ "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG", "CHAT_MSG_SKILL", "SKILL_LINES_CHANGED",
      "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "CHAT_MSG_LOOT", "GET_ITEM_INFO_RECEIVED", "NEW_MOUNT_ADDED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
      pcall(watcher.RegisterEvent, watcher, event)
    end
  end
end
-- This notifier exposes /doink options achievement, but detection is independent.
ns.Notifiers.Achievement = { type = "achievement", events = {}, OnEvent = function() end,
  Test = function() return { id = "test", title = "A new adventure", category = "levels",
    description = "Test achievement from DOINK - Triple K." } end }
