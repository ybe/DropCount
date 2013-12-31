--[[****************************************************************
	LootCount DropCount v1.50

	Author: Evil Duck
	****************************************************************

	For the game World of Warcraft
	Stand-alone addon, and plug-in for the add-on LootCount.

	****************************************************************]]

-- 1.50 loot-grid with filter options, added metatable database
--      code (automatic pack/unpack/cache), lower cpu impact in combat,
--      MT'd best area update, fixed erroneous kill-counts for gathering-loot,
--      fixed bug in options for database reduction, added gathering profs
--      data, various small changes
-- 1.42 Skipped 5.2's added money loot
-- 1.40 Added forges and trainers, new icon plot code (compacted), merge
--      forges and trainers, options gui, BG DB cleaning, selective
--      exclusion of DB sections, compact TT option, 'Count' added to
--      database removal code
-- 1.36 DuckMod removed, database update
-- 1.34d4 DuckMod v2.9906, database update
-- 1.34d3 DuckMod v2.10, database update
-- 1.34d2 DuckMod v2.08, database update
-- 1.32 Fixed cache-bug (implied merge), added tt-toggle for mobs, new
--      version DuckMod
-- 1.30 Added clean-up for morons who think they can edit the database
--      themselves, 4.2 combat-event, other minor changes for the morons
-- 1.26 Fix for remote (most) quest recording, flaw-fix for null-kills
-- 1.24 Fix for WoW v4.1 (combat event), more fixes
-- 1.22 Fixed background non-existent done quests, bugfixes, new database
-- 1.20 Cataclysm - Several changes, new database
-- 1.00 WoW 4
-- 0.82 fixed a bug in "DB.Purge", included correct database
-- 0.80 separated instance and world drop areas, changed quest faction
--      to player faction, less memory-intentsive at DB.Write, time-sliced
--      removal of mobs from item drop-list, tuned cpu-load at merge a
--      bit more, fixed bug in quest-convert (seven) that could lose
--      area-names, minor sorting in NPC quests, fixed a bug in item
--      search, added search for area by item, added search GUI, purge
--      cache after merge
-- 0.76 added lower limit for merge throttle, added check for duplicate
--      q-givers in multiple factions, remove zero-items from vendors
--      when visiting them, moblist on <alt> + mouseover is now sorted
--      by kills and ratio (was ratio only with low limit of 10 kills),
--      limited best area to outside instances due to instance spawn-rates,
--      fixed bug in faction assignment for q-givers
-- 0.74 Faster build-up of burst, fixed rare read-bug, added clean-up
--      for missing mobs, fixed bug in worldmap icon draw, added repair-
--      option for maps, resolved a few system-load issues, added best
--      drop-area for items, changed check for valid zones
-- 0.71a Fix for empty hardcoded databases
-- 0.71 Various bug-fixes, done quests not shown in MM
-- 0.70a Fixed some bugs in memory compression that resulted in erroneous storage
-- 0.70 Complete code clean-up, XML-change to fit the new worldmap
--      (mouse-over works again), added (un)read in book tooltip,
--      all item-questgivers forced to neutral, database clean-up code,
--      items dropped only once by a mob will be hidden (/lcdc single) -
--      does not apply to profession loot, fixed bug in database merge,
--      "removed" lag when showing drop-list, added compressed data,
--      tweaked map-icons display, several other optimizations,
--      included database v4 (52b(139)/1552v/2945q/4788i/5488m)
-- 0.58 Internal work-version
-- 0.56 Bugfix in guild-sharing to better support the new profession system,
--      fixed quest-icon in menu, added quest area,
--      included database v3 (50b/1421v/974q/3792i/4759m)
-- 0.54 Updates the done quests with server-provided data, bugfix in
--      profession-loot, added mob-update, show/hide quests in maps
-- 0.50 Coloured quest-titles, tweaked cache speed, upgraded to DuckMod 2.0,
--      added support for profession-loot from mobs, added prebuilt database
-- 0.40 Added quests-givers, tracking of quests done, where quests start
-- 0.32 Added repair-vendor display
-- 0.30b Quick bugfix
-- 0.30a Fixed dependency-bug
-- 0.30 Added vendors: minimap/worldmap/search, added books: minimap/worldmap/search
-- 0.20 Added support for sharing data in guild, some bugfixes
-- 0.10 First version


BINDING_HEADER_DROPCOUNT = "DropCount hotkeys";
BINDING_NAME_DC_TOGGLEFILTERFRAME = "Open worldmap filter selector";
BINDING_NAME_DC_TOGGLEITEMFILTER = "Track item on worldmap (toggle)";

local _;
local VERSIONt="1.50";		-- current version text
local VERSIONn=tonumber(VERSIONt);
LOOTCOUNT_DROPCOUNT_VERSIONTEXT = "DropCount v"..VERSIONt;
LOOTCOUNT_DROPCOUNT = "DropCount";
SLASH_DROPCOUNT1 = "/dropcount";
SLASH_DROPCOUNT2 = "/lcdc";
local DM_WHO="LCDC";

--DropCount={			-- profiling
local DropCount={		-- release
	Loaded=nil,
	Debug=nil,
	Update=0,
	LootCount={ Menu_ClickedButton=nil, },
	VendorReadProblem=nil,		-- indicate to vendor scanner that previous attempt was erroneous
	ProfessionLootMob=nil,		-- profsession-loot on a mob
	ItemTextFrameHandled=nil,	-- the open textframe has been dealt with
	Tooltip={},					-- tooltip-related functions
	TooltipExtras={},			-- extra functionality for tooltips
	Event={},					-- event-related functions
	OnUpdate={},				-- functions for OnUpdate
	Hook={},					-- container for hooks and related functionality
	Map={},						-- map functionality
	Crawler={},					-- crawler support
	MT={						-- everything multitasking
		Icons={},				-- icon hadling
		DB={ Maintenance={}, },	-- database handling
	},
	Quest={},					-- everything quest
	Target={					-- everything about selected or focused dude
		MyKill=nil,
		GUID="0x0",
		Skin=nil,
		UnSkinned=nil,
		LastAlive=nil,
		LastFaction=nil,
		CurrentAliveFriendClose=nil,
		OpenMerchant=nil,
	},
	Tracker={					-- tracking stuff
		Gather=nil,
		LastListType=nil,
		Looted={},
		Skinned={},
		TimedQueue={},
		QueueSize=0,
		ConvertQuests=0,		-- Quests to convert to new format
		UnknownItems=nil,
		RequestedItem=nil,
		Elapsed=0,
		Exited=true,
		Merge={
			Total=-1,
			Goal=0,
			Mobs=-1,
			MobsGoal=0,
			Book={ New=0, Updated=0, },
			Quest={ New={}, Updated={}, },
			Vendor={ New={}, Updated={}, },
			Mob={ New=0, Updated=0, },
			Item={ New=0, Updated=0, },
			Forge={ New=0, Updated=0, },
			Trainer={ New={}, Updated={}, },
			Grid={ New=0, Updated=0, },
			Nodes={ New=0, Updated=0, },
			Gather={ New=0, Updated=0, },
		},
		CleanImport={ Cleaned=nil, Okay=0, Deleted=0, },
	},
	Cache={						-- everything cache
		Timer=6,
		Retries=0,
		CachedConvertItems=0,	-- Items requested from server when converting DB
	},
	Search={					-- everything search
		_section="",
		_result={},
	},
	Timer={						-- "everything" timer
		VendorDelay=-1,
		StartupDelay=5,
		PrevQuests=-1,
	},
	WoW5={},					-- everything WoW5 (basically a converter)
};
DropCountXML={
	Icon={
		MM={},
		WM={},
		Vendor={},
		VendorMM={},
		Book={},
		BookMM={},
		Quest={};
		QuestMM={};
		Forge={};
		ForgeMM={};
	},
};

local CONST={
	LOOTEDAGE=1200,
	PERMANENTITEM=-1,		-- permanent vendor item
	UNKNOWNCOUNT=-2,
	C_BASIC="|cFF00FFFF",	-- AARRGGBB
	C_GREEN="|cFF00FF00",
	C_RED="|cFFFF0000",
	C_LBLUE="|cFF6060FF",
	C_HBLUE="|cFEA0A0FF",		-- highlight
	C_YELLOW="|cFFFFFF00",
	C_WHITE="|cFFFFFFFF",
	LISTLENGTH=25,
	KILLS_UNRELIABLE=10,
	KILLS_RELIABLE=50,
	RESCANQUESTS=1.5,
	QUEUETIME=900,
	QUESTID=nil,
	CACHESPEED=1/3,
	CACHEMAXRETRIES=10,
	QUESTRATIO=-1,
	PROFESSIONS={},
	PROFICON={},
	ZONES=nil,
	MYFACTION=nil,
	QUEST_UNKNOWN=0,
	QUEST_DONE=1,
	QUEST_STARTED=2,
	QUEST_NOTSTARTED=3,
	WM_W=100, WMSQ_W=1,
	WM_H=100, WMSQ_H=1,
};
local nagged=nil;
local Basic=CONST.C_BASIC;
local Green=CONST.C_GREEN;
local Red=CONST.C_RED;
local Blue="|cFF0000FF";		-- blue
local lBlue=CONST.C_LBLUE;		-- light blue
local hBlue=CONST.C_HBLUE;		-- highlight
local Yellow=CONST.C_YELLOW;
local White=CONST.C_WHITE;

-- Table handling
local Table={
	v03={},
	LastPackerVersion="03",
	tableSlowCompress={},
	Scrap={},
	Default={ Default={ UseCache=true, Base=nil, }, },
};
Table[1]={ Entry ="\1", String="\1\1", Number="\1\2", Bool="\1\3", Nil="\1\4", Other ="\1\9", sTable="\2", eTable="\3", Version="\4", ThisVersion="1", Last="\4", };
Table[2]={ Entry ="\2", String="\2\7", Number="\2\2", Bool="\2\3", Nil="\2\4", Other ="\2\9", sTable="\3", eTable="\4", Version="\7", ThisVersion="2", Last="\7", };
Table.CV=2;
Table.Entry=Table[Table.CV].Entry; Table.String=Table[Table.CV].String; Table.Number=Table[Table.CV].Number; Table.Bool=Table[Table.CV].Bool;
Table.Nil=Table[Table.CV].Nil; Table.Other=Table[Table.CV].Other; Table.sTable=Table[Table.CV].sTable; Table.eTable=Table[Table.CV].eTable;
Table.Version=Table[Table.CV].Version; Table.ThisVersion=Table[Table.CV].ThisVersion; Table.Last=Table[Table.CV].Last;

local MT={
	LastStack="",
	Current=0,
	Count=0,
	Speed=(1/30)*1000,		-- regular, fixed, noticable by user
	FastMT=(1/100)*1000,	-- adaptable, virtually un-noticable
	LastTime=0,
	Threads={ },
};

-- Saved per character
LootCount_DropCount_Character={ ShowZone=true, };

-- Global save
LootCount_DropCount_DB={};
local dcdb;
LootCount_DropCount_Maps={}
LootCount_DropCount_NoQuest = {
	[10593] = true,
	[2799] = true,
	[2744] = true,
	[8705] = true,
	[21377] = true,
	[35188] = true,
	[8392] = true,
	[16656] = true,
	[11512] = true,
	[8394] = true,
	[8391] = true,
	[8393] = true,
	[8396] = true,
	[2738] = true,
	[5113] = true,
	[38551] = true,
	[8483] = true,
	[22526] = true,
	[22527] = true,
	[12841] = true,
	[22529] = true,
	[28452] = true,
	[29209] = true,
	[21383] = true,
	[22528] = true,
	[10450] = true,
	[25433] = true,
	[18945] = true,
	[2732] = true,
	[2740] = true,
	[5117] = true,
	[2748] = true,
	[4582] = true,
	[19259] = true,
	[2725] = true,
	[5134] = true,
	[24449] = true,
	[20404] = true,
	[2749] = true,
	[29426] = true,
	[11407] = true,
	[30810] = true,
	[31812] = true,
	[11018] = true,
	[2734] = true,
	[2742] = true,
	[2750] = true,
	[30809] = true,
	[29739] = true,
	[29740] = true,
	[11754] = true,
	[29425] = true,
	[2735] = true,
	[18944] = true,
	[2751] = true,
	[2730] = true,
	[12840] = true,
	[24291] = true,
	[24401] = true,
	[25719] = true,
	[24368] = true,
}

local Astrolabe = DongleStub("Astrolabe-1.0");	-- reference to the Astrolabe mapping library
local function xy(x,y) if (not y) then return floor(x/100),x%100; end return (x*100)+y; end
local function copytable(t,new)		-- Safe table-copy with optional merge (equal entries will be overwritten, arg1 has pri)
	if (not t and not new) then return nil; end
	if (not t) then t={}; end if (not new) then new={}; end
	local i,v;
	for i,v in rawpairs(t) do if (type(v)=="table") then new[i]=copytable(v,new[i]); else new[i]=v; end end
	return new;
end

-- Set up for handling
function DropCountXML:OnLoad(frame)
	frame:RegisterEvent("ADDON_LOADED");
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED");
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");
	frame:RegisterEvent("LOOT_OPENED");
	frame:RegisterEvent("LOOT_SLOT_CLEARED");
	frame:RegisterEvent("MERCHANT_SHOW");
	frame:RegisterEvent("MERCHANT_CLOSED");
	frame:RegisterEvent("WORLD_MAP_UPDATE");
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	frame:RegisterEvent("QUEST_DETAIL");
	frame:RegisterEvent("QUEST_COMPLETE");
	frame:RegisterEvent("QUEST_ACCEPTED");
	frame:RegisterEvent("UNIT_SPELLCAST_START");
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
	frame:RegisterEvent("QUEST_FINISHED");

	CONST.PROFESSIONS[1],_,CONST.PROFICON[1]=GetSpellInfo(8613);	-- Skinning - loot
	CONST.PROFESSIONS[2],_,CONST.PROFICON[2]=GetSpellInfo(2366);	-- Herb gathering - loot, gather
	CONST.PROFESSIONS[3],_,CONST.PROFICON[3]=GetSpellInfo(2575);	-- Mining - loot, gather
	CONST.PROFESSIONS[4],_,CONST.PROFICON[4]=GetSpellInfo(49383);	-- Salvaging - loot
	CONST.PROFESSIONS[5],_,CONST.PROFICON[5]=GetSpellInfo(2656);	-- Smelting
	CONST.PROFESSIONS[6],_,CONST.PROFICON[6]=GetSpellInfo(2259);	-- Alchemy
	CONST.PROFESSIONS[7],_,CONST.PROFICON[7]=GetSpellInfo(2018);	-- Blacksmithing
	CONST.PROFESSIONS[8],_,CONST.PROFICON[8]=GetSpellInfo(7411);	-- Enchanting
	CONST.PROFESSIONS[9],_,CONST.PROFICON[9]=GetSpellInfo(4036);	-- Engineering
	CONST.PROFESSIONS[10],_,CONST.PROFICON[10]=GetSpellInfo(45357);	-- Inscription
	CONST.PROFESSIONS[11],_,CONST.PROFICON[11]=GetSpellInfo(25229);	-- Jewelcrafting
	CONST.PROFESSIONS[12],_,CONST.PROFICON[12]=GetSpellInfo(2108);	-- Leatherworking
	CONST.PROFESSIONS[13],_,CONST.PROFICON[13]=GetSpellInfo(3908);	-- Tailoring
	CONST.PROFESSIONS[14],_,CONST.PROFICON[14]=GetSpellInfo(33388);	-- Apprentice riding
	DropCountXML.ForgeIcon=CONST.PROFICON[5];

	StaticPopupDialogs["LCDC_D_NOTIFICATION"] = {
		text="Text",button1="Close",timeout=0,whileDead=1,hideOnEscape=1,
		OnAccept = function() StaticPopup_Hide ("LCDC_D_NOTIFICATION"); DropCount:NewVersion(); end, };
	StaticPopupDialogs["LCDC_D_NEWVERSIONINSTALLED"] = {
		text="Text",button1="Close",timeout=0,whileDead=1,hideOnEscape=1,
		OnAccept = function() StaticPopup_Hide("LCDC_D_NEWVERSIONINSTALLED"); end, };

	SlashCmdList.DROPCOUNT=function(msg) DropCountXML.Slasher(msg) end;

	DropCount.TooltipExtras:SetFunctions(GameTooltip);
	DropCount.TooltipExtras:SetFunctions(LootCount_DropCount_TT);
	DropCount.TooltipExtras:SetFunctions(LootCount_DropCount_CF);
	DropCount.TooltipExtras:SetFunctions(LootCount_DropCount_GD);
	LootCount_DropCount_GD.loc={x=0,y=0};

	if (not MT.TheFrameWorldMap) then
		MT.TheFrameWorldMap=CreateFrame("Frame","DropCount-MT-WM-Messager",WorldMapDetailFrame);
		if (not MT.TheFrameWorldMap) then DropCount:Chat("Critical: Could not create a DuckMod frame (2)",1); return; end
		CONST.WM_W=WorldMapDetailFrame:GetWidth(); CONST.WMSQ_W=CONST.WM_W/100;
		CONST.WM_H=WorldMapDetailFrame:GetHeight(); CONST.WMSQ_H=CONST.WM_H/100;
	end
	MT.TheFrameWorldMap:SetScript("OnUpdate",DropCountXML.HeartBeat);
end

-- There's slashing to be done
function DropCountXML.Slasher(msg)
	if (not msg) then msg=""; end
	local fullmsg=msg;
	if (msg:len()>0) then msg=msg:lower(); end

	if (msg=="gui") then LCDC_VendorSearch:Show(); return;
	elseif (msg=="single") then LootCount_DropCount_Character.ShowSingle=not LootCount_DropCount_Character.ShowSingle or nil;
		DropCount:Chat(Basic.."Display single-drop items: |r"..((LootCount_DropCount_Character.ShowSingle and "ON") or "OFF")); return;
	elseif (msg=="compact") then LootCount_DropCount_Character.CompactView=not LootCount_DropCount_Character.CompactView or nil;
		DropCount:Chat(Basic.."Mouse-over info: |r"..((LootCount_DropCount_Character.CompactView and "COMPACT") or "NORMAL")); return;
	elseif (msg=="best") then LootCount_DropCount_Character.NoTooltip=not LootCount_DropCount_Character.NoTooltip or nil;
		DropCount:Chat(Basic.."Tooltip \"Best known area\": |r"..((LootCount_DropCount_Character.NoTooltip and "OFF") or "ON")); return;
	elseif (msg=="new") then DropCount:NewVersion(); return;
	end

	if (msg=="debug") then DropCount.Debug=not DropCount.Debug or nil; DropCount:Chat(Basic.."DropCount debug: |r"..((DropCount.Debug and "ON") or "OFF")); return;
	elseif (msg=="ripper") then MT:Run("RIPPER",Ripper_MT_Run,MT.YieldExt); return;
	elseif (msg=="slow") then Table.PrintSlowestCompress(); return;
	elseif (msg=="dbmobs") then DropCount:PrintMobsStatus(); return;
	elseif (msg=="loc") then local X,Y=DropCount:GetPlayerPosition(); DropCount:Chat("X,Y: "..X..","..Y); return;
	end

	DropCount:Chat(Basic..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."|r");
	if (msg=="?") then DropCount:CleanDB(); return; end

	DropCount:Chat(Green..SLASH_DROPCOUNT2.." ?|r -> Statistics");
	DropCount:Chat(Green..SLASH_DROPCOUNT2.." single|r -> Show/hide items that has only dropped once");
	DropCount:Chat(Green..SLASH_DROPCOUNT2.." compact|r -> Toggle compact tooltip display");
	DropCount:Chat(Green..SLASH_DROPCOUNT2.." best|r -> Toggle "..Basic.."\"Best known area\"|r from items' tooltips.");
	if (DropCount.Debug) then
		DropCount:Chat(hBlue..SLASH_DROPCOUNT2.." dbmobs|r -> Perform a mob database evaluation");
		DropCount:Chat(hBlue..SLASH_DROPCOUNT2.." slow|r -> List slowest data storages");
		DropCount:Chat(hBlue..SLASH_DROPCOUNT2.." ripper|r -> Invoke ripperMT");
		DropCount:Chat(hBlue..SLASH_DROPCOUNT2.." loc|r -> Print player position");
	end
end

function DropCount.Event.COMBAT_LOG_EVENT_UNFILTERED(_,how,_,source,_,_,_,GUID,mob)
	DropCount.WoW5:ConvertMOB(mob,GUID:sub(7,10));
	if (how=="PARTY_KILL" and (bit.band(source,COMBATLOG_OBJECT_TYPE_PET) or bit.band(source,COMBATLOG_OBJECT_TYPE_PLAYER))) then
		if (GetNumGroupMembers()<1) then DropCount:AddKill(true,GUID,GUID:sub(7,10),mob,LootCount_DropCount_Character.Skinning); end
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end	-- hooked up, so notify of possible change
	end
end

function DropCount.Event.PLAYER_FOCUS_CHANGED(...) DropCount.Event.PLAYER_TARGET_CHANGED(...); end
function DropCount.Event.PLAYER_TARGET_CHANGED()
	local targettype=DropCount:GetTargetType();
	DropCount.Target.MyKill=nil;
	DropCount.Target.Skin=nil;
	DropCount.Target.UnSkinned=nil;
	DropCount.Target.CurrentAliveFriendClose=nil;
	if (not targettype) then return; end
	DropCount.ProfessionLootMob=nil;		-- only zero on new target, not on removal of target
	DropCount.BlindCast=nil;
	DropCount.Target.Classification=UnitClassification(targettype);		-- elite, rare, etc
	DropCount.Target.ClassificationSGUID=tostring(UnitGUID(targettype)):sub(7,10);
	if (not UnitIsDead(targettype)) then
		DropCount.Target.LastFaction=UnitFactionGroup(targettype);
		if (not DropCount.Target.LastFaction) then DropCount.Target.LastFaction="Neutral"; end
		DropCount.Target.LastAlive=UnitName(targettype);
		DropCount.WoW5:ConvertMOB(UnitName(targettype),UnitGUID(targettype):sub(7,10));
		DropCount.Target.CurrentAliveFriendClose=nil;
		if (CheckInteractDistance(targettype,2)) then	-- Trade-distance
			DropCount.Target.CurrentAliveFriendClose=DropCount.Target.LastAlive;
		end
		return;
	end
	if (UnitIsFriend("player",targettype)) then return; end
	DropCount.Target.CurrentAliveFriendClose=nil;
	DropCount.Target.Skin=UnitName(targettype);					-- Get current valid target
	DropCount.Target.GUID=UnitGUID(targettype);
	DropCount.Target.UnSkinned=DropCount.Target.GUID:sub(7,10);	-- Set unit for skinning-drop
	if (UnitIsTapped(targettype)) and (not UnitIsTappedByPlayer(targettype)) then return; end	-- Not my kill (in case of skinning)
	DropCount.Target.MyKill=DropCount.Target.Skin;			-- Save name of dead targetted/focused enemy
end

--== MoP: GetLootSourceInfo(slot) - will return an erroneous list of creature GUIDs and count
--== ---> These errors seem to be linked to items rather than code, and the errors are diminishing with time
function DropCount.WoW5:ConvertMOB(name,sguid,base,unp)
	if (not base) then base=dcdb; end
	if (not name or not sguid or not base.Count[name]) then return; end				-- nothing to convert
	if (sguid=="0000") then return; end
	local mdata=base.Count[name];							-- get old data
	mdata.Name=name;										-- add textual name
	base.Count[sguid]=mdata;								-- write it at short guid
	base.Count[name]=nil;									-- remove old entry
	if (unp) then Table:Unpack(DM_WHO,sguid,base.Count); end	-- re-unpack the new storage
	Table:PurgeCache(DM_WHO);
	for item,idata in rawpairs(base.Item) do				-- do all items without unpacking
		if (idata:find(name,1,true)) then					-- look for this mob by name
			idata=base.Item[item];							-- read the item
			if (idata.Name and idata.Name[name]) then		-- look for mob by name
				idata.Name[sguid]=idata.Name[name];			-- copy it to short guid
				idata.Name[name]=nil;						-- remove by name
			end
			if (idata.Skinning and idata.Skinning[name]) then
				idata.Skinning[sguid]=idata.Skinning[name];
				idata.Skinning[name]=nil;
			end
			base.Item[item]=idata;							-- over-write item
		end
	end
end

-- The function "FixLootAmounts()" requires the loot window to be open.
-- The return values are two tables, whereas the first has a format
-- compatible with the original loot window format paired up and items as
-- parent tables, like so:
-- {
--     item1 = { GUID_1A=amount_1A, GUID_1B=amount_1B, ... },
--     item2 = { GUID_2A=amount_2A, GUID_2B=amount_2B, ... },
--     ...
-- }
-- This format is easy to adapt to existing loot code as it comes with a
-- built-in function for retrieving loot-frame compatible data for each
-- item. Just as you would ask for the list for each slot, you can ask the
-- return data to provide a loot-frame format by calling
-- retval:GetLootFormat(loot) where "retval" is the first table returned
-- by the FixLootAmounts function, and "loot" is either an item (link or
-- similar) or a numeric slot in the loot frame.
--
-- The other table is formatted with GUIDs at the top for easier access
-- for DropCount usage, with items listed.
function DropCount:FixLootAmounts()
	local slots=GetNumLootItems(); if (slots<1) then if (DropCount.Debug) then DropCount:Chat("Zero-loot",1); end return; end
	local items={};for i=1,slots do local thisi=DropCount:GetID(GetLootSlotLink(i)); if (thisi) then _,_,items[thisi]=GetLootSlotInfo(i); end end
	local mobs={}; for i=1,slots do
		local item=DropCount:GetID(GetLootSlotLink(i)); if (item) then local t={GetLootSourceInfo(i)};
		for j=1,#t,2 do if (not mobs[t[j] ]) then mobs[t[j] ]={}; end local buf={ Count=t[j+1], Item=item };
		if (DropCount.ProfessionLootMob) then buf.Count=items[item]; end table.insert(mobs[t[j] ],buf);
	end end end
	local vitems={}; for m,d in pairs(mobs) do for _,mi in pairs(d) do
		if (not vitems[mi.Item]) then vitems[mi.Item]={ mobs=1, amount=mi.Count, guid={ m } };
		else vitems[mi.Item].mobs=vitems[mi.Item].mobs+1; vitems[mi.Item].amount=vitems[mi.Item].amount+mi.Count; table.insert(vitems[mi.Item].guid,m);
	end end end
	for i,d in pairs(items) do
		if (vitems[i]) then if (d~=vitems[i].amount) then
			if (vitems[i].mobs==1) then for _,mi in pairs(mobs[vitems[i].guid[1] ]) do if (mi.Item==i) then mi.Count=d; end end
			else local fi,num,mt=nil,0,{};
				for _m,_d in pairs(mobs) do for _,mi in pairs(_d) do if (mi.Item==i) then
					local sg=_m:sub(7,10); if (not mt[sg]) then mt[sg]={ c=mi.Count, n=1, guid={_m} }; num=num+1; if (not fi) then fi=_m; end
					else mt[sg].c=mt[sg].c+mi.Count; mt[sg].n=mt[sg].n+1; table.insert(mt[sg].guid,_m);
				end end end end
				if (num==1) then for _,mi in pairs(mobs[fi]) do if (mi.Item==i) then mi.Count=mi.Count+(d-vitems[i].amount); end end
				else local tr=0;
					for _m,_d in pairs(mt) do mt[_m].r=DropCount:GetRatio(i,_m); mt[_m].r=mt[_m].r*mt[_m].n; tr=tr+mt[_m].r; if (mt[_m].r==0) then mt[_m].r=.01; end end
					local all=0; for _m,_d in pairs(mt) do mt[_m].a=(mt[_m].r/tr)*d; mt[_m].a=floor(mt[_m].a+.5); all=all+mt[_m].a; end
					if (all~=d) then
						all=d-all; if (all>0) then repeat local lom,lod; for _m,_d in pairs(mt) do if (not lom or mt[_m].a<lod) then lom=_m; lod=_d.a; end end mt[lom].a=mt[lom].a+1; all=all-1; until (all==0);
						else repeat local him,hid; for _m,_d in pairs(mt) do if (not him or mt[_m].a>hid) then him=_m; hid=_d.a; end end mt[him].a=mt[him].a-1; all=all+1; until (all==0);
					end end
					for _,mi in pairs(mobs) do for _,mid in pairs(mi) do if (mid.Item==i) then mid.Count=0; end end end
					for sg,sgd in pairs(mt) do for m,mi in pairs(mobs) do if (m:sub(7,10)==sg) then
						local stopit=nil; for _,mid in pairs(mi) do if (mid.Item==i) then mid.Count=sgd.a; stopit=true; break; end end if (stopit) then break; end
	end end end end end end end end
	local ret={}; for guid,gL in pairs(mobs) do for _,i in pairs(gL) do if (not ret[i.Item]) then ret[i.Item]={}; end ret[guid]=i.Count; end end
	ret.GetLootFormat=function(t,i)
		if (type(i)=="string") then i=DropCount:GetID(i); else i=DropCount:GetID(GetLootSlotLink(i)); end if (not i or not t[i]) then return; end
		local lft={}; for g,c in pairs(t[i]) do table.insert(lft,g); table.insert(lft,c); end return unpack(lft); end
	return ret,mobs;
end

function DropCount:GetCurrentTooltipHeader()
	if (GameTooltip:NumLines()<1) then return nil; end
	local text=_G["GameTooltipTextLeft1"]:GetText();
	if (text=="") then return nil; end
	return text;
end

function DropCount:GetCurrentObjectID()
	DropCount.Tracker.LastObjectIDName=self:GetCurrentTooltipHeader();
	if (GameTooltip:GetItem()) then return nil; end
	local lang=GetLocale();
	for objID,odata in rawpairs(dcdb.Gather.GatherNodes) do
		if (odata:find(DropCount.Tracker.LastObjectIDName,1,true)) then
			local o=dcdb.Gather.GatherNodes[objID];
			if (o.Name and o.Name[lang]==DropCount.Tracker.LastObjectIDName) then
			return objID; end
		end
	end
	return nil;
end

function DropCount:SaveGatheringLoot(profession)
	local profDB=nil;
	if (profession==CONST.PROFESSIONS[2]) then profDB="GatherHERB";
	elseif (profession==CONST.PROFESSIONS[3]) then profDB="GatherORE";
	else return; end
	local slots=GetNumLootItems(); if (slots<1) then DropCount:Chat("No loot slots at gather",1); return; end
	local items={};
	local nodeicon;
	for i=1,slots do
		local thisi=DropCount:GetID(GetLootSlotLink(i));
		if (thisi) then
			local thisp=tonumber(thisi:match("^item:(%d+):"));
			local itemname,thisicon;
			thisicon,itemname,items[thisi]=GetLootSlotInfo(i);		-- icon, name, quantity
			local first,last=itemname:sub(1,ceil(itemname:len()/2)),itemname:sub(0-ceil(itemname:len()/2));		-- first and second half of looted item name
			if (DropCount.Tracker.LastObjectIDName:find(first,1,true) or DropCount.Tracker.LastObjectIDName:find(last,1,true)) then nodeicon=thisicon; end
		end
	end
	if (not nodeicon) then nodeicon,_,_=GetLootSlotInfo(1); end		-- icon, name, quantity
	local objID=DropCount.Tracker.GatherObject;
	DropCount.Tracker.GatherObject=nil;
	local buf=dcdb.Gather.GatherNodes[objID]; if (not buf) then buf={ }; end
	buf.Count=buf.Count or 0;
	buf.Loot=buf.Loot or {};
	buf.Count=buf.Count+1;
	for link,count in pairs(items) do
		if (not buf.Loot[link]) then buf.Loot[link]=0; end
		buf.Loot[link]=buf.Loot[link]+count;
	end
	buf.Icon=nodeicon;
	dcdb.Gather.GatherNodes[objID]=buf;				-- save it
	DropCountXML:AddGatheringLoot(profDB,objID);	-- add current here
end

-- gather grid
function DropCountXML:AddGatheringLoot(profDB,objID,map,level,x,y,noaddgather)
	if (not profDB or ((objID or 0)==0 and not noaddgather)) then return; end		-- must have profession and an object, or only profession if not counting
	map=map or 0;
	level=level or 0;
	x=x or 0;
	y=y or 0;
	if (map==0) then map=DropCount:GetMapTable(); map,level=map.ID,map.Floor; end	-- get player map and level
	if (x==0 and y==0) then x,y=GetPlayerMapPosition("player"); end					-- get player position
	if (x==0 and y==0) then return; end
	if (x<1 and y<1) then x=floor(x*100); y=floor(y*100); end						-- make 100-grid
	map=tostring(map).."_"..tostring(level);										-- create individual map

	local buf=dcdb.Gather[profDB][map]; if (not buf) then buf={ Gathers=0, OID={ }, }; end	-- get gather-section
	if (not buf.Grid) then buf.Grid=""; for i=1,5 do buf.Grid=buf.Grid..string.char(0,250); end end	-- 250 zeros five times
	if (not noaddgather) then
		buf.Gathers=buf.Gathers+1;
		buf.OID[objID]=(buf.OID[objID] or 0)+1;
	end
	local grid=DropCount:UnpackBitGrid(buf.Grid);	-- unpack grid
	local pos=(y*100)+x;							-- linearised position
	local byte=floor(pos/8)+1;						-- byte-position for bits with lua offset
	local setbit=2^(pos%8);							-- bit
	y=grid:byte(byte,byte);							-- grab old byte
	if (bit.band(y,setbit)==0) then					-- test bit
		y=bit.bor(y,setbit);						-- set bit
		local tmp;
		if (byte>1) then tmp=grid:sub(1,byte-1); else tmp=""; end	-- it's not the first byte
		tmp=tmp..string.char(y);									-- numberify modified byte
		if (byte<1250) then tmp=tmp..grid:sub(byte+1); end			-- it's not the last byte
		buf.Grid=DropCount:PackBitGrid(tmp);		-- save grid
		LootCount_DropCount_GD.loc.x=0;		-- force visual update
	end
	dcdb.Gather[profDB][map]=buf;			-- save with new count and optional new location
end

function DropCount:PackBitGrid(rawgrid)
	local len=rawgrid:len();
	local grid="";
	local i=1;
	repeat
		if (rawgrid:sub(i,i)~=string.char(0)) then grid=grid..rawgrid:sub(i,i);	-- insert non-null directly
		else
			local j=0;					-- note the "offset" j=0 ultimately makes one character result
			repeat j=j+1; until(rawgrid:sub(i+j,i+j)~=string.char(0) or i+j>len or j==255);		-- check for non-null or full buffer
			grid=grid..string.char(0,j);					-- add compressed coding
			i=i+(j-1);					-- possible to add zero in case single zero bytes and i marches on by for-statement
		end
		i=i+1;
	until(i>len);
	return grid;
end

function DropCount:UnpackBitGrid(packedgrid)
	local grid="";
	local i=1;
	repeat
		if (packedgrid:byte(i,i)==0) then
			grid=grid..string.rep(packedgrid:sub(i,i),packedgrid:byte(i+1,i+1));	-- recreate empty space
			i=i+1;																	-- skip past of counter byte
		else grid=grid..packedgrid:sub(i,i); end									-- direct copy byte
		i=i+1;
	until(i>packedgrid:len());
	return grid;
end

function DropCount.Event.LOOT_OPENED()
	if (DropCount.Tracker.GatherDone) then DropCount:SaveGatheringLoot(DropCount.Tracker.GatherDone); DropCount.Tracker.GatherDone=nil; return;
	elseif (DropCount.BlindCast or not DropCount.Target.Skin) then return; end	-- blind cast or friendly target at any distance
	if (DropCount.Target.MyKill) then DropCount.Grid:Add(DropCount.Target.UnSkinned); end	-- Add tagret to grid
	local i,mobs=DropCount:FixLootAmounts(); if (not mobs) then return; end
	if (not DropCount.OldQuestsVerified) then dcdb.QuestQuery=GetQuestsCompleted(); DropCount:GetQuestNames(); DropCount.OldQuestsVerified=true; end
	local nogrid=0;
	for _ in pairs(mobs) do nogrid=nogrid+1; end
	if (nogrid>2) then nogrid=true; else nogrid=nil; end	-- possibly an area pull, so don't add all to grid in one spot
	for guid,list in pairs(mobs) do
		local skipit=nil;
		local sguid=guid:sub(7,10);
		local mTable=DropCount.Tracker.Looted;										-- select normal loot mobs
		if (DropCount.ProfessionLootMob) then mTable=DropCount.Tracker.Skinned;		-- select skinning loot mobs
		else -- It's normal, so check if it has already been skinned
			if (DropCount.Tracker.Skinned[guid]) then skipit=true; end				-- already skinned, so loot is not correct
		end
		if (mTable[guid]) then skipit=true; end			-- Loot already done for this one
		if (not skipit) then
			if (DropCount.Target.UnSkinned and not nogrid) then DropCount.Grid:Add(sguid); end	-- if nothing selected, assume fishing
			if (DropCount.ProfessionLootMob and DropCount.Target.MyKill) then DropCount:AddKill(true,guid,sguid);		-- If my kill (or pet or something that makes me loot it)
			elseif (not DropCount.ProfessionLootMob) then DropCount:AddKill(true,guid,sguid); end	-- Add the targeted dead dude that I didn't have the killing blow on
			local now=time();
			-- Save loot
			mTable[guid]=now;							-- Set it
			for i=1,#list do
				if (list[i].Item and list[i].Count==0) then list[i].Count=1; end
				if (list[i].Count>0 and (DropCount.Target.MyKill or DropCount.Target.Skin)) then DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count); end
			end
			DropCount.ProfessionLootMob=nil;			-- Set normal type loot
			-- Remove old mobs
			for guid,when in pairs(mTable) do if (now-when>CONST.LOOTEDAGE) then mTable[guid]=nil; end end
		end
	end
