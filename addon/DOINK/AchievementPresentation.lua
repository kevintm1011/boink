local ADDON,ns=...
local A=ns.Achievements
local function Icon(id,icon,chain,order)
  local e=A.byID[id];if not e then return end
  e.icon=icon;e.chain=chain or e.key;e.order=order or e.target
end
local profIcons={
 [171]="Trade_Alchemy",[164]="Trade_BlackSmithing",[333]="Trade_Engraving",
 [202]="Trade_Engineering",[182]="Trade_Herbalism",[165]="Trade_LeatherWorking",
 [186]="Trade_Mining",[393]="INV_Misc_Pelt_Wolf_01",[197]="Trade_Tailoring",
 [185]="INV_Misc_Food_15",[129]="Spell_Holy_SealOfSacrifice",[356]="Trade_Fishing",
}
for _,e in ipairs(A.catalog) do
  local profession=tonumber(e.id:match("^profession_(%d+)_"))
  if profession then Icon(e.id,profIcons[profession]) end
  if e.category=="levels" then Icon(e.id,"Achievement_Level_"..(e.target==5 and 10 or e.target)) end
  if e.category=="playtime" then Icon(e.id,"INV_Misc_PocketWatch_01") end
end
Icon("epic","INV_Sword_39")
Icon("legendary","INV_Hammer_Unique_Sulfuras")
Icon("mount","Ability_Mount_RidingHorse","mount_collection",1)
Icon("mounts_10","Ability_Mount_RidingHorse","mount_collection",10)
Icon("riding","Ability_Mount_RidingHorse","riding_training",75)
Icon("riding_fast","Ability_Mount_Charger","riding_training",150)
Icon("dual_wield","Ability_DualWield")
Icon("unarmed_300","INV_Gauntlets_04")
-- Recommended starting levels are a browsing order, not entry requirements.
-- New Forever dungeon levels follow Blizzard's October 20 overview.
local dungeons={
 {"rfc",13,"Spell_Fire_SealOfFire"},{"thanes",13,"INV_Hammer_16"},
 {"lordaeron",15,"INV_Misc_Head_Undead_01"},{"wc",17,"Spell_Nature_Sleep"},
 {"deadmines",18,"INV_Misc_Bandana_01"},{"sfk",22,"Spell_Shadow_ChillTouch"},
 {"stockades",24,"INV_Misc_Key_03"},{"excavation",24,"INV_Pick_02"},
 {"bfd",24,"Spell_Frost_SummonWaterElemental"},{"dalaran",28,"Spell_Arcane_PortalDalaran"},
 {"gnomeregan",29,"INV_Gizmo_01"},{"rfk",29,"Spell_Nature_Thorns"},
 {"sm",30,"INV_Misc_Book_06"},{"drowned",35,"INV_Misc_MonsterHead_03"},
 {"rfd",37,"Spell_Shadow_RaiseDead"},{"uldaman",40,"INV_Stone_01"},
 {"kroldok",40,"INV_ThrowingAxe_03"},{"zf",44,"INV_Misc_Idol_03"},
 {"maraudon",46,"Spell_Nature_Earthquake"},{"alcaz",48,"INV_Misc_Key_14"},
 {"st",50,"Spell_Shadow_LifeDrain"},{"brd",52,"Spell_Fire_Volcano"},
 {"brs",55,"INV_Misc_MonsterClaw_04"},{"blackmaw",55,"Ability_Racial_BearForm"},
 {"diremaul",56,"INV_Misc_Eye_01"},{"scholomance",58,"INV_Misc_Bone_ElfSkull_01"},
 {"stratholme",58,"Spell_Shadow_DeathCoil"},{"shapers",58,"INV_Misc_Gem_Crystal_02"},
 {"barrow",60,"Spell_Nature_ForceOfNature"},{"hyjal",60,"Spell_Nature_Tranquility"},
 {"onyxia",60,"INV_Misc_Head_Dragon_01"},
}
for _,d in ipairs(dungeons) do
  Icon("instance_"..d[1],d[3]);local e=A.byID["instance_"..d[1]]
  e.recommendedLevel=d[2]
end
function A.Icon(entry)
  return "Interface\\Icons\\"..(entry.icon or "INV_Misc_Book_09")
end
-- A chain keeps all unlocked tiers in saved data but presents just the next
-- locked tier. Fully completed chains keep their last tier as a trophy.
function A.VisibleEntries(category,query,history)
  local groups,order={},{}
  for _,e in ipairs(A.catalog) do
    if category=="all" or category=="summary" or e.category==category then
      local key=e.chain or e.key
      if not groups[key] then groups[key]={};order[#order+1]=key end
      groups[key][#groups[key]+1]=e
    end
  end
  local result={}
  for _,key in ipairs(order) do
    local chain=groups[key]
    table.sort(chain,function(a,b) return (a.order or a.target)<(b.order or b.target) end)
    local chosen=chain[#chain]
    for _,e in ipairs(chain) do local _,_,earned=A.Progress(e);if not earned then chosen=e;break end end
    for index,e in ipairs(chain) do
      e.tier=index;e.tiers=#chain
      local _,_,earned=A.Progress(e)
      if ((history and earned) or (not history and e==chosen)) and (not query or query=="" or (e.title.." "..e.description):lower():find(query:lower(),1,true)) then
        result[#result+1]=e
      end
    end
  end
  -- Stable category order, then dungeon level (with alphabetical ties).
  local categoryOrder={};for i,c in ipairs(A.categories) do categoryOrder[c[1]]=i end
  local catalogOrder={};for i,e in ipairs(A.catalog) do catalogOrder[e.id]=i end
  table.sort(result,function(a,b)
    if a.category~=b.category then return categoryOrder[a.category]<categoryOrder[b.category] end
    if a.recommendedLevel and b.recommendedLevel then
      if a.recommendedLevel~=b.recommendedLevel then return a.recommendedLevel<b.recommendedLevel end
      return a.title<b.title
    end
    return catalogOrder[a.id]<catalogOrder[b.id]
  end)
  return result
end