end

function DropCount.Event.MERCHANT_SHOW()
	DropCount.Target.OpenMerchant=DropCount.Target.LastAlive; DropCount.Timer.VendorDelay=1; end
function DropCount.Event.MERCHANT_CLOSED()
	DropCount.Timer.VendorDelay=-1; DropCount.VendorReadProblem=nil; end
function DropCount.Event.WORLD_MAP_UPDATE()
	if (not WorldMapDetailFrame:IsVisible()) then return; end MT:Run("WM Plot",DropCount.MT.Icons.PlotWorldmap); end
function DropCount.Event.ZONE_CHANGED_NEW_AREA()
	Table:PurgeCache(DM_WHO); MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end

function DropCount.Event.QUEST_DETAIL()
	local qName=GetTitleText();
	local target=DropCount:GetTargetType();
	if (target) then target=CheckInteractDistance(DropCount:GetTargetType(),3); end	-- Duel - 9,9 yards
	if (not target) then DropCount.Target.CurrentAliveFriendClose=nil; end	-- No target, or too far away
	if (qName) then DropCount.Quest:SaveQuest(qName,DropCount.Target.CurrentAliveFriendClose); end
end

function DropCount.Event.QUEST_COMPLETE()
	local qName=GetTitleText();
	local qID=true;
	if (LootCount_DropCount_Character.Quests[qName]) then qID=LootCount_DropCount_Character.Quests[qName].ID; end
	if (not LootCount_DropCount_Character.DoneQuest) then LootCount_DropCount_Character.DoneQuest={}; end
	if (not LootCount_DropCount_Character.DoneQuest[qName]) then LootCount_DropCount_Character.DoneQuest[qName]=qID; --DropCount:Chat("Quest \""..qName.."\" completed",0,1,0);
	else
		if (type(LootCount_DropCount_Character.DoneQuest[qName])=="table") then
			if (qID and qID~=true) then LootCount_DropCount_Character.DoneQuest[qName][qID]=true; end
		elseif (qID and qID~=true) then
			LootCount_DropCount_Character.DoneQuest[qName]=nil;
			LootCount_DropCount_Character.DoneQuest[qName]={[qID]=true};
		end
	end
	LCDC_RescanQuests=CONST.RESCANQUESTS;
end

function DropCount.Event.QUEST_FINISHED()		-- Also when frame is closed (apparently)
	LCDC_RescanQuests=CONST.RESCANQUESTS; end
function DropCount.Event.QUEST_ACCEPTED()
	LCDC_RescanQuests=CONST.RESCANQUESTS; end

function DropCount.Event.UNIT_SPELLCAST_SUCCEEDED(name,spell)
	if (name~="player") then return; end		-- Someone else in party
	if (DropCount.Tracker.Gather==spell) then DropCount.Tracker.GatherDone=spell; end	-- gathering done for spell to save from loot window
	DropCount.Tracker.Gather=nil;
end

function DropCount.Event.UNIT_SPELLCAST_START(name,spell)
	if (name~="player") then return; end		-- Someone else in party
	DropCount.ProfessionLootMob=nil;					-- Set normal type loot
	DropCount.BlindCast=not DropCount.Target.Skin or nil;
	DropCount.Tracker.Gather=nil;
	DropCount.Tracker.GatherDone=nil;
	if (spell==CONST.PROFESSIONS[1] or spell==CONST.PROFESSIONS[2] or
		spell==CONST.PROFESSIONS[3] or spell==CONST.PROFESSIONS[4]) then
		if (DropCount.Target.Skin) then DropCount.ProfessionLootMob=spell;			-- casting on a skinning-target, so set loot-by-profession type
		else
			DropCount.Tracker.GatherObject=DropCount:GetCurrentObjectID();
			if (DropCount.Tracker.GatherObject) then DropCount.Tracker.Gather=spell; end		-- save spell as current ongoing gather
		end
		return;
	end

	local skillName=GetTradeSkillLine();
	if (skillName and skillName==CONST.PROFESSIONS[3]) then		-- Mining, so it could a forge
		if (GetTradeSkillSelectionIndex()==0) then return; end
		skillName=GetTradeSkillInfo(GetTradeSkillSelectionIndex());
		if (not skillName or skillName~=spell) then return; end
		local fZone=GetRealZoneText();
		local forges=dcdb.Forge[fZone];
		if (not forges) then forges={}; end
		local saved=nil;
		local fX,fY=DropCount:GetPlayerPosition();
		for forge,fRaw in pairs(forges) do
			local x,y=fRaw:match("(.+)_(.+)"); x=tonumber(x); y=tonumber(y);
			if (fX>=x-1 and fX<=x+1 and fY>=y-1 and fY<=y+1) then forges[forge]=fX.."_"..fY; saved=true; end
		end
		if (not saved) then table.insert(forges,fX.."_"..fY); end
		dcdb.Forge[fZone]=forges;
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
	end
end

function DropCount.Event.ADDON_LOADED(addon)
	if (addon~="LootCount_DropCount") then return; end
	dcdb=LootCount_DropCount_DB;		-- set short-form
	if (DropCount_Local_Code_Enabled) then DropCount.Debug=true; end
	Table:Init(DM_WHO,true,dcdb);	-- Set defaults for compressing database with cache
	CONST.MYFACTION=UnitFactionGroup("player");
	CreateDropcountDB(dcdb);
	DropCount.Hook.TT_SetBagItem=GameTooltip.SetBagItem; GameTooltip.SetBagItem=DropCount.Hook.SetBagItem;
	LootCount_DropCount_Character.ShowZoneMobs=nil;		-- obsolete
	LootCount_DropCount_Character.ShowZone=nil;			-- obsolete
	LootCount_DropCount_Character.InvertMobTooltip=nil;	-- obsolete
	dcdb.GUILD=nil; dcdb.RAID=nil;						-- obsolete
	if (dcdb.IconX and dcdb.IconY) then DropCount:MinimapSetIconAbsolute(dcdb.IconX,dcdb.IconY); else DropCount:MinimapSetIconAngle(dcdb.IconPosition or 180); end
	LootCount_DropCount_Character.LastQG=LootCount_DropCount_Character.LastQG or {};
	local k,v=next(dcdb.Book); v=dcdb.Book[k];	-- get first book for verification
	if (v.Zone) then for k in rawpairs(dcdb.Book) do dcdb.Book[k]=nil; end end		-- kill it, data is anchient, obsolete and then mostly misplaced
	Astrolabe:Register_OnEdgeChanged_Callback(DropCountXML.AstrolabeEdge,1);
	DropCount:RemoveFromDatabase(); wipe(LootCount_DropCount_RemoveData); LootCount_DropCount_RemoveData=nil;
	DropCount.Loaded=0;				-- starting OnUpdate
	if (not DropCount_Local_Code_Enabled) then dcdb.GridMinimap=nil; dcdb.OreMinimap=nil; dcdb.HerbMinimap=nil; dcdb.GridWorldmap=nil; end
	if (dcdb.DontFollowVendors) then dcdb.VendorMinimap=nil; dcdb.VendorWorldmap=nil; end
	if (dcdb.DontFollowVendors) then dcdb.RepairMinimap=nil; dcdb.RepairWorldmap=nil; end
	if (dcdb.DontFollowBooks) then dcdb.BookMinimap=nil; dcdb.BookWorldmap=nil; end
	if (dcdb.DontFollowForges) then dcdb.ForgeMinimap=nil; dcdb.ForgeWorldmap=nil; end
	if (dcdb.DontFollowGrid) then dcdb.GridMinimap=nil; dcdb.GridWorldmap=nil; end
	if (dcdb.DontFollowGrid) then dcdb.RareMinimap=nil; dcdb.RareWorldmap=nil; end
	if (dcdb.DontFollowTrainers) then dcdb.TrainerMinimap=nil; dcdb.TrainerWorldmap=nil; end
	if (dcdb.DontFollowQuests) then dcdb.QuestMinimap=nil; dcdb.QuestWorldmap=nil; end
	if (dcdb.DontFollowGather) then dcdb.HerbMinimap=nil; dcdb.HerbWorldmap=nil; end
	if (dcdb.DontFollowGather) then dcdb.OrbMinimap=nil; dcdb.OrbWorldmap=nil; end
	LCDC_ResultListScroll:DMClear();		-- Prep search-list
	LCDC_VendorSearch_UseVendors:SetText("Vendors"); LCDC_VendorSearch_UseVendors:SetChecked(true);
	LCDC_VendorSearch_UseQuests:SetText("Quests"); LCDC_VendorSearch_UseQuests:SetChecked(true);
	LCDC_VendorSearch_UseBooks:SetText("Books"); LCDC_VendorSearch_UseBooks:SetChecked(true);
	LCDC_VendorSearch_UseItems:SetText("Items"); LCDC_VendorSearch_UseItems:SetChecked(true);
	LCDC_VendorSearch_UseMobs:SetText("Creatures"); LCDC_VendorSearch_UseMobs:SetChecked(true);
	LCDC_VendorSearch_UseTrainers:SetText("Trainers"); LCDC_VendorSearch_UseTrainers:SetChecked(true);
	-- Fire initial MT tasks
	MT:Run("ConvertAndMerge",DropCount.MT.ConvertAndMerge);	-- DropCount.OnUpdate:RunConvertAndMerge(elapsed);
	-- populate grid filter list
	if (LootCount_DropCount_Character.Sheet) then
		for section,st in pairs(LootCount_DropCount_Character.Sheet) do
			DropCount_GridFilterFrame_Filters:DMAdd(section,nil,-1);
			for code,entry in pairs(st) do
				DropCountXML.AddUnitToGridFilter(section,entry.name,code,entry.icon)
	end end end
end

function DropCount:NewVersion()
	if (dcdb.LastNotifiedVersion==VERSIONn) then return; end
	local text="";
	if (not dcdb.LastNotifiedVersion and not dcdb.MergedData) then			-- first install
		text=text..Green.."Thank you for installing DropCount.|r\n\n";
	end
	dcdb.LastNotifiedVersion=dcdb.LastNotifiedVersion or 0;
	-- new things to try
	local things="";
	if (dcdb.LastNotifiedVersion<1.50) then
		things=things..Yellow.."*|r Review the minimap menu and key bindings.\n";
		things=things..Yellow.."*|r Add a commonly dropped item in worldmap locations.\n\n";
	end
	if (things~="") then
		text=text..Basic.."Things you may want to try with your new DropCount:\n"..things;
	end
	-- code changes
	local changes="";
	if (dcdb.LastNotifiedVersion<1.50) then
		changes=changes..Yellow.."*|r Items and creatures on the worldmap.\n";
		changes=changes..Yellow.."*|r Herbs and ore on the worldmap.\n";
		changes=changes..Yellow.."*|r Code restructuring and bug fixes.\n";
	end
	if (changes~="") then
		text=text..Basic.."Changes in "..Green..LOOTCOUNT_DROPCOUNT_VERSIONTEXT..Basic.." since your last upgrade:\n"..changes;
	end

	if (text:len()>2) then
		StaticPopupDialogs["LCDC_D_NEWVERSIONINSTALLED"].text=text:sub(1,-2);	-- cut last '\n'
		StaticPopup_Show("LCDC_D_NEWVERSIONINSTALLED");
	end
	dcdb.LastNotifiedVersion=VERSIONn;
end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_LEAVE()
	GameTooltip:Hide(); end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_ENTER(frame,index)
	local entry=frame.DMTheList[index];
	if (entry.DB.Section=="Item") then DropCount.Tooltip:MobList(entry.DB.Entry,nil,nil,nil,LCDC_VendorSearch.SearchTerm);
	elseif (entry.DB.Section=="Creature") then DropCount.Tooltip:SetLootlist(entry.DB.Entry,entry.DB.sguid,GameTooltip);
	elseif (entry.DB.Section=="Gathering profession") then DropCount.Tooltip:Node(entry.Tooltip);
	elseif (entry.Tooltip) then			-- something else, but with tooltip, so assume raw line-by-line tooltip provided
		if (GameTooltip:IsVisible()) then return; end
		GameTooltip:SetOwner(frame,"ANCHOR_CURSOR");
		GameTooltip:SetText(entry.Tooltip[1]);
		local i=2; while(entry.Tooltip[i]) do GameTooltip:LCAddLine(entry.Tooltip[i],.6,.6,1,0); i=i+1; end	-- spew tooltip
		local found=nil;
		if (entry.DB.Section=="Vendor") then
			local eData=dcdb.Vendor[entry.DB.Entry];
			if (eData) then for _,iTable in pairs(eData.Items) do if (iTable.Name) then
						if (iTable.Name:lower():find(LCDC_VendorSearch.SearchTerm)) then
							if (not found) then found=true; GameTooltip:LCAddLine(" ",1,1,1,0); GameTooltip:LCAddLine("Matches:",1,1,1,0); end	-- init text
							GameTooltip:LCAddLine("   "..iTable.Name,1,1,1,0);
			end end end end
		elseif (entry.DB.Section=="Quest") then
			local eData=dcdb.Quest[CONST.MYFACTION][entry.DB.Entry];
			if (eData and eData.Quests) then for _,iTable in ipairs(eData.Quests) do
					local useit=nil;
					if (iTable.Quest:lower():find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
					if (iTable.Header and iTable.Header:lower():find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
					if (useit) then
						if (not found) then found=true; GameTooltip:LCAddLine(" ",1,1,1,0); GameTooltip:LCAddLine("Matches:",1,1,1,0); end	-- init text
						GameTooltip:LCAddDoubleLine("   "..iTable.Quest,iTable.Header,1,1,1,1,1,1);
			end end end
		end
		GameTooltip:Show();
	end
end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_CLICKED(frame,index,checked)
	local entry=frame.DMTheList[index];
	if (frame==LCDC_ListOfOptions_List) then
		if (entry.DB.Negative) then checked=(not checked) or nil; end
		if (entry.DB.Base) then
			_G["LootCount_DropCount_"..entry.DB.Base][entry.DB.Setting]=checked;
			MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		end
	elseif (frame==LCDC_ResultListScroll) then
		if (entry.DB.Section=="Creature") then
			GameTooltip:Hide();
			local internal,name=entry.DB.Entry,entry.DB.Entry;
			if (dcdb.Count[internal] and dcdb.Count[internal].Name) then name=dcdb.Count[internal].Name; end
			local menu=DMMenuCreate();
			menu:Add("Track on worldmap",function () DropCountXML.AddUnitToGridFilter("Creature",name,internal); end );	-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
			menu:Show();
		elseif (entry.DB.Section=="Vendor") then
			GameTooltip:Hide();
			DropCount.Tooltip:SetNPCContents(entry.DB.Entry,frame,GameTooltip,true);
		elseif (entry.DB.Section=="Quest") then
			GameTooltip:Hide();
			DropCount.Tooltip:QuestList(CONST.MYFACTION,entry.DB.Entry,frame,GameTooltip);
		elseif (entry.DB.Section=="Item") then
			GameTooltip:Hide();
			local internal,name=entry.DB.Entry,entry.DB.Entry;
			if (dcdb.Item[internal] and dcdb.Item[internal].Item) then name=dcdb.Item[internal].Item; end
			local menu=DMMenuCreate();
			menu:Add("View...",function () SetItemRef(entry.DB.Entry); end);
			menu:Add("Track on worldmap",function () DropCountXML.AddUnitToGridFilter("Item",name,internal); end );	-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
			menu:Show();
		end
	elseif (frame==DropCount_DataOptionsFrame_List) then
		if (entry.DB.Negative) then checked=not checked or nil; end
		if (checked) then checked=true; else checked=false; end		-- force true/false
		if (entry.DB.Base) then
			if (not DropCount_DataOptionsFrame.DBSettings) then DropCount_DataOptionsFrame.DBSettings={}; end
			if (not DropCount_DataOptionsFrame.DBSettings[entry.DB.Base]) then DropCount_DataOptionsFrame.DBSettings[entry.DB.Base]={}; end
			DropCount_DataOptionsFrame.DBSettings[entry.DB.Base][entry.DB.Setting]={checked,entry.DB};
		end
	end
end

-- An event has been received
function DropCountXML:OnEvent(_,event,...)
	if (DropCount.Event[event]) then DropCount.Event[event](...); return; end
end

-- called when "DropCount_DataOptionsFrame" is about to hide
function DropCountXML:VerifySectionSettings()
	dcdb.ForcedOptions=1;
	local reload=nil;
	if (not _G["DropCount_DataOptionsFrame"].DBSettings) then return; end	-- no changes
	for db,dbd in pairs(_G["DropCount_DataOptionsFrame"].DBSettings) do
		for name,value in pairs(dbd) do
			local cur=_G["LootCount_DropCount_"..db][name];
			if (cur) then cur=true; else cur=nil; end					-- get forced true/nil of current state
			if (value[1]) then value[1]=true; else value[1]=nil; end	-- set force true/nil of wanted state
			if (cur~=value[1]) then reload=true; end					-- new state, so flag a reload
			_G["LootCount_DropCount_"..db][name]=value[1];				-- insert new state
			for base,direct in pairs(value[2].nousebase or {}) do
				local set=value[1]; if (not direct) then set=(not set) or nil; end
				rawset(rawget(dcdb[base],"__METADATA__"),"nouse",set);
			end
			for base,direct in pairs(value[2].nousesub or {}) do
				local set=value[1]; if (not direct) then set=(not set) or nil; end
				for sub in pairs(dcdb[base]) do rawset(rawget(dcdb[base][sub],"__METADATA__"),"nouse",set); end
			end
		end
	end
	return reload;
end

-- hooked for setting items at tooltips
function DropCount.Hook.SetBagItem(self,bag,slot)
	local hasCooldown,repairCost=DropCount.Hook.TT_SetBagItem(self,bag,slot);
	local _,item=GameTooltip:GetItem();
	DropCount.Hook:AddLocationData(GameTooltip,item);
	return hasCooldown,repairCost;
end

-- insert best looting area in given tooltip
function DropCount.Hook:AddLocationData(frame,item)
	if (LootCount_DropCount_Character.NoTooltip) then return; end
	local ThisItem=DropCount:GetID(item);
	if (ThisItem) then
		local iData=dcdb.Item[ThisItem];
		if (iData) then
			local text="|cFFF89090B|cFFF09098e|cFFE890A0s|cFFE090A8t |cFFD890B0k|cFFD090B8n|cFFC890C0o|cFFC090C8w|cFFB890D0n |cFFB090D8a|cFFA890E0r|cFFA090E8e|cFF9890F0a: |cFF9090F8";
			if (iData.Best) then frame:LCAddLine(text..iData.Best.Location.." at "..iData.Best.Score.."%",.6,.6,1,1);	-- 1=wrap text
			elseif (iData.BestW) then frame:LCAddLine(text..iData.BestW.Location.." at "..iData.BestW.Score.."%",.6,.6,1,1);	-- 1=wrap text
			end
		end
		frame:Show();	-- trigger full gametooltip redraw
	end
end

function DropCount:Length(t)
	if (not t) then return 0; end local count=0; for _ in pairs(t) do count=count+1; end return count; end

function DropCount:GetQuestNames()
	if (not dcdb.QuestQuery) then return; end
	if (not LootCount_DropCount_Character.DoneQuest) then LootCount_DropCount_Character.DoneQuest={}; end
	-- Remove all that is already okay
	for dqName,dqState in pairs(LootCount_DropCount_Character.DoneQuest) do
		if (type(dqState)=="table") then for queueNum in pairs(dqState) do dcdb.QuestQuery[queueNum]=nil; end
		else dcdb.QuestQuery[dqState]=nil; end
	end
	DropCount.Tracker.ConvertQuests=0;
	for _,_ in pairs(dcdb.QuestQuery) do DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests+1; end
	DropCount.Timer.PrevQuests=3;
end

function DropCount:GetQuestName(link)
	if (not link:find("quest:",1,true)) then return nil; end
	LootCount_DropCount_CF:SetOwner(WorldFrame, "ANCHOR_NONE"); LootCount_DropCount_CF:ClearLines(); LootCount_DropCount_CF:SetHyperlink(link);
	local text=_G["LootCount_DropCount_CFTextLeft1"]:GetText();
	LootCount_DropCount_CF:Hide();
	return text;
end

function DropCountXML.AstrolabeEdge() for v,icon in pairs(DropCountXML.Icon.MM) do if (Astrolabe:IsIconOnEdge(icon)) then icon:SetAlpha(.6); else icon:SetAlpha(1); end end end

function DropCount.Quest:AddLastQG(qGiver)
	if (not LootCount_DropCount_Character.LastQG) then return; end
	local index,found=1,10;
	for index=1,10 do if (LootCount_DropCount_Character.LastQG[index]==qGiver) then found=index; break; end end
	table.remove(LootCount_DropCount_Character.LastQG,found);		-- primitive remove (OOB will silently do nothing)
	table.insert(LootCount_DropCount_Character.LastQG,1,qGiver);	-- primitive insert
end

function DropCount.Quest:SaveQuest(qName,qGiver,qLevel)
	local OnlyAddQuest=nil;
	if (not qName) then return; end
	if (not qLevel) then qLevel=0; end
	if (not CONST.MYFACTION) then return; end
	if (not dcdb.Quest[CONST.MYFACTION]) then dcdb.Quest[CONST.MYFACTION]={}; end

	if (not qZone) then qZone="Unknown"; end
	local qX,qY=DropCount:GetPlayerPosition();
	local qZone=DropCount:GetFullZone();
	if (not qGiver or qGiver=="") then
		qGiver="- item - ("..(DropCount:GetFullZone() or qZone).." "..math.floor(qX)..","..math.floor(qY)..")";
		if (QuestNPCModelNameText:IsVisible()) then					-- the text in the pop-out frame with a 3D model attached to the quest frame
			local fsText=QuestNPCModelNameText:GetText();
			if (dcdb.Quest[CONST.MYFACTION][fsText]) then qGiver=fsText; OnlyAddQuest=true; end		-- We have a remote quest with a known quest-giver
	end end
	local qTable={ [qGiver]=dcdb.Quest[CONST.MYFACTION][qGiver]; };
	if (not qTable[qGiver]) then qTable[qGiver]={}; end
	if (not OnlyAddQuest) then
		qTable[qGiver].Zone=qZone;
		if (not qTable[qGiver].X or not qTable[qGiver].Y or (qTable[qGiver].X and qX~=0 and qTable[qGiver].Y and qY~=0)) then
			qTable[qGiver].X=qX; qTable[qGiver].Y=qY;
	end end
	qTable[qGiver].Map=DropCount:GetMapTable();
	local i=1;
	if (qTable[qGiver].Quests) then
		while (	qTable[qGiver].Quests[i] and (
				(type(qTable[qGiver].Quests[i])~="table" and qTable[qGiver].Quests[i]~=qName)
				or
				(type(qTable[qGiver].Quests[i])=="table" and qTable[qGiver].Quests[i].Quest~=qName)
				) ) do i=i+1; end
	else qTable[qGiver].Quests={}; end
	local newquest=nil;
	if (not qTable[qGiver].Quests[i]) then newquest=true; end
	if (type(qTable[qGiver].Quests[i])~="table") then qTable[qGiver].Quests[i]={}; end
	qTable[qGiver].Quests[i].Quest=qName;

	self:AddLastQG(qGiver);
	while (qTable[qGiver].Quests[i+1]) do							-- It's not the bottom quest
		qTable[qGiver].Quests[i],qTable[qGiver].Quests[i+1]=qTable[qGiver].Quests[i+1],qTable[qGiver].Quests[i];
		newquest=true;
		i=i+1;
	end
	if (newquest) then
		dcdb.Quest[CONST.MYFACTION][qGiver]=qTable[qGiver];
		if (DropCount.Debug) then DropCount:Chat(Basic.."Quest "..Green.."\""..qName.."\""..Basic.." saved for "..Green..qGiver); end
	end
end

function DropCount.Quest:Scan()
	local thislist={};
	if (not LootCount_DropCount_Character.Quests) then LootCount_DropCount_Character.Quests={}; end
	wipe(LootCount_DropCount_Character.Quests);
	-- Get all current quests
	ExpandQuestHeader(0);			-- Expand all quest-headers
	local i=1;
	local lastheader=nil;
	while (GetQuestLogTitle(i)~=nil) do
		local questTitle,level,questTag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily=GetQuestLogTitle(i);
		if (not isHeader) then
			SelectQuestLogEntry(i);
			local link=GetQuestLink(i);
			local questID,i1,i2=link:match("|Hquest:(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
			LootCount_DropCount_Character.Quests[questTitle]={ ID=tonumber(questID), Header=lastheader, };
			local goal=GetNumQuestLeaderBoards();
			if (goal and goal>0) then
				LootCount_DropCount_Character.Quests[questTitle].Items={};
				local peek,found=1,nil;
				while(peek<=goal) do
					local desc,oType,done=GetQuestLogLeaderBoard(peek);
					if (oType=="item") then
						local _,_,itemName,numItems,numNeeded=string.find(desc, "(.*):%s*([%d]+)%s*/%s*([%d]+)");
						if (itemName) then found=true; LootCount_DropCount_Character.Quests[questTitle].Items[itemName]=tonumber(numNeeded); end
					end
					peek=peek+1;
				end
				if (not found) then LootCount_DropCount_Character.Quests[questTitle].Items=nil; end
			end
		else
			lastheader=questTitle;
		end
		i=i+1;
	end
	if (not DropCount.SpoolQuests) then DropCount.SpoolQuests={}; end
	DropCount.SpoolQuests=copytable(LootCount_DropCount_Character.Quests,DropCount.SpoolQuests);
	-- Book-keeping: Items for each quest
	for quest,qData in pairs(LootCount_DropCount_Character.Quests) do
		if (qData.Items) then
			for item,amount in pairs(qData.Items) do
				local iData=dcdb.Item[item];
				if (iData) then
					if (not iData.Quest) then iData.Quest={}; end
					iData.Quest[quest]=amount;
					dcdb.Item[item]=iData;
	end end end end
	-- Shove numbers
	i=1;
	if (dcdb.Quest[CONST.MYFACTION]) then
		while(LootCount_DropCount_Character.LastQG[i]) do	-- q-givers list
			local tqg=dcdb.Quest[CONST.MYFACTION][LootCount_DropCount_Character.LastQG[i]];
			if (tqg) then
				local changed=nil;
				if (tqg and tqg.Quests) then				-- Same q-giver from database
					local qi=1;
					while (tqg.Quests[qi] and not changed) do
						if (not tqg.Quests[qi].ID) then
							for qname,qnTable in pairs(LootCount_DropCount_Character.Quests) do
								if (tqg.Quests[qi].Quest==qname) then tqg.Quests[qi].ID=qnTable.ID; changed=true; end
								if (changed) then break; end	-- This q okay
						end end
						qi=qi+1
				end end
				if (changed) then dcdb.Quest[CONST.MYFACTION][LootCount_DropCount_Character.LastQG[i]]=tqg; end
			end
			i=i+1
	end end
end

function DropCount:WalkQuests()
	if (not DropCount.SpoolQuests) then return; end
	-- Stuff all known headers
	local converted=nil;
	if (not dcdb.Quest) then return; end
	for quest,qTable in pairs(DropCount.SpoolQuests) do
		for faction,fTable in pairs(dcdb.Quest) do
			if (faction=="Neutral" or faction==CONST.MYFACTION) then
				for npc,nData in rawpairs(fTable) do
					if (nData:find(quest,1,true)) then
						local nTable=dcdb.Quest[faction][npc];
						if (nTable.Quests) then
							local changed=nil;
							for index,qData in pairs(nTable.Quests) do
								if (type(qData)~="table") then nTable.Quests[index]={ Quest=qData, }; converted=true; changed=true; end
								if (nTable.Quests[index].Quest==quest) then
									if (not nTable.Quests[index].Header or
										(qTable.Header and nTable.Quests[index].Header~=qTable.Header)) then
										nTable.Quests[index].Header=qTable.Header;
										changed=true;
							end end end
							if (changed) then dcdb.Quest[faction][npc]=nTable; end
		end end end end end
		DropCount.SpoolQuests[quest]=nil;
		return;
	end
	if (empty) then DropCount.SpoolQuests=nil; end
end

function DropCount.MT.Icons:PlotWorldmap()
	if (not WorldMapDetailFrame) then return; end
	local mapID=GetCurrentMapAreaID();
	local floorNum=GetCurrentMapDungeonLevel();
	local ZoneName=LootCount_DropCount_Maps[GetLocale()]
	if (ZoneName) then ZoneName=ZoneName[mapID]; end
	local unit=DropCount.MT.Icons:BuildIconList(mapID,floorNum,nil,dcdb.BookWorldmap,dcdb.ForgeWorldmap,dcdb.QuestWorldmap,dcdb.VendorWorldmap,dcdb.RepairWorldmap,dcdb.TrainerWorldmap,dcdb.GridWorldmap,dcdb.RareWorldmap,dcdb.HerbWorldmap,dcdb.OreWorldmap);
	local index=1;
	while (_G["LCDC_WorldmapIcon"..index]) do _G["LCDC_WorldmapIcon"..index]:Hide(); index=index+1; end
	for index,eTable in pairs(unit) do
		eTable.width=eTable.width or (12/CONST.WMSQ_W);
		eTable.height=eTable.height or (12/CONST.WMSQ_H);
		MT:Yield();
		if (not _G["LCDC_WorldmapIcon"..index]) then
			DropCountXML.Icon.WM[index]=CreateFrame("Button","LCDC_WorldmapIcon"..index,WorldMapDetailFrame,"LCDC_VendorFlagTemplate");
			DropCountXML.Icon.WM[index].icon=DropCountXML.Icon.WM[index]:CreateTexture("ARTWORK");
		else DropCountXML.Icon.WM[index]=_G["LCDC_WorldmapIcon"..index]; end
		DropCountXML.Icon.WM[index].icon:SetTexture(eTable.icon);
		DropCountXML.Icon.WM[index]:SetWidth(CONST.WMSQ_W*eTable.width); DropCountXML.Icon.WM[index]:SetHeight(CONST.WMSQ_H*eTable.height);
		if (eTable.r and eTable.g and eTable.b) then DropCountXML.Icon.WM[index].icon:SetVertexColor(eTable.r,eTable.g,eTable.b,eTable.a or 1);
		else DropCountXML.Icon.WM[index].icon:SetVertexColor(1,1,1,eTable.a or 1); end
		DropCountXML.Icon.WM[index].icon:SetAllPoints();
		if (not eTable.X or not eTable.Y) then DropCount:Chat("Broken entry: "..eTable.Name.." - "..eTable.Type); end
		DropCountXML.Icon.WM[index].Info={
			Name=eTable.Name,
			Type=eTable.Type,
			Service=eTable.Service,
			Map=mapID,
			Floor=floorNum,
			X=eTable.X/100,
			Y=eTable.Y/100,
			hW=(DropCountXML.Icon.WM[index]:GetWidth()/2)/CONST.WM_W,	-- 0-1
			hH=(DropCountXML.Icon.WM[index]:GetHeight()/2)/CONST.WM_H,	-- 0-1
		}
		Astrolabe:PlaceIconOnWorldMap(	WorldMapDetailFrame,
										DropCountXML.Icon.WM[index],
										DropCountXML.Icon.WM[index].Info.Map,
										DropCountXML.Icon.WM[index].Info.Floor,
										DropCountXML.Icon.WM[index].Info.X+DropCountXML.Icon.WM[index].Info.hW,
										DropCountXML.Icon.WM[index].Info.Y+DropCountXML.Icon.WM[index].Info.hH);
	end
end

function DropCountXML:OnEnterIcon(frame)
	LCDC_VendorFlag_Info=true;
	if (not frame.Info) then return; end
	if (frame.Info.Type=="Vendor") then DropCount.Tooltip:SetNPCContents(frame.Info.Name); return; end
	if (frame.Info.Type=="Book") then DropCount.Tooltip:Book(frame.Info.Name,parent); return; end
	if (frame.Info.Type=="Quest") then DropCount.Tooltip:QuestList(CONST.MYFACTION,frame.Info.Name,parent); return; end
	if (frame.Info.Type=="Grid") then DropCount.Tooltip:Grid(frame.Info.Service,parent); return; end
	if (frame.Info.Type=="Rare") then DropCount.Tooltip:Rare(frame.Info.Service,parent); return; end
	if (frame.Info.Type=="Gather") then DropCount.Tooltip:Gather(frame.Info.Service,parent); return; end
	LootCount_DropCount_TT:ClearLines();
	LootCount_DropCount_TT:SetOwner(UIParent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText(frame.Info.Name);
	LootCount_DropCount_TT:LCAddLine(frame.Info.Type,1,1,1);
	if (frame.Info.Service) then LootCount_DropCount_TT:LCAddLine(frame.Info.Service,1,1,1); end
	LootCount_DropCount_TT:Show();
end

local function colour_R(hue)
	hue=hue%360;
	if (hue<60 or hue>=300) then return 1; end
	if (hue>=120 and hue<240) then return 0; end
	if (hue>=240) then hue=(hue-240)/60; return hue; end
	hue=(119-hue)/60; return hue;
end

local function colour_G(hue)
	hue=hue%360;
	if (hue<120) then return 0; end
	if (hue>=180 and hue<300) then return 1; end
	if (hue<180) then hue=(hue-120)/60; return hue; end
	hue=(359-hue)/60; return hue;
end

local function colour_B(hue)
	hue=hue%360;
	if (hue>=240) then return 0; end
	if (hue>=60 and hue<180) then return 1; end
	if (hue<60) then hue=hue/60; return hue; end
	hue=(239-hue)/60; return hue;
end

local function hueRGB(hue)
	return colour_R(hue),colour_G(hue),colour_B(hue); end

local function blendspot(m1,m2,list)
	if (not m2 or m1==m2) then return m1; end	-- a quickie
	if (not m1) then return m2; end				-- a quickie
	if (not list) then list={nil,nil,nil}; end	-- pre-hash to 4
	wipe(list);
	if (m1 and m1~="") then for _,m in ipairs({strsplit(",",m1)}) do list[m]=true; end end
	if (m2 and m2~="") then for _,m in ipairs({strsplit(",",m2)}) do list[m]=true; end end
	if (not next(list)) then return nil; end	-- nothing
	m1=""; for m in pairs(list) do m1=m1..m..","; end
	return m1:sub(1,-2);	-- cut last comma
end

local function checkspot(ref,spot)
	if (not spot or spot.r~=ref.r or spot.g~=ref.g or spot.b~=ref.b) then return nil; end
	if (spot.width and spot.width>1) then return nil; end
	if (spot.height and spot.height>1) then return nil; end
	return true;
end

-- intersection of mobs
local function dointersect(m1,m2)
	if (not m1 or not m2) then return nil; end
	local mobs="";
	for _,m in ipairs({strsplit(",",m1)}) do if (m2:find(m)) then mobs=mobs..m..","; end end		-- check every 1 in 2
	if (mobs=="") then return nil; end		-- no intersection
	return mobs:sub(1,-2);	-- cut last comma
end

function DropCount.MT.Icons:AddIcons_Grid(unit,zn,mapID,level,minimal)
	if (not LootCount_DropCount_Character.Sheet) then LootCount_DropCount_Character.Sheet={ Item={}, Creature={}, }; end
	if (not LootCount_DropCount_Character.Sheet.Item) then LootCount_DropCount_Character.Sheet.Item={}; end
	if (not LootCount_DropCount_Character.Sheet.Creature) then LootCount_DropCount_Character.Sheet.Creature={}; end

	local buf=dcdb.Grid[mapID.."_"..level];		-- unpack grid
	local filter=next(LootCount_DropCount_Character.Sheet.Item) or next(LootCount_DropCount_Character.Sheet.Creature);
	if (not DropCount_Local_Code_Enabled and not filter) then return; end
	-- distill mobs
	local allmobs={};
	for _,m in pairs(buf) do for __,sg in ipairs({strsplit(",",m)}) do allmobs[sg]=true; end MT:Yield(); end
	-- lists mobs
	local types={};
	for m in pairs(allmobs) do
		if (not filter or LootCount_DropCount_Character.Sheet.Creature[m]) then types[m]=true; MT:Yield();
	end end
	-- list items
	local items={};
	for i in pairs(LootCount_DropCount_Character.Sheet.Item or {}) do					-- check requested items
		local ibuf=dcdb.Item[i]; if (ibuf) then for sg in pairs(allmobs) do				-- cycle all zone mobs
				if ((ibuf.Name and ibuf.Name[sg]) or (ibuf.Skinning and ibuf.Skinning[sg])) then	-- mob present in item
					items[i]=items[i] or {m={}};										-- init item filter
					if (ibuf.Name and ibuf.Name[sg]) then items[i].n=true; end			-- set normal loot
					if (ibuf.Skinning and ibuf.Skinning[sg]) then items[i].s=true; end	-- set skinning loot
					table.insert(items[i].m,sg);										-- set mob
				end
				MT:Yield();
	end end end
	-- create entry list
	local part,list=0,{};
	for sg in pairs(types) do					-- do all requested mobs
		part=part+1;
		for spot,mobs in pairs(buf) do			-- do all recorded spots
			if (mobs:find(sg)) then if (list[spot]) then list[spot]=list[spot]..","..sg; else list[spot]=sg; end
		end
		MT:Yield();
	end end
	for i,_ in pairs(items) do					-- do all requested items
		part=part+1;
		for spot,mobs in pairs(buf) do			-- do all recorded spots
			for _,m in ipairs(items[i].m) do	-- do all mobs for this item
				if (mobs:find(m)) then if (list[spot]) then list[spot]=list[spot]..","..i; else list[spot]=i; end end
			end
			MT:Yield();
	end end
	-- assign colours
	part=(360/part)%360;	-- 0-359
	local hue=120;			-- blue
	for sg in pairs(types) do types[sg]=hue; hue=(hue+part)%360; MT:Yield(); end
	for i in pairs(items) do items[i].h=hue; hue=(hue+part)%360; MT:Yield(); end
	-- create sheet display
	local oldlist=copytable(list);
	local hx,hy,x,y,gx,gy,gs;
	local temp={nil,nil,nil};
	for spot in pairs(oldlist) do
		hx,hy=xy(spot);		-- set center location
	--	outer rim.............................................      inner square................... inner..                        center.... outer rim....  inner...
	--	X       Y       Validate coordinate validity                X        Y        Spot          data                           data       data           data
		x=hx-2; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-1; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx;   y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+1; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy-1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy-1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy;   if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy;   gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy;   if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy;   gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy+1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy+1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-1; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx;   y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+1; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		MT:Yield();
	end
	wipe(oldlist);
	-- create grid colours
	local colour,cont,tr,tg,tb,hc,r,g,b={};
	for spot in pairs(list) do
		cont={strsplit(",",list[spot])};
		tr,tg,tb,hc=0,0,0,0;
		for _,c in ipairs(cont) do
			if (types[c]) then r,g,b=hueRGB(types[c]);	-- mob hue
			else r,g,b=hueRGB(items[c].h); end			-- item hue
			tr=tr+r; tg=tg+g; tb=tb+b;					-- sum up
		end
		hc=tr;
		if (tg>hc) then hc=tg; end
		if (tb>hc) then hc=tb; end
		if (hc<1) then hc=1; end
		colour[spot]={r=tr/hc,g=tg/hc,b=tb/hc};
		MT:Yield();
	end
	wipe(types); wipe(items);		-- done with these
	-- reduce by enlarge
	for hy=0,99 do for hx=0,99 do
		local spot=xy(hy,hx);
		if (colour[spot]) then				-- there's something unhandled here
			colour[spot].width=1;
			colour[spot].height=1;
			local sx,sy=xy(spot);			-- get loc
			local tx,ty=sx+1,sy;			-- preset next loc
			local tspot=xy(tx,ty);			-- set test-spot
			-- find first full line
			while(checkspot(colour[spot],colour[tspot])) do	-- expandable spot
				colour[tspot]=nil;							-- kill spot
				colour[spot].width=colour[spot].width+1;	-- expand left spot to the right
				tx=tx+1; tspot=xy(tx,ty);					-- set next spot
			end
			tx=tx-1;		-- this broke, so go back
			-- find full lines
			local valid=true;
			repeat
				ty=ty+1;					-- next line
				for scan=sx,tx do
					tspot=xy(scan,ty);		-- set test-spot
					if (not checkspot(colour[spot],colour[tspot])) then valid=nil; break; end	-- not equal or usable -> not a full line -> we're done here
				end
				if (valid) then
					colour[spot].height=colour[spot].height+1;		-- add one height
					for scan=sx,tx do colour[xy(scan,ty)]=nil; end	-- clear base data - width set at first line
				end
			until (not valid);
		end
	end MT:Yield(); end		-- hx,hy loops
	-- create icon entries
	local x,y,r,g,b;
	for area in pairs(colour) do
		x,y=xy(area);
		table.insert(unit,{Name=tostring(x)..","..tostring(y),Service=list[area],Type="Grid",X=x,Y=y,a=.3,r=colour[area].r,g=colour[area].g,b=colour[area].b,icon="Interface\\AddOns\\LootCount_DropCount\\white.tga",width=colour[area].width,height=colour[area].height});
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Book(unit,zn,mapID,level,minimal)
	for book,rawbook in rawpairs(dcdb.Book) do
		if (rawbook:find(zn,1,true)) then
			local buf=dcdb.Book[book];
			if (buf[""]) then buf[""]=nil; dcdb.Book[book]=buf; end
			for index,bTable in pairs(dcdb.Book[book]) do
				if (bTable.Zone and bTable.Zone:find(zn,1,true)==1) then
					table.insert(unit,{Name=book,Type="Book",X=bTable.X,Y=bTable.Y,icon="Interface\\Spellbook\\Spellbook-Icon"});
				end
				MT:Yield();
	end end end
end

function DropCount.MT.Icons:AddIcons_Forge(unit,zn,mapID,level,minimal)
	local raw=dcdb.Forge[zn];
	if (raw) then
		for forge,fRaw in pairs(raw) do
			local x,y=fRaw:match("(.+)_(.+)"); x=tonumber(x); y=tonumber(y);
			table.insert(unit,{Name="Forge",Type="Forge",X=x,Y=y,icon=CONST.PROFICON[5]});
	end end
	MT:Yield();
end

function DropCount.MT.Icons:AddIcons_Quest(unit,zn,mapID,level,minimal)
	for npc,nRaw in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
		if (nRaw:find(zn,1,true)) then
			local nTable=dcdb.Quest[CONST.MYFACTION][npc];
			if (nTable.Quests) then
				if (nTable.Zone and nTable.Zone:find(zn,1,true)==1) then
					local r,g,b,level=1,1,1,0;
					for _,qTable in pairs(nTable.Quests) do
						local state=DropCount:GetQuestStatus(qTable.ID,qTable.Quest);
						if (state==CONST.QUEST_NOTSTARTED and level<3) then r,g,b=0,1,0; level=3; end
						if (state==CONST.QUEST_STARTED and level<2) then r,g,b=1,1,1; level=2; end
						if (state==CONST.QUEST_DONE and level<1) then r,g,b=0,0,0; level=1; end
						if (state==CONST.QUEST_UNKNOWN) then r,g,b=1,0,0; level=100; end
					end
					if (level>1 or not minimal) then
						table.insert(unit,{Name=npc,Type="Quest",X=nTable.X,Y=nTable.Y,r=r,g=g,b=b,icon="Interface\\QuestFrame\\UI-Quest-BulletPoint"});
		end end end end
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Vendor(unit,zn,mapID,level,minimal)
	for vendor,vRaw in rawpairs(dcdb.Vendor) do
		if (vRaw:find(zn,1,true)) then
			local buf=dcdb.Vendor[vendor];
			local x,y,zone,faction,repair=buf.X,buf.Y,buf.Zone,buf.Faction,buf.Repair;
			if (faction=="Neutral" or faction==CONST.MYFACTION) then
				if (zone and zone:find(zn,1,true)==1) then
					local texture="Interface\\GROUPFRAME\\UI-Group-MasterLooter";
					if (repair) then texture="Interface\\GossipFrame\\VendorGossipIcon"; end
					table.insert(unit,{Name=vendor,Type="Vendor",X=x,Y=y,icon=texture});
		end end end
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Trainer(unit,zn,mapID,level,minimal)
	for npc,nRaw in rawpairs(dcdb.Trainer[CONST.MYFACTION]) do
		if (nRaw:find(zn,1,true)) then
			local nTable=dcdb.Trainer[CONST.MYFACTION][npc];
			if (nTable.Zone and nTable.Zone:find(zn,1,true)==1) then
				local texture="Interface\\Icons\\INV_Misc_QuestionMark";
				for index,prof in pairs(CONST.PROFESSIONS) do
					if (prof==nTable.Service or prof:find(nTable.Service) or nTable.Service:find(prof)) then texture=CONST.PROFICON[index]; break; end
				end
				table.insert(unit,{Name=npc,Service=nTable.Service,Type="Trainer",X=nTable.X,Y=nTable.Y,icon=texture});
		end end
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Rare(unit,zn,mapID,level,minimal)
	local buf=dcdb.Grid[mapID.."_"..level];		-- unpack grid
	if (not buf) then return; end
	-- distill mobs
	local allmobs={};
	for _,m in pairs(buf) do for __,sg in ipairs({strsplit(",",m)}) do allmobs[sg]=true; end MT:Yield(); end
	-- lists mobs
	local types={};
	for m in pairs(allmobs) do
		if (not filter or LootCount_DropCount_Character.Sheet.Creature[m]) then types[m]=true; MT:Yield();
	end end
	-- filter out non-rare mobs
	for mob in pairs(types) do
		local buf=dcdb.Count[mob];
		if (not buf or not buf.C or not buf.C:find("rare",1,true)) then
			types[mob]=nil;
	end end
	-- create filtered entry list
	local list={};
	for sg in pairs(types) do					-- do all requested mobs
		for spot,mobs in pairs(buf) do			-- do all recorded spots
			if (mobs:find(sg)) then if (list[spot]) then list[spot]=list[spot]..","..sg; else list[spot]=sg; end
		end
		MT:Yield();
	end end
	-- create sheet display
	local oldlist=copytable(list);
	local hx,hy,x,y,gx,gy,gs;
	local temp={nil,nil,nil};	-- pre-hash to 4
	for spot in pairs(oldlist) do
		hx,hy=xy(spot);		-- set center location
	--	outer rim.............................................      inner square................... inner..                        center.... outer rim....  inner...
	--	X       Y       Validate coordinate validity                X        Y        Spot          data                           data       data           data
		x=hx-2; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-1; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx;   y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+1; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy-2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy-1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy-1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy-1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy;   if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy;   gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy;   if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy;   gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy+1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy+1; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-2; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx-1; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx-1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx;   y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx;   gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+1; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		x=hx+2; y=hy+2; if (x>=0 and y>=0 and x<=99 and y<=99) then gx=hx+1; gy=hy+1; gs=xy(gx,gy); list[gs]=blendspot(dointersect(list[spot],list[xy(x,y)]),list[gs],temp); end
		MT:Yield();
	end
	wipe(oldlist);
	-- create icon entries
	local x,y,r,g,b;
	for area in pairs(list) do
		x,y=xy(area);
		table.insert(unit,{Name=tostring(x)..","..tostring(y),Service=list[area],Type="Rare",X=x,Y=y-.25,a=1,r=1,g=1,b=1,icon="INTERFACE\\Challenges\\ChallengeMode_Medal_Silver",width=2,height=2});
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Herbs(...)
	if (not dcdb.Gather.GatherHERB) then return; end return DropCount.MT.Icons:AddIcons_Gather(dcdb.Gather.GatherHERB,...); end
function DropCount.MT.Icons:AddIcons_Ore(...)
	if (not dcdb.Gather.GatherORE) then return; end return DropCount.MT.Icons:AddIcons_Gather(dcdb.Gather.GatherORE,...); end
function DropCount.MT.Icons:AddIcons_Gather(base,unit,zn,mapID,level,minimal)
	local node=(base==dcdb.Gather.GatherHERB and "Herb") or "Ore";
	local icon=(base==dcdb.Gather.GatherHERB and CONST.PROFICON[2]) or CONST.PROFICON[3];
	local buf=base[mapID.."_"..level]; if (not buf) then return; end	-- unpack
	local pos=0;					-- bit-position
	local grid=buf.Grid;
	local i=1;
	repeat
		if (grid:byte(i,i)==0) then i=i+1; pos=pos+(grid:byte(i,i)*8);
		else
			local x,y;
			local tmp=grid:byte(i,i);
			for j=1,8 do
				if (bit.band(tmp,1)==1) then
					y,x=xy(pos);		-- NOTE: x/y swap
					table.insert(unit,{Name=node.." "..tostring(x)..","..tostring(y),Service=buf,Type="Gather",X=x,Y=y-.25,a=1,r=1,g=1,b=1,icon=icon,width=.75,height=.75});
				end
				MT:Yield();
				tmp=bit.rshift(tmp,1);
				pos=pos+1;
		end end
		i=i+1;
	until(i>grid:len());
end

function DropCount.MT.Icons:BuildIconList(mapID,level,minimal,bBook,bForge,bQuest,bVendor,bRepair,bTrainer,bGrid,bRare,bGatherHERB,bGatherORE)
	local zn=LootCount_DropCount_Maps[GetLocale()][mapID];
	local unit={};
	if (bGrid and dcdb.Grid[mapID.."_"..level]) then self:AddIcons_Grid(unit,zn,mapID,level,minimal); end	-- Grid
	if (bBook) then self:AddIcons_Book(unit,zn,mapID,level,minimal); end	-- Book
	if (bForge) then self:AddIcons_Forge(unit,zn,mapID,level,minimal); end	-- Forge
	if (bQuest and dcdb.Quest[CONST.MYFACTION]) then self:AddIcons_Quest(unit,zn,mapID,level,minimal); end	-- Quest
	if (bVendor or bRepair) then self:AddIcons_Vendor(unit,zn,mapID,level,minimal); end	-- Vendor
	if (bTrainer and dcdb.Trainer[CONST.MYFACTION]) then self:AddIcons_Trainer(unit,zn,mapID,level,minimal); end	-- Trainer
	if (bRare) then self:AddIcons_Rare(unit,zn,mapID,level,minimal); end	-- Rare creatures
	if (bGatherHERB) then self:AddIcons_Herbs(unit,zn,mapID,level,minimal); end	-- gathering profession
	if (bGatherORE) then self:AddIcons_Ore(unit,zn,mapID,level,minimal); end	-- gathering profession
	return unit;
end

function DropCount.MT.Icons:PlotMinimap()
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();	-- Map helpers
	local unit=DropCount.MT.Icons:BuildIconList(mapID,floorNum,true,dcdb.BookMinimap,dcdb.ForgeMinimap,dcdb.QuestMinimap,dcdb.VendorMinimap,dcdb.RepairMinimap,dcdb.TrainerMinimap,dcdb.GridMinimap,dcdb.RareMinimap,dcdb.HerbMinimap,dcdb.OreMinimap);
	for index,eTable in pairs(DropCountXML.Icon.MM) do Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.MM[index]); end
	for index,eTable in pairs(unit) do
		MT:Yield(true);
		if (not _G["LCDC_MinimapIcon"..index]) then
			DropCountXML.Icon.MM[index]=CreateFrame("Button","LCDC_MinimapIcon"..index,UIParent,"LCDC_VendorFlagTemplate");
			DropCountXML.Icon.MM[index].icon=DropCountXML.Icon.MM[index]:CreateTexture("ARTWORK");
		else
			DropCountXML.Icon.MM[index]=_G["LCDC_MinimapIcon"..index];
		end
		DropCountXML.Icon.MM[index].icon:SetTexture(eTable.icon);
		if (eTable.r and eTable.g and eTable.b) then DropCountXML.Icon.MM[index].icon:SetVertexColor(eTable.r,eTable.g,eTable.b);
		else DropCountXML.Icon.MM[index].icon:SetVertexColor(1,1,1); end
		DropCountXML.Icon.MM[index].icon:SetAllPoints();
		if (not eTable.X or not eTable.Y) then DropCount:Chat("Broken entry: "..eTable.Name.." - "..eTable.Type,1); end	-- can be in some very old data
		DropCountXML.Icon.MM[index].Info={
			Name=eTable.Name,
			Type=eTable.Type,
			Service=eTable.Service,
			Map=mapID,
			Floor=floorNum,
			X=eTable.X/100,
			Y=eTable.Y/100,
		}
		Astrolabe:PlaceIconOnMinimap(DropCountXML.Icon.MM[index],DropCountXML.Icon.MM[index].Info.Map,DropCountXML.Icon.MM[index].Info.Floor,DropCountXML.Icon.MM[index].Info.X,DropCountXML.Icon.MM[index].Info.Y);
	end
end

function DropCount:GetMapTable()
	local map={}; map.ID,map.Floor,_,_=Astrolabe:GetCurrentPlayerPosition(); return map; end

function DropCount:ReadMerchant(dude)
	local rebuildIcons=nil;
	local numItems=GetMerchantNumItems();
	if (not numItems or numItems<1) then return true; end
	local vData;
	if (not dcdb.Vendor[dude]) then vData={ Items={} }; rebuildIcons=true; DropCount:Chat(Basic.."DropCount:|r "..Green.."New vendor added to database|r");
	else vData=dcdb.Vendor[dude]; end
	local posX,posY=DropCount:GetPlayerPosition();
	vData.Repair=_G.MerchantRepairAllButton:IsVisible();
	vData.Zone=DropCount:GetFullZone();
	vData.X,vData.Y=posX,posY;
	vData.Faction=DropCount.Target.LastFaction;
	vData.Map=DropCount:GetMapTable();
	-- Remove all permanent items
	if (vData.Items) then
		for item,avail in pairs(vData.Items) do
			if (not avail or not avail.Count or avail.Count==0 or avail.Count==CONST.PERMANENTITEM) then vData.Items[item]=nil; end
	end end
	-- Add all items
	local ReadOk,index=true,1;
	while (index<=numItems) do
		local link=GetMerchantItemLink(index);
		link=DropCount:GetID(link);
		if (link) then
			local itemName,itemLink=GetItemInfo(link);
			local _,_,_,_,count=GetMerchantItemInfo(index);			-- count==-1 unlimited
			if (not vData.Items) then vData.Items={}; end
			vData.Items[link]={ Name=itemName, Count=count, };
		else ReadOk=nil; end
		index=index+1;
	end
	if (not ReadOk) then DropCount.VendorReadProblem=true;
	else
		dcdb.Vendor[dude]=vData;
		if (DropCount.VendorReadProblem or rebuildIcons) then MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end
	end
	return ReadOk;
end

function DropCount.Map:ForDatabase()
	SetMapToCurrentZone();	-- Missä vittu me olemme
	local mapID,floorNum=GetCurrentMapAreaID (),GetCurrentMapDungeonLevel();	-- Set the Astrolabe pair
	local here=GetRealZoneText(); if (not here) then here=" "; end
	local ss=GetSubZoneText(); if (not ss) then ss=" "; end
	-- Update internal mapID register for this locale
	if (not LootCount_DropCount_Maps) then LootCount_DropCount_Maps={}; end
	if (not LootCount_DropCount_Maps[GetLocale()]) then LootCount_DropCount_Maps[GetLocale()]={}; end
	LootCount_DropCount_Maps[GetLocale()][mapID]=here;
	return mapID,floorNum,here,ss,here.." - "..ss;
end

function DropCount:GetFullZone()
	local here=GetRealZoneText() or "";			-- Set zone for last kill
	if (here=="") then return nil; end
	local ss=GetSubZoneText();					-- Set subzone/area for last kill
	if (ss=="") then ss=nil; end
	if (ss) then here=here.." - "..ss; end
	return here;
end

function DropCount:GetPlayerPosition()
	local posX,posY=GetPlayerMapPosition("player"); return (floor(posX*100000))/1000,(floor(posY*100000))/1000; end

function DropCount:AddKill(oma,GUID,sguid,mob,reservedvariable,noadd,notransmit,otherzone)
	if (not mob and not sguid) then return; end
	-- Check if already counted
	local i=DropCount.Tracker.QueueSize;
	while (i>0) do if (DropCount.Tracker.TimedQueue[i].GUID==GUID) then return; end i=i-1; end
	local now=time();
	local mTable=dcdb.Count[sguid];
	if (not mTable) then mTable={ Kill=0, Name=mob };
	elseif (not mTable.Name) then mTable.Name=mob; end
	if (sguid==DropCount.Target.ClassificationSGUID and DropCount.Target.Classification~="normal") then mTable.C=DropCount.Target.Classification; end
	if (not otherzone) then otherzone=DropCount:GetFullZone(); end
	mTable.Zone=otherzone;		-- Set zone for last kill
	if (not noadd) then
		if (not mTable.Kill) then mTable.Kill=0; end
		mTable.Kill=mTable.Kill+1;
		if (not nagged) then		-- tell about the milestone. send tha stuff!
			if (mTable.Name and ((mTable.Kill<=50 and mTable.Kill%25==0) or mTable.Kill%100==0)) then
				DropCount:Chat(Basic.."DropCount: "..Yellow..mTable.Name..Basic.." has been killed "..Yellow..mTable.Kill..Basic.." times!");
				DropCount:Chat(Basic.."Please consider submitting your SavedVariables file at "..Yellow.."ducklib.com -> DropCount"..Basic..", or sending it to "..Yellow.."dropcount@ducklib.com"..Basic.." to help develop the DropCount addon.");
				nagged=true;
		end end
		dcdb.Count[sguid]=mTable;
	else dcdb.Count[sguid]=mTable; return; end
	if (not mob) then return; end
	DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize+1;
	table.insert(DropCount.Tracker.TimedQueue,1,{Mob=mob,GUID=GUID,Oma=oma,Time=now});
	if (DropCount.Tracker.QueueSize>=10) then
		MT:Run("MM Update Best "..DropCount.Tracker.TimedQueue[10].Mob,DropCount.MT.UpdateBest,DropCount.MT);
	end
end

-- update best areas
function DropCount.MT:UpdateBest()
	local mDB=dcdb.Count[DropCount.Tracker.TimedQueue[10].Mob];
	if (mDB and mDB.Zone) then
		local list=DropCount:BuildItemList(DropCount.Tracker.TimedQueue[10].Mob);
		for item,percent in pairs(list) do
			MT:Yield();
			local iDB=dcdb.Item[item];
			local store=nil;
			if (not iDB.Best) then iDB.Best={ Location=mDB.Zone, Score=percent }; store=true;
			elseif (percent>iDB.Best.Score or mDB.Zone==iDB.Best.Location) then iDB.Best={ Location=mDB.Zone, Score=percent }; store=true;
			end
			if (not IsInInstance()) then
				if (not iDB.BestW) then iDB.BestW={ Location=mDB.Zone, Score=percent }; store=true;
				elseif (percent>iDB.BestW.Score or mDB.Zone==iDB.BestW.Location) then iDB.BestW={ Location=mDB.Zone, Score=percent }; store=true;
			end end
			if (store) then
				if (iDB.Best and iDB.BestW and iDB.Best.Location==iDB.BestW.Location and iDB.Best.Score==iDB.BestW.Score) then iDB.BestW=nil; end
				dcdb.Item[item]=iDB;
	end end end
end

function DropCount:AddLootMob(GUID,sguid,mob,item)
	local nameTable;
	local iTable=dcdb.Item[item];
	if (DropCount.ProfessionLootMob) then if (not iTable.Skinning) then iTable.Skinning={}; end nameTable=iTable.Skinning;
	else if (not iTable.Name) then iTable.Name={}; end nameTable=iTable.Name; end
	-- New stuff, so make database ready
	if (not nameTable[sguid]) then nameTable[sguid]=0; end		-- Mob not in drop-list -> Not looted, but make entry (will be added later)
	dcdb.Item[item]=iTable;
	if (not dcdb.Count[sguid]) then DropCount:AddKill(nil,GUID,sguid,mob,nil,true,true,""); end	-- Mob not in kill-list -> Add it with zero kills
end

function DropCount:AddLoot(GUID,sguid,mob,item,count,notransmit)
	local now,iTable=time(),dcdb.Item[item];
	if (not iTable) then iTable={}; end
	local itemName,itemLink=GetItemInfo(item);
	iTable.Item=itemName; iTable.Time=now;				-- Last point in time for loot of this item
	dcdb.Item[item]=iTable;
	DropCount:AddLootMob(GUID,sguid,mob,item);			-- Make register
	iTable=dcdb.Item[item];
	local skinning,nameTable;
	if (DropCount.ProfessionLootMob) then nameTable=iTable.Skinning; skinning=true;
	else nameTable=iTable.Name; end
	nameTable[sguid]=nameTable[sguid]+count;
	dcdb.Item[item]=iTable;
	if (skinning) then		-- Skinner-loot, so add it as a skinning-kill
		if (DropCount.Target.UnSkinned and DropCount.Target.UnSkinned==sguid) then
			local mTable=dcdb.Count[sguid];
			if (mTable) then
				if (not mTable.Skinning) then mTable.Skinning=0; end
				mTable.Skinning=mTable.Skinning+1;
				DropCount.Target.UnSkinned=nil;					-- Added, so next loot on this target is more than one items from same skinning
				dcdb.Count[sguid]=mTable;
	end end end
	if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
end

function DropCount:GetRatio(item,sguid)
	if (CONST.QUESTID) then
		local _,_,_,_,_,itemtype=GetItemInfo(item);
		local _,itemID=DropCount:GetID(item);
		if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then return CONST.QUESTRATIO,CONST.QUESTRATIO; end
	end
	if (not dcdb.Item[item]) then return 0,0,true; end		-- no such item
	if (not dcdb.Count[sguid]) then return 0,0,true; end	-- no such dude
	local nKills,nRatio,sKills,sRatio=0,0,0,0;
	local iTable=dcdb.Item[item];
	if (not iTable.Name and not iTable.Skinning) then return 0,0,true; end	-- nothing
	if (iTable.Name and not iTable.Name[sguid]) then nRatio=0; end			-- not there
	if (iTable.Skinning and not iTable.Skinning[sguid]) then sRatio=0; end	-- not there
	local mTable=dcdb.Count[sguid];
	if (iTable.Name) then
		nKills=mTable.Kill; nRatio=0;
		if (nKills and nKills>0 and iTable.Name[sguid]) then
			nRatio=iTable.Name[sguid]/nKills;
			if (iTable.Name[sguid]<2) then unsafe=true; end
	end end
	if (iTable.Skinning) then
		sKills=mTable.Skinning; sRatio=0;
		if (sKills and sKills>0 and iTable.Skinning[sguid]) then
			sRatio=iTable.Skinning[sguid]/sKills;
			if (iTable.Skinning[sguid]<2) then unsafe=true; end
	end end
	return nRatio,sRatio;
end

function DropCount:TimedQueueRatio(item,noyield)
	local inqueue={};
	local i=1;
	while (i<=DropCount.Tracker.QueueSize and DropCount.Tracker.TimedQueue[i]) do
		if (DropCount.Tracker.TimedQueue[i].Oma) then	-- my kills only
			if (not noyield) then MT:Yield(); end
			if (not inqueue[DropCount.Tracker.TimedQueue[i].Mob]) then
				local drop,sD=DropCount:GetRatio(item,DropCount.Tracker.TimedQueue[i].Mob);
				if (not drop or drop==0) then drop=sD; end
				inqueue[DropCount.Tracker.TimedQueue[i].Mob]={ Count=1, Ratio=drop };
			else
				inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count=inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count+1;
		end end
		i=i+1;
	end
	local ratio,count=0,0;
	for mob,mTable in pairs(inqueue) do count=count+mTable.Count; ratio=ratio+(mTable.Count*mTable.Ratio); end
	if (count<1) then return; end
	return ratio/count;
end

function DropCount:FormatPst(ratio,addition)
	if (not ratio) then ratio=0; end
	if (ratio<0) then return "Quest"; end
	if (not addition) then addition=""; end
	local pc=ratio*100;
	if (pc>=10) then return string.format("%.0f",pc)..addition;
	elseif (pc>=1) then return string.format("%.1f",pc)..addition;
	elseif (pc==0) then return "0"..addition; end
	return string.format("%.02f",pc)..addition;
end

-- LootCount: Callback
function DropCount.LootCount.DropItem(button,itemID)
	DropCount.LootCount:SetButtonInfo(button,itemID,true);						-- Start counting from now
	_,_,_,_,_,_,_,_,_,button.User.Texture=GetItemInfo(itemID);					-- Set custom texture
end

-- LootCount: Callback
function DropCount.LootCount.IconClicked(button,LR,count)
	if (count~=1) then return; end
	if (LR=="RightButton") then DropCount.LootCount:ToggleMenu(button); end
end

-- LootCount: Support
function DropCount.LootCount.Tooltip(button) DropCount.Tooltip:MobList(button,true); end

-- LootCount: Callback
function DropCount.LootCount.UpdateButton(button)
	if (not button) then return; end			-- End of iteration
	if (not button.User or not button.User.Texture) then return; end
	local texture=_G[button:GetName().."IconTexture"];
	texture:SetTexture(button.User.Texture);			-- Set texture from item
	if (not dcdb.Item[button.User.itemID]) then return; end			-- Nothing assigned yet
	local iTable=dcdb.Item[button.User.itemID];
	if (not iTable.Name and not itable.Skinning) then return; end	-- No known droppers
	local ratio=DropCount:TimedQueueRatio(button.User.itemID,true);
	local goalvalue=nil;
	if (button.goal and button.goal>0) then
		local amount=LootCount_GetItemCount(button.User.itemID);
		if (amount>=button.goal) then goalvalue="OK";
		else
			goalvalue=button.goal-amount;
			if (ratio>0) then goalvalue=math.ceil(goalvalue/ratio); else goalvalue=""; end
	end end
	if (DropCount.LootCount.Registered) then LootCountAPI.SetData(LOOTCOUNT_DROPCOUNT,button,DropCount:FormatPst(ratio),goalvalue); end
end

-- LootCount: Support
function DropCount.LootCount:SetButtonInfo(button,itemID,clearit)
	if (not button.User) then button.User = { };
	elseif (clearit) then wipe(button.User); end
	if (not button.User.itemID or itemID) then
		if (not itemID) then return nil; end
		button.User.itemID=itemID;
	end
	return true;
end

-- LootCount: Support
function DropCount.LootCount:ToggleMenu(button)
	DropCount.LootCount.Menu_ClickedButton=button;
	local menu=DMMenuCreate(button);
	menu:Add("Set goal",function () LootCount_ButtonForGoal=button; StaticPopup_Show("LOOT_COUNT_GOAL"); end);
	menu:Show();
end

function DropCount:GetTargetType()
	local targettype="playertarget";
	local mobname=UnitName(targettype);
	if (not mobname) then mobname=UnitName("focus"); if (not mobname) then return nil; end targettype="focus"; end
	return targettype;
end

function DropCount:GetRatioColour(ratio)
	if (not ratio) then ratio=0; end
	if (ratio>1) then ratio=1; elseif (ratio<0) then ratio=0; end
	ratio=string.format("|cFF%02X%02X%02X",128+(ratio*127),128+(ratio*127),128+(ratio*127));		-- AARRGGBB
	return ratio;
end

-- Create list of vendors that carry this item
function DropCount.Tooltip:VendorList(button,getlist)
	if (not dcdb.Converted) then DropCount:Chat(Red.."The DropCount database is currently being converted to the new format. Your data will be available when this is done.|r"); return; end
	if (type(button)=="string") then button={ FreeFloat=true, User={ itemID=button, }, };
	elseif (not button.User or not button.User.itemID) then return; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (not getlist) then
		if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR"); else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
		GameTooltip:SetText(colour.."["..itemname.."]|r");
	end
	local currentzone=GetRealZoneText();
	if (not currentzone) then currentzone=""; end
	local ThisZone,list,line,droplist=GetRealZoneText(),{},1,0;
	for vendor,vTable in rawpairs(dcdb.Vendor) do
		if (vTable and vTable:find(button.User.itemID,1,true)) then
			vTable=dcdb.Vendor[vendor];		-- get it
			if (vTable and vTable.Zone and vTable.Items and vTable.Items[button.User.itemID]) then
				list[line]={};
				local zone=lBlue;
				if (vTable.Zone and vTable.Zone:find(ThisZone,1,true)==1) then zone=hBlue; end
				zone=zone..vTable.Zone.." - "..floor(vTable.X or 0)..","..floor(vTable.Y or 0).."|r";
				list[line].Ltext=zone.." : "..Yellow..vendor.."|r ";
				list[line].Rtext="";
				if (type(vTable.Items[button.User.itemID])=="table") then
					if (vTable.Items[button.User.itemID].Count>=0) then list[line].Rtext=Red.."*|r";
					elseif (vTable.Items[button.User.itemID].Count==CONST.UNKNOWNCOUNT) then list[line].Rtext=Yellow.."*|r";
				end end
				line=line+1;
	end end end
	list=DropCount:SortByNames(list);
	if (getlist) then return copytable(list); end
	if (line==1) then GameTooltip:LCAddLine("No known vendors",1,1,1);
	else line=1; while(list[line]) do GameTooltip:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1); line=line+1; end end
	GameTooltip:Show();
end

function DropCount:Highlight(text,highlight,terminate)
	if (not highlight) then return text; end
	if (not terminate) then terminate="|r"; end
	local start,stop=text:lower():find(highlight:lower());
	if (not start) then return text; end
	local sf,sm,se="","","";
	if (start>1) then sf=text:sub(1,start-1); end
	sm=text:sub(start,stop);
	se=text:sub(stop+1);
	return sf.."|cFFFFFF00"..sm..terminate..se;
end

-- create a list of mobs that drops the item in question
function DropCount.Tooltip:MobList(button,plugin,limit,down,highlight)
	if (type(button)=="string") then
		button={ FreeFloat=true, User={ itemID=button, } };
	elseif (not button.User or not button.User.itemID) then
		GameTooltip:SetOwner(button,"ANCHOR_RIGHT");
		GameTooltip:SetText("Drop an item here");
		GameTooltip:Show();
		return;
	end
	if (not dcdb.Item[button.User.itemID]) then return; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR");
	else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
	local iTable=dcdb.Item[button.User.itemID];
	local skinningdrop=iTable.Skinning;
	local normaldrop=iTable.Name;
	local scrap=colour.."["..DropCount:Highlight(itemname,highlight,colour).."]|r:";
	if (LootCount_DropCount_Character.CompactView) then
		if (skinningdrop) then if (normaldrop) then scrap=scrap.." (L/|cFFFF00FFP|r)"; else scrap=scrap.." (|cFFFF00FFP|r)"; end end
	end
	GameTooltip:SetText(scrap);
	local currentzone=GetRealZoneText();
	if (not currentzone) then currentzone=""; end
	if (not LootCount_DropCount_Character.CompactView) then
		if (skinningdrop) then
			if (normaldrop) then scrap="Loot and |cFFFF00FFprofession"; else scrap="Profession"; end
			GameTooltip:LCAddLine(scrap,1,0,1);
	end end
	if (iTable.Best) then
		if (not LootCount_DropCount_Character.CompactView) then
			GameTooltip:LCAddDoubleLine("Best drop-area:",DropCount:Highlight(iTable.Best.Location,highlight).." ("..iTable.Best.Score.."\%)",0,1,1,0,1,1);
			if (iTable.BestW) then GameTooltip:LCAddDoubleLine(" ",DropCount:Highlight(iTable.BestW.Location,highlight).." ("..iTable.BestW.Score.."\%)",0,1,1,0,1,1); end
		else
			GameTooltip:LCAddLine(DropCount:Highlight(iTable.Best.Location,highlight).." ("..iTable.Best.Score.."\%)",0,1,1);
			if (iTable.BestW) then GameTooltip:LCAddLine(DropCount:Highlight(iTable.BestW.Location,highlight).." ("..iTable.BestW.Score.."\%)",0,1,1); end
	end end
	-- Do normal loot
	local list,line,droplist={},1,0;
	if (normaldrop) then
		for mob,drops in pairs(iTable.Name) do
			local pretext,i,Show="",1,nil;
			while(DropCount.Tracker.TimedQueue[i]) do
				if (DropCount.Tracker.TimedQueue[i].Mob==mob and DropCount.Tracker.TimedQueue[i].Oma) then
					pretext="-> ";
					Show=true;						-- Show this one no matter what
					droplist=droplist+1;			-- Count a hi-pri entry
					i=DropCount.Tracker.QueueSize;	-- Break
				end
				i=i+1;
			end

			local low,high=64,255;
			list[line]={};

			local mTable=dcdb.Count[mob];
			if (not mTable) then DropCount:RemoveFromItems("Name",mob);
			else
				if (mTable.Kill) then list[line].Count=mTable.Kill;
				else list[line].Count=0; end
				local saturation=((high-low)/(CONST.KILLS_RELIABLE-CONST.KILLS_UNRELIABLE))*list[line].Count;
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);			-- AARRGGBB
				list[line].ratio=DropCount:GetRatio(button.User.itemID,mob);	-- Normal
				local zone="";
				if (not LootCount_DropCount_Character.CompactView and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end
				local mobName=dcdb.Count[mob].Name or mob;
				list[line].Ltext=colour..pretext..DropCount:Highlight(mobName,highlight,colour)..zone.."|r: ";
				list[line].Show=Show;
				line=line+1;
	end end end
	list=DropCount:SortByRatio(list);
	-- Do profession-loot
	local dlist,dline={},1;
	if (skinningdrop) then
		for mob,drops in pairs(iTable.Skinning) do
			local pretext,i,Show="",1,nil;
			while(DropCount.Tracker.TimedQueue[i]) do
				if (DropCount.Tracker.TimedQueue[i].Mob==mob and DropCount.Tracker.TimedQueue[i].Oma) then
					pretext="-> ";
					Show=true;							-- Show this one no matter what
					droplist=droplist+1;				-- Count a hi-pri entry
					i=DropCount.Tracker.QueueSize;	-- Break
				end
				i=i+1;
			end

			local low,high=64,255;
			dlist[dline]={};

			local mTable=dcdb.Count[mob];
			if (not mTable) then DropCount:RemoveFromItems("Skinning",mob);
			else
				if (mTable.Skinning) then dlist[dline].Count=mTable.Skinning;
				else dlist[dline].Count=0; end
				local saturation=((high-low)/(CONST.KILLS_RELIABLE-CONST.KILLS_UNRELIABLE))*dlist[dline].Count;
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);			-- AARRGGBB
				_,dlist[dline].ratio=DropCount:GetRatio(button.User.itemID,mob); -- Skinning
				local zone="";
				if (not LootCount_DropCount_Character.CompactView and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end
				local mobName=dcdb.Count[mob].Name or mob;
				dlist[dline].Ltext=colour..pretext..DropCount:Highlight(mobName,highlight,colour)..zone.."|r: ";
				if (normaldrop) then dlist[dline].Ltext="|cFFFF00FF*|r "..dlist[dline].Ltext; end
				dlist[dline].Show=Show;
				dline=dline+1;
	end end end
	dlist=DropCount:SortByRatio(dlist);
	for dline,raw in ipairs(dlist) do list[line]=raw; line=line+1; end
	-- merge lists
	if (not limit) then limit=DropCount:FindListLowestByLength(list,CONST.LISTLENGTH-droplist); end	-- find kill-count to demand for display
	-- Type list
	local count,supressed,lowKill,goal=0,0,0,CONST.LISTLENGTH-droplist;	-- Subtract hi-pri entry
	line=1;
	while(list[line]) do
		list[line].Count=list[line].Count or 0;
		if ((count<goal and list[line].Count>=limit) or list[line].Show) then
			GameTooltip:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
			if (not list[line].Show) then count=count+1; end	-- Count all normal entries
		else
			if (list[line].Count<limit) then lowKill=lowKill+1; end
			supressed=supressed+1;
		end
		line=line+1;
	end
	if (supressed>0) then GameTooltip:LCAddDoubleLine(supressed.." more entries","",1,.5,1,1,1,1); end
	GameTooltip:Show();
end

-- do repeated tests with increasing demands to number of kills/loots ("low").
-- this will remove those with fewer kills
-- stop when list is sufficiently short with said demands.
-- return kill-count demand for said list
function DropCount:FindListLowestByLength(list,length)
	list=copytable(list);
	local low=-1;
	local curLength;
	repeat
		curLength=0;
		low=low+1;
		for index,iData in pairs(list) do
			if (iData.Count) then
				if (iData.Count<low) then list[index]=nil; else curLength=curLength+1; end	-- Remove entry -> Count it
		end end
	until(curLength<=length);
	return low;
end

function DropCount:SortByRatio(list)
	table.sort(list,function (a,b) return (a.ratio or 0)>(b.ratio or 0); end);
	local line=1;
	while(list[line]) do
		list[line].Rtext=DropCount:GetRatioColour(list[line].ratio)..DropCount:FormatPst(list[line].ratio,"%|r");
		line=line+1;
	end
	return list;
end

function DropCount:SortByCount(list)
	table.sort(list,function (a,b) return a.Count<b.Count; end); return list; end
function DropCount:SortByNames(list)
	table.sort(list,function (a,b) return a.Ltext<b.Ltext; end); return list; end

function DropCount:PrintMobsStatus()
	local o,n,m=0,0,0;
	for entry,raw in rawpairs(dcdb.Count) do
		if (entry:len()~=4 or not tonumber(entry,16)) then o=o+1;	-- not seen
		elseif (not raw:find("r4:Namer",1,true)) then m=m+1;		-- nameless
		else n=n+1; end												-- all good
	end
	print(Yellow..tonumber(o)..Red.." old "..Basic.."name format");
	print(Yellow..tonumber(m)..Green.." new "..Basic.."name format, "..hBlue.."missing "..Basic.."name");
	print(Green..tonumber(n).." new "..Basic.."name format");
end

function DropCount:GetQuestStatus(qId,qName)
	local Dark="|cFF808080";
	if (not qName) then return CONST.QUEST_UNKNOWN,White; end
	if (not dcdb.Quest) then return CONST.QUEST_UNKNOWN,White; end
	-- Check running quests
	if (LootCount_DropCount_Character.Quests) then
		if (LootCount_DropCount_Character.Quests[qName]) then
			if (LootCount_DropCount_Character.Quests[qName].ID) then if (LootCount_DropCount_Character.Quests[qName].ID==qId) then return CONST.QUEST_STARTED,Yellow; end
			else return CONST.QUEST_STARTED,Red; end
	end end
	-- Maybe it's done
	if (LootCount_DropCount_Character.DoneQuest) then
		if (LootCount_DropCount_Character.DoneQuest[qName]) then
			if (LootCount_DropCount_Character.DoneQuest[qName]==qId) then return CONST.QUEST_DONE,Dark;		-- I've done it
			else return CONST.QUEST_DONE,Dark; end		-- I've done it
	end end
	return CONST.QUEST_NOTSTARTED,Green;
end

function DropCount.Tooltip:QuestList(faction,npc,parent,frame)
	if (not frame) then frame=LootCount_DropCount_TT; end
	local nTable=dcdb.Quest[faction][npc];
	if (not nTable or not nTable.Quests) then
		nTable=dcdb.Quest["Neutral"][npc];
		if (not nTable or not nTable.Quests) then return; end
	end
	parent=parent or UIParent;
	frame:ClearLines();
	frame:SetOwner(parent,"ANCHOR_CURSOR");
	frame:SetText(npc);
	if (dcdb.Vendor[npc]) then frame:LCAddSmallLine("Vendor available",.5,.5,0); end
	for _,qData in pairs(nTable.Quests) do
		local quest,header,id=qData.Quest,qData.Header or "",qData.ID;
		local _,colour=DropCount:GetQuestStatus(id,quest);
		frame:LCAddDoubleLine("  "..colour..quest,colour..header,1,1,1,1,1,1);
	end
	frame:Show();
	return true;
end

-- called when mouseover for rare mobs map icons
-- supplied is a string of comma-separated sguid looted in this location
function DropCount.Tooltip:Rare(mobs,parent,tt)
	DropCount.Tooltip:Grid(mobs,parent,tt,"Rare creature");
--	tt=tt or LootCount_DropCount_TT;
end

-- called when mouseover for gather map icons
-- supplied is a string of comma-separated node IDs found in this location
function DropCount.Tooltip:Gather(map,parent,tt)
	tt=tt or LootCount_DropCount_TT;
	if (not parent) then parent=UIParent; end
	tt:ClearLines();
	tt:SetOwner(parent,"ANCHOR_CURSOR");
	tt:SetText("Gather");
	-- add nodes
	for oid,count in pairs(map.OID) do
		if (not dcdb.Gather.GatherNodes or not dcdb.Gather.GatherNodes[oid] or not dcdb.Gather.GatherNodes[oid].Name) then return; end	-- broken
		local name=dcdb.Gather.GatherNodes[oid].Name[GetLocale()] or dcdb.Gather.GatherNodes[oid].Name.enUS;		-- get textual name for this node
		tt:LCAddDoubleLine(name,DropCount:FormatPst(count/map.Gathers,"%"),1,1,1,1,1,1);
	end
	tt:Show();
end

function DropCount.Tooltip:Node(obj,parent,tt)
	obj=tonumber(obj);
	obj=dcdb.Gather.GatherNodes[obj]; if (not obj or not obj.Loot) then return; end	-- no node, or a different kind (like Glowcap wich is same-named item and object)
	tt=tt or GameTooltip;
	if (not parent) then parent=UIParent; end
	tt:ClearLines();
	tt:SetOwner(parent,"ANCHOR_CURSOR");
	tt:SetText(obj.Name[GetLocale()] or obj.Name.enUS or "<Unknown gather node>");
	-- the monitor will add the rest
	tt:Show();	-- recalc size
end

-- called when mouseover for grid map icons
-- supplied is a string of comma-separated sguid looted in this location
function DropCount.Tooltip:Grid(mobs,parent,tt,header)
	tt=tt or LootCount_DropCount_TT;
	mobs={strsplit(",",mobs)};
	local droplist,skinlist,itemlist={},{},{};
	local gotmobs=nil;
	for item,iData in rawpairs(dcdb.Item) do						-- cycle all items
		for _,sguid in pairs(mobs) do								-- cycle all mobs in this slot
			if (sguid:len()==4 and iData:find(sguid,1,true)) then	-- plain search for mob sguid
				gotmobs=true;
				local iTable=dcdb.Item[item];						-- read data for proper test
				if (iTable.Name and iTable.Name[sguid]) then			-- if mob drops this item -> list it 
					local itemname,_,rarity,_,_,itemtype=GetItemInfo(item);	-- get item basics
					local questitem=nil;
					if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then
						questitem=true;
					end
					if (not itemname or not rarity) then				-- unknown item
						DropCount.Cache:AddItem(item);					-- run server cache
						if (not itemname and iTable.Item) then itemname=iTable.Item; rarity=0; end		-- set generic
					end
					if (itemname and iTable.Name[sguid]>1) then			-- more than once dropped
						local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;	-- get rarity colour
						if (questitem) then colour=Yellow; end	-- override with yellow quest colour
						droplist[itemname]=colour..itemname;			-- add item with colour to drop-list
				end end
				if (iTable.Skinning and iTable.Skinning[sguid]) then	-- item skinned from current mob
					local itemname,_,rarity=GetItemInfo(item);			-- get item basics
					if (not itemname or not rarity) then				-- unknown item
						DropCount.Cache:AddItem(item);					-- run server cache
						if (not itemname and iTable.Item) then itemname=iTable.Item; rarity=0; end		-- set generic
					end
					if (itemname) then									-- got item
						local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;	-- get rarity colour
						skinlist[itemname]=colour..itemname;			-- add item with colour to skin-list
	end end end end end
	for _,item in pairs(mobs) do		-- cycle all mobs in this slot
		if (item:len()>4) then			-- it's an item link
			local _,_,rarity=GetItemInfo(item);
			local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;	-- get rarity colour
			itemlist[item]=colour..dcdb.Item[item].Item;	-- get the name with colour
	end end
	-- build tooltip
	local emptyline=nil;
	local anc="ANCHOR_CURSOR";
	if (not parent) then parent=UIParent;
	elseif (parent==PlayerFrame) then anc="ANCHOR_BOTTOMLEFT"; end
	tt:ClearLines();
	tt:SetOwner(parent,anc);
	tt:SetText(header or "Grid info");
	if (gotmobs) then
		for _,sguid in pairs(mobs) do
			if (sguid:len()==4 and dcdb.Count[sguid]) then tt:LCAddSmallLine((dcdb.Count[sguid].Name or sguid),1,1,1); end
		end
		emptyline=true;
	end
	if (next(droplist)) then
		if (emptyline) then tt:LCAddSmallLine(" ",1,1,1); end
		tt:LCAddSmallLine("Drop",1,1,1);
		for _,txt in pairs(droplist) do tt:LCAddSmallLine("    "..txt,1,1,1); end
		tt:LCAddSmallLine(Basic.."    (Single dropped items skipped)",1,1,1);
		emptyline=true;
	end
	if (next(skinlist)) then
		if (emptyline) then tt:LCAddSmallLine(" ",1,1,1); end
		tt:LCAddSmallLine("Profession drop",1,1,1);
		for _,txt in pairs(skinlist) do tt:LCAddSmallLine("    "..txt,1,1,1); end
		emptyline=true;
	end
	if (next(itemlist)) then
		if (emptyline) then tt:LCAddSmallLine(" ",1,1,1); end
		tt:LCAddSmallLine("Items",1,1,1);
		for _,txt in pairs(itemlist) do tt:LCAddSmallLine("    "..txt,1,1,1); end
		emptyline=true;
	end
	tt:Show();
	if (tt==LootCount_DropCount_GD) then tt:SetAlpha(.3); else tt:SetAlpha(1); end
end

function DropCount.Tooltip:Book(book,parent)
	local buf=dcdb.Book[book];
	local bStatus=Red.."Need to read|r";
	local count=GetAchievementNumCriteria(1244);
	while (count>0) do
		bName,_,hasRead,_,_,playername=GetAchievementCriteriaInfo(1244,count);
		if (playername==UnitName("player") and bName==book) then
			if (hasRead==true) then bStatus=Green.."Done with this book|r"; end
			count=1;
		end
		count=count-1;
	end
	if (not parent) then parent=UIParent; end
	LootCount_DropCount_TT:ClearLines();
	LootCount_DropCount_TT:SetOwner(parent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText("Book");
	LootCount_DropCount_TT:LCAddLine(book,1,1,1);
	LootCount_DropCount_TT:LCAddLine(bStatus,1,1,1);
	LootCount_DropCount_TT:Show();
end

function DropCount.Tooltip:SetNPCContents(unit,parent,frame,force)
	local breakit=nil;
	if (not frame) then frame=LootCount_DropCount_TT; end
	if (not force and dcdb.Quest[CONST.MYFACTION] and dcdb.Quest[CONST.MYFACTION][unit]) then
		DropCount.Tooltip:QuestList(CONST.MYFACTION,unit,parent,frame);
	end
	if (not dcdb.Vendor[unit]) then return; end
	local vData=dcdb.Vendor[unit];
	if (not vData or not vData.Items) then return; end
	if (not parent) then parent=UIParent; end
	local line=unit;
	if (vData.Repair) then line=line..Green.." (Repair)"; end
	frame:ClearLines();
	frame:SetOwner(parent,"ANCHOR_CURSOR");
	frame:SetText(line);
	if (dcdb.Quest[CONST.MYFACTION][unit] or dcdb.Quest["Neutral"][unit]) then frame:LCAddSmallLine("Quests list available",.5,.5,0); end
	local list={};
	line=1;
	local missingitems,itemsinlist,item,iTable=0;
	for item,iTable in pairs(vData.Items) do
		local itemname,_,rarity=GetItemInfo(item);
		if (not itemname or not rarity) then
			DropCount.Cache:AddItem(item);
			missingitems=missingitems+1;
		else
			local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
			list[line]={ Ltext=colour..itemname.."|r ", Rtext="" };
			if (iTable.Count>=0) then list[line].Ltext=Red.."* |r"..list[line].Ltext;
			elseif (iTable.Count==CONST.UNKNOWNCOUNT) then list[line].Ltext=Yellow.."* |r"..list[line].Ltext;
			end
			line=line+1;
			itemsinlist=true;
	end end
	if (missingitems>0) then
		frame:LCAddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		frame:LCAddDoubleLine("Loading...","",1,0,0,0,0,0);
		frame:Show();
		frame.Loading=true;
		return true;
	end
	frame.Loading=nil;
	if (not itemsinlist) then frame:Hide(); return; end
	list=DropCount:SortByNames(list);
	line=1;
	while(list[line]) do frame:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1); line=line+1; end
	frame:Show();
	return true;
end

function DropCount:ShowNPC(unit,sguid,AltTT,compact)
	if (dcdb.Count[unit]) then DropCount.WoW5:ConvertMOB(unit,sguid); end
	if (not DropCount.Tracker.LastListType) then DropCount.Tracker.LastListType="drop"; end
	if (DropCount.Tracker.LastListType=="drop") then
		DropCount.Tracker.LastListType="quest";
		if (dcdb.Quest[CONST.MYFACTION][unit] or dcdb.Quest["Neutral"][unit]) then
			if (DropCount.Tooltip:QuestList(CONST.MYFACTION,unit)) then return; end
		end
	end
	if (DropCount.Tracker.LastListType=="quest") then
		DropCount.Tracker.LastListType="service";
		if (dcdb.Vendor[unit]) then
			if (DropCount.Tooltip:SetNPCContents(unit,nil,nil,true)) then return; end
		end
	end
	if (DropCount.Tracker.LastListType=="service") then
		DropCount.Tracker.LastListType="drop";
		if (dcdb.Count[sguid]) then
			if (DropCount.Tooltip:SetLootlist(unit,sguid,AltTT,compact)) then return; end
		end
	end
end

-- list what a creature drops
-- alternatively diverts to other lists
function DropCount.Tooltip:SetLootlist(unit,sguid,AltTT,compact)
	if (dcdb.Count[unit]) then DropCount.WoW5:ConvertMOB(unit,sguid); end
	if (not dcdb.Count[sguid]) then DropCount.Tooltip:SetNPCContents(unit); return; end
	if (type(AltTT)~="table") then compact=AltTT; AltTT=LootCount_DropCount_TT; end
	AltTT:ClearLines();
	AltTT:SetOwner(UIParent,"ANCHOR_CURSOR");
	local text="";
	local mTable=dcdb.Count[sguid];
	if (not mTable.Kill) then mTable.Kill=0; end
	LootCount_DropCount_Character.MouseOver=copytable(mTable);
	if (not LootCount_DropCount_Character.CompactView) then
		AltTT:SetText(unit);
		if (mTable.Skinning and mTable.Skinning>0) then text="Profession-loot: "..mTable.Skinning.." times"; end
		AltTT:LCAddDoubleLine(mTable.Kill.." kills",text,.4,.4,1,1,0,1);
	else
		text=unit.." |cFF6666FFK:"..mTable.Kill;
		if (mTable.Skinning and mTable.Skinning>0) then text=text.." |cFFFF00FFP:"..mTable.Skinning; end
		AltTT:SetText(text);
	end
	local list,line,missingitems,itemsinlist,singlelist={},1,0,nil,{};
	for item,iData in rawpairs(dcdb.Item) do
		if (iData:find(sguid,1,true)) then		-- Plain search
			local iTable=dcdb.Item[item];
			if (iTable.Name and iTable.Name[sguid]) then
				local itemname,_,rarity,_,_,itemtype=GetItemInfo(item);
				local questitem=nil;
				if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then
					questitem=true;
				end
				if (not itemname or not rarity) then
					DropCount.Cache:AddItem(item);
					missingitems=missingitems+1;
				elseif (LootCount_DropCount_Character.ShowSingle or questitem or iTable.Name[sguid]~=1) then
					if (LootCount_DropCount_Character.ShowSingle and iTable.Name[sguid]==1) then
						if (not singlelist[rarity]) then singlelist[rarity]=1; else singlelist[rarity]=singlelist[rarity]+1; end
					else
						local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
						local thisratio=DropCount:GetRatio(item,sguid);
						list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio };
						if (iTable.Quest) then list[line].Quests=copytable(iTable.Quest); end
						line=line+1;
					end
					itemsinlist=true;
			end end
			if (iTable.Skinning and iTable.Skinning[sguid]) then
				local itemname,_,rarity=GetItemInfo(item);
				if (not itemname or not rarity) then
					DropCount.Cache:AddItem(item);
					missingitems=missingitems+1;
				else
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local _,thisratio=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, profession=true };
					list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext;	-- AARRGGBB
					if (iData.Quest) then list[line].Quests=copytable(iData.Quest); end
					line=line+1;
					itemsinlist=true;
	end end end end
	if (missingitems>0) then
		AltTT:LCAddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		AltTT:LCAddDoubleLine("Loading...","",1,0,0,0,0,0);
		AltTT:Show();
		AltTT.Loading=true;
		return;
	end
	AltTT.Loading=nil;
	if (not itemsinlist) then AltTT:Hide(); return; end

	list=DropCount:SortByRatio(list);
	local listcopy=copytable(list);
	for i,raw in ipairs(listcopy) do if (raw.profession) then table.insert(list,copytable(raw)); list[i].delete=true; end end
	wipe(listcopy); listcopy=nil;
	repeat local found=nil; for i,raw in ipairs(list) do if (raw.delete) then table.remove(list,i); found=true; end end until (not found);

	local smallspace=nil;
	if (next(singlelist)) then
		for rarity,count in pairs(singlelist) do
			local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
			list[line]={ Ltext="    "..count.." x "..colour.."single drop items|r", ratio=-100 };
			line=line+1;
		end
		smallspace=true;
	end
	-- Build the window on screen
	line=1;
	while(list[line]) do
		if (list[line].ratio==-100) then
			if (smallspace) then AltTT:LCAddSmallLine(" ",1,1,1); smallspace=nil; end
			AltTT:LCAddSmallLine(list[line].Ltext,1,1,1);
		else AltTT:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1); end
		if (((compact and IsShiftKeyDown()) or not compact) and list[line].Quests) then
			for quest,amount in pairs(list[line].Quests) do
				if (dcdb.Quest[CONST.MYFACTION]) then
					for npc,rawData in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
						if (rawData:find(quest,1,true)) then
							local qData=dcdb.Quest[CONST.MYFACTION][npc];
							if (qData.Quests) then
								for _,qListData in ipairs(qData.Quests) do
									if (qListData.Quest==quest) then
										if (not qListData.Header) then AltTT:LCAddSmallLine("   "..amount.." for "..quest,.5,.3,.2);
										else AltTT:LCAddSmallLine("   "..amount.." for "..quest.." ("..qListData.Header..")",.5,.3,.2); end
										AltTT:LCAddSmallLine("   |cFFFFFF00   ! |r"..npc.." ("..qData.Zone.." - "..math.floor(qData.X)..","..math.floor(qData.Y)..")",.5,.3,.2);
		end end end end end end end end
		line=line+1;
	end
	AltTT:Show();
	return true;
end

function DropCount.TooltipExtras:SetFunctions(widget)
	widget.LCAddLine=DropCount.TooltipExtras.AddLine
	widget.LCAddDoubleLine=DropCount.TooltipExtras.AddDoubleLine
	widget.LCAddSmallLine=DropCount.TooltipExtras.AddSmallLine
	widget:AddLine("1"); widget:AddLine("2");
	widget.LCFont,widget.LCSize,widget.LCFlags=_G[widget:GetName().."TextLeft"..widget:NumLines()]:GetFont();
end

function DropCount.TooltipExtras:AddLine(text,r,g,b,a) self:AddLine(text,r,g,b,a); _G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags); end
function DropCount.TooltipExtras:AddSmallLine(text,r,g,b,a) self:AddLine(text,r,g,b,a); _G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize*.75,self.LCFlags); end
function DropCount.TooltipExtras:AddDoubleLine(textL,textR,rL,gL,bL,rR,gR,bR) self:AddDoubleLine(textL,textR,rL,gL,bL,rR,gR,bR); _G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags); _G[self:GetName().."TextRight"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags); end

function DropCount.Cache:AddItem(item)
	DropCount.Cache.Retries=0;
	if (not DropCount.Tracker.UnknownItems) then DropCount.Tracker.UnknownItems={}; DropCount.Cache.Timer=.5; end
	DropCount.Tracker.UnknownItems[item]=true;
end

-- A blind update will queue a request at the server without any
-- book-keeping at this side.
-- CATACLYSM: Cache has been greatly improved by speed at the server side.
-- CATACLYSM: Blind item spew has been implemented to take advantage of it.
function DropCount.Cache:Execute(item,blind)
	if (type(item)=="number") then item="item:"..item;
	elseif (type(item)~="string") then return true; end
	local name=GetItemInfo(item);
	if (not LootCount_DropCount_CF:IsVisible()) then
		if (not name) then
			LootCount_DropCount_CF:SetOwner(UIParent); LootCount_DropCount_CF:SetHyperlink(item); LootCount_DropCount_CF:Hide();
			if (not blind) then DropCount.Cache.Retries=DropCount.Cache.Retries+1; end
			return false;
		else if (not blind) then DropCount.Cache.Retries=0; end end
	end
	return true;
end

function DropCountXML:GUI_Search()
	local find=LCDC_VendorSearch_FindText:GetText();
	LCDC_ResultListScroll:DMClear();
	LCDC_VendorSearch.SearchTerm=find;
	DropCount.Search:Do(LCDC_VendorSearch_FindText:GetText(),
						LCDC_VendorSearch_UseVendors:GetChecked(),
						LCDC_VendorSearch_UseQuests:GetChecked(),
						LCDC_VendorSearch_UseBooks:GetChecked(),
						LCDC_VendorSearch_UseItems:GetChecked(),
						LCDC_VendorSearch_UseMobs:GetChecked(),
						LCDC_VendorSearch_UseTrainers:GetChecked());
	for section,sTable in pairs(DropCount.Search._result) do
		local xml=LCDC_ResultListScroll:DMAdd(section,nil,-1);
		xml.Tooltip=nil;
		wipe(xml.DB);
		for _,entry in pairs(sTable) do
			xml=LCDC_ResultListScroll:DMAdd(entry.Entry,nil,0,entry.Icon);
			if (xml) then xml.Tooltip=entry.Tooltip; wipe(xml.DB); xml.DB=nil; xml.DB=entry.DB; end
	end end
end

function DropCount.Search:Found(section,entry,tooltip,db,icon)
	if (not self._result[section]) then self._result[section]={}; end
	db=db or {};
	if (not db.Section) then db.Section=section; end
	table.insert(self._result[section],{ Entry=entry, Tooltip=tooltip, DB=db, Icon=icon });
end

function DropCount.Search:Do(find,uVen,uQue,uBoo,uIte,uMob,uTra)
	if (not find) then return; end
	find=strtrim(find:lower()); if (find=="") then return; end
	wipe(self._result);
	-- Search vendors
	local entry;
	if (uVen) then
		for vendor,vData in rawpairs(dcdb.Vendor) do
			if (vData:lower():find(find,1,true)) then
				local buf=dcdb.Vendor[vendor];
				local X,Y,Zone,Faction,Repair=buf.X,buf.Y,buf.Zone,buf.Faction,buf.Repair;
				if (Faction==CONST.MYFACTION or Faction=="Neutral") then
					local tt={Faction.." vendor: "..vendor,Zone..string.format(" (%.0f,%.0f)",X,Y)};
					if (Repair) then table.insert(tt,"Can repair your stuff"); end
					self:Found("Vendor",Zone..": "..vendor,tt,{Section="Vendor",Entry=vendor,Data=vData});
	end end end end
	-- Search quests
	if (uQue) then
		for npc,nData in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
			if (nData:lower():find(find,1,true)) then
				local npcData=dcdb.Quest[CONST.MYFACTION][npc];
				self:Found("Quest",npcData.Zone..": "..npc,{"Quest-giver: "..npc,npcData.Zone..string.format(" (%.0f,%.0f)",npcData.X,npcData.Y)},{Section="Quest",Entry=npc,Data=nData});
	end end end
	-- Search books
	if (uBoo) then
		for book,rawbook in rawpairs(dcdb.Book) do
			if (book:lower():find(find,1,true) or rawbook:lower():find(find,1,true)) then
				local tt={"Book: "..book};
				for index,iData in ipairs(dcdb.Book[book]) do table.insert(tt,iData.Zone..string.format(" (%.0f,%.0f)",iData.X,iData.Y)); end
				self:Found("Book",book,tt,{Section="Book",Entry=npc});
	end end end
	-- Search items
	if (uIte) then
		for item,iData in rawpairs(dcdb.Item) do
			if (iData:lower():find(find,1,true)) then
				DropCount.Cache:AddItem(item);
				local itemData=dcdb.Item[item];
				self:Found("Item",itemData.Item,nil,{Section="Item",Entry=item,Data=itemData},GetItemIcon(item));
	end end end
	-- Search mobs
	if (uMob) then
		for mob,data in rawpairs(dcdb.Count) do
			if (mob:lower():find(find,1,true) or data:lower():find(find,1,true)) then
				local t=dcdb.Count[mob];
				self:Found("Creature",t.Name or mob,nil,{Section="Creature",Entry=mob});
	end end end
	-- Search trainers
	if (uTra) then
		for npc,nData in rawpairs(dcdb.Trainer[CONST.MYFACTION]) do
			if (nData:lower():find(find,1,true)) then
				local npcData=dcdb.Trainer[CONST.MYFACTION][npc];
				self:Found("Trainer",npcData.Zone..": "..npc,{"Trainer "..npc..": "..npcData.Service,npcData.Zone..string.format(" (%.0f,%.0f)",npcData.X,npcData.Y)},{Section="Trainer",Entry=npc,Data=nData});
	end end end
	-- search nodes
	-- if (it_is_selected) then
		local lang=GetLocale();
		for objID,od in rawpairs(dcdb.Gather.GatherNodes) do
			local use,t=nil,nil;
			if (od:lower():find(find,1,true)) then
				t=dcdb.Gather.GatherNodes[objID];
				if (t.Name[lang] and t.Name[lang]:lower():find(find,1,true)) then use=true; end
			end
			if (not use) then
				if (not t) then t=dcdb.Gather.GatherNodes[objID]; end
				if (t.Loot) then
					for i in pairs(t.Loot) do
						local item=dcdb.Item[i];
						if (item and item.Item and item.Item:lower():find(find,1,true)) then use=true; break; end
			end end end
			if (use) then
				local name=t.Name[lang] or t.Name.enUS or "<Unknown gathering node>";
				self:Found("Gathering profession",name,objID,nil,t.Icon or "");
		end end
	-- end
end

function DropCount:CleanDB()
	local text=Basic.."DropCount:|r ";
	if (DropCount.Debug) then
		UpdateAddOnMemoryUsage();
		local usage=GetAddOnMemoryUsage("LootCount_DropCount");
		usage=string.format("%.0fKB",usage);
		text="DropCount memory usage: "..usage.." -> ";
	end
	-- List key-data
	local nowitems,nowmobs;
	nowitems=0; for book in rawpairs(dcdb.Book) do nowitems=nowitems+1; end
	DropCount:Chat(Basic.."DropCount: "..Green..nowitems..Basic.." known book titles");
	nowmobs=0; for _ in rawpairs(dcdb.Vendor) do nowmobs=nowmobs+1; end
	DropCount:Chat(Basic.."DropCount:|r "..Green..nowmobs.."|r known vendors");
	nowmobs=0; for _,fTable in pairs(dcdb.Quest) do for _ in rawpairs(fTable) do nowmobs=nowmobs+1; end end
	DropCount:Chat(Basic.."DropCount:|r "..Green..nowmobs.."|r known quest-givers");
	nowitems=0; for _ in rawpairs(dcdb.Item) do nowitems=nowitems+1; end
	text=text..Green..nowitems.."|r items";
	if (not LootCount_DropCount_StartItems) then LootCount_DropCount_StartItems=nowitems; end
	nowmobs=0; for _ in rawpairs(dcdb.Count) do nowmobs=nowmobs+1; end
	text=text.." -> "..Green..nowmobs.."|r creatures";
	if (not LootCount_DropCount_StartMobs) then LootCount_DropCount_StartMobs=nowmobs; end
	DropCount:Chat(text);
	if (nowitems-LootCount_DropCount_StartItems>0 or nowmobs-LootCount_DropCount_StartMobs>0) then
		DropCount:Chat(Basic.."DropCount:|r New this session: "..Green..nowitems-LootCount_DropCount_StartItems.."|r items, "..Green..nowmobs-LootCount_DropCount_StartMobs.."|r mobs");
	end
	DropCount:Chat(Basic.."Type "..Green..SLASH_DROPCOUNT2..Basic.." to view options");
	DropCount:Chat(Basic.."Please consider submitting your SavedVariables file at "..Yellow.."ducklib.com -> DropCount"..Basic..", or sending it to "..Yellow.."dropcount@ducklib.com"..Basic.." to help develop the DropCount addon.");
end

function DropCount:SaveBook(BookName,bZone,bX,bY,Map)
	local silent=true;
	if (not bX or not bY or not bZone) then
		bX,bY=DropCount:GetPlayerPosition();
		bZone=DropCount:GetFullZone();
		Map=DropCount:GetMapTable()
		silent=nil;
	end
	if (not bZone) then bZone="Unknown"; end
	local i=1;
	local newBook,updatedBook=0,0;
	local buf;
	if (not dcdb.Book[BookName]) then
		if (not silent) then DropCount:Chat(Basic.."Location of new book "..Green.."\""..BookName.."\""..Basic.." saved"); end
		buf={};						-- create new title
		newBook=1;
	else
		local found=nil;
		buf=dcdb.Book[BookName];	-- load existing title
		while (not found and buf[i]) do
			if (buf[i].Zone==bZone) then found=true; updatedBook=1; i=i-1; end		-- Found in same zone
			i=i+1;
	end end
	buf[i]={ X=bX, Y=bY, Zone=bZone, Map=Map, };
	dcdb.Book[BookName]=buf;
	if (not silent) then
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		DropCount:Chat(Basic..BookName..Green.." saved. "..Basic..i.." volumes known.");
	end
	return newBook,updatedBook;
end

function DropCount:SaveTrainer(name,service,zone,x,y,faction)
	if (not faction) then faction=CONST.MYFACTION; end
	dcdb.Trainer[faction][name]={Service=service,Zone=zone,X=x,Y=y};
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
end

function DropCountXML:OnUpdate(frame,elapsednow)
	if (not DropCount.Loaded) then return; end
	if (not DropCount.Tracker.Exited) then return; end	-- block for real MT
	DropCount.Tracker.Exited=nil;
	MT.FastMT=elapsednow*0.99;				-- aim at slighly lower fps for fast switching
	if (MT.FastMT>MT.Speed) then MT.FastMT=MT.Speed; end	-- limit to slowest MT
	MT:Next();		-- Run multi-threading
	DropCount.Loaded=DropCount.Loaded+elapsednow;
	DropCount.Tracker.Elapsed=DropCount.Tracker.Elapsed+elapsednow;
	local elapsed=DropCount.Tracker.Elapsed;
	DropCount.Tracker.Elapsed=0;
	-- add quest-ID
	if (not CONST.QUESTID and (not DropCount.Tracker.UnknownItems or not DropCount.Tracker.UnknownItems["item:31812"])) then
		_,_,_,_,_,CONST.QUESTID=GetItemInfo("item:31812");
		if (not CONST.QUESTID) then DropCount.Cache:AddItem("item:31812"); end
	end
	-- delayed merchant read
	if (DropCount.Timer.VendorDelay>=0) then
		DropCount.Timer.VendorDelay=DropCount.Timer.VendorDelay-elapsed;
		if (DropCount.Timer.VendorDelay<0) then
			if (not DropCount:ReadMerchant(DropCount.Target.OpenMerchant)) then DropCount.Timer.VendorDelay=.5; end
	end end
	-- day-to-day things
	DropCount.OnUpdate:RunMouseoverInWorld();
	DropCount.OnUpdate:MonitorReadableTexts();
	if (DropCount.Tracker.UnknownItems) then DropCount.OnUpdate:RunUnknownItems(elapsed); end
	if (DropCount.Tracker.QueueSize>0) then DropCount.OnUpdate:RunTimedQueue(); end
	DropCount.OnUpdate:MonitorGameTooltip();
	if (DropCount.Timer.StartupDelay) then DropCount.OnUpdate:RunStartup(elapsed); end
	if (LCDC_RescanQuests) then DropCount.OnUpdate:RunQuestScan(elapsed); end
	if (dcdb.QuestQuery) then DropCount.OnUpdate:WalkOldQuests(elapsed); end
	if (DropCount.SpoolQuests) then DropCount:WalkQuests(); end
	-- the trainer
	if (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
		if (not self.CTF) then
			self.CTF=true;
			local isEnabled=GetTrainerServiceTypeFilter("used");
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",1); end
			local trainerService=GetTrainerServiceSkillLine(1);
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",0); end
			if (IsTradeskillTrainer()) then		-- this filters out riding trainers
				DropCount:SaveTrainer(DropCount.Target.CurrentAliveFriendClose,trainerService,DropCount:GetFullZone(),DropCount:GetPlayerPosition());
		end end
	else self.CTF=nil; end
	-- Grid HUD control
	if (DropCount_Local_Code_Enabled) then
		local x,y=GetPlayerMapPosition("player"); x=floor(x*100); y=floor(y*100);
		if (x~=LootCount_DropCount_GD.loc.x or y~=LootCount_DropCount_GD.loc.y) then
			LootCount_DropCount_GD.loc.x=x; LootCount_DropCount_GD.loc.y=y;
			local map,lvl;
			map=DropCount:GetMapTable(); map,lvl=(map.ID or 0),(map.Floor or 0);
			if (dcdb.Grid[map.."_"..lvl]) then
				local buf=dcdb.Grid[map.."_"..lvl];		-- unpack grid
				if (buf[(x*100)+y]) then DropCount.Tooltip:Grid(buf[(x*100)+y],PlayerFrame,LootCount_DropCount_GD)
				else LootCount_DropCount_GD:Hide(); end
			else
				LootCount_DropCount_GD:Hide();
	end end end
	-- hook on to lootcount
	if (not DropCount.LootCount.Registered) then
		if (LootCountAPI and LootCountAPI.Register and LootCount_Loaded) then
			-- Old LootCount dependency load-code
			local info = {	Name=LOOTCOUNT_DROPCOUNT,
							MenuText="LootCount Drop-rate",
							Update=DropCount.LootCount.UpdateButton,
							Drop=DropCount.LootCount.DropItem,
							Clicker=DropCount.LootCount.IconClicked,
							Texture="Interface\\Icons\\INV_Misc_QuestionMark",
							Tooltip=DropCount.LootCount.Tooltip,
							ColorBottom={ r=1, g=1, b=0 },
							ColorTop={ r=.7, g=.7, b=0 },
						};
			LootCountAPI.Register(info);
			DropCount.LootCount.Registered=true;
			DropCount:Chat(Basic.."DropCount:|r "..Green.."LootCount detected. DropCount is available from the LootCount menu.");
	end end
	-- hook on to crawler
	if (not DropCount.Crawler.Registered) then
		if (CrawlerXML and CrawlerXML.SetPlugin) then
			CrawlerXML:SetPlugin("DropCount",DropCount.Crawler);
			DropCount.Crawler.Registered=true;
			DropCount:Chat(Basic.."DropCount:|r "..Green.."Crawler detected. DropCount is available as a Crawler plug-in.");
	end end
	DropCount.Tracker.Exited=true;
end

-- Keep un-MT'd
function DropCount.OnUpdate:RunUnknownItems(elapsed)
	DropCount.Cache.Timer=DropCount.Cache.Timer-elapsed;
	if (DropCount.Cache.Timer<=0) then
		DropCount.Cache.Timer=CONST.CACHESPEED;
		if (not DropCount.Tracker.RequestedItem) then
			local counter=0;
			for unknown,value in pairs(DropCount.Tracker.UnknownItems) do
				if (not DropCount.Tracker.RequestedItem) then DropCount.Tracker.RequestedItem=unknown; end
				DropCount.Cache:Execute(unknown,true);	-- spew blind (pre) update
				counter=counter+1;
				if (counter>=5) then break; end
			end
			if (not DropCount.Tracker.RequestedItem) then DropCount.Tracker.UnknownItems=nil; return; end
		end
		local itemname=GetItemInfo(DropCount.Tracker.RequestedItem);
		if (not itemname) then
			DropCount.Cache:Execute(DropCount.Tracker.RequestedItem);
		else
			DropCount.Tracker.UnknownItems[DropCount.Tracker.RequestedItem]=nil;
			DropCount.Tracker.RequestedItem=nil;
			DropCount.Cache.Retries=0;
			if (not dcdb.Converted) then
				-- Counting items
				local i=0;
				for _ in pairs(DropCount.Tracker.UnknownItems) do i=i+1; end
				if (i<6 or (i>5 and i%25==0)) then DropCount:Chat("Converting DropCount database: "..i.." items left...",0,1,1); end
		end end
	end
	if (DropCount.Cache.Retries>=CONST.CACHEMAXRETRIES) then
		DropCount:Chat("Not retrievable: "..DropCount.Tracker.RequestedItem,1);
		if (dcdb.Item[DropCount.Tracker.RequestedItem]) then
			local iTable=dcdb.Item[DropCount.Tracker.RequestedItem];
			if (iTable.Item) then DropCount:Chat("\""..DropCount.Tracker.RequestedItem.."\" seem to be \""..iTable.Item.."\"",1); end
		end
		DropCount:Chat("This can happen if it has not been seen on the server since last server restart.",1);
		DropCount.Tracker.UnknownItems=nil;			-- Too many tries, so abort
		DropCount.Tracker.RequestedItem=nil;
	end
end

function DropCount.OnUpdate:RunMouseoverInWorld()
	if (UnitExists("mouseover")) then
		local modifier,unit,sguid=IsAltKeyDown(),UnitName("mouseover"),UnitGUID("mouseover"):sub(7,10);
		if (modifier) then
			if (not LootCount_DropCount_TT:IsVisible()) then DropCount:ShowNPC(unit,sguid,LootCount_DropCount_Character.CompactView);
			elseif (LootCount_DropCount_TT.Loading) then
				LootCount_DropCount_TT:Hide();
				DropCount.Tooltip:SetLootlist(unit,sguid,LootCount_DropCount_Character.CompactView);
			end
			return;
	end end
	if (not LCDC_VendorFlag_Info) then if (LootCount_DropCount_TT:IsVisible()) then LootCount_DropCount_TT:Hide(); end end
end

function DropCount.OnUpdate:RunTimedQueue()
	local now=time();
	if (now-DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize].Time>CONST.QUEUETIME) then
		table.remove(DropCount.Tracker.TimedQueue,DropCount.Tracker.QueueSize);
		DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize-1;
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
	end
end

function DropCount:BuildItemList(mob)
	local list={};
	for item,iData in rawpairs(dcdb.Item) do
		MT:Yield();
		if (iData:find(mob,1,true)) then
			list[item]=floor(DropCount:TimedQueueRatio(item)*100);
			if (list[item]<0) then list[item]=nil; end
		end
	end
	return list;
end

function DropCount.OnUpdate:MonitorGameTooltip()
	if (not GameTooltip or not GameTooltip:IsVisible()) then if (DropCount.Tracker.GameTooltipObjectIdHandled) then DropCount.Tracker.GameTooltipObjectIdHandled=nil; end return; end
	if (not IsControlKeyDown() and not IsAltKeyDown()) then
		local handled=DropCount.Tracker.GameTooltipObjectIdHandled;		-- find previous assignment
		local obj=DropCount:GetCurrentObjectID();						-- find current hover
		DropCount.Tracker.GameTooltipObjectIdHandled=obj;				-- save current hover as active hover
		if (DropCount.Tracker.GameTooltipObjectIdHandled==handled) then return; end		-- no change since last check
		obj=dcdb.Gather.GatherNodes[obj]; if (not obj or not obj.Loot) then return; end	-- no node, or a different kind (like Glowcap wich is same-named item and object)
		GameTooltip:LCAddLine(" ",1,1,1);
   		if (DropCount.Debug) then GameTooltip:LCAddLine(Basic..obj.Count.." gathers (debug-text only)",1,1,1); end
		local links={};
		for item,count in pairs(obj.Loot) do
			local _,link=GetItemInfo(item);
			if (link and (obj.Count or 0)>0) then table.insert(links,{l=link,r=count/obj.Count}); end
		end
		table.sort(links,function (a,b) return (a.r>b.r); end);
		for _,it in ipairs(links) do GameTooltip:LCAddLine("    "..it.l.."  ("..DropCount:FormatPst(it.r).."%)",1,1,1); end
		GameTooltip:Show();	-- recalc size
		return;
	end
	local _,ThisItem=GameTooltip:GetItem();
	if (not ThisItem) then return; end
	ThisItem=DropCount:GetID(ThisItem);
	if (ThisItem) then
		if (IsControlKeyDown()) then DropCount.Tooltip:VendorList(ThisItem);
		elseif (IsAltKeyDown()) then DropCount.Tooltip:MobList(ThisItem); end
	end
end

function DropCount.OnUpdate:MonitorReadableTexts()
	if (ItemTextFrame and ItemTextFrame:IsVisible()) then
		if (DropCount.ItemTextFrameHandled) then return; end
		if (ItemTextGetCreator()) then							-- A player created text
			DropCount.ItemTextFrameHandled=true;
		elseif (ItemTextTitleText) then							-- There's a header
			local material=ItemTextGetMaterial();
			if (not material) then material="Parchment"; end
			if (material=="Parchment") then						-- It's parchment
				if (ItemTextNextPageButton:IsVisible()) then	-- Multi-page
					local theItem=ItemTextTitleText:GetText();
					if (theItem) then							-- There's something in the header
						if (not GetItemInfo(theItem)) then		-- It's not an item name
							DropCount:SaveBook(theItem);			-- it's by high probability a book
							DropCount.ItemTextFrameHandled=true;
		end end end end end
	elseif (DropCount.ItemTextFrameHandled) then
		DropCount.ItemTextFrameHandled=nil;
	end
end

function DropCount.OnUpdate:RunStartup(elapsed)
	DropCount.Timer.StartupDelay=DropCount.Timer.StartupDelay-elapsed;
	if (DropCount.Timer.StartupDelay<=0) then
		DropCount.Timer.StartupDelay=nil;
		Astrolabe:CalculateMinimapIconPositions();
		LCDC_RescanQuests=CONST.RESCANQUESTS;
	end
end

function DropCount.OnUpdate:RunQuestScan(elapsed)
	LCDC_RescanQuests=LCDC_RescanQuests-elapsed;
	if (LCDC_RescanQuests<0) then
		LCDC_RescanQuests=nil;
		DropCount.Quest:Scan();
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
	end
end

function DropCount.OnUpdate:WalkOldQuests(elapsed)
	if (DropCount.Timer.PrevQuests>=0) then
		DropCount.Timer.PrevQuests=DropCount.Timer.PrevQuests-elapsed;
		return;
	end
	if (DropCount.Timer.PrevQuests<0 and dcdb.QuestQuery) then
		local count=nil;
		for qIndex in pairs(dcdb.QuestQuery) do
			count=true;
			local qName=DropCount:GetQuestName("quest:"..qIndex);
			if (qName) then
				if (LootCount_DropCount_Character.DoneQuest[qName]) then
					if (type(LootCount_DropCount_Character.DoneQuest[qName])~="table") then
						if (LootCount_DropCount_Character.DoneQuest[qName]~=true) then
							local num=LootCount_DropCount_Character.DoneQuest[qName];
							LootCount_DropCount_Character.DoneQuest[qName]=nil;
							LootCount_DropCount_Character.DoneQuest[qName]={[num]=true,[qIndex]=true};
						else LootCount_DropCount_Character.DoneQuest[qName]=qIndex; end
					else LootCount_DropCount_Character.DoneQuest[qName][qIndex]=true; end
				else LootCount_DropCount_Character.DoneQuest[qName]=qIndex; end
				dcdb.QuestQuery[qIndex]=nil;
				DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests-1;
			else
				if (type(dcdb.QuestQuery[qIndex])~="number") then dcdb.QuestQuery[qIndex]=10;
				else
					dcdb.QuestQuery[qIndex]=dcdb.QuestQuery[qIndex]-1;
					if (dcdb.QuestQuery[qIndex]<0) then
						dcdb.QuestQuery[qIndex]=nil;
						DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests-1;
			end end end
			DropCount.Timer.PrevQuests=(1/3);
			break;
		end
		if (not count) then dcdb.QuestQuery=nil; LCDC_RescanQuests=CONST.RESCANQUESTS; end
	end
end

function DropCount.MT.DB:CleanImport()
	local sects=0;
	for _,md in ipairs(LootCount_DropCount_MergeData) do sects=sects+1; end
	if (DropCount.Debug) then DropCount:Chat("debug: Cleaning import data: "..sects.." sections.",.8,.8,1); end
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		if (DropCount.Debug) then DropCount:Chat("debug: Cleaning section "..s,.8,.8,1); end
		DropCount.MT.DB.Maintenance:_0x(md,true);		-- Check for WoW 4.2 combatmessage f-up
		DropCount.MT.DB.Maintenance:_Skinning(md,true);	-- null profession
		DropCount.Tracker.CleanImport.Okay=0;
		DropCount.MT.DB.Maintenance:_Kill(md,true);		-- null drop
		if (not checkMob) then
			if (DropCount.Debug) then
				DropCount:Chat("debug: Cleaning import data done",.8,.8,1);
				DropCount:Chat("debug: Deleted: "..DropCount.Tracker.CleanImport.Deleted,.8,.8,1);
				DropCount:Chat("debug: Okay: "..DropCount.Tracker.CleanImport.Okay,.8,.8,1);
			end
			DropCount.Tracker.CleanImport.Cleaned=true;
	end end
end

-- Check for WoW 4.2 combatmessage f-up
function DropCount.MT.DB.Maintenance:_0x(t,y)
	if (not t or not t.Count) then return; end
	for m in rawpairs(t.Count) do
		if (m:find("0x",1,true)==1) then
			DropCount:RemoveFromItems("Name",m,t) MT:Yield(y);
			DropCount:RemoveFromItems("Skinning",m,t)
			t.Count[m]=nil;
			Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
			DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
			if (DropCount.Debug) then DropCount:Chat("("..DropCount.Tracker.CleanImport.Deleted.."/"..DropCount.Tracker.CleanImport.Deleted+DropCount.Tracker.CleanImport.Okay..") "..m.." has been deleted.",.8,.8,1); end
		end
		MT:Yield();			-- "slow"
	end
	Table:PurgeCache(DM_WHO);
end

-- Check that mobs have registered drops for their loot type
function DropCount.MT.DB.Maintenance:_Skinning(t,y) return self:_Drop(t,"Skinning",y); end
function DropCount.MT.DB.Maintenance:_Kill(t,y) return self:_Drop(t,"Kill",y); end
-- Check drop sections for validity
function DropCount.MT.DB.Maintenance:_Drop(t,s,y)
	local si=s;
	if (si=="Kill") then si="Name"; end	-- items do "Name"
	if (s=="Name") then s="Kill"; end	-- mobs do "Kill"
	for m,md in rawpairs(t.Count) do
		DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;
		if (md:find(s,1,true)) then	-- possibly had this drop type
			local mt=t.Count[m];
			if (mt and mt[s] and mt[s]>2) then	-- got it
				local foundone=nil;
				for i,id in rawpairs(t.Item) do		-- cycle items
					if (id:find(m,1,true)) then		-- possible mob precense
						local it=t.Item[i];
						if (it and it[si] and it[si][m] and it[si][m]>0) then foundone=true; break; end	-- dropped by said mob and not quest item
					end
					MT:Yield();		-- must be slow to ever finish
				end
				if (not foundone) then		-- no skinning drop for skinned mob
					DropCount:RemoveFromItems("Name",m,t,true); MT:Yield(y);
					DropCount:RemoveFromItems("Skinning",m,t,true);
					if (DropCount.Debug) then DropCount:Chat("debug: "..s.."-drop missing: "..(mt.Name or m).." deleted.",.8,.8,1); end
					t.Count[m]=nil;
					Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
					DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
					DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay-1;		-- remove it again
				else MT:Yield(y); end
			end
		else MT:Yield(y); end
	end
	Table:PurgeCache(DM_WHO);
end

-- Check for Pandaria hotwired addons
function DropCount.MT.DB.Maintenance:_KillHotwiredLoot(t,y)
	local first=time({year=2012,month=8,day=28});
	for i in rawpairs(t.Item) do
		local buf=t.Item[i];
		if (buf and buf.Time and buf.Time>first and buf.Time<time()) then
			if (dcdb.LocalImporter) then print("==>> Importer found:",buf.Item or i,date("%c",buf.Time)); end
			if (t~=dcdb or not dcdb.LocalImporter) then
				if (buf.Name) then
					for m in pairs(buf.Name) do
						DropCount:RemoveFromItems("Name",m,t,true); MT:Yield(true);
						t.Count[m]=nil;
						Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
						MT:Yield(y);
				end end
				if (buf.Skinning) then
					for m in pairs(buf.Skinning) do
						DropCount:RemoveFromItems("Skinning",m,t,true); MT:Yield(true);
						t.Count[m]=nil;
						Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
						MT:Yield(y);
				end end
				t.Item[i]=nil;
				Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
			else MT:Yield(); end
		else MT:Yield(y); end
	end
	Table:PurgeCache(DM_WHO);
end

-- This can run for too long
-- Hopefully fixed now by removing garbagecollect
function DropCount.MT.DB:CleanDatabase()
	if (DropCount.Debug) then DropCount:Chat("debug:","Running low-impact background database cleaner..."); end
	for faction,fTable in pairs(dcdb.Quest) do			-- Remove QG without quests or location 0,0
		for qg,qgd in rawpairs(fTable) do								-- All factions
			local x,y=qg:match("^%- item %- %(.+ %- .+ (%d+)%,(%d+)%)$");
			if (x and y and (x=="0" or y=="0")) then
				fTable[qg]=nil;
				Table:PurgeCache(DM_WHO);
				if (DropCount.Debug) then DropCount:Chat("Misplaced QG: "..faction..": "..qg.." deleted",.8,.8,1); end
			elseif (not qgd:find("Quests",1,true) and not dcdb.Quest[faction][qg].Quests) then
				fTable[qg]=nil;
				Table:PurgeCache(DM_WHO);
				if (DropCount.Debug) then DropCount:Chat("Empty QG: "..faction..": "..qg.." deleted",.8,.8,1); end
			end
			MT:Yield(true);		-- maintain low profile ("too long" has happened here)
		end
	end
	Table:PurgeCache(DM_WHO);
	DropCount.WeHaveCleanDatabaseQG=true;
	DropCount.MT.DB.Maintenance:_0x(dcdb,true);		-- Check for WoW 4.2 combatmessage f-up
	DropCount.MT.DB.Maintenance:_Skinning(dcdb,true);
	DropCount.MT.DB.Maintenance:_Kill(dcdb,true);
	if (DropCount.Debug) then DropCount:Chat("debug:","Cleaning database done.",.8,.8,1); end
end

function DropCount.MT.DB:TrimNodes()
	if (DropCount.Debug) then print("debug:","trimming nodes..."); end
	local before=DropCountXML:TableBytes(dcdb.Gather.GatherNodes);
	local lang=GetLocale();
	for i,node in dcdbpairs(dcdb.Gather.GatherNodes) do
		if (node.Name and node.Name[lang]) then
			for j in pairs(node.Name) do if (j~=lang) then node.Name[j]=nil; end end	-- remove all other
			dcdb.Gather.GatherNodes[i]=node;		-- put it back where it came from
			MT:Yield(true);			-- be quiet
	end end
	Table:PurgeCache(DM_WHO);
	if (DropCount.Debug) then
		local after=DropCountXML:TableBytes(dcdb.Gather.GatherNodes);
		print("debug:","nodes trimmed:",before,"->",after,"=",Green..string.format("%.0f%%",(100/before)*(before-after)));
	end
end

function DropCount.MT.DB:CleanDatabaseDD()
	if (DropCount.Debug) then print("debug:","checking for dual dudes..."); end
	for name in rawpairs(dcdb.Count) do
		if ((name:len()==4 and tonumber(name,16))) then	-- it's new
			local test=dcdb.Count[name].Name or "";
			if (dcdb.Count[test]) then
				DropCount.MT:ClearMobDrop(nil,test,"Skinning");
				DropCount.MT:ClearMobDrop(nil,test,"Name");
				dcdb.Count[test]=nil;
				if (DropCount.Debug) then print("debug","Removed duplicate dude",test,"for sguid",name); end
		end end
		MT:Yield(true);
	end
	Table:PurgeCache(DM_WHO);
	if (DropCount.Debug) then print("debug:","dual dudes done"); end
end

function DropCount.MT.DB:CleanDatabaseQG()
	repeat MT:Yield(true); until (DropCount.WeHaveCleanDatabaseQG);		-- wait until QG DB cleaning is done
	if (DropCount.Debug) then DropCount:Chat("debug: Running QG cleaner..."); end
	local scanA="^%- item %- %((.+) %- .+ %d+%,%d+%)$";				-- Set filter A		"- item - (Uldum - Obelisk of the Sun 42,57)" / "- item - (Stormwind City - Wizard's Sanctum 48,87)"
	local scanB="^%- item %- %((.+) %d+%,%d+%)$";					-- Set filter B		"- item - (Uldum 39,67)"
	local scanI="^%- item %- %(.+ %d+%,%d+%)$";						-- Set filter item
	local buf={};
	-- Remove duplicate same-zone item quest givers
	for faction,fTable in pairs(dcdb.Quest) do
		for qg,qgr in rawpairs(fTable) do									-- All factions
			-- find zone for this npc or item
			local zone=qg:match(scanA);									-- Get zone if any
			if (not zone) then zone=qg:match(scanB); end
			if (not zone) then											-- no zone, so npc
				zone=dcdb.Quest[faction][qg].Zone;			-- get npc's zone
				if (zone:find(" - ",1,true)) then zone=zone:match("^(.+) %- .+$"); end		-- main zone only
			end
			-- spool all item qg for that zone
			wipe(buf);
			for _qg,_qgr in pairs(fTable) do							-- spool zone
				if (_qg:find(zone,1,true)) then table.insert(buf,_qg); end		-- zone in item QG name
				MT:Yield();		-- low fps for a fraction of a second as opposed to 10 minutes or lag
			end
			local qgd=dcdb.Quest[faction][qg];				-- get first item
			-- cycle all same-zone item qg
			for _bi,_qg in pairs(buf) do								-- spool zone
				local _zone=_qg:match(scanA);							-- get zone if any
				if (not _zone) then _zone=_qg:match(scanB); end
				if (_zone and _zone==zone and qg~=_qg) then				-- same zone, different item
					-- compare quests to find duplicates and remove them
					for i,q in ipairs(qgd.Quests) do					-- cycle first quests
						if (fTable[_qg]:find(tostring(q.ID)) and fTable[_qg]:find(q.Quest) and fTable[_qg]:find(q.Header)) then	-- All strings present
							local _qgd=dcdb.Quest[faction][_qg];	-- Get tester item
							for _i,_q in ipairs(_qgd.Quests) do			-- cycle tester quests
								if (_q.ID==q.ID and _q.Quest==q.Quest and _q.Header==q.Header) then		-- has same quest?
									table.remove(_qgd.Quests,_i);
									if (DropCount.Debug) then DropCount:Chat("Duplicate "..faction.." QI: ".._qg..", deleted: "..q.Quest.." in "..q.Header,.8,.8,1); end
									-- only save if there are more quests as empty will be deleted
									if (next(_qgd.Quests)) then dcdb.Quest[faction][_qg]=_qgd; end		-- check for more quest
									break;
							end end
							if (not next(_qgd.Quests)) then				-- check for empty quest list
								fTable[_qg]=nil;
								Table:PurgeCache(DM_WHO,true);
								break;
						end end
						MT:Yield(true);		-- maintain low profile
	end end end end end
	Table:PurgeCache(DM_WHO);
	if (DropCount.Debug) then DropCount:Chat("debug: Cleaning QG database done.",.8,.8,1); end
end

function DropCount.MT:UpgradeDatabaseStorageVersion(t,ver)
	if (not ver) then ver=Table.LastPackerVersion; end
	local dive=nil;
	for name,data in rawpairs(t) do if (type(data)=="table") then dive=true; break; end MT:Yield(); end	-- no unpacked tables within "__DATA__"
	if (dive) then
		for name,data in rawpairs(t) do
			if (type(data)=="table") then if (DropCount.Debug) then print("debug:",name,"converts to",ver,"..."); end DropCount.MT:UpgradeDatabaseStorageVersion(data,ver); end
			MT:Yield(true);
		end
		return;
	end
	-- we're at an end-level compressed table
	for name,data in rawpairs(t) do					-- get raw to check version
		if (data:find("^"..ver)) then MT:Yield();	-- go quickly past correct versions
		else t[name]=t[name]; MT:Yield(true); end	-- read older version, write back with preferred compression
	end
	Table:PurgeCache(DM_WHO);
end

function DropCount:UnpackMergedata()
	if (DropCount.__UnpackMergedata) then return; end
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		-- Unpack all entries for quick repeated access
		for entry in pairs(md.Item) do Table:Unpack(DM_WHO,entry,md.Item); end
		for entry in pairs(md.Count) do Table:Unpack(DM_WHO,entry,md.Count); end
		for entry in pairs(md.Vendor) do Table:Unpack(DM_WHO,entry,md.Vendor); end
		for entry in pairs(md.Book) do Table:Unpack(DM_WHO,entry,md.Book); end
		for entry in pairs(md.Forge) do Table:Unpack(DM_WHO,entry,md.Forge); end
		for entry in pairs(md.Grid) do Table:Unpack(DM_WHO,entry,md.Grid); end
		for _,fd in pairs(md.Trainer) do for entry in pairs(fd) do Table:Unpack(DM_WHO,entry,fd); end end
		for _,fd in pairs(md.Quest) do for entry in pairs(fd) do Table:Unpack(DM_WHO,entry,fd); end end
		for _,sd in pairs(md.Gather) do for entry in pairs(sd) do Table:Unpack(DM_WHO,entry,sd); end end
	end
	DropCount.__UnpackMergedata=true;
end

function DropCount.MT:ConvertAndMerge()
	-- Check for really old stuff
	while (DropCount.Loaded<=10) do MT:Yield(true); end
	if (not dcdb.Converted or dcdb.MergedData<5) then
		dcdb.MergedData=5;
		dcdb.Converted=7;
		dcdb.Vendor={};
		dcdb.Book={};
		dcdb.Item={};
		dcdb.Quest={};
		dcdb.Count={};
--		collectgarbage("collect");
	end
	if (not LootCount_DropCount_MergeData) then return; end
	-- register mergable data and strip unwanted data
	for _,md in ipairs(LootCount_DropCount_MergeData) do		-- ipairs to not include other settings
		CreateDropcountDB(md);
		-- single-level
		if (dcdb.DontFollowMobsAndDrops) then wipe(dcdb.Count.__DATA__); wipe(md.Count.__DATA__); end
		if (dcdb.DontFollowMobsAndDrops) then wipe(dcdb.Item.__DATA__); wipe(md.Item.__DATA__); end
		if (dcdb.DontFollowVendors) then wipe(dcdb.Vendor.__DATA__); wipe(md.Vendor.__DATA__); end
		if (dcdb.DontFollowBooks) then wipe(dcdb.Book.__DATA__); wipe(md.Book.__DATA__); end
		if (dcdb.DontFollowForges) then wipe(dcdb.Forge.__DATA__); wipe(md.Forge.__DATA__); end
		if (dcdb.DontFollowGrid) then wipe(dcdb.Grid.__DATA__); wipe(md.Grid.__DATA__); end
		-- sub-leveled
		if (dcdb.DontFollowTrainers) then for sub in pairs(dcdb.Trainer) do wipe(dcdb.Trainer[sub].__DATA__); end end
		if (dcdb.DontFollowTrainers) then for sub in pairs(md.Trainer) do wipe(md.Trainer[sub].__DATA__); end end
		if (dcdb.DontFollowQuests) then for sub in pairs(dcdb.Quest) do wipe(dcdb.Quest[sub].__DATA__); end end
		if (dcdb.DontFollowQuests) then for sub in pairs(md.Quest) do wipe(md.Quest[sub].__DATA__); end end
		if (dcdb.DontFollowGather) then for sub in pairs(dcdb.Gather) do wipe(dcdb.Gather[sub].__DATA__); end end
		if (dcdb.DontFollowGather) then for sub in pairs(md.Gather) do wipe(md.Gather[sub].__DATA__); end end
	end
	LootCount_DropCount_MergeData.indices=copytable(LootCount_DropCount_MergeData_indices); wipe(LootCount_DropCount_MergeData_indices);
	InsertDropcountDB(LootCount_DropCount_MergeData.indices,"indices");
	if (LootCount_DropCount_MergeData.Version~=dcdb.MergedData) then
		DropCount:Chat("New version of DropCount has been installed.",.6,1,.6);
		if (not dcdb.FixedHotWired) then
			DropCount:Chat("Due to WoW loot bugs (and some users' unskilled DropCount hacks), an extended database check has been implemented. This is a must for it to work at all with Pandaria.",.7,.7,1);
		else
			DropCount:Chat("Your database will be checked for errors before merge with the new data can commence.",.7,.7,1);
		end
		DropCount:Chat("During this time, your fps will drop to about 30. I am very sorry for this inconvenience. This will only happen once after installing a new version, so it is recommended to let it finish.",.7,.7,1);
		DropCount:Chat("You can log out during this period if you so wish, and the operation will restart when you log back in. You will be presented with a summary when all operations have finished.",.7,.7,1);
	end


--local tmp

--tmp=dcdb.Item["item:17327:0:0:0:0:0:0"];
--dcdb.testerdecode=copytable(tmp);
--print(tmp);

--tmp=LootCount_DropCount_MergeData[1].Item["item:17327:0:0:0:0:0:0"];
--dcdb.testerdecode=copytable(tmp);
--print(tmp);

	-- Check for hotwired addons for aoe loot changes
	if (not dcdb.FixedHotWired) then
		DropCount:Chat("Running post-Pandaria database clean-up...");
		DropCount.MT.DB.Maintenance:_KillHotwiredLoot(dcdb,true);	-- Check for Pandaria hotwired addons
		dcdb.FixedHotWired=time();
	end
	-- convert known GUID/name
	if (LootCount_DropCount_MergeData.Version~=dcdb.MergedData) then
		DropCount:UnpackMergedata();		-- can be repeatedly called - will upack only once
		DropCount:Chat("Running database integrity check...");
		for mdi,md in ipairs(LootCount_DropCount_MergeData) do			-- outer section (complete databases enclosed)
			if (DropCount.Debug) then DropCount:Chat("debug: Setting GUID in mergedata "..mdi.." from local...",0,1,0); end
			for name,data in rawpairs(md.Count) do						-- raw import data
				if ((name:len()~=4 or not tonumber(name,16)) and not dcdb.Count.__DATA__[name]) then	-- it's not converted and local data does not have it
					for sguid,rawg in rawpairs(dcdb.Count) do
						if (rawg:find(name,1,true) and sguid:len()==4 and tonumber(sguid,16)) then		-- found same name in converted local data
							local datag=dcdb.Count[sguid];
							if (datag.Name==name) then DropCount.WoW5:ConvertMOB(name,sguid,md,true); break; end	-- convert data for import and keep unpacked
						end MT:Yield();
			end end end
			Table:PurgeCache(DM_WHO);
			if (DropCount.Debug) then DropCount:Chat("debug: Setting GUID in local from mergedata "..mdi.."...",0,1,0); end
			for name,datar in rawpairs(dcdb.Count) do					-- raw local data
				if ((name:len()~=4 or not tonumber(name,16)) and not md.Count[name]) then		-- it's not converted and it's different in merge-data
					local datan=dcdb.Count[name];								-- read old version
					for sguid,rawg in rawpairs(md.Count) do
						if (rawg:find(name,1,true) and sguid:len()==4 and tonumber(sguid,16)) then	-- found same name in converted local data
							local datag=md.Count[sguid];
							if (datag.Name==name) then DropCount.WoW5:ConvertMOB(name,sguid); break; end		-- convert data for import
						end MT:Yield();
			end end end
			Table:PurgeCache(DM_WHO);
			if (DropCount.Debug) then DropCount:Chat("debug: Setting C in local from mergedata "..mdi.."...",0,1,0); end
			for name,datan in rawpairs(md.Count) do						-- raw import data - UNPACKED
				if (datan and datan.C) then
					local datal=dcdb.Count[name];
					if (datal and datan.C~=datal.C) then datal.C=datan.C; dcdb.Count[name]=datal; end
			end MT:Yield(); end
			Table:PurgeCache(DM_WHO);
			if (DropCount.Debug) then DropCount:Chat("debug: Setting C in mergedata "..mdi.." from local...",0,1,0); end
			for name,datar in rawpairs(dcdb.Count) do					-- raw local data
				if (datar:find("worldboss",1,true) or datar:find("rare",1,true) or datar:find("elite",1,true)) then
					local datan=dcdb.Count[name];							-- read local version
					local datai=md.Count[name];
					if (datan and datai and datan.C~=datai.C) then datai.C=datan.C; md.Count[name]=datai; end
			end MT:Yield(); end
			Table:PurgeCache(DM_WHO);
		end
		if (DropCount_Local_Code_Enabled) then DropCount.MT.DB:CleanImport(); end
		DropCount.Tracker.CleanImport.Cleaned=true;
		DropCount.MT:MergeDatabase();
	end
	wipe(LootCount_DropCount_MergeData); LootCount_DropCount_MergeData=nil;
	if (dcdb.MergedData~=dcdb.CleanedData) then
		DropCount.MT.DB:CleanDatabase();
		dcdb.CleanedData=dcdb.MergedData;
	end
	if (dcdb.MergedData~=dcdb.CleanedDataQG) then
		DropCount.MT.DB:CleanDatabaseQG();
		dcdb.CleanedDataQG=dcdb.MergedData;
	end
	if (dcdb.PackerSweepCompleted~=Table.LastPackerVersion) then
		DropCount.MT:UpgradeDatabaseStorageVersion(dcdb);
		dcdb.PackerSweepCompleted=Table.LastPackerVersion;
	end
	if (dcdb.MergedData~=dcdb.GatherNodeTrim) then
		DropCount.MT.DB:TrimNodes();
		dcdb.GatherNodeTrim=Table.MergedData;
	end
	DropCount.MT.DB:CleanDatabaseDD();		-- do double dudes leisurely last
end

function DropCount:RemoveFromDatabase()
	-- Delete quests from database
	if (LootCount_DropCount_RemoveData.Quest) then
		for faction,fTable in pairs(LootCount_DropCount_RemoveData.Quest) do
			for npc in pairs(fTable) do
				local nTable=LootCount_DropCount_RemoveData.Quest[faction][npc];
				if (not nTable.Quests) then			-- Remove entire NPC
					dcdb.Quest[faction][npc]=nil;
				else								-- Remove specific quest
					if (dcdb.Quest[faction][npc]) then
						local tempTable=dcdb.Quest[faction][npc];		-- Get said NPC
						for _,qTable in pairs(nTable.Quests) do			-- Walk quests to remove
							local index,found=1,nil;
							while (tempTable.Quests[index] and not found) do
								if (tempTable.Quests[index].Quest==qTable.Quest) then found=true; end
								index=index+1;
							end
							if (found) then
								index=index-1;
								while (tempTable.Quests[index+1]) do
									tempTable.Quests[index]=copytable(tempTable.Quests[index+1]);
									index=index+1;
								end
								tempTable.Quests[index]=nil;
								dcdb.Quest[faction][npc]=tempTable;
	end end end end end end end
	-- delete drops from creatures
	if (LootCount_DropCount_RemoveData.Count) then
		for npc,nData in pairs(LootCount_DropCount_RemoveData.Count) do
			if (dcdb.Count[npc]) then
				for section,item in pairs(nData) do
					local iSect=section;
					if (iSect=="Kill") then iSect="Name"; end
					if (type(item)=="table") then				-- remove named items
						for _,item in pairs(item) do DropCount:RemoveMobFromItem(item,npc,iSect); end	-- remove from item loot list
					elseif (type(item)=="boolean") then			-- remove entire section
						local mTable=dcdb.Count[npc];
						if (mTable[section]) then
							mTable[section]=nil;					-- Kill it
							dcdb.Count[npc]=mTable;		-- save it
							DropCount:RemoveFromItems(iSect,npc);	-- remove from all loot lists
	end end end end end end
	-- Remove qgivers in neutral if it's in horde or alliance as well
	if (dcdb.Quest.Neutral) then
		for npc,_ in rawpairs(dcdb.Quest.Neutral) do
			for faction,fData in pairs(dcdb.Quest) do
				if (faction~="Neutral") then if (fData[npc]) then dcdb.Quest.Neutral[npc]=nil; end end
	end end end
	-- remove items from game (drops and vendors)
	if (LootCount_DropCount_RemoveData.Item) then
		for item,iRaw in pairs(LootCount_DropCount_RemoveData.Item) do
			if (iRaw==false) then
				dcdb.Item[item]=nil;
				for v,vr in rawpairs(dcdb.Vendor) do
					if (vr:find(item,1,true)) then
						local vd=dcdb.Vendor[v];
						if (vd.Items and vd.Items[item]) then vd.Items[item]=nil; dcdb.Vendor[v]=vd; end
	end end end end end
end

function DropCount:IsEmpty(check)
	if (not check) then return true; end
	if (next(check)) then return nil; end
	return true;
end

-- remove a specified mob from all items
function DropCount:RemoveFromItems(section,npc,base,y)
	if (not base) then base=dcdb; end
	if (not base.Item) then return; end
	for item,iData in rawpairs(base.Item) do
		if (iData:find(npc,1,true)) then
			local iTable=base.Item[item];
			if (iTable[section]) then
				iTable[section][npc]=nil;					-- Kill it
				base.Item[item]=iTable;
				if (y) then MT:Yield(); end
	end end end
end

function DropCount.MT:MergeStatus(mobs)
--	DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
	local pc;
	if (not mobs) then pc=floor((DropCount.Tracker.Merge.Total/DropCount.Tracker.Merge.Goal)*100);
	else pc=floor((DropCount.Tracker.Merge.Mobs/DropCount.Tracker.Merge.MobsGoal)*100); end
--print(mobs,pc);
	if (pc%10==0 and pc>DropCount.Tracker.Merge.Printed) then
			DropCount.Tracker.Merge.Printed=floor(pc/10)*10;
			local sat=(0.4/100)*pc;
			if (not mobs) then DropCount:Chat("Data merged: "..pc.."%",1-sat,.6+sat,.6);
			else DropCount:Chat("Mobs merged: "..pc.."%",1-sat,.6+sat,.6);
	end end
	MT:Yield(nil,pc);
end

function DropCount.MT:MergeDatabase()
	if (not LootCount_DropCount_MergeData) then return false; end
	if (not dcdb.MergedData) then dcdb.MergedData=0; end
	if (LootCount_DropCount_MergeData.Version==dcdb.MergedData) then return false; end
	DropCount.Tracker.Merge.Total=0;
	DropCount.Tracker.Merge.Goal=0;
	DropCount.Tracker.Merge.Mobs=0;
	DropCount.Tracker.Merge.MobsGoal=0;
	local sects=0;
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		sects=sects+1;
		for _ in rawpairs(md.Count) do DropCount.Tracker.Merge.MobsGoal=DropCount.Tracker.Merge.MobsGoal+1; MT:Yield(); end
		for _ in rawpairs(md.Vendor) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _ in rawpairs(md.Item) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _,bT in dcdbpairs(md.Book) do
			for _ in pairs(bT) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		end
		for _,qT in pairs(md.Quest) do
			for _ in rawpairs(qT) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		end
		if (not md.Forge) then md.Forge={}; end
		for _ in rawpairs(md.Forge) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		if (not md.Trainer) then md.Trainer={ [CONST.MYFACTION]={}, }; end
		for _,tT in pairs(md.Trainer) do
			for _ in rawpairs(tT) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		end
		for _ in rawpairs(md.Grid) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _ in rawpairs(md.Gather.GatherNodes) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _ in rawpairs(md.Gather.GatherORE) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _ in rawpairs(md.Gather.GatherHERB) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
	end
	DropCount:Chat(LOOTCOUNT_DROPCOUNT_VERSIONTEXT,1,.3,.3);
	DropCount:Chat("There are "..DropCount.Tracker.Merge.Goal+DropCount.Tracker.Merge.MobsGoal.." entries to merge with your database.",1,.6,.6);
	DropCount:Chat("This will take a few minutes, depending on the speed of your computer.",1,.6,.6);
	DropCount:Chat("You can play while this is running, and you will probably experience lower FPS "..Basic.."while not in combat|r.",1,.6,.6);
	if (DropCount.Debug) then DropCount:Chat("===> "..sects.." sections.",1,.6,.6); end
	-- merge mobs
	DropCount.Tracker.Merge.Printed=-1;
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		local strict=(dcdb.MergedData==4) or nil;	-- special case override
		for mob in rawpairs(md.Count) do
			local newMob,updatedMob=DropCount.MT:MergeMOB(mob,s,strict);
			DropCount.Tracker.Merge.Mob.New=DropCount.Tracker.Merge.Mob.New+newMob;
			DropCount.Tracker.Merge.Mob.Updated=DropCount.Tracker.Merge.Mob.Updated+updatedMob;
			DropCount.Tracker.Merge.Mobs=DropCount.Tracker.Merge.Mobs+1;
			DropCount.MT:MergeStatus(true);			-- true = mob-merge update
	end end
	Table:PurgeCache(DM_WHO);
	DropCount.Tracker.Merge.Printed=-1;
	-- merge everything else
	DropCount.Tracker.Merge.Printed=-1;
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		-- Gather locations
		local sect="GatherORE";
		repeat
			for mapID,gd in dcdbpairs(md.Gather[sect]) do
				DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
				local map,level=mapID:match("^(%d+)_(%d+)$"); map=tonumber(map); level=tonumber(level);		-- get area IDs
				local pos,grid,i=0,gd.Grid,1;
				repeat
					if (grid:byte(i,i)==0) then i=i+1; pos=pos+(grid:byte(i,i)*8);
					else
						local tmp=grid:byte(i,i);
						for j=1,8 do
							if (bit.band(tmp,1)==1) then
								local y,x=xy(pos);
								DropCountXML:AddGatheringLoot(sect,nil,map,level,x,y,true); end	-- NOTE: x/y swap at "xy(pos)"
							tmp=bit.rshift(tmp,1); pos=pos+1;
						end
						DropCount.MT:MergeStatus();	-- Will handle yield
					end
					i=i+1;
				until(i>grid:len());
				local buf=dcdb.Gather[sect][mapID] or { Gathers=0, OID={}, };		-- get my own data
				if (gd.Gathers>buf.Gathers) then									-- incoming have more gathers
					buf.Gathers=gd.Gathers;											-- use incoming loots
					buf.OID=gd.OID;													-- discard my own data
				end
				dcdb.Gather[sect][mapID]=buf;										-- save
				DropCount.Tracker.Merge.Gather.Updated=DropCount.Tracker.Merge.Gather.Updated+1;
			end
			if (sect=="GatherORE") then sect="GatherHERB"; else sect=nil; end
		until(not sect);
		-- Gather nodes
		local lang=GetLocale();
		for oid,od in dcdbpairs(md.Gather.GatherNodes) do			-- do all incoming objectID's
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local buf=dcdb.Gather.GatherNodes[oid] or { Count=0, Loot={}, Name={}, };
			buf.Count=buf.Count or -1; od.Count=od.Count or 0; buf.Name=buf.Name or {};		-- in case of half registered and none-looted
			if (od.Count>buf.Count) then
				buf.Count=od.Count;						-- set higher count directly
				buf.Loot=od.Loot;						-- discard my own data
				DropCount.Tracker.Merge.Nodes.Updated=DropCount.Tracker.Merge.Nodes.Updated+1;
			end
			buf.Icon=buf.Icon or od.Icon;				-- use other icon only if mine is missing
			if (not buf.Name[lang]) then	-- it's missing
				local ind=LootCount_DropCount_MergeData.indices[oid];
--print("oid",oid);
				if (ind.Name[lang]) then	-- it's missing
					buf.Name[lang]=LootCount_DropCount_MergeData.indices[oid].Name[lang];				-- so set correct one
				end
			end
			dcdb.Gather.GatherNodes[oid]=buf;					-- save
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		-- Grid
		for z,zd in dcdbpairs(md.Grid) do							-- cycle grid areas
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local map,level=z:match("^(%d+)_(%d+)$"); map=tonumber(map); level=tonumber(level);		-- get area IDs
			for loc,dudes in pairs(zd) do							-- cycle all area entries
				local x,y=xy(loc);									-- get location
				for _,sguid in ipairs({strsplit(",",dudes)}) do DropCount.Grid:Add(sguid,map,level,x,y); end	-- add all location dudes to local database
				DropCount.Tracker.Merge.Grid.Updated=DropCount.Tracker.Merge.Grid.Updated+1;
				DropCount.MT:MergeStatus();	-- Will handle yield
		end end
		Table:PurgeCache(DM_WHO);
		-- Forges
		for area,merge in dcdbpairs(md.Forge) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local localF=dcdb.Forge[area];
			if (localF) then
				for mi,mData in pairs(merge) do
					for index,lData in pairs(localF) do
						MT:Yield();
						local mX,mY=mData:match("(.+)_(.+)"); mX=tonumber(mX); mY=tonumber(mY);
						local lX,lY=lData:match("(.+)_(.+)"); lX=tonumber(lX); lY=tonumber(lY);
						if (mX>=lX-1 and mX<=lX+1 and mY>=lY-1 and mY<=lY+1) then
							localF[index]=mX.."_"..mY;			-- set new position
							DropCount.Tracker.Merge.Forge.Updated=DropCount.Tracker.Merge.Forge.Updated+1;
				end end end
				for _,mData in pairs(merge) do
					MT:Yield();
					table.insert(localF,mData);		-- add new forge
					DropCount.Tracker.Merge.Forge.New=DropCount.Tracker.Merge.Forge.New+1;
				end
				dcdb.Forge[area]=localF;			-- save modified area data
			else
				dcdb.Forge[area]=merge;			-- save new area
			end
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		Table:PurgeCache(DM_WHO);
		-- Trainers
		for faction,fData in pairs(md.Trainer) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			if (not DropCount.Tracker.Merge.Trainer.New[faction]) then DropCount.Tracker.Merge.Trainer.New[faction]=0; end
			if (not DropCount.Tracker.Merge.Trainer.Updated[faction]) then DropCount.Tracker.Merge.Trainer.Updated[faction]=0; end
			for trainer,tData in dcdbpairs(fData) do
				if (not dcdb.Trainer[faction][trainer]) then DropCount.Tracker.Merge.Trainer.New[faction]=DropCount.Tracker.Merge.Trainer.New[faction]+1;
				else DropCount.Tracker.Merge.Trainer.Updated[faction]=DropCount.Tracker.Merge.Trainer.Updated[faction]+1; end
				dcdb.Trainer[faction][trainer]=tData;
				DropCount.MT:MergeStatus();	-- Will handle yield
		end end
		Table:PurgeCache(DM_WHO);
		-- Vendors
		for vend,vTable in dcdbpairs(md.Vendor) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local faction=vTable.Faction or "Unknown";
			if (not DropCount.Tracker.Merge.Vendor.New[faction]) then DropCount.Tracker.Merge.Vendor.New[faction]=0; end
			if (not DropCount.Tracker.Merge.Vendor.Updated[faction]) then DropCount.Tracker.Merge.Vendor.Updated[faction]=0; end
			if (not dcdb.Vendor[vend]) then
				dcdb.Vendor[vend]=vTable;
				DropCount.Tracker.Merge.Vendor.New[faction]=DropCount.Tracker.Merge.Vendor.New[faction]+1;
			else
				local updated,tv=nil,dcdb.Vendor[vend];
				if (not vTable.X or not vTable.Y) then vTable.X=0; vTable.Y=0; end
				if ((vTable.X and vTable.Y and vTable.Zone and (vTable.X>0 or vTable.Y>0)) and ((tv.X and tv.Y and tv.Zone and (tv.X>0 or tv.Y>0)))) then
					if (floor(tv.X)~=floor(vTable.X) or floor(tv.Y)~=floor(vTable.Y) or tv.Zone~=vTable.Zone) then updated=true; end
					tv.X,tv.Y,tv.Zone=vTable.X,vTable.Y,vTable.Zone;
					if (vTable.Faction) then tv.Faction=vTable.Faction; end
					if (vTable.Map) then tv.Map=vTable.Map; end
				end
				if (vTable.Items) then
					if (not tv.Items) then tv.Items=copytable(vTable.Items); updated=true;
					else
						for item,iTable in pairs(vTable.Items) do
							if (not tv.Items[item]) then tv.Items[item]=copytable(iTable); updated=true;
							else
								if (iTable.Count~=-2 and tv.Items[item].Count==-2) then tv.Items[item].Count=iTable.Count; updated=true; end
				end end end end
				if (updated) then
					DropCount.Tracker.Merge.Vendor.Updated[faction]=DropCount.Tracker.Merge.Vendor.Updated[faction]+1;
					dcdb.Vendor[vend]=tv;
				end
			end
			md.Vendor[vend]=nil;	-- Done this vendor
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		Table:PurgeCache(DM_WHO);
		-- Books
		for title,bTable in dcdbpairs(md.Book) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local newB,updB=nil,nil;
			for index,vTable in pairs(bTable) do
				local newT,updT=DropCount:SaveBook(title,vTable.Zone,vTable.X,vTable.Y,vTable.Map);
				if (not newB) then if (newT>0) then newB=true; updB=nil; elseif (updT) then updB=true; end end
			end
			if (newB) then DropCount.Tracker.Merge.Book.New=DropCount.Tracker.Merge.Book.New+1; end
			if (updB) then DropCount.Tracker.Merge.Book.Updated=DropCount.Tracker.Merge.Book.Updated+1; end
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		Table:PurgeCache(DM_WHO);
		-- Quests
		for faction,fTable in pairs(md.Quest) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			DropCount.Tracker.Merge.Quest.New[faction]=0;
			DropCount.Tracker.Merge.Quest.Updated[faction]=0;
			for npc,nTable in dcdbpairs(fTable) do
				if (not dcdb.Quest[faction][npc]) then		-- Don't have it, so take all
					dcdb.Quest[faction][npc]=nTable;
					DropCount.Tracker.Merge.Quest.New[faction]=DropCount.Tracker.Merge.Quest.New[faction]+1;
				else
					local updated=nil;
					-- Have it, so update location and merge quests
					local tn=dcdb.Quest[faction][npc];
					tn.X,tn.Y=nTable.X,nTable.Y;
					if (nTable.Map) then tn.Map=nTable.Map; end
					tn.Zone=nTable.Zone;
					if (not tn.Quests) then tn.Quests={}; end
					if (updated) then
						dcdb.Quest[faction][npc]=tn;
						DropCount.Tracker.Merge.Quest.Updated[faction]=DropCount.Tracker.Merge.Quest.Updated[faction]+1;
				end end
				DropCount.MT:MergeStatus();
		end end
		Table:PurgeCache(DM_WHO);
		-- item statics
		for item,miData in dcdbpairs(md.Item) do
			DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
			local saveit=nil;
			local buf=dcdb.Item[item];
			if (not buf) then
				buf=copytable(miData);
				if (buf.Name) then wipe(buf.Name); end			-- no known mobs
				if (buf.Skinning) then wipe(buf.Skinning); end	-- no known mobs
				DropCount.Tracker.Merge.Item.Updated=DropCount.Tracker.Merge.Item.Updated-1;	-- compensate
				DropCount.Tracker.Merge.Item.New=DropCount.Tracker.Merge.Item.New+1;			-- brand new item
				saveit=true;
			else
				-- merge quests
				if (miData.Quests) then buf.Quests=copytable(buf.Quests,miData.Quests); saveit=true; end
				-- Merge best areas
				if (miData.Best and buf.Best) then		-- all-round best
					if (miData.Best.Score>buf.Best.Score) then buf.Best.Score=miData.Best.Score; buf.Best.Location=miData.Best.Location; saveit=true; end
				end
				if (miData.BestW and buf.BestW) then	-- no-instance (world) best
					if (miData.BestW.Score>buf.BestW.Score) then buf.BestW.Score=miData.BestW.Score; buf.BestW.Location=miData.BestW.Location; saveit=true; end
				end
				if (buf.Best and buf.BestW) then		-- use no-instance only if better than all-round data
					if (buf.BestW.Score>buf.Best.Score) then buf.Best=buf.BestW; buf.BestW=nil; saveit=true; end
				end
			end
			if (saveit) then dcdb.Item[item]=buf; DropCount.Tracker.Merge.Item.Updated=DropCount.Tracker.Merge.Item.Updated+1; end
			DropCount.MT:MergeStatus();
		end
		Table:PurgeCache(DM_WHO);
		-- Maps (not counted in final report)
		if (LootCount_DropCount_Maps) then		-- I have maps
			for Lang,LTable in pairs(LootCount_DropCount_Maps) do		-- Check all locales I have
				if (md[Lang]) then		-- Hardcoded has same locale
					LootCount_DropCount_Maps[Lang]=copytable(md[Lang],LootCount_DropCount_Maps[Lang]);	-- Blend tables
					MT:Yield();
		end end end
	end
	-- Output result
	dcdb.MergedData=LootCount_DropCount_MergeData.Version;
	local text="";
	-- mobs
	if (DropCount.Tracker.Merge.Mob.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Mob.New.." new mobs"; end
	if (DropCount.Tracker.Merge.Mob.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Mob.Updated.." updated mobs"; end
	-- Vendors
	local amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Vendor.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new vendors"; end
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Vendor.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated vendors"; end
	-- Quests
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Quest.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new quest-givers"; end
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Quest.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated quest-givers"; end
	-- Books
	if (DropCount.Tracker.Merge.Book.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Book.New.." new books"; end
	if (DropCount.Tracker.Merge.Book.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Book.Updated.." updated books"; end
	-- Items
	if (DropCount.Tracker.Merge.Item.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Item.New.." new items"; end
	if (DropCount.Tracker.Merge.Item.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Item.Updated.." updated items"; end
	-- Trainers
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Trainer.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new profession trainers"; end
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Trainer.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated profession trainers"; end
	-- Forges
	if (DropCount.Tracker.Merge.Forge.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Forge.New.." new forges"; end
	if (DropCount.Tracker.Merge.Forge.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Forge.Updated.." updated forges"; end
	-- nodes
	if (DropCount.Tracker.Merge.Nodes.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Nodes.Updated.." profession node-types updated"; end
	-- gather
	if (DropCount.Tracker.Merge.Gather.Updated>0) then text=text.."\nProfession-maps updated"; end
	-- grid
	if (DropCount.Tracker.Merge.Grid.Updated>0) then text=text.."\nItem drop-maps updated"; end

	-- done
	DropCount:Chat("Your DropCount database has been updated.",1,.6,.6);
	if (text:len()>0) then
		text=LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."\nData merge summary:\n"..text;
		StaticPopupDialogs["LCDC_D_NOTIFICATION"].text=text;
		StaticPopup_Show("LCDC_D_NOTIFICATION");
	end
	Table:PurgeCache(DM_WHO)
	return true;
end

function DropCount.MT:ClearMobDrop(_,mob,section)
	for item,iRaw in rawpairs(dcdb.Item) do
		if (item) then DropCount:RemoveMobFromItem(item,mob,section,iRaw); MT:Yield(); end
	end
end

function DropCount:RemoveMobFromItem(item,mob,section,iRaw)
	if (not iRaw or iRaw:find(mob,1,true)) then
		local iTable=dcdb.Item[item];
		if (iTable and iTable[section] and iTable[section][mob]) then
			iTable[section][mob]=nil;
			dcdb.Item[item]=iTable;
	end end
end

-- Check mobs and insert anything that is missing
-- IMPORTANT: Do not merge counts! Only insert missing!
--
-- o Check if new data has more kills/skinnings than me
--   If I don't have it at all, mine is set up as zero.
function DropCount.MT:MergeMOB(mob,mdSection,strict)
	local newMob,updatedMob,kill,skinning=0,0,nil,nil;
	local tester,mData,cData,mKill,mSkinning;
	mData=LootCount_DropCount_MergeData[mdSection].Count[mob];
	cData=dcdb.Count[mob];
	-- Create the mob if it doesn't exist
	if (not cData and (mData.Kill or mData.Skinning)) then
		mKill,mSkinning=mData.Kill,mData.Skinning;				-- grab incoming kills/skins
		cData=mData; cData.Kill,cData.Skinning=nil,nil;			-- copy mob, reset kill/skin
		newMob=1;
	end
	-- Merge kills
	if (mKill) then
		if (not cData.Kill) then cData.Kill=0; end
		tester=cData.Kill; if (strict) then tester=tester-1; end
		if (mKill>tester) then
			DropCount.MT:ClearMobDrop(nil,mob,"Name");	-- New (and higher) count, so remove old drops
			kill=mKill; cData.Kill=kill;
			if (newMob==0) then updatedMob=1; end
	end end
	-- Merge skinning (all professions)
	if (mSkinning) then
		if (not cData.Skinning) then cData.Skinning=0; end
		tester=cData.Skinning; if (strict) then tester=tester-1; end
		if (mSkinning>tester) then
			DropCount.MT:ClearMobDrop(nil,mob,"Skinning");
			skinning=mSkinning; cData.Skinning=skinning;
			if (newMob==0) then updatedMob=1; end
	end end
	-- do loot
	if (kill or skinning) then
		local sect;
		for item,iRaw in rawpairs(LootCount_DropCount_MergeData[mdSection].Item) do
			if (type(iRaw)=="table" or iRaw:find(mob,1,true)) then
				sect="Name"; if (not kill) then sect="Skinning"; end
				local iTable=LootCount_DropCount_MergeData[mdSection].Item[item];	-- get incoming item data
				repeat		-- do kill and skinning sections
					if (iTable[sect] and iTable[sect][mob]) then					-- exists in source, so update with this item
						local miTable;
						if (not dcdb.Item[item]) then								-- unknown item in target
							miTable=copytable(iTable);								-- copy item to target
							if (miTable.Name) then wipe(miTable.Name); end			-- remove mobs
							if (miTable.Skinning) then wipe(miTable.Skinning); end	-- remove mobs
							DropCount.Tracker.Merge.Item.New=DropCount.Tracker.Merge.Item.New+1;	-- brand new item
						else miTable=dcdb.Item[item]; end							-- get local data
						if (not miTable[sect]) then miTable[sect]={}; end			-- make it if not there
						miTable[sect][mob]=iTable[sect][mob];						-- insert/overwrite this mob count at this item
						dcdb.Item[item]=miTable;									-- save item
					end
					if (sect=="Name" and skinning) then sect="Skinning"; else sect=nil; end
				until(not sect);
	end end end
	if (cData) then
		if (not cData.Kill and not cData.Skinning) then cData=nil; end
		dcdb.Count[mob]=cData;
	end
	return newMob,updatedMob;
end

function DropCountXML.MinimapOnEnter(frame)
	GameTooltip:SetOwner(frame,"ANCHOR_LEFT");
	GameTooltip:SetText("DropCount");
	GameTooltipTextLeft1:SetTextColor(0,1,0);
	GameTooltip:LCAddLine(LOOTCOUNT_DROPCOUNT_VERSIONTEXT);
	GameTooltip:LCAddLine(Basic.."<Left-click>|r for menu");
	GameTooltip:LCAddLine(Basic.."<Right-click>|r and drag to move");
	GameTooltip:LCAddLine(Basic.."<Shift-right-click>|r and drag for free-move");
	if (DropCount.LootCount.Registered) then GameTooltip:LCAddLine(Basic.."LootCount: "..Green.."Present"); end
	if (DropCount.Crawler.Registered) then GameTooltip:LCAddLine(Basic.."Crawler: "..Green.."Present"); end
	GameTooltip:Show();
end

function DropCountXML.MinimapOnClick(frame)
	local menu=DMMenuCreate(DropCount_MinimapIcon);
	menu:Add("GUI",nil,DDT_TEXT);
	menu:Add("Search...",function () LCDC_VendorSearch:Show(); end);
	menu:Add("Locations...",function () DropCount_GridFilterFrame:Show(); end);
	menu:Add("Options...",function () LCDC_ListOfOptions:Show(); end);
	menu:Add("Data...",function () DropCountXML:ShowDataOptionsFrame(); end);
	menu:Add(lBlue.."About DropCount...",function () DropCount:About(); end);
	menu:Separator();
	menu:Add("Minimap",nil,DDT_TEXT);
	if (not dcdb.DontFollowVendors) then menu:Add("Vendors",function() dcdb.VendorMinimap=(not dcdb.VendorMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.VendorMinimap,nil,0,"Interface\\GROUPFRAME\\UI-Group-MasterLooter"); end
	if (not dcdb.DontFollowVendors) then menu:Add("Repair",function() dcdb.RepairMinimap=(not dcdb.RepairMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.RepairMinimap,nil,0,"Interface\\GossipFrame\\VendorGossipIcon"); end
	if (not dcdb.DontFollowBooks) then menu:Add("Books",function() dcdb.BookMinimap=(not dcdb.BookMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.BookMinimap,nil,0,"Interface\\Spellbook\\Spellbook-Icon"); end
	if (not dcdb.DontFollowQuests) then menu:Add("Quests",function() dcdb.QuestMinimap=(not dcdb.QuestMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.QuestMinimap,nil,0,"Interface\\QuestFrame\\UI-Quest-BulletPoint"); end
	if (not dcdb.DontFollowTrainers) then menu:Add("Trainers",function() dcdb.TrainerMinimap=(not dcdb.TrainerMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.TrainerMinimap,nil,0,"Interface\\Icons\\INV_Misc_QuestionMark"); end
	if (not dcdb.DontFollowForges) then menu:Add("Forges",function() dcdb.ForgeMinimap=(not dcdb.ForgeMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.ForgeMinimap,nil,0,CONST.PROFICON[5]); end
	if (not dcdb.DontFollowGrid) then menu:Add("Rare creatures",function() dcdb.RareMinimap=(not dcdb.RareMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.RareMinimap,nil,0,"INTERFACE\\Challenges\\ChallengeMode_Medal_Silver"); end
	if (DropCount_Local_Code_Enabled) then
		if (not dcdb.DontFollowGrid) then menu:Add("* Grid",function() dcdb.GridMinimap=(not dcdb.GridMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.GridMinimap); end
		if (not dcdb.DontFollowGather) then menu:Add("* Ores",function() dcdb.OreMinimap=(not dcdb.OreMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.OreMinimap); end
		if (not dcdb.DontFollowGather) then menu:Add("* Herbs",function() dcdb.HerbMinimap=(not dcdb.HerbMinimap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.HerbMinimap); end
	end
	menu:Separator();
	menu:Add("Worldmap",nil,DDT_TEXT);
	if (not dcdb.DontFollowVendors) then menu:Add("Vendors",function() dcdb.VendorWorldmap=(not dcdb.VendorWorldmap) or nil; end,DDT_CHECK,nil,dcdb.VendorWorldmap,nil,0,"Interface\\GROUPFRAME\\UI-Group-MasterLooter"); end
	if (not dcdb.DontFollowVendors) then menu:Add("Repair",function() dcdb.RepairWorldmap=(not dcdb.RepairWorldmap) or nil; end,DDT_CHECK,nil,dcdb.RepairWorldmap,nil,0,"Interface\\GossipFrame\\VendorGossipIcon"); end
	if (not dcdb.DontFollowBooks) then menu:Add("Books",function() dcdb.BookWorldmap=(not dcdb.BookWorldmap) or nil; end,DDT_CHECK,nil,dcdb.BookWorldmap,nil,0,"Interface\\Spellbook\\Spellbook-Icon"); end
	if (not dcdb.DontFollowQuests) then menu:Add("Quests",function() dcdb.QuestWorldmap=(not dcdb.QuestWorldmap) or nil; end,DDT_CHECK,nil,dcdb.QuestWorldmap,nil,0,"Interface\\QuestFrame\\UI-Quest-BulletPoint"); end
	if (not dcdb.DontFollowTrainers) then menu:Add("Trainers",function() dcdb.TrainerWorldmap=(not dcdb.TrainerWorldmap) or nil; end,DDT_CHECK,nil,dcdb.TrainerWorldmap,nil,0,"Interface\\Icons\\INV_Misc_QuestionMark"); end
	if (not dcdb.DontFollowForges) then menu:Add("Forges",function() dcdb.ForgeWorldmap=(not dcdb.ForgeWorldmap) or nil; end,DDT_CHECK,nil,dcdb.ForgeWorldmap,nil,0,CONST.PROFICON[5]); end
	if (not dcdb.DontFollowGrid) then menu:Add("Rare creatures",function() dcdb.RareWorldmap=(not dcdb.RareWorldmap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.RareWorldmap,nil,0,"INTERFACE\\Challenges\\ChallengeMode_Medal_Silver"); end
	if (not dcdb.DontFollowGrid and DropCount_Local_Code_Enabled) then menu:Add("* Grid",function() dcdb.GridWorldmap=(not dcdb.GridWorldmap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotWorldmap); end,DDT_CHECK,nil,dcdb.GridWorldmap); end
	if (not dcdb.DontFollowGather) then menu:Add("Ores",function() dcdb.OreWorldmap=(not dcdb.OreWorldmap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.OreWorldmap); end
	if (not dcdb.DontFollowGather) then menu:Add("Herbs",function() dcdb.HerbWorldmap=(not dcdb.HerbWorldmap) or nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,nil,dcdb.HerbWorldmap); end
	menu:Show();
end

-- Thanks to Yatlas and Gello for the initial code
function DropCountXML.MinimapBeingDragged()
	-- Thanks to Gello for this code
	local xpos,ypos=GetCursorPosition();
	local xmin,ymin=Minimap:GetLeft(),Minimap:GetBottom();
	if (IsShiftKeyDown()) then
		dcdb.IconPosition=nil;
		xpos=(xpos/UIParent:GetScale()-xmin)-16;
		ypos=(ypos/UIParent:GetScale()-ymin)+16;
		DropCount:MinimapSetIconAbsolute(xpos,ypos);
		return;
	end
	dcdb.IconX,dcdb.IconY=nil,nil;
	xpos=xmin-xpos/UIParent:GetScale()+70
	ypos=ypos/UIParent:GetScale()-ymin-70
	DropCount:MinimapSetIconAngle(math.deg(math.atan2(ypos,xpos)));
end

function DropCount:MinimapSetIconAngle(v)
	dcdb.IconPosition=v%360;
	DropCount_MinimapIcon:SetPoint("TOPLEFT","Minimap","TOPLEFT",54-(78*cos(dcdb.IconPosition)),(78*sin(dcdb.IconPosition))-55);
	DropCount_MinimapIcon:Show();
end

function DropCount:MinimapSetIconAbsolute(x,y)
	dcdb.IconX,dcdb.IconY=x,y;
	DropCount_MinimapIcon:SetPoint("TOPLEFT","Minimap","BOTTOMLEFT",x,y);
end

--
-- DuckLib extracts
--
function DropCount:Chat(msg,r,g,b)
	if (not DEFAULT_CHAT_FRAME) then return; end
	if (not r and not g and not b) then r=1; g=1; b=1; end;
	DEFAULT_CHAT_FRAME:AddMessage(msg,r or 0,g or 0,b or 0);
end

-- Return the common DuckMod ID
function DropCount:GetID(link)
	if (type(link)~="string") then
		if (type(link)~="number") then return nil,nil; end
		_,link=GetItemInfo(link);
	end
	local itemID,i1,i2,i3,i4,i5,i6=link:match("|Hitem:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
	if (not i6) then itemID,i1,i2,i3,i4,i5,i6=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)"); end
	if (not i6) then return; end
	return "item:"..itemID..":"..i1..":"..i2..":"..i3..":"..i4..":"..i5..":"..i6,tonumber(itemID);
end

-- Multi-threading utility
function MT:Run(name,func,...)
	for _,tTable in pairs(self.Threads) do
		if (tTable.orig==func and tTable.name==name) then
			if (DropCount.Debug) then print("debug:",name.."> Already running in another thread. Aborted."); end
			return;
	end end
	self.RunningCo=true;
	self.Count=self.Count+1;
	self.Threads[self.Count]={ name=name, orig=func, cr=coroutine.create(func), };
	self.LastTime=debugprofilestop();
	self.LastStack="Running "..name;
	local succeeded,result=coroutine.resume(self.Threads[self.Count].cr,...);
	if (not succeeded and Swatter) then
		if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
		else DropCount:Chat(result); DropCount:Chat(self.LastStack); end
	end
	self.RunningCo=nil;
end

-- yields immediately if in combat
function MT:Yield(fast,dbdata)
	local now=debugprofilestop();
	self.LastStack=debugstack(2);
	local speed=self.Speed;
	if (fast) then speed=self.FastMT; end
	if (now-self.LastTime<=speed and not InCombatLockdown()) then return; end
	self.LastTime=now;
	coroutine.yield();
	self.LastStack=debugstack(2);
end

function MT:YieldExt() MT:Yield(); end

function MT:Next()
	if (self.Count<1) then return; end
	if (self.RunningCo) then return; end	-- Don't if we are already doing it. In case of real MT.
	self.Current=self.Current+1;
	if (not self.Threads[self.Current]) then self.Current=1; end	-- Wrap
	if (not self.Threads[self.Current]) then return; end	-- Nothing to do
	if (coroutine.status(self.Threads[self.Current].cr)=="dead") then
		local removeIt=self.Current;
		while (self.Threads[removeIt]) do self.Threads[removeIt]=self.Threads[removeIt+1]; removeIt=removeIt+1; end
		self.Current=self.Current-1;
		self.Count=self.Count-1;
		return;
	end
	self.RunningCo=true;
	local succeeded,result=coroutine.resume(self.Threads[self.Current].cr);
	if (not succeeded) then
		DropCount.Loaded=nil;		-- crash the main thread
		if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
		else DropCount:Chat(result); DropCount:Chat(self.LastStack); end
	end
	self.RunningCo=nil;
end

function MT:Processes() return self.Count; end

--
-- May have to not use "match", as multibyte characters seems to mess up byte counting. More tests needed.
-- Maybe the () positional counter is a character counter and not a byte counter.
--
-- speedy version
function Table.v03.DecodeTable(s)
	local _match,_tonumber,_settype,_sub,_byte=string.match,tonumber,Table.v03.SetType,string.sub,string.byte;	-- make everything local
	local t={};
	local nTY,nLE,name,dTY,dLE;
	local pos,maxlen=1,s:len();
	repeat
		nTY=_byte(s,pos);													-- get type with numeric representation to not create a new string
		nLE,pos=_match(s,".(%x-):().*",pos); nLE=_tonumber(nLE,16);			-- capture data-length,position - convert length to number
		name=_settype(nTY,_sub(s,pos,pos+(nLE-1))); pos=pos+nLE;			-- grab it and advance to next
		dTY=_byte(s,pos);													-- get type with numeric representation to not create a new string
--print(s:sub(pos))
		dLE,pos=_match(s,".(%x-):().*",pos); dLE=_tonumber(dLE,16);			-- empty capture reads character position
		t[name]=_settype(dTY,_sub(s,pos,pos+(dLE-1))); pos=pos+dLE;			-- grab, shove, advance
	until (pos>maxlen);
	return t;
end

-- third letter of native type string - lower case, hex representation for avoiding string
function Table.v03.SetType(ty,da)
	if (ty==0x72) then return tostring(da); end		-- r-stRing
	if (ty==0x6D) then return tonumber(da); end		-- m-nuMber
	if (ty==0x6F) then return (da=="true"); end		-- o-boOl
	if (ty==0x62) then if (da=="") then return {}; end return Table.v03.DecodeTable(da); end	-- b-taBle
	if (ty==0x6C) then return nil; end				-- l-niL
	if (ty==0x6E) then return nil; end				-- n-fuNction
	return da;
end

-- this function:
--   accesses all global functions locally for speed
--   uses table concat for extreme speed in repetetive storage, like cloth with 700+ creatures codes in well under 5ms
--   In case of further timing problems: further work can be to store all strings separately to remove all string concatenations
function Table.v03.CodeTable(t)
	local _string_format,_codetable,_tostring,_type,_len,_sub=string.format,Table.v03.CodeTable,tostring,type,string.len,string.sub;	-- make everything local
	local list={};
	local tmp,add;
	for en,ed in pairs(t) do
		tmp=_tostring(en);
		if (_type(ed)=="table") then add=_codetable(ed); else add=_tostring(ed); end
		list[#list + 1]=_sub(_type(en),3,3).._string_format("%X",_len(tmp))..":"..tmp.._sub(_type(ed),3,3).._string_format("%X",_len(add))..":"..add;
	end
	return table.concat(list);
end

function Table:Init(who,UseCache,Base)
	if (who=="Default") then return; end
	if (not Base) then return nil; end
	if (not self.Default[who]) then self.Default[who]={}; end
	wipe(self.Default[who]);
	self.Default[who].UseCache	= UseCache;
	self.Default[who].Base		= Base;
	self.Default[who].Cache		= {};
end

function Table:GetType(typedata,tdExtra,CV)
	if (not CV) then CV=self.CV; end
	if (type(typedata)=="string") then return self[CV].String; end
	if (type(typedata)=="number") then return self[CV].Number; end
	if (type(typedata)=="boolean") then return self[CV].Bool; end
	if (type(typedata)=="table") then return self[CV].sTable..string.char(tdExtra); end
	if (not typedata) then return self[CV].Nil; end
	return self[CV].Other;
end

function Table:CompressV3(tData,s,e)
	local now=debugprofilestop();
	local tmp=Table.v03.CodeTable(tData);
	table.insert(Table.tableSlowCompress,{t=debugprofilestop()-now,s=s,e=e});
	table.sort(Table.tableSlowCompress,function (a,b) return (a.t>b.t); end);
	table.remove(Table.tableSlowCompress,6);	-- keep list of five
	return tmp;
end

function Table.PrintSlowestCompress()
	print(Yellow.."List of slowest v3 compressions:");
	for i,d in ipairs(Table.tableSlowCompress) do print(i,Red..string.format("%.1f",d.t).." ms",Green..d.s,Yellow..d.e); end
end

function Table:DecompressV3(ref,cString,anon)
	ref=Table.v03.DecodeTable(cString);			-- store at given reference
	return ref;
end

-- applies correct compressor and handles cache
function Table:Write(who,entry,tData,base,section)
	local cache=self.Default[who].UseCache;
	if (not who) then who="Default"; end
	if (not base) then
		base=self.Default[who].Base[section];
	elseif (section and base~=self.Default[who].Base[section]) then		-- Only cache for base data
		cache=false
	end
	base=base.__DATA__;
	if (tData) then
		base[entry]="03"..self:CompressV3(tData,section,entry);		-- timing debug
	else base[entry]=nil; end
	if (cache) then
		if (base==self.Default[who].Base) then
			if (section) then
				if (not self.Default[who].Cache[section]) then self.Default[who].Cache[section]={}; end
				cache=self.Default[who].Cache[section];
			else cache=self.Default[who].Cache; end
			cache[entry]=tData;
	end end
	return true;
end

function Table:PullEntry(cString,CV)
	if (not CV) then CV=self.CV; end
	local stop1,stop2,stop3;
	if (cString:sub(1,1)==self[CV].sTable) then
		stop1=cString:find(self[CV].eTable..cString:sub(2,2),3,true);
		if (not stop1) then return nil; end	-- Missing data
		return cString:sub(1,2),cString:sub(3,stop1-1),cString:sub(stop1+2);
	end
	stop1=cString:find(self[CV].Entry,3,true); if (not stop1) then stop1=cString:len()+1; end	-- Virtual entry position
	stop2=cString:find(self[CV].sTable,3,true); if (not stop2) then stop2=cString:len()+1; end	-- Virtual entry position
	stop3=cString:find(self[CV].eTable,3,true); if (not stop3) then stop3=cString:len()+1; end	-- Virtual entry position
	if (stop1>stop2) then stop1=stop2; end
	if (stop1>stop3) then stop1=stop3; end
	return cString:sub(1,2),cString:sub(3,stop1-1),cString:sub(stop1);
end

function Table:DecompressV1(base,cString,anon)
	while(cString:len()>0) do
		local eType,eData=nil,nil;
		local dType,dData=nil,nil;
		if (anon) then
			dType,dData,cString=self:PullEntry(cString,1);
			dData=self:DecompressV1(base,dData);	-- dData is now without table-tags
		else
			eType,eData,cString=self:PullEntry(cString,1);		-- Entry name
			if (eType==self[1].Number) then eData=tonumber(eData); end
			dType,dData,cString=self:PullEntry(cString,1);		-- Entry data
			if (dType==self[1].Number) then dData=tonumber(dData);
			elseif (dType==self[1].Bool) then if (dData=="true") then dData=true; else dData=false; end
			elseif (dType==self[1].Nil) then dData=nil;
			elseif (dType:sub(1,1)==self[1].sTable) then
				base[eData]={};
				dData=self:DecompressV1(base[eData],dData);	-- dData is now without table-tags
		end end
		if (not base) then return dData; else if (anon) then base=dData; else base[eData]=dData; end end
	end
	return base;
end

function Table:DecompressV2(base,cString,anon)
	while(cString:len()>0) do
		local eType,eData=nil,nil;
		local dType,dData=nil,nil;
		if (anon) then
			dType,dData,cString=self:PullEntry(cString,2);
			dData=self:DecompressV2(base,dData);	-- dData is now without table-tags
		else
			eType,eData,cString=self:PullEntry(cString,2);		-- Entry name
			if (eType==self[2].Number) then eData=tonumber(eData); end
			dType,dData,cString=self:PullEntry(cString,2);		-- Entry data
			if (dType==self[2].Number) then dData=tonumber(dData);
			elseif (dType==self[2].Bool) then if (dData=="true") then dData=true; else dData=false; end
			elseif (dType==self[2].Nil) then dData=nil;
			elseif (dType:sub(1,1)==self[2].sTable) then
				base[eData]={};
				dData=self:DecompressV2(base[eData],dData);	-- dData is now without table-tags
		end end
		if (not base) then return dData; else if (anon) then base=dData; else base[eData]=dData; end end
	end
	return base;
end

-- Unpack an entry from meta and store it in real position unpacked for quick access. Import-data only.
function Table:Unpack(who,entry,base)
	if (not base) then return; end
	if (not who) then who="Default"; end								-- Using default settings
	local raw=base.__DATA__;
	if (not raw or not raw[entry]) then return; end
	if (type(raw[entry])~="string") then return; end
	rawset(base,entry,base[entry]);				-- store upacked by meta over packed
end

-- applies correct decompressor and handles cache
function Table:Read(who,entry,base,section)
	local cache=self.Default[who].UseCache;
	if (not who) then who="Default"; end												-- Using default settings
	if (not base) then base=self.Default[who].Base[section];
	elseif (section and base~=self.Default[who].Base[section]) then cache=false; end	-- Only cache for base data
	if (not base.__DATA__[entry]) then return nil; end									-- Entry does not exist
	base=base.__DATA__;								-- go raw (converted at log-in, so applies to all versions)
	if (type(base[entry])~="string") then												-- Not a packed entry
		if (type(base[entry])=="table") then return base[entry]; end					-- allow unpacked entry
		if (DropCount.Debug) then DropCount:Chat("Got "..type(base[entry]).." as entry"); end
		return nil;																		-- error in entry
	end
	local fnDecompress=self["DecompressV"..(base[entry]:sub(2,2) or "0")];				-- find decompressor
	if (not fnDecompress) then return nil; end											-- no decompressor for this data
	if (not cache) then																	-- not using cache, so decompress to scrap-book and return it
		wipe(self.Scrap);
		return copytable(fnDecompress(self,self.Scrap,base[entry]:sub(3),true));		-- Strip version
	end
	if (section) then																	-- using sections (like alliance/horde sub-table)
		if (not self.Default[who].Cache[section]) then self.Default[who].Cache[section]={}; end
		cache=self.Default[who].Cache[section];
	else cache=self.Default[who].Cache; end												-- no deeper levels
	if (not cache[entry]) then cache[entry]=fnDecompress(self,{},base[entry]:sub(3),true); end -- not decompressed yet, so decompress to cache
	return cache[entry];
end

function Table:PurgeCache(who,nocollect) wipe(self.Default[who].Cache); end

-- Drop grid
DropCount.Grid={};
function DropCount.Grid:Add(sguid,map,level,x,y)
	if (not sguid or sguid==0 or not dcdb.Count[sguid] or not dcdb.Count[sguid].Name) then return; end	-- no dude
	map=map or 0; level=level or 0; x=x or 0; y=y or 0;								-- make legal
	if (map==0) then map=DropCount:GetMapTable(); map,level=map.ID,map.Floor; end	-- none provided, use current
	if (x==0 or y==0) then x,y=GetPlayerMapPosition("player"); end					-- none provided, use current
	if (x==0 or y==0) then return; end												-- illegal position
	if (x<1 and y<1) then x=floor(x*100); y=floor(y*100); end						-- make 100-grid
	map=tostring(map).."_"..tostring(level);										-- map ID
	local buf=dcdb.Grid[map] or {};													-- get unpacked map data
	local loc=xy(x,y);																-- composite grid location
	if (not buf[loc]) then buf[loc]=tostring(sguid);	-- set sguid directly
	else
		if (buf[loc]:find(sguid)) then return; end		-- already there
		buf[loc]=buf[loc]..","..tostring(sguid);		-- no, so add it
	end
	LootCount_DropCount_GD.loc.x=0;		-- force visual update
	dcdb.Grid[map]=buf;					-- pack and store
end

-- toggle tooltipped item grid inclusion
function DropCountXML:ToggleGridFilter_Item()
	if (not GameTooltip:IsVisible()) then return; end
	local name,item=GameTooltip:GetItem(); item=DropCount:GetID(item); if (not item or not name) then return; end
	if (DropCountXML.AddUnitToGridFilter("Item",name,item)) then			-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
		print(Basic.."Item "..Yellow..name..Basic.." is now "..Green.."shown"..Basic.." on the worldmap.");
	else
		print(Basic.."Item "..Yellow..name..Basic.." has been "..Red.."removed"..Basic.." from the worldmap.");
	end
end

function DropCountXML:TableBytes(t)
	local bytes=40; for _,raw in rawpairs(t) do if (type(raw)=="table") then bytes=bytes+self:TableBytes(raw); else bytes=bytes+tostring(raw):len()+17; end end return bytes;
end

function DropCount:About()
	local sf=_G["DropCount_DataOptionsFrame_List"];
	DropCount_DataOptionsFrame_Info:SetJustifyH("LEFT");
	DropCount_DataOptionsFrame_Info:SetJustifyV("TOP");
	DropCount_DataOptionsFrame_Info:SetText(Basic.."The Evil Duck had a vision. He wanted to know. So he created DropCount. And he saw that it was good. So he built upon it, further adding data until the knowlewdge became near unbearable. But the knowledge brought new powers. He could take more. So he added more. And he shared with his fellow man. And they shared with him.\nAnd thus, a community for the good of all WoW was born.");
	sf.DMItemHeight=17; sf.DMSpacing=0; sf:DMClear();
	sf.defaultSort=nil;

	sf:DMAdd("About: Sharing data",DM_STATE_LIST,-1);
		sf:DMAdd("Plain and simple, DropCount benefits from players'",DM_STATE_LIST,0);
		sf:DMAdd("own data, and any help you can give is appreciated.",DM_STATE_LIST,0);
		sf:DMAdd("To make the process of sending your data as simple",DM_STATE_LIST,0);
		sf:DMAdd("as possible, two options are available:",DM_STATE_LIST,0);
		sf:DMAdd("1) By email to \""..Basic.."dropcount@ducklib.com|r\"",DM_STATE_LIST,0);
		sf:DMAdd("2) Visit \""..Basic.."ducklib.com|r\", select \"DropCount\" from",DM_STATE_LIST,0);
		sf:DMAdd("the menu, and upload your database from there.",DM_STATE_LIST,0);
		sf:DMAdd("- Both options will of course require you to locate",DM_STATE_LIST,0);
		sf:DMAdd("your database file. The most general method is to",DM_STATE_LIST,0);
		sf:DMAdd("search your computer for a file named",DM_STATE_LIST,0);
		sf:DMAdd("\"LootCount_DropCount.lua\". Several files will",DM_STATE_LIST,0);
		sf:DMAdd("be found, and the database is the largest one.",DM_STATE_LIST,0);
		sf:DMAdd("- Some players like to contribute on a regular",DM_STATE_LIST,0);
		sf:DMAdd("basis. To submit data once per month is enough.",DM_STATE_LIST,0);
		sf:DMAdd("Any more often serves little purpose.",DM_STATE_LIST,0);
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd("About: Memory management",DM_STATE_LIST,-1);
		sf:DMAdd("DropCount maintains its huge amount of data by",DM_STATE_LIST,0);
		sf:DMAdd("compressing unused data. You will see that DropCount",DM_STATE_LIST,0);
		sf:DMAdd("will typically orbit the 20MB area all depending on",DM_STATE_LIST,0);
		sf:DMAdd("what you are doing today.",DM_STATE_LIST,0);
		sf:DMAdd("This number will be quite a bit bigger the first few",DM_STATE_LIST,0);
		sf:DMAdd("minutes after logging in, and a whole lot bigger when",DM_STATE_LIST,0);
		sf:DMAdd("you have installed a new version until data merging",DM_STATE_LIST,0);
		sf:DMAdd("has finished.",DM_STATE_LIST,0);
		sf:DMAdd("Some players sees this as too much and has asked for",DM_STATE_LIST,0);
		sf:DMAdd("a leaner version. You can select what data you want to",DM_STATE_LIST,0);
		sf:DMAdd("use, but there is a give and take in it; If you want",DM_STATE_LIST,0);
		sf:DMAdd("data, it will require storage. It's as simple as that. But",DM_STATE_LIST,0);
		sf:DMAdd("if you want a rule of thumb of DropCount's memory",DM_STATE_LIST,0);
		sf:DMAdd("usage, it is that while you play (lots of stuff unpacked)",DM_STATE_LIST,0);
		sf:DMAdd("DropCount compression removes about 80% memory",DM_STATE_LIST,0);
		sf:DMAdd("usage.",DM_STATE_LIST,0);
		sf:DMAdd("Yes, it would shoot past 100MB in a heartbeat without",DM_STATE_LIST,0);
		sf:DMAdd("compression.",DM_STATE_LIST,0);
		sf:DMAdd("There's a lot of data.",DM_STATE_LIST,0);
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd("About: System load",DM_STATE_LIST,-1);
		sf:DMAdd("DropCount has two main modes of operation:",DM_STATE_LIST,0);
		sf:DMAdd("1) Day-to-day usage",DM_STATE_LIST,0);
		sf:DMAdd("2) Fresh install and upgrades",DM_STATE_LIST,0);
		sf:DMAdd("- In normal day-to-day usage, DropCount will stay",DM_STATE_LIST,0);
		sf:DMAdd("nicely in the background, and you should never notice",DM_STATE_LIST,0);
		sf:DMAdd("it in terms of system load. It blends quite nicely in",DM_STATE_LIST,0);
		sf:DMAdd("with any other addon, and will yield computing power",DM_STATE_LIST,0);
		sf:DMAdd("if the need should arise.",DM_STATE_LIST,0);
		sf:DMAdd("- With fresh installs and upgrades, the new DropCount",DM_STATE_LIST,0);
		sf:DMAdd("comes with a brand new database. This new data will",DM_STATE_LIST,0);
		sf:DMAdd("be merged with the data you already have, and this is",DM_STATE_LIST,0);
		sf:DMAdd("definitely not a straight forward copy or overlay.",DM_STATE_LIST,0);
		sf:DMAdd("Many calculations and considerations needs to be",DM_STATE_LIST,0);
		sf:DMAdd("made, and lots of data needs constant crosschecking.",DM_STATE_LIST,0);
		sf:DMAdd("Above all, this takes time. Lots of time.",DM_STATE_LIST,0);
		sf:DMAdd("I'll not bore you with the math, so suffice to say",DM_STATE_LIST,0);
		sf:DMAdd("DropCount will drop your fps to about 30 while",DM_STATE_LIST,0);
		sf:DMAdd("performing a database merge. This is considered as",DM_STATE_LIST,0);
		sf:DMAdd("playable for normal tasks.",DM_STATE_LIST,0);
		sf:DMAdd("However - if you enter combat, DropCount will",DM_STATE_LIST,0);
		sf:DMAdd("relinquish any and all \"excess\" CPU usage. You'll get",DM_STATE_LIST,0);
		sf:DMAdd("your normal fps back instantly.",DM_STATE_LIST,0);

	_G["DropCount_DataOptionsFrame_TotalBytes"]:SetText("");
	DropCount_DataOptionsFrame:Show();
end

function DropCountXML:ShowDataOptionsFrame()
	local sf=_G["DropCount_DataOptionsFrame_List"];
	DropCount_DataOptionsFrame_Info:SetText(Basic.."Select the components you wish to use from the below list.\n\n"..Red.."NOTE: Data you have gathered for any removed sections will be permanently lost.\n\n"..White.."NB: \""..lBlue.."Blue"..White.."\" entries = checked.");
	DropCount_DataOptionsFrame_Info:SetJustifyH("LEFT");
	DropCount_DataOptionsFrame_Info:SetJustifyV("TOP");
	DropCount_DataOptionsFrame:Show();
	sf.DMItemHeight=32;					-- bigger icon sizes
	sf.DMSpacing=4;						-- give it some air
	sf:DMClear();
	sf.defaultSort=true;

	local bytes,total=0,0;
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowMobsAndDrops) then state=DM_STATE_UNCHECKEDinc; end	-- unchecked
		bytes=self:TableBytes(dcdb.Count)+self:TableBytes(dcdb.Item); total=total+bytes;
		entry=sf:DMAddDouble("Item drop-rates from mobs",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Drop rates","Which creature drops what and how often.","Usage: Everywhere."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowMobsAndDrops", nousebase={ Count=true, Item=true }, };
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowQuests) then state=DM_STATE_UNCHECKEDinc; end			-- unchecked
		bytes=self:TableBytes(dcdb.Quest); total=total+bytes;
		entry=sf:DMAddDouble("Quest givers",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Quests","Quest givers, the quests they have and where they are located.","Usage: Worldmap, minimap, world."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowQuests", nousesub={ Quest=true }, };		-- sub
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowVendors) then state=DM_STATE_UNCHECKEDinc; end
		bytes=self:TableBytes(dcdb.Vendor); total=total+bytes;
		entry=sf:DMAddDouble("Vendors",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Vendors","Their merchandise and locations.","Usage: Everywhere"};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowVendors", nousebase={ Vendor=true }, };
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowBooks) then state=DM_STATE_UNCHECKEDinc; end			-- unchecked
		bytes=self:TableBytes(dcdb.Book); total=total+bytes;
		entry=sf:DMAddDouble("Books",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Books","Name and locations.","Usage: Worldmap, minimap."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowBooks", nousebase={ Book=true }, };
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowTrainers) then state=DM_STATE_UNCHECKEDinc; end		-- unchecked
		bytes=self:TableBytes(dcdb.Trainer); total=total+bytes;
		entry=sf:DMAddDouble("Profession trainers",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Trainers","Their professions and locations.","Usage: Worldmap, minimap."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowTrainers", nousesub={ Trainer=true }, };	-- sub
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowForges) then state=DM_STATE_UNCHECKEDinc; end			-- unchecked
		bytes=self:TableBytes(dcdb.Forge); total=total+bytes;
		entry=sf:DMAddDouble("Forges",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Forge","Their locations.","Usage: Worldmap, minimap."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowForges", nousebase={ Forge=true }, };
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowGrid) then state=DM_STATE_UNCHECKEDinc; end			-- unchecked
		bytes=self:TableBytes(dcdb.Grid); total=total+bytes;
		entry=sf:DMAddDouble("Creature and item locations",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Locations","Where creatures are located and where items drop. Also tracks rare creatures.","Usage: Worldmap."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowGrid", nousebase={ Grid=true }, };
	state=DM_STATE_CHECKEDinc; if (dcdb.DontFollowGather) then state=DM_STATE_UNCHECKEDinc; end			-- unchecked
		bytes=self:TableBytes(dcdb.Gather); total=total+bytes;
		entry=sf:DMAddDouble("Gathering locations",string.format("Current: %.02fMB",bytes/(1024*1024)),state,0,"");
		entry.Tooltip={"Gathering professions","Locations and loot for gathering professions.","Usage: Worldmap, minimap."};
		entry.DB={ Negative=true, Base="DB", Setting="DontFollowGather", nousesub={ Gather=true }, };

	_G["DropCount_DataOptionsFrame_TotalBytes"]:SetText(string.format("Current compressed data storage: %.02fMB",total/(1024*1024)));
end

function DropCountXML:Filter_Search()
	-- search items and mobs only
	DropCount.Search:Do(DropCount_GridFilterFrame_FindText:GetText(),nil,nil,nil,true,true,nil);
	local menu=DMMenuCreate(DropCount_GridFilterFrame_FindText);
	for section,sTable in pairs(DropCount.Search._result) do
		menu:Add(section,nil,DDT_TEXT);
		for _,entry in pairs(sTable) do
			if (not entry.Icon) then
				-- insert some portrait for mob if possible
			end
			menu:Add(	entry.Entry,			-- text
						function () DropCountXML.AddUnitToGridFilter(section,entry.Entry,entry.DB.Entry,entry.Icon) end,	-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
						nil,nil,nil,nil,nil,	-- mode,tooltip,checked,inactive,indent
						entry.Icon);			-- icon
	end end
	menu:Show();
end

-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
function DropCountXML.AddUnitToGridFilter(section,name,code,icon)
	if (not LootCount_DropCount_Character.Sheet[section]) then LootCount_DropCount_Character.Sheet[section]={}; end
	if (LootCount_DropCount_Character.Sheet[section][code]) then LootCount_DropCount_Character.Sheet[section][code]=nil;
	else LootCount_DropCount_Character.Sheet[section][code]={icon=icon,name=name}; end
	-- redraw filter list
	DropCount_GridFilterFrame_Filters:DMClear();
	if (not DropCount_Local_Code_Enabled) then dcdb.GridWorldmap=nil; end
	for section,st in pairs(LootCount_DropCount_Character.Sheet) do
		DropCount_GridFilterFrame_Filters:DMAdd(section,nil,-1);
		for code,entry in pairs(st) do
			DropCount_GridFilterFrame_Filters:DMAdd(entry.name,nil,nil,entry.icon);
			dcdb.GridWorldmap=true;
	end end
	return (LootCount_DropCount_Character.Sheet[section][code]~=nil) or nil;
end

-- database meta
dropcountnonfailtable={
	__index = function (t,k)
		if (not rawget(t,k)) then rawset(t,k,{}); InsertDropcountDB(rawget(t,k),k); end
		return rawget(t,k);
	end,
}

dropcountdatabasemetacode={
	__index = function (t,k)
		if (k==nil) then return nil; end
		if (not rawget(t,"__DATA__")) then return nil; end
		if (not rawget(rawget(t,"__DATA__"),k)) then						-- don't have this item key
			if (rawget(rawget(t,"__METADATA__"),"cache")=="Item") then		-- the question is an item
				if (k:find("item:",1,true)) then return nil; end			-- query is item code, so don't have it
				-- traverse for name
				for item,iRaw in rawpairs(t) do				-- traverse without unpacking
					if (iRaw:find(k,1,true)) then			-- textual search
						local thisItem=t[item];				-- proper read -> recursive metatable
						if (thisItem.Item==k) then			-- found item by name
							return thisItem;				-- return unpacked data
			end end end end
			return nil;
		end
		return Table:Read(DM_WHO,k,t,t.__METADATA__.cache);
	end,
	__newindex = function (t,k,v)
		if (not rawget(t,"__METADATA__")) then return nil; end
		if (rawget(rawget(t,"__METADATA__"),"nouse")~=nil) then return nil; end						-- section not activated
		if (rawget(rawget(t,"__METADATA__"),"cache")=="Item" and not k:find("item:",1,true)) then	-- key is item but not item code
			-- traverse for name
			for item,iRaw in rawpairs(t) do				-- traverse without unpacking
				if (iRaw:find(k,1,true)) then			-- textual search
					local thisItem=t[item];				-- proper read -> recursive metatable
					if (thisItem.Item==k) then			-- found item by name
						k=item; break;					-- set true key and proceed as normal
			end end end
			if (not k:find("item:",1,true)) then return nil; end	-- key is still not item code
		end
		return Table:Write(DM_WHO,k,v,t,t.__METADATA__.cache);
	end,
	__tostring = function (t)
		return "DropCount "..t.__METADATA__.cache.." database";
	end,
-- metamethod "__len" cannot be redefined.
}

function InsertDropcountDB(db,cache)
	if (not db) then return nil; end
	setmetatable(db,nil);			-- remove whatever is there
	-- old section for conversion (it assumes old data is compressed already)
	if (not db.__METADATA__) then
		db.__DATA__={};
		db.__METADATA__= { cache=cache };
		for k,v in pairs(db) do
			if (k~="__DATA__" and k~="__METADATA__") then	-- not one of the new ones
				db.__DATA__[k]=v;							-- so set it
				db[k]=nil;									-- remove old (hash will retain for pairs function)
		end end
	else db.__METADATA__.cache=cache; end
	return setmetatable(db,dropcountdatabasemetacode);
end

function CreateDropcountDB(db)
	if (db~=dcdb) then setmetatable(db,dropcountnonfailtable); end	-- not for local database
	-- convert books to packed data
	if (db.Book and (not db.Book.__METADATA__ or not db.Book.__DATA__)) then
		local buf=copytable(db.Book); wipe(db.Book);			-- make copy of everything and wipe
		InsertDropcountDB(db.Book,"Book");		-- set up as new type
		for book,bdata in pairs(buf) do db.Book[book]=bdata; end	-- spew and pack by metatable
		wipe(buf);								-- be nice to memory
	end
	if (not db.Book) then db.Book={}; end InsertDropcountDB(db.Book,"Book");
	if (not db.Vendor) then db.Vendor={}; end InsertDropcountDB(db.Vendor,"Vendor");
	if (not db.Grid) then db.Grid={}; else end InsertDropcountDB(db.Grid,"Grid");
	if (not db.Item) then db.Item={}; end InsertDropcountDB(db.Item,"Item");
	if (not db.Count) then db.Count={}; end InsertDropcountDB(db.Count,"Count");
	if (not db.Forge) then db.Forge={}; end InsertDropcountDB(db.Forge,"Forge");
	-- trainer > faction > trainer
	if (not db.Trainer) then db.Trainer={}; end
	setmetatable(db.Trainer,dropcountnonfailtable);
	for faction in pairs(db.Trainer) do InsertDropcountDB(db.Trainer[faction],"Trainer"); end
	-- quest > faction > quest giver
	if (not db.Quest) then db.Quest={}; end
	setmetatable(db.Quest,dropcountnonfailtable);
	for faction in pairs(db.Quest) do InsertDropcountDB(db.Quest[faction],"Quest"); end
	-- gather > GatherTYPE > zone
	if (not db.Gather) then db.Gather={}; end
	setmetatable(db.Gather,dropcountnonfailtable);
	for gather in pairs(db.Gather) do InsertDropcountDB(db.Gather[gather],gather); end	-- both gather types have separate cache
end

function dcdbpairs(t)
	if (not rawget(t,"__DATA__")) then return pairs(t); end
	return function (t,k)
		local kv=nil;
		repeat k=next(t.__DATA__,k); if (k) then kv=t[k]; end until (not k or kv);	-- invoke metatable for data
		return k,kv;
	end,t,nil;
end
function rawpairs(t)
	if (not rawget(t,"__DATA__")) then return pairs(t); end
	return function (t,k)
		local kv=nil;
		repeat k=next(t.__DATA__,k); if (k) then kv=t.__DATA__[k]; end until (not k or kv);	-- Don't invoke metatable for data
		return k,kv;
	end,t,nil;
end


-- Crawler support
function DropCount.Crawler.GenerateWN(data)
	local pageTOP=[[<wn><body><h1 align="center">]]..LOOTCOUNT_DROPCOUNT_VERSIONTEXT..[[</h1><h2 align="center">WoWnet interface</h2>]];
	local pageBOT=[[</body></wn>]];
	local pageSRC=[[
<set form="DropCount_Search"/>
  <text pad="25">Search DropCount:</text>
  <edit id="EDIT_search" glue="LEFT" pad="5"/>
  <button width="200" send="form">Search</button>
<set form=""/>]]
	local pageMSG=[[<text pad="25">%s</text>]];
	if (not data or data=="" or data=="search") then
		return pageTOP..pageSRC..pageBOT;
	end
	if (data:find("search:",1,true)==1) then
		data=data:sub(8);
		data=strtrim(data);
		if (data=="") then return pageTOP..string.format(pageMSG,"No search-phrase specified")..pageSRC..pageBOT; end
		-- do the search
		DropCount.Search:Do(data,true,true,true,true,true,true);
		-- build the WN code
		local page=pageTOP..pageSRC;
		for section,sTable in pairs(DropCount.Search._result) do
			page=page..[[<h2 pad="10">]]..section..[[</h2>]];
			for _,entry in pairs(sTable) do
				if (entry.Icon) then
					page=page..[[<img width="14" height="14" pad="10">]]..entry.Icon..[[</img>]];
					page=page..[[<text glue="left" pad="3">]]..entry.Entry..[[</text>]];
				else
					page=page..[[<text pad="27">]]..entry.Entry..[[</text>]];
				end
			end
		end
		return page..pageBOT;
	end
	return pageTOP..string.format(pageMSG,"Unknown DropCount request")..pageSRC..pageBOT;
end

DropCount.Crawler._Description="DropCount remote: Allows users of Crawler to search your DropCount database.";
