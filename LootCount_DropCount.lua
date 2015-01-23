--[[****************************************************************
	LootCount DropCount v2.00

	Author: Evil Duck
	****************************************************************

	For the game World of Warcraft
	Stand-alone addon, and plug-in for the add-on LootCount.

	****************************************************************]]

-- 2.00 further language independency, some code compacting, some load
--      improvements, unknown items in bags added to DB, filtering
--      of vendors by item, better search results for gather nodes, FAQ,
--      mouse-over creature/item grid filter, changed minimap icon strata,
--		changed location format, vendor filter by special items, improved
--		filtering accessibility, mapping icons rewritten for speed and memory
--		requirements, WoW6 GUID changes, gathering coverage, item monitors,
--		precache quest item links at quest dialog, auto-assigned monitors
-- 1.50r1 added datatype checking for storage version conversion
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
BINDING_NAME_DC_TOGGLEGRIDFILTER = "Track item or creature on worldmap (toggle)";

local _;
local VERSIONt="2.00";		-- current version text
local VERSIONn=tonumber(VERSIONt);
local VERSIONimportdebug=7.1501;		-- set to data-version to circumvent data delete on login. MEMORY HOG! debugging purposes ONLY!
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
	TooltipClass={},			-- extra functionality for tooltips
	Event={},					-- event-related functions
	OnUpdate={},				-- functions for OnUpdate
	Hook={},					-- container for hooks and related functionality
	Map={},						-- map functionality
	Crawler={},					-- crawler support
	MT={						-- everything multitasking
		Icons={},				-- icon hadling
		DB={ Maintenance={}, },	-- database handling
		Quest={},				-- everything quest
		Search={ _result={}, },	-- everything search
	},
	GUI={},						-- everything data GUI
	Quest={},					-- everything quest
	Target={					-- everything about targeting
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
		CleanImport={ Cleaned=nil, Okay=0, Deleted=0, },
		NotifyQuestItem={},
		RevLookup={},
		Unretrievable={},
		MaxSessionValue={},
	},
	Cache={						-- everything cache
		Timer=6,
		Retries=0,
		CachedConvertItems=0,	-- Items requested from server when converting DB
	},
	Timer={						-- "everything" timer
		VendorDelay=-1,
		StartupDelay=5,
		PrevQuests=-1,
	},
	DB={ },						-- everything DB (converters, ++)
	Painter={ x=0,y=0, maps={}, },		-- for the artistic gatherer
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
	LOOTEDAGE=1200,			-- how long to remember looting a mob
	PERMANENTITEM=-1,		-- permanent vendor item
	UNKNOWNCOUNT=-2,		-- unknown vendor item count (not to be confused with limited supply)
	LISTLENGTH=25,			-- maximum number of creatures in a tooltip
	KILLS_UNRELIABLE=10,	-- lowest useable kill count
	KILLS_RELIABLE=50,		-- lowest trustworthy kill count
	RESCANQUESTS=1.5,		-- delay for scanning player quest list
	QUEUETIME=900,			-- how long to remember a killed mob
	QUESTID=nil,			-- common ID for items that drops conditionally
	CACHESPEED=1/3,			-- tick for item cache from server
	CACHEMAXRETRIES=10,		-- max retries for a single item
	QUESTRATIO=-1,			-- drop ratio reported for quest items
	PROFESSIONS={},			-- numeric list of all possible professions
	PROFICON={},			-- same-numbered profession icons
--	ZONES=nil,
	MYFACTION=nil,			-- player's faction
	QUEST_UNKNOWN=0,		-- status of this quest is: unknown
	QUEST_DONE=1,			-- status of this quest is: done (turned in)
	QUEST_STARTED=2,		-- status of this quest is: started (picked up)
	QUEST_NOTSTARTED=3,		-- status of this quest is: not started (not picked up)
	WM_W=100, WMSQ_W=1,		-- world map width in pixels, sheet square width in pixels
	WM_H=100, WMSQ_H=1,		-- world map height in pixels, sheet square height in pixels
	GUIREFRESH=(5*60),		-- slowest refresh rate for GUI monitors
};
local nagged=nil;
local Basic="|cFF00FFFF";
local Green="|cFF00FF00";
local Red="|cFFFF0000";
local Blue="|cFF0000FF";		-- blue
local lBlue="|cFF6060FF";		-- light blue
local hBlue="|cFEA0A0FF";		-- highlight
local Yellow="|cFFFFFF00";
local dYellow="|cFF808000";
local White="|cFFFFFFFF";
local Purple="|cFFFF00FF";
local lPurple="|cFFFF80FF";
local dBrown="|cFF804C33";
local Gray="|cFF909090";
local Orange="|cFFE04224";

-- Table handling
local Table={
	v03={},
	LastPackerVersion="03",
	tableSlowCompress={},
	Scrap={},
	Cache={},
};
local mmicons,mmlist,wmicons,wmlist={},{},{},{};

-- Backward compression compatibility
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

local gui={};				-- GUI data viewers
local guiitems={};			-- GUI items to consider
local guiitemswork={};		-- GUI items workbench

-- Saved per character
LootCount_DropCount_Character={ ShowZone=true, };
local dccs;
local ttLCFont,ttLCSize,ttLCFlags;

-- Global save
LootCount_DropCount_DB={};
local dcdb;
LootCount_DropCount_Maps={}
local dcmaps;
LootCount_DropCount_NoQuest = {
	[10593] = true, [2799] = true, [2744] = true, [8705] = true, [21377] = true, [35188] = true, [8392] = true, [16656] = true,
	[11512] = true, [8394] = true, [8391] = true, [8393] = true, [8396] = true, [2738] = true, [5113] = true, [38551] = true,
	[8483] = true, [22526] = true, [22527] = true, [12841] = true, [22529] = true, [28452] = true, [29209] = true, [21383] = true,
	[22528] = true, [10450] = true, [25433] = true, [18945] = true, [2732] = true, [2740] = true, [5117] = true, [2748] = true,
	[4582] = true, [19259] = true, [2725] = true, [5134] = true, [24449] = true, [20404] = true, [2749] = true, [29426] = true,
	[11407] = true, [30810] = true, [31812] = true, [11018] = true, [2734] = true, [2742] = true, [2750] = true, [30809] = true,
	[29739] = true, [29740] = true, [11754] = true, [29425] = true, [2735] = true, [18944] = true, [2751] = true, [2730] = true,
	[12840] = true, [24291] = true, [24401] = true, [25719] = true, [24368] = true,
}

local maskQITEM=QUEST_ITEMS_NEEDED;	-- "%2$d/%3$d %1$s"
maskQITEM=maskQITEM:gsub("%d%$","");
maskQITEM=maskQITEM:gsub("%%s","(%.+)");
maskQITEM=maskQITEM:gsub("%%d","(%%d+)");
maskQITEM=maskQITEM:gsub("/","%%s*/%%s*");
maskQITEM="^"..maskQITEM.."$";
local maskQNPC=QUEST_MONSTERS_KILLED;	-- "%2$d/%3$d %1$s slain"
maskQNPC=maskQNPC:gsub("%d%$","");
maskQNPC=maskQNPC:gsub("%%s","(%.+)");
maskQNPC=maskQNPC:gsub("%%d","(%%d+)");
maskQNPC=maskQNPC:gsub("/","%%s*/%%s*");
maskQNPC="^"..maskQNPC.."$";

local Astrolabe = DongleStub("Astrolabe-1.0");	-- reference to the Astrolabe mapping library
local function xy(x,y) if (not y) then x=tonumber(x); return floor(x/100),x%100; end return (x*100)+y; end
local function copytable(t,new)		-- Safe table-copy with optional merge (equal entries will be overwritten, arg1 has pri, arg2 destroyed)
	if (not t and not new) then return nil; end
	t=t or {}; new=new or {}; for i,v in rawpairs(t) do if (type(v)=="table") then new[i]=copytable(v,new[i]); else new[i]=v; end end
	return new;
end
local function chat(...)
	if (not DEFAULT_CHAT_FRAME) then return; end
	local count=select("#",...);
	local text="";
	local arg;
	local i=1;
	while(i<=count) do
		arg=select(i,...);
		text=text..tostring(arg).." ";
		i=i+1;
	end
	DEFAULT_CHAT_FRAME:AddMessage(text);
end
--local function print(...)
local function _debug(...)
	if (not DropCount.Debug) then return; end
	if (not ChatFrame3) then _G["print"]("dbg:",...); return; end
	local count=select("#",...);
	local text="dbg: ";
	local arg;
	local i=1;
	while(i<=count) do
		arg=select(i,...);
		text=text..tostring(arg).." ";
		i=i+1;
	end
	ChatFrame3:AddMessage(strtrim(text));
end
local function IsEqual(A,B)
	if (type(A)=="table") then
		for k,v in pairs(A) do if (B[k]~=v) then return nil; end end
		for k,v in pairs(B) do if (A[k]~=v) then return nil; end end
		return true;
	end
	for item in A:gmatch("(item:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+)") do if (not B:find(item,1,true)) then return nil; end end
	for item in B:gmatch("(item:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+)") do if (not A:find(item,1,true)) then return nil; end end
	return true;
end

local function map_set(m,f,s)
	if (type(m)=="string") then							-- convert text zone to mapID
		local zone,subzone=m:match("^(.+) %- (.+)$");
		if (zone) then m=zone; end s=subzone or ""; m=dcmaps(m);
		if (m=="") then return "0_0_"; end				-- zone not found
		f=0;											-- source was text name, so level/floor was not provided
	end
	if (not m or not f) then							-- missing map data
		SetMapToCurrentZone();
		m,f=GetCurrentMapAreaID(),GetCurrentMapDungeonLevel();	-- get the map location (not player, but should be okay anyway)
		s=GetSubZoneText();										-- grab current sub-zone
		-- Update internal mapID register for this locale
		if (not dcmaps[GetLocale()]) then dcmaps[GetLocale()]={}; end
		if (not dcmaps[GetLocale()][m]) then dcmaps[GetLocale()][m]=GetRealZoneText() or " "; end
	end
	return tostring(m).."_"..tostring(f).."_"..tostring(s or "");		-- we don't want sub-zone "nil"
end
local function location_set(x,y,m,f,s)
	if ((x or 0)==0 or (y or 0)==0) then x,y=DropCount:GetPlayerPosition(); end return tostring(x).."_"..tostring(y).."_"..map_set(m,f,s); end
local function map_get(s)
	local map,level,subzone=tostring(s):match("^(%d+)_(%d+)_(.*)$"); return tonumber(map or 0),tonumber(level or 0),subzone or ""; end
local function location_get(s)
	local x,y,map,level,subzone=tostring(s):match("^([%d%.]+)_([%d%.]+)_(%d+)_(%d+)_(.*)$");
	return tonumber(x or 0),tonumber(y or 0),tonumber(map or 0),tonumber(level or 0),subzone or ""; end
local function MapPlusNumber_Code(m,f,s,n)
	return map_set(m,f,s).."_"..tostring(n or 0); end
local function MapPlusNumber_Decode(m)
	if (not m) then return nil; end local f,s,n; m,n=tostring(m):match("^(.+)_(%d+)$"); m,f,s=map_get(m); return m,f,s,tonumber(n); end
local function Map_Code(m,f,s)
	return map_set(m,f,s); end
local function Map_Decode(m)
	if (not m) then return nil; end local f,s; m,f,s=map_get(m); return m,f,s; end
local function Location_Code(x,y,m,f,s)
	return location_set(x,y,m,f,s); end
local function Location_Decode(loc)
	if (not loc) then return nil; end local x,y,m,f,s=location_get(loc); return x,y,m,f,s; end	-- shortcut will remove all but one return value
local function MapTest(m,f)
	return "_"..m.."_"..f.."_"; end
local function FormatZone(loc,long,pos)
	if (not loc) then loc=Location_Code(); end local _x,_y,_m,_f,_s=Location_Decode(loc); loc=dcmaps(_m);
	if (long and (_s or "")~="") then loc=loc.." - ".._s; end if (pos) then return loc.." ("..floor(_x)..","..floor(_y)..")"; end
	return loc; end
local function FormatBest(loc)
	if (not loc) then return nil,nil; end local _m,_f,_s,_n=MapPlusNumber_Decode(loc); loc=dcmaps(_m);
	if ((_s or "")~="") then loc=loc.." - ".._s; end return loc,_n; end
local function CurrentMap()
	local m,f,_,_=Astrolabe:GetCurrentPlayerPosition(); m=m or 0; f=f or 0; return m,f,tostring(m).."_"..tostring(f); end
local function Highlight(text,highlight,terminate)
	if (not highlight) then return text; end					-- nothing to highlight
	if (not terminate) then terminate="|r"; end					-- no termination, use regular
	local start,stop=text:lower():find(highlight:lower());		-- no-caps indices search
	if (not start) then return text; end						-- not found, so no highlight
	local sf,sm,se="","","";									-- all initially empty
	if (start>1) then sf=text:sub(1,start-1); end				-- grab beginning
	sm=text:sub(start,stop);									-- grab middle (in correct caps)
	se=text:sub(stop+1);										-- grab ending
	return sf.."|cFFFFFF00"..sm..terminate..se;					-- return highlighted text
end
local function addclass(class,container)
	for k,v in pairs(class) do container[k]=v; end				-- add class to container
end
local function getid(link,yield)	-- Return the common DuckMod ID
	if (type(link)~="string") then
		if (type(link)~="number") then return nil,nil; end
		_,link=GetItemInfo(link);
		return getid(link,yield);
	elseif (DropCount.Tracker.RevLookup[link]) then				-- provided name has been previously found
		_debug("Reverse look-up:",link);
		link=DropCount.Tracker.RevLookup[link];					-- use it
	elseif (not link:find("item:",1,true)) then					-- unknown name provided
		for item,iRaw in rawpairs(dcdb.Item) do					-- traverse without unpacking
--			if (yield) then yield(); end
			if (yield) then yield(true); end
			if (iRaw:find(link,1,true)) then					-- textual search
				local thisItem=dcdb.Item[item];					-- proper read -> recursive metatable
				if (thisItem.Item==link) then					-- found item by name
					DropCount.Tracker.RevLookup[link]=item;		-- save provided name (link) with its found link (item)
					link=item; break;							-- set true key and proceed as normal
		end end end
	end
--	local itemID,i1,i2,i3,i4,i5,i6=link:match("|Hitem:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
--	if (not i6) then itemID,i1,i2,i3,i4,i5,i6=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)"); end
	local itemID,i1,i2,i3,i4,i5,i6=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)");
	if (not i6) then return; end
	return "item:"..itemID..":"..i1..":"..i2..":"..i3..":"..i4..":"..i5..":"..i6,tonumber(itemID);
end


-- Set up for handling
function DropCountXML:OnLoad(frame)
	frame:RegisterEvent("ADDON_LOADED");
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED");
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");
	frame:RegisterEvent("LOOT_OPENED");
	frame:RegisterEvent("LOOT_CLOSED");
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
	frame:RegisterEvent("TRADE_SKILL_SHOW");
	frame:RegisterEvent("TRADE_SKILL_CLOSE");
	frame:RegisterEvent("CHAT_MSG_SKILL");
	frame:RegisterEvent("TRADE_SKILL_UPDATE");

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
	CONST.PROFESSIONS[15],_,CONST.PROFICON[15]=GetSpellInfo(18248);	-- Fishing
	CONST.PROFESSIONS[16],_,CONST.PROFICON[16]=GetSpellInfo(2550);	-- Cooking
	CONST.PROFESSIONS[17],_,CONST.PROFICON[17]=GetSpellInfo(27028);	-- First Aid
	CONST.PROFESSIONS[18],_,CONST.PROFICON[18]=GetSpellInfo(78670);	-- Archaeology
	DropCountXML.ForgeIcon=CONST.PROFICON[5];

	local text=string.format(ERR_SKILL_UP_SI,"PROFTEXT",12345);			-- string,integer
	local s1,e1=text:find("PROFTEXT",1,true);
	local s2,e2=text:find("12345",1,true);
	local _pre,_mid,_post="","","";
	if (s1>1) then _pre=text:sub(1,s1-1); end
	if (e1<(s2-2)) then _mid=text:sub(e1+1,s2-1); end
	_post=text:sub(e2+1); if (not _post) then _post=""; end
	DropCount.skillMatch=_pre.."(.+)".._mid.."(%d+)".._post;

	StaticPopupDialogs["LCDC_D_NOTIFICATION"] = {
		text="Text",button1="Close",timeout=0,whileDead=1,hideOnEscape=1,
		OnAccept = function() StaticPopup_Hide ("LCDC_D_NOTIFICATION"); DropCount:NewVersion(); end, };
	StaticPopupDialogs["LCDC_D_NEWVERSIONINSTALLED"] = {
		text="Text",button1="Close",timeout=0,whileDead=1,hideOnEscape=1,
		OnAccept = function() StaticPopup_Hide("LCDC_D_NEWVERSIONINSTALLED"); end, };

	SlashCmdList.DROPCOUNT=function(msg) DropCountXML.Slasher(msg) end;
	DropCountXML:OnTooltipLoad(GameTooltip);

	if (not MT.TheFrameWorldMap) then
		MT.TheFrameWorldMap=CreateFrame("Frame","DropCount-MT-WM-Messager",WorldMapDetailFrame);
		if (not MT.TheFrameWorldMap) then chat(Red,"Critical: Could not create a DuckMod frame (2)"); return; end
		CONST.WM_W=WorldMapDetailFrame:GetWidth(); CONST.WMSQ_W=CONST.WM_W/100;
		CONST.WM_H=WorldMapDetailFrame:GetHeight(); CONST.WMSQ_H=CONST.WM_H/100;
	end
--	MT.TheFrameWorldMap:SetScript("OnUpdate",DropCountXML.HeartBeat);
	MT.TheFrameWorldMap:SetScript("OnUpdate",DropCountXML.OnUpdate);
end

function DropCountXML.Slasher(msg)
	msg=msg or "";
	local fullmsg=msg;
	if (msg:len()>0) then msg=msg:lower(); end
	if (msg=="debug") then DropCount.Debug=not DropCount.Debug or nil; chat(Basic.."DropCount debug: |r"..((DropCount.Debug and "ON") or "OFF")); return;
	elseif (msg=="slow") then Table.PrintSlowestCompress(); return;
	elseif (msg=="dbmobs") then DropCount:PrintMobsStatus(); return;
	elseif (msg=="loc") then local X,Y=DropCount:GetPlayerPosition(); chat("X,Y: "..X..","..Y); return;
	end
	if (DropCount_Local_Code_Enabled) then
		if (msg=="ripper") then MT:Run("RIPPER",Ripper_MT_Run,MT.YieldExt); return;		-- run external code
		-- export data for deployment
		elseif (msg=="export") then MT:Run("RIPPER",Ripper_MT_Export,MT.YieldExt,MapPlusNumber_Code,MapPlusNumber_Decode); return;
		elseif (msg=="addforge" and DropCount.Debug) then DropCount:SaveForge(); return;
		end
	end

	if (msg=="vimake") then
		MT:Run("dblv",DropCount.MT.dbVendorItems_Create,DropCount.MT,dcdb); return;
	end

	chat(Basic..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."|r");
	if (DropCount.PerformingAction) then chat(hBlue.."Currently: "..DropCount.PerformingAction);
	elseif (msg=="?" or not DropCount.Debug) then DropCount:CleanDB(); return; end		-- don't do this while action is being performed
	if (not DropCount.Debug) then return; end
	chat(Green..SLASH_DROPCOUNT2.." ?|r -> Statistics");
	chat(hBlue..SLASH_DROPCOUNT2.." dbmobs|r -> Perform a mob database evaluation");
	chat(hBlue..SLASH_DROPCOUNT2.." slow|r -> List slowest data storages");
	chat(hBlue..SLASH_DROPCOUNT2.." ripper|r -> Invoke ripperMT");
	chat(hBlue..SLASH_DROPCOUNT2.." loc|r -> Print player position");
end

function DropCount.MT:dbVendorItems_Convert(db)
	_debug("Creating VendorItems-type database and shoving tokens...");
	local equal,tmp;
	local mask,count;
	count=0;
	for k,v in rawpairs(db.Vendor) do
		if (v:match("(item:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+)")) then
			for a,b in rawpairs(db.VendorItems) do
				MT:Yield(); tmp=a;											-- in case it's found and we need to know the key
				equal=IsEqual(v,b);											-- check keys and values
				if (equal) then break; end									-- it's the same, so no need to continue
			end
			if (type(db.Vendor[k].Items)=="table") then						-- it needs converting (NOTE: vendor cache will happen here)
				if (not equal) then											-- block not previously saved
					repeat tmp=tostring(math.random(0xFFFF)); until(not db.VendorItems.__DATA__[tmp]);	-- 16 bit random key
					db.VendorItems[tmp]=db.Vendor[k].Items;					-- save and pack
					count=count+1;
				end
				equal=db.Vendor[k]; equal.Items=tmp; db.Vendor[k]=equal;	-- set token
			end
		end
	end
	_debug("VendorItems database complete with",count,"entries.");
end

function DropCount.Event.COMBAT_LOG_EVENT_UNFILTERED(_,how,_,source,_,_,_,GUID,mob)
	local sguid=DropCount.MakeSGUID(GUID); if (not sguid) then return; end
	DropCount.DB:ConvertMOB(mob,sguid);
--	if (how=="PARTY_KILL" and (bit.band(source,COMBATLOG_OBJECT_TYPE_PET) or bit.band(source,COMBATLOG_OBJECT_TYPE_PLAYER))) then
	if (how=="PARTY_KILL" and (source:find("Player-",1,true==1) or source:find("Pet-",1,true)==1)) then
--_debug(how,source,sguid,GUID,mob)
		if (GetNumGroupMembers()<1) then DropCount:AddKill(true,GUID,sguid,mob,dccs.Skinning); end
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end	-- hooked up, so notify of possible change
	end
end

function DropCount.Event.PLAYER_FOCUS_CHANGED(...) DropCount.Event.PLAYER_TARGET_CHANGED(...); end
function DropCount.Event.PLAYER_TARGET_CHANGED()
	local targettype=DropCount:GetTargetType();
	DropCount.Target.MyKill=nil; DropCount.Target.Skin=nil; DropCount.Target.UnSkinned=nil; DropCount.Target.CurrentAliveFriendClose=nil;
	if (not targettype) then return; end
	DropCount.ProfessionLootMob=nil;									-- only zero on new target, not on removal of target
	DropCount.BlindCast=nil;
	DropCount.Target.Classification=UnitClassification(targettype);		-- elite, rare, etc
	DropCount.Target.ClassificationSGUID=DropCount.MakeSGUID(UnitGUID(targettype));
	if (not UnitIsDead(targettype)) then								-- It's alive!
		DropCount.Target.LastFaction=UnitFactionGroup(targettype);
		if (not DropCount.Target.LastFaction) then DropCount.Target.LastFaction="Neutral"; end
		DropCount.Target.LastAlive=UnitName(targettype);
		DropCount.DB:ConvertMOB(UnitName(targettype),DropCount.MakeSGUID(UnitGUID(targettype)));
		DropCount.Target.CurrentAliveFriendClose=nil;
		if (CheckInteractDistance(targettype,2)) then DropCount.Target.CurrentAliveFriendClose=DropCount.Target.LastAlive; end	-- Trade-distance
		return;
	end
	if (UnitIsFriend("player",targettype)) then return; end		-- it's a dead friend. we really shouldn't loot those.
	DropCount.Target.CurrentAliveFriendClose=nil;
	DropCount.Target.Skin=UnitName(targettype);
	DropCount.Target.GUID=UnitGUID(targettype);	-- Get current valid target
--	DropCount.Target.UnSkinned=DropCount.Target.GUID:sub(7,10);	-- Set unit for skinning-drop
--_debug(DropCount.Target.GUID);
	DropCount.Target.UnSkinned=DropCount.MakeSGUID(DropCount.Target.GUID);	-- Set unit for skinning-drop
	if (UnitIsTapped(targettype)) and (not UnitIsTappedByPlayer(targettype)) then return; end	-- Not my kill (in case of skinning)
	DropCount.Target.MyKill=DropCount.Target.Skin;			-- Save name of dead targetted/focused enemy
end

-- Apply to: Quest, Vendor, Trainer
function DropCount.DB:ConvertLocation_Generic(t)
	if (not t.X or not t.Y or not t.Zone) then return t; end
	if (not t.Map) then t.Map={ID=t.Zone,Floor=0,}; end					-- only old textual representation, so no known floor
	t._Location_=Location_Code(t.X,t.Y,t.Map.ID,t.Map.Floor,t.Zone:match("^.+ %- (.*)$") or "");
	t.X=nil; t.Y=nil; t.Map=nil; t.Zone=nil;							-- remove old representation
	return t;
end

-- Apply to: Book
function DropCount.DB:ConvertLocation_Book(t)
	for k,v in ipairs(t) do
		if (type(v)=="table" and v.X and v.Y and v.Zone) then
			if (not v.Map) then v.Map={ID=v.Zone,Floor=0,}; end					-- only old textual representation, so no known floor
			t[k]=Location_Code(v.X,v.Y,v.Map.ID,v.Map.Floor,v.Zone:match("^.+ %- (.*)$") or "");
	end end
	return t;
end

-- Apply to: Item
function DropCount.DB:ConvertLocation_Item(t)
	if (type(t.Best)=="table") then t.Best=MapPlusNumber_Code(t.Best.Location,0,"",t.Best.Score); end
	if (type(t.BestW)=="table") then t.BestW=MapPlusNumber_Code(t.BestW.Location,0,"",t.BestW.Score); end
	return t;
end

-- Apply to: Count
function DropCount.DB:ConvertLocation_Creature(t)
	t.Zone=nil; return t; end				-- don't need it anymore

function DropCount.DB:ConvertMOB(name,sguid,base,unp)
	if (not base) then base=dcdb; end
	if (not name or not sguid or not base.Count[name]) then return; end				-- nothing to convert
	if (sguid=="0000") then return; end
	local mdata=base.Count[name];							-- get old data
	mdata.Name=name;										-- add textual name
	base.Count[sguid]=mdata;								-- write it at short guid
	base.Count[name]=nil;									-- remove old entry
	if (unp) then Table:Unpack(sguid,base.Count); end		-- re-unpack the new storage
	Table:PurgeCache(DM_WHO);
	for item,idata in rawpairs(base.Item) do				-- do all items
		if (type(idata)~="string" or idata:find(name,1,true)) then					-- look for mob by old name
			idata=base.Item[item];							-- read the item
			if (idata.Name and idata.Name[name]) then		-- look for mob by old name
				idata.Name[sguid]=idata.Name[name];			-- copy it to short guid
				idata.Name[name]=nil;						-- remove by old name
			end
			if (idata.Skinning and idata.Skinning[name]) then
				idata.Skinning[sguid]=idata.Skinning[name];
				idata.Skinning[name]=nil;
			end
			base.Item[item]=idata;							-- over-write item
	end end
end

--== MoP: GetLootSourceInfo(slot) - will return an erroneous list of creature GUIDs and count
--== ---> These errors seem to be linked to items rather than code, and the errors are diminishing with time

-- The following function will correct any loot amount that are reported
-- with erroneous amounts by the game.
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
	local _insert=table.insert;
	local slots=GetNumLootItems(); if (slots<1) then _debug("debug: Zero-loot",1); return; end
	local items={};for i=1,slots do local thisi=getid(GetLootSlotLink(i)); if (thisi) then _,_,items[thisi]=GetLootSlotInfo(i); end end
	local mobs={}; for i=1,slots do
		local item=getid(GetLootSlotLink(i)); if (item) then local t={GetLootSourceInfo(i)};
		for j=1,#t,2 do if (not mobs[t[j] ]) then mobs[t[j] ]={}; end local buf={ Count=t[j+1], Item=item };
		if (DropCount.ProfessionLootMob) then buf.Count=items[item]; end _insert(mobs[t[j] ],buf); end end end
	local vitems={}; for m,d in pairs(mobs) do for _,mi in pairs(d) do
		if (not vitems[mi.Item]) then vitems[mi.Item]={ mobs=1, amount=mi.Count, guid={ m } };
		else vitems[mi.Item].mobs=vitems[mi.Item].mobs+1; vitems[mi.Item].amount=vitems[mi.Item].amount+mi.Count; _insert(vitems[mi.Item].guid,m); end end end
	for i,d in pairs(items) do
		if (vitems[i]) then if (d~=vitems[i].amount) then
			if (vitems[i].mobs==1) then for _,mi in pairs(mobs[vitems[i].guid[1] ]) do if (mi.Item==i) then mi.Count=d; end end else local fi,num,mt=nil,0,{};
				for _m,_d in pairs(mobs) do for _,mi in pairs(_d) do if (mi.Item==i) then
					local sg=DropCount.MakeSGUID(_m); if (not mt[sg]) then mt[sg]={ c=mi.Count, n=1, guid={_m} }; num=num+1; if (not fi) then fi=_m; end
					else mt[sg].c=mt[sg].c+mi.Count; mt[sg].n=mt[sg].n+1; _insert(mt[sg].guid,_m); end end end end
				if (num==1) then for _,mi in pairs(mobs[fi]) do if (mi.Item==i) then mi.Count=mi.Count+(d-vitems[i].amount); end end else local tr=0;
					for _m,_d in pairs(mt) do mt[_m].r=DropCount:GetRatio(i,_m); mt[_m].r=mt[_m].r*mt[_m].n; tr=tr+mt[_m].r; if (mt[_m].r==0) then mt[_m].r=.01; end end
					local all=0; for _m,_d in pairs(mt) do mt[_m].a=(mt[_m].r/tr)*d; mt[_m].a=floor(mt[_m].a+.5); all=all+mt[_m].a; end
					if (all~=d) then
						all=d-all; if (all>0) then repeat local lom,lod; for _m,_d in pairs(mt) do if (not lom or mt[_m].a<lod) then lom=_m; lod=_d.a; end end mt[lom].a=mt[lom].a+1; all=all-1; until (all==0);
						else repeat local him,hid; for _m,_d in pairs(mt) do if (not him or mt[_m].a>hid) then him=_m; hid=_d.a; end end mt[him].a=mt[him].a-1; all=all+1; until (all==0); end end
					for _,mi in pairs(mobs) do for _,mid in pairs(mi) do if (mid.Item==i) then mid.Count=0; end end end
					for sg,sgd in pairs(mt) do for m,mi in pairs(mobs) do if (DropCount.MakeSGUID(m)==sg) then
						local stopit=nil; for _,mid in pairs(mi) do if (mid.Item==i) then mid.Count=sgd.a; stopit=true; break; end end if (stopit) then break; end end end end end end end end end
	local ret={}; for guid,gL in pairs(mobs) do for _,i in pairs(gL) do if (not ret[i.Item]) then ret[i.Item]={}; end ret[i.Item][guid]=i.Count; end end
	ret.GetLootFormat=function(t,i)
		if (type(i)=="string") then i=getid(i); else i=getid(GetLootSlotLink(i)); end if (not i or not t[i]) then return; end
		local lft={}; for g,c in pairs(t[i]) do _insert(lft,g); _insert(lft,c); end return unpack(lft); end
	return ret,mobs;
end

function DropCount:GetCurrentTooltipHeader()
	if (GameTooltip:NumLines()<1) then return nil; end
	local text=_G["GameTooltipTextLeft1"]:GetText(); return (text~="" and text) or nil; end

function DropCount:GetCurrentObjectID()
	if (GameTooltip:GetItem()) then return nil; end
	local header=self:GetCurrentTooltipHeader();
	if (not header) then return; end									-- WoW6: often called with an empty tooltip
	DropCount.Tracker.LastObjectIDName=header;
	local lang=GetLocale();
	for objID,odata in rawpairs(dcdb.Gather.GatherNodes) do
		if (odata:find(DropCount.Tracker.LastObjectIDName,1,true)) then
			if (dcdb.Gather.GatherNodes[objID]._Name==DropCount.Tracker.LastObjectIDName) then return objID; end
	end end
	return nil;
end

function DropCount:SaveGatheringLoot(profession)
	local profDB;
	if (profession==CONST.PROFESSIONS[2]) then profDB="GatherHERB"; elseif (profession==CONST.PROFESSIONS[3]) then profDB="GatherORE"; else return; end
	local slots=GetNumLootItems(); if (slots<1) then return; end
	local items,nodeicon={},nil;
	for i=1,slots do
		local thisi=getid(GetLootSlotLink(i));
		if (thisi) then
			local thisp=tonumber(thisi:match("^item:(%d+):"));
			local itemname,thisicon;
			thisicon,itemname,items[thisi]=GetLootSlotInfo(i);		-- icon, name, quantity
			local first,last=itemname:sub(1,ceil(itemname:len()/2)),itemname:sub(0-ceil(itemname:len()/2));		-- first and second half of looted item name
			if (DropCount.Tracker.LastObjectIDName:find(first,1,true) or DropCount.Tracker.LastObjectIDName:find(last,1,true)) then nodeicon=thisicon; end
	end end
	if (not nodeicon) then nodeicon,_,_=GetLootSlotInfo(1); end		-- icon, name, quantity
	local objID=DropCount.Tracker.GatherObject;
	DropCount.Tracker.GatherObject=nil;
	local buf=dcdb.Gather.GatherNodes[objID] or {};
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
	map=map or 0; level=level or 0;
	x=x or 0; y=y or 0;
	if (map==0) then map,level=CurrentMap(); end									-- get player map and level
	if (x==0 and y==0) then x,y=GetPlayerMapPosition("player"); end					-- get player position
	if (x==0 and y==0) then return; end
	if (x<1 and y<1) then x=floor(x*100); y=floor(y*100); end						-- make 100-grid
	map=tostring(map).."_"..tostring(level);										-- create individual map
	local buf=dcdb.Gather[profDB][map]; buf=buf or { Gathers=0, OID={ }, };			-- get gather-section
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
	end
	dcdb.Gather[profDB][map]=buf;			-- save with new count and optional new location
end

function DropCount:PackBitGrid(rawgrid)
	local len,grid,i,j,_char=rawgrid:len(),"",1,0,string.char;
	repeat
		if (rawgrid:sub(i,i)~=_char(0)) then grid=grid..rawgrid:sub(i,i);	-- insert non-null directly
		else
			j=0;								-- note the "offset" j=0 ultimately makes one character result
			repeat j=j+1; until(rawgrid:sub(i+j,i+j)~=_char(0) or i+j>len or j==255);		-- check for non-null or full buffer
			grid=grid.._char(0,j);				-- add compressed coding
			i=i+(j-1);							-- possible to add zero in case single zero bytes and i marches on by for-statement
		end
		i=i+1;
	until(i>len);
	return grid;
end

function DropCount:UnpackBitGrid(packedgrid)
	local len,grid,i,_rep=packedgrid:len(),"",1,string.rep;
	repeat
		if (packedgrid:byte(i,i)==0) then
			grid=grid.._rep(packedgrid:sub(i,i),packedgrid:byte(i+1,i+1));	-- recreate empty space
			i=i+1;															-- skip past of counter byte
		else grid=grid..packedgrid:sub(i,i); end							-- direct copy byte
		i=i+1;
	until(i>len);
	return grid;
end

function DropCount:Length(t)
	local c=0; for _ in pairs(t or {}) do c=c+1; end return c; end

function DropCount.Event.LOOT_OPENED()
	if (DropCount.Tracker.GatherDone) then DropCount:SaveGatheringLoot(DropCount.Tracker.GatherDone); DropCount.Tracker.GatherDone=nil; return;
	elseif (DropCount.BlindCast or not DropCount.Target.Skin) then return; end		-- blind cast or friendly target at any distance
	if (DropCount.Target.MyKill) then DropCount.Grid:Add(DropCount.Target.UnSkinned); end	-- Add tagret to grid
	local i,mobs=DropCount:FixLootAmounts(); if (not mobs) then return; end
	local now=time();
	for k in pairs(i) do k=getid(k); if (k) then guiitems[k]=now; end end			-- spool all looted items
	for k,v in pairs(guiitems) do if (now-v>CONST.QUEUETIME) then guiitems[k]=nil; end end	-- remove all old loot
	_debug("Item auto-queue:",DropCount:Length(guiitems));
	if (not DropCount.OldQuestsVerified) then dcdb.QuestQuery=GetQuestsCompleted(); DropCount:GetQuestNames(); DropCount.OldQuestsVerified=true; end
	local nogrid=0;
	for _ in pairs(mobs) do nogrid=nogrid+1; end
	if (nogrid>2) then nogrid=true; else nogrid=nil; end	-- possibly an area pull, so don't add all to grid in one spot
	for guid,list in pairs(mobs) do
		local skipit=nil;
		local sguid=DropCount.MakeSGUID(guid);
		local mTable=DropCount.Tracker.Looted;										-- select normal loot mobs
		if (DropCount.ProfessionLootMob) then mTable=DropCount.Tracker.Skinned;		-- select skinning loot mobs
		else																		-- It's normal, so check if it has already been skinned
			if (DropCount.Tracker.Skinned[guid]) then skipit=true; end				-- already skinned, so loot is not correct
		end
		if (mTable[guid]) then skipit=true; end			-- Loot already done for this one
		if (not skipit) then
			if (DropCount.Target.UnSkinned and not nogrid) then DropCount.Grid:Add(sguid); end	-- if nothing selected, assume fishing
			if (DropCount.ProfessionLootMob and DropCount.Target.MyKill) then DropCount:AddKill(true,guid,sguid);		-- If my kill (or pet or something that makes me loot it)
			elseif (not DropCount.ProfessionLootMob) then DropCount:AddKill(true,guid,sguid); end	-- Add the targeted dead dude that I didn't have the killing blow on
--			local now=time();
			-- Save loot
			mTable[guid]=now;							-- Set it
			for i=1,#list do
				if (list[i].Item and list[i].Count==0) then list[i].Count=1; end
				if (list[i].Count>0 and (DropCount.Target.MyKill or DropCount.Target.Skin)) then
--_debug(list[i].Item,list[i].Count);
					DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count); end
			end
			DropCount.ProfessionLootMob=nil;			-- Set normal type loot
			-- Remove old mobs
			for guid,when in pairs(mTable) do if (now-when>CONST.LOOTEDAGE) then mTable[guid]=nil; end end
		end
	end
	DropCount.GUI:AssignAutoItems();	-- auto-assign monitors
end

-- fires twice
function DropCount.Event.LOOT_CLOSED()
	MT:Run("Look for quest starters",DropCount.MT.Quest.ScanStartItem,DropCount.MT.Quest);
	MT:Run("Verify item ID",DropCount.MT.VerifyItemId,DropCount.MT);
end

function DropCount.Event.MERCHANT_SHOW()
	DropCount.Target.OpenMerchant=DropCount.Target.LastAlive; DropCount.Timer.VendorDelay=1; end
function DropCount.Event.MERCHANT_CLOSED()
	DropCount.Timer.VendorDelay=-1; DropCount.VendorReadProblem=nil; end
function DropCount.Event.WORLD_MAP_UPDATE()
	if (not WorldMapDetailFrame:IsVisible()) then return; end
	MT:Run("WM Plot",DropCount.MT.Icons.PlotWorldmap,DropCount.MT.Icons);
--	MT:Run("LocationRecorder_Bookkeeping()",DropCount.MT.LocationRecorder_Bookkeeping,DropCount.MT);
end
function DropCount.Event.ZONE_CHANGED_NEW_AREA()
	Table:PurgeCache(DM_WHO); MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end

function DropCount.Event.QUEST_DETAIL()
	local qName=GetTitleText();
	local target=DropCount:GetTargetType();
	if (target) then target=CheckInteractDistance(target,3); end			-- Duel - 9,9 yards
	if (not target) then DropCount.Target.CurrentAliveFriendClose=nil; end	-- No target, or too far away
	if (qName) then DropCount.Quest:SaveQuest(qName,DropCount.Target.CurrentAliveFriendClose); end
	local index=1;
	repeat						-- buffer named items
		local link=GetQuestLogItemLink("required",index);
		if (link) then
			link=getid(link);
			if (link and dcdb.Item[link] and dcdb.Item[link].Item) then
				getid(dcdb.Item[link].Item);							-- grab by name
			end
		end
	until (not link);
end

function DropCount.Event.QUEST_COMPLETE()
	local qName=GetTitleText();
	local qID=true;
	if (dccs.Quests[qName]) then qID=dccs.Quests[qName].ID; end
	if (not dccs.DoneQuest) then dccs.DoneQuest={}; end
	if (not dccs.DoneQuest[qName]) then dccs.DoneQuest[qName]=qID; --chat("Quest \""..qName.."\" completed",0,1,0);
	else
		if (type(dccs.DoneQuest[qName])=="table") then
			if (qID and qID~=true) then dccs.DoneQuest[qName][qID]=true; end
		elseif (qID and qID~=true) then
			dccs.DoneQuest[qName]=nil;
			dccs.DoneQuest[qName]={[qID]=true};
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
--_debug(name,spell)
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
	if (skillName and skillName==CONST.PROFESSIONS[3]) then		-- Mining, so it could be a forge
		if (GetTradeSkillSelectionIndex()==0) then return; end
		skillName=GetTradeSkillInfo(GetTradeSkillSelectionIndex());
		if (not skillName or skillName~=spell) then return; end
		DropCount:SaveForge();
	end
end

function DropCount.Event.TRADE_SKILL_CLOSE()
	DropCount.Event.TRADE_SKILL_SHOWactive=nil;
end

function DropCount.Event.TRADE_SKILL_SHOW()
	DropCount.Event.TRADE_SKILL_SHOWactive=true;
	DropCount.Event.TRADE_SKILL_SHOW_scanner();
end

function DropCount.Event.TRADE_SKILL_UPDATE()
	DropCount.Event.TRADE_SKILL_SHOW_scanner();
end

function DropCount.Event.CHAT_MSG_SKILL(text)
	if (not text:match(DropCount.skillMatch)) then return; end
	DropCount.Event.TRADE_SKILL_SHOW_scanner();
end


-- fires when tradeskill window opens
function DropCount.Event.TRADE_SKILL_SHOW_scanner()
	if (not DropCount.Event.TRADE_SKILL_SHOWactive or IsTradeSkillLinked()) then return; end	-- only my own stuff from the list
	local skill,rank,maxlevel=GetTradeSkillLine(); if (skill=="UNKNOWN") then return; end
	dccs.Trades=dccs.Trades or { [skill]={} };
	dccs.Trades[skill]=dccs.Trades[skill] or {};
	for i=1,GetNumTradeSkills() do
		local name,header=GetTradeSkillInfo(i);							-- 'name' is recipe name, like "Pants of fiery wrath"
		if (header~="header") then dccs.Trades[skill][name]=1; end		-- value unimportant. only need the keys.
	end
end
-- reagentName,reagentTexture,reagentCount,playerReagentCount=GetTradeSkillReagentInfo(skillIndex,reagentIndex)
-- link=GetTradeSkillReagentItemLink(skillIndex,reagentIndex)


function DropCount:SaveForge()
	local _tonumber=tonumber;
	local map=CurrentMap();
	local forges=dcdb.Forge[map] or {};
	local saved=nil;
	local fX,fY=DropCount:GetPlayerPosition();
	for forge,fRaw in pairs(forges) do
		local x,y=fRaw:match("^(.+)_(.+)$"); x=_tonumber(x); y=_tonumber(y);
		if (fX==x and fY==y) then saved=true; break;				-- repeated forge
		elseif (fX>=x-1 and fX<=x+1 and fY>=y-1 and fY<=y+1) then forges[forge]=fX.."_"..fY; saved=true; break;end
	end
	if (not saved) then table.insert(forges,fX.."_"..fY); end
	dcdb.Forge[map]=forges;
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
end

function DropCount:ClearMergeTracker()
	dcdb.Tracker={						-- tracking stuff through relogs
		Total=-1, Goal=0, Mobs=-1, MobsGoal=0, Book={ New=0, Updated=0, }, Quest={ New={}, Updated={}, }, Vendor={ New={}, Updated={}, },
		Mob={ New=0, Updated=0, }, Item={ New=0, Updated=0, }, Forge={ New=0, Updated=0, }, Trainer={ New={}, Updated={}, },
		Grid={ New=0, Updated=0, }, Nodes={ New=0, Updated=0, }, Gather={ New=0, Updated=0, },
	};
end

function DropCount.Event.ADDON_LOADED(addon)
	if (addon~="LootCount_DropCount") then return; end
	dcdb=LootCount_DropCount_DB;			-- set short-form
	dccs=LootCount_DropCount_Character;		-- set short-form
	dcmaps=LootCount_DropCount_Maps;		-- set short-form
	setmetatable(dcmaps,dropcountmapmeta);	-- make maps callable
	if (DropCount_Local_Code_Enabled) then DropCount.Debug=true; end
	CONST.MYFACTION=UnitFactionGroup("player");
	CreateDropcountDB(dcdb);
	DropCount.Hook.TT_SetBagItem=GameTooltip.SetBagItem; GameTooltip.SetBagItem=DropCount.Hook.SetBagItem;
	DropCount.Hook.TT_SetGuildBankItem=GameTooltip.SetGuildBankItem; GameTooltip.SetGuildBankItem=DropCount.Hook.SetGuildBankItem;
	DropCount.Hook.DCTT_Show=DropCountTooltip.Show; DropCountTooltip.Show=DropCount.Hook.ShowDCTT;
	DropCount.Hook.DCTT_Hide=DropCountTooltip.Hide; DropCountTooltip.Hide=DropCount.Hook.HideDCTT;
	dccs.ShowZoneMobs=nil; dccs.ShowZone=nil; dccs.InvertMobTooltip=nil; dcdb.GUILD=nil; dcdb.RAID=nil;			-- obsolete
	if (not dcdb.Tracker) then DropCount:ClearMergeTracker(); end
	if (dcdb.IconX and dcdb.IconY) then DropCount:MinimapSetIconAbsolute(dcdb.IconX,dcdb.IconY); else DropCount:MinimapSetIconAngle(dcdb.IconPosition or 180); end
	dccs.LastQG=dccs.LastQG or {};
	dccs.Filter=dccs.Filter or {};
	dccs.Monitor=dccs.Monitor or {};
	local k,v=next(dcdb.Book); v=dcdb.Book[k];	-- grab any book for verification
	if (v.Zone) then for k in rawpairs(dcdb.Book) do dcdb.Book[k]=nil; end end		-- kill it, data is anchient, obsolete, and then mostly misplaced
	Astrolabe:Register_OnEdgeChanged_Callback(DropCountXML.AstrolabeEdge,1);
	DropCount:RemoveFromDatabase(); wipe(LootCount_DropCount_RemoveData); LootCount_DropCount_RemoveData=nil;
	DropCount.Loaded=0;				-- starting OnUpdate timer
	if (not DropCount_Local_Code_Enabled) then dcdb.GridMinimap=nil; dcdb.OreMinimap=nil; dcdb.HerbMinimap=nil; dcdb.GridWorldmap=nil; end
	if (dcdb.DontFollowVendors) then dcdb.VendorMinimap=nil; dcdb.VendorWorldmap=nil; dcdb.RepairMinimap=nil; dcdb.RepairWorldmap=nil; end
	if (dcdb.DontFollowBooks) then dcdb.BookMinimap=nil; dcdb.BookWorldmap=nil; end
	if (dcdb.DontFollowForges) then dcdb.ForgeMinimap=nil; dcdb.ForgeWorldmap=nil; end
	if (dcdb.DontFollowGrid) then dcdb.GridMinimap=nil; dcdb.GridWorldmap=nil; end
	if (dcdb.DontFollowGrid) then dcdb.RareMinimap=nil; dcdb.RareWorldmap=nil; end
	if (dcdb.DontFollowTrainers) then dcdb.TrainerMinimap=nil; dcdb.TrainerWorldmap=nil; end
	if (dcdb.DontFollowQuests) then dcdb.QuestMinimap=nil; dcdb.QuestWorldmap=nil; end
	if (dcdb.DontFollowGather) then dcdb.HerbMinimap=nil; dcdb.HerbWorldmap=nil; dcdb.OrbMinimap=nil; dcdb.OrbWorldmap=nil; end
	LCDC_ResultListScroll:DMClear();		-- Prep search-list
	LCDC_VendorSearch_UseVendors:SetText("Vendors"); LCDC_VendorSearch_UseVendors:SetChecked(true);
	LCDC_VendorSearch_UseQuests:SetText("Quests"); LCDC_VendorSearch_UseQuests:SetChecked(true);
	LCDC_VendorSearch_UseBooks:SetText("Books"); LCDC_VendorSearch_UseBooks:SetChecked(true);
	LCDC_VendorSearch_UseAreaMobs:SetText("Zone mobs (slow)"); LCDC_VendorSearch_UseAreaMobs:SetChecked(false);
	LCDC_VendorSearch_UseAreaItems:SetText("Zone items (slow)"); LCDC_VendorSearch_UseAreaItems:SetChecked(false);
	LCDC_VendorSearch_UseItems:SetText("Items"); LCDC_VendorSearch_UseItems:SetChecked(true);
	LCDC_VendorSearch_UseMobs:SetText("Creatures"); LCDC_VendorSearch_UseMobs:SetChecked(true);
	LCDC_VendorSearch_UseTrainers:SetText("Trainers"); LCDC_VendorSearch_UseTrainers:SetChecked(true);
	LCDC_VendorSearch_UseProfItems:SetText("Profession items"); LCDC_VendorSearch_UseProfItems:SetChecked(true);
	LCDC_VendorSearch_UsegatherNode:SetText("Gather nodes"); LCDC_VendorSearch_UsegatherNode:SetChecked(true);
	DropCount.GUI:reCreateGUI();		-- restore monitors
	MT:Run("ConvertAndMerge",DropCount.MT.ConvertAndMerge);			-- Fire initial MT tasks
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
	if (dcdb.LastNotifiedVersion<2.00) then
		things=things..Yellow.."*|r Check out the new \"How do I ...\" section.\n";
		things=things..Yellow.."*|r Try the new loot monitors.\n";
		things=things..Yellow.."*|r Try the new \"Gathering Coverage\" option.\n";
		things=things..Yellow.."*|r Filter vendors by specific items.\n";
		things=things..Yellow.."*|r Filter vendors by profession.\n";
		things=things..Yellow.."*|r Review the minimap menu and key bindings.\n";
		things=things..Yellow.."*|r Check out the updated \"Search...\" option.\n";
	end
	if (dcdb.LastNotifiedVersion<1.50) then
		things=things..Yellow.."*|r Add a commonly dropped item in worldmap locations.\n";
	end
	if (things~="") then
		text=text..Basic.."Things you may want to try with your new DropCount:\n"..things;
	end
	if (dcdb.LastNotifiedVersion==0) then dcdb.LastNotifiedVersion=VERSIONn; end	-- update here to not show the next section for new installs
	-- code changes
	local changes="";
	if (dcdb.LastNotifiedVersion<2.00) then
		changes=changes..Yellow.."*|r WoW 6.\n";
		changes=changes..Yellow.."*|r Better support for localized data.\n";
		changes=changes..Yellow.."*|r Improved system load.\n";
		changes=changes..Yellow.."*|r UI strata changes.\n";
		changes=changes..Yellow.."*|r Minor database changes.\n";
	end
	if (dcdb.LastNotifiedVersion<1.50) then
		changes=changes..Yellow.."*|r Items and creatures on the worldmap.\n";
		changes=changes..Yellow.."*|r Herbs and ore on the worldmap.\n";
	end
	changes=changes..Yellow.."*|r Code restructuring and bug fixes.\n";
	if (changes~="") then
		text=text.."\n"..Basic.."Changes in "..Green..LOOTCOUNT_DROPCOUNT_VERSIONTEXT..Basic.." since your last upgrade:\n"..changes;
	end
	-- display it
	if (text:len()>2) then
		StaticPopupDialogs["LCDC_D_NEWVERSIONINSTALLED"].text=text:sub(1,-2);	-- cut last '\n'
		StaticPopup_Show("LCDC_D_NEWVERSIONINSTALLED");
	end
	dcdb.LastNotifiedVersion=VERSIONn;			-- update for all versions
end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_LEAVE()
	DropCountTooltip:Hide();
	GameTooltip:Hide(); end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_ENTER(frame,index)
	local entry=frame.DMTheList[index];
	if (entry.DB.Section=="Item") then DropCount.Tooltip:MobList(entry.DB.Entry,nil,nil,nil,LCDC_VendorSearch.SearchTerm);
	elseif (entry.DB.Section=="Creature") then if (entry.Entry~=entry.DB.Entry) then DropCount.Tooltip:SetLootlist(entry.Entry,entry.DB.Entry); end
	elseif (entry.DB.Section=="Gathering profession") then DropCount.Tooltip:Node(entry.Tooltip,nil,true);
	elseif (entry.Tooltip) then			-- something else, but with tooltip, so assume raw line-by-line tooltip provided
		if (DropCountTooltip:IsVisible()) then return; end
--		DropCountTooltip:SetOwner(frame,"ANCHOR_CURSOR");
		DropCountTooltip:Init(frame);
		DropCountTooltip:SetText(entry.Tooltip[1]);
		DropCountTooltip:Add(entry.Tooltip);							-- spew tooltip
		local found=nil;
		if (entry.DB.Section=="Vendor") then
			local eData=dcdb.Vendor[entry.DB.Entry];
			if (eData) then
				for item,iTable in pairs(eData.Items) do
					if (dcdb.Item[item] and dcdb.Item[item].Item:lower():find(LCDC_VendorSearch.SearchTerm)) then
						if (not found) then found=true; DropCountTooltip:Add(" "); DropCountTooltip:Add("Matches:"); end	-- init text
						DropCountTooltip:Add("   "..Highlight(dcdb.Item[item].Item,LCDC_VendorSearch.SearchTerm));
			end end end
		elseif (entry.DB.Section=="Quest") then
			local eData=dcdb.Quest[CONST.MYFACTION][entry.DB.Entry];
			if (eData and eData.Quests) then for _,iTable in ipairs(eData.Quests) do
					local useit=nil;
					if (iTable.Quest:lower():find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
					if (iTable.Header and iTable.Header:lower():find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
					if (useit) then
						if (not found) then found=true; DropCountTooltip:Add(" "); DropCountTooltip:Add("Matches:"); end	-- init text
						DropCountTooltip:Add("   "..iTable.Quest,iTable.Header);
			end end end
		else
			return;
		end
		DropCountTooltip:Show();
	end
end

function DropCount.Event.DMEVENT_LISTBOX_ITEM_CLICKED(frame,index,checked,mousebutton)
	local entry=frame.DMTheList[index];
	if (frame==LCDC_ListOfOptions_List) then
		if (entry.DB.Negative) then checked=(not checked) or nil; end
		if (entry.DB.Base) then
			_G["LootCount_DropCount_"..entry.DB.Base][entry.DB.Setting]=checked;
			MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		end
	elseif (frame==LCDC_ResultListScroll) then
		if (entry.DB.Section=="Creature") then
			DropCountTooltip:Hide();
			local internal,name=entry.DB.Entry,entry.DB.Entry;
			if (dcdb.Count[internal] and dcdb.Count[internal].Name) then name=dcdb.Count[internal].Name; end
			if (mousebutton=="LeftButton") then
			else
				local menu=DMMenuCreate();
				menu:Add("Track on worldmap",function () DropCountXML.AddUnitToGridFilter("Creature",name,internal); end );	-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
				menu:Show();
			end
		elseif (entry.DB.Section=="Vendor") then
			DropCountTooltip:Hide();
			if (mousebutton=="LeftButton") then DropCount.Tooltip:Vendor(entry.DB.Entry,frame,true); end
		elseif (entry.DB.Section=="Quest") then
			DropCountTooltip:Hide();
			if (mousebutton=="LeftButton") then DropCount.Tooltip:QuestList(CONST.MYFACTION,entry.DB.Entry,frame); end
		elseif (entry.DB.Section=="Item") then
			DropCountTooltip:Hide();
			local internal,name=entry.DB.Entry,entry.DB.Entry;
			if (dcdb.Item[internal] and dcdb.Item[internal].Item) then name=dcdb.Item[internal].Item; end
			if (mousebutton=="LeftButton") then SetItemRef(entry.DB.Entry);
			else
				local menu=DMMenuCreate();
				menu:Add("Track as loot on worldmap",function () DropCountXML.AddUnitToGridFilter("Item",name,internal); end );	-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
				menu:Add("Track vendors",function () dccs.Filter.VendorItem=dccs.Filter.VendorItem or {}; dccs.Filter.VendorItem[internal]=1; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end );
				menu:Add("Add monitor",function () DropCount.GUI:CreateGUI():SetItem(internal); end );
				menu:Show();
			end
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
	if (DropCount.Event[event]) then DropCount.Event[event](...); return; end end

-- called when "DropCount_DataOptionsFrame" is about to hide
function DropCountXML:VerifySectionSettings()
	dcdb.ForcedOptions=1;
	local reload=nil;
	if (not _G["DropCount_DataOptionsFrame"].DBSettings) then return; end	-- no changes
	for db,dbd in pairs(_G["DropCount_DataOptionsFrame"].DBSettings) do
		for name,value in pairs(dbd) do
			local cur=_G["LootCount_DropCount_"..db][name];
			cur=(cur and true) or nil;									-- get forced true/nil of current state
			value[1]=(value[1] and true) or nil;						-- get forced true/nil of wanted state
			if (cur~=value[1]) then reload=true; end					-- new state, so flag a reload
			_G["LootCount_DropCount_"..db][name]=value[1];				-- insert new state
			for base,direct in pairs(value[2].nousebase or {}) do
				local set=value[1]; if (not direct) then set=(not set) or nil; end
				rawset(rawget(dcdb[base],"__METADATA__"),"nouse",set);	-- inhibit storage for this database
			end
			for base,direct in pairs(value[2].nousesub or {}) do
				local set=value[1]; if (not direct) then set=(not set) or nil; end
				for sub in pairs(dcdb[base]) do rawset(rawget(dcdb[base][sub],"__METADATA__"),"nouse",set); end
	end end end
	return reload;
end

function DropCountXML:OnTooltipLoad(frame)
	addclass(DropCount.TooltipClass,frame);
	if (frame==GameTooltip) then
		frame:SetText("1"); frame:AddLine("2"); frame:AddLine("3");
		ttLCFont,ttLCSize,ttLCFlags=_G[frame:GetName().."TextLeft"..frame:NumLines()]:GetFont();
		frame:Show(); frame:Hide();
	end
	frame.Init=DropCount.Tooltip.DCTT_Init;
end

function DropCount.TooltipClass.Add(tt,text,rtext,wrap)
	if (type(rtext)=="boolean") then rtext,wrap=nil,rtext; end			-- single text with wrap specified
	wrap=(wrap and 1) or nil;											-- 1 or nil
	DropCount.TooltipClass.AddText(tt,text,rtext,ttLCSize,wrap);
end

function DropCount.TooltipClass.AddSmall(tt,text,rtext,wrap)
	if (type(rtext)=="boolean") then rtext,wrap=nil,rtext; end			-- single text with wrap specified
	wrap=(wrap and 1) or nil;											-- 1 or nil
	DropCount.TooltipClass.AddText(tt,text,rtext,ttLCSize*.75,wrap);
end

--print("|T"..icon..":0|t",link,"starts a quest!");
function DropCount.TooltipClass.AddText(tt,text,rtext,size,wrap)
	local ttname=tt:GetName();
	local add=function(lt,rt,li,ri)
		li=(li and "|T"..li..":0|t ") or ""; ri=(ri and " |T"..ri..":0|t") or "";
		if (rt) then tt:AddDoubleLine(li..tostring(lt),tostring(rt)..ri);
		else tt:AddLine(li..tostring(lt),1,1,1,wrap); end
		_G[ttname.."TextLeft"..tt:NumLines()]:SetFont(ttLCFont,size,ttLCFlags);
		if (_G[ttname.."TextRight"..tt:NumLines()]) then _G[ttname.."TextRight"..tt:NumLines()]:SetFont(ttLCFont,size,ttLCFlags); end
	end
	if (type(text)~="table") then add(text,rtext); return; end
	rtext=rtext or {};
	local i=1;
	while(text[i]) do														-- walk list
		if (type(text[i])~="table") then add(text[i],rtext[i]);				-- it's not a table, so add text
		else																-- it's a table
			rtext[i]=rtext[i] or {};
			add(text[i].l or text[i].Ltext,rtext[i].r or rtext[i].Rtext,text[i].licon or text[i].Licon,rtext[i].ricon or rtext[i].Ricon);	-- add potential double text
		end
		i=i+1;
	end
end

-- hooked for setting items at tooltips
function DropCount.Hook.SetBagItem(self,bag,slot)
	local hasCooldown,repairCost=DropCount.Hook.TT_SetBagItem(self,bag,slot);
	local _,item=self:GetItem();
	item=getid(item);
	DropCount.Hook:AddLocationData(self,item);
	DropCount.Hook:AddLootStats(self,item);
	return hasCooldown,repairCost;
end
function DropCount.Hook.SetGuildBankItem(self,tab,slot)
	DropCount.Hook.TT_SetGuildBankItem(self,tab,slot);
	local _,item=self:GetItem();
	item=getid(item);
	DropCount.Hook:AddLocationData(self,item);
	DropCount.Hook:AddLootStats(self,item);
end
function DropCount.Hook.ShowDCTT(frame)
--	if (GameTooltip) then GameTooltip:Hide(); end		-- for future all-purpose usage
--	frame.CreatingFrame=1;
	DropCount.Hook.DCTT_Show(frame);
--_debug("CreatingFrame",frame.CreatingFrame);
end
function DropCount.Hook.HideDCTT(frame)
	DropCount.Hook.DCTT_Hide(frame);
--	frame.CreatingFrame=nil;
--_debug("CreatingFrame",frame.CreatingFrame);
end

-- insert looting stats
function DropCount.Hook:AddLootStats(frame,item)
	if (dccs.NoTooltip or not item) then return; end
	local count,list=0,{};
	count=DropCount.Hook.AddLootStats_Vendor(item);
	if (count>0) then table.insert(list,lBlue.."Vendors: "..count); end
	count=DropCount.Hook.AddLootStats_CreatureLoot(item);
	if (count>0) then table.insert(list,lBlue.."Mob loot: "..count); end
	count=DropCount.Hook.AddLootStats_CreatureProf(item);
	if (count>0) then table.insert(list,lBlue.."Mob prof.: "..count); end
	count=DropCount.Hook.AddLootStats_Gathering(item);
	if (count>0) then table.insert(list,lBlue.."Gather: "..count); end
	-- spew data
	count=1; while(list[count]) do frame:Add(list[count],list[count+1]); count=count+2; end
end

function DropCount.Hook.AddLootStats_Vendor(item)
	local count,faction=0,string.format("r%X:",CONST.MYFACTION:len())..CONST.MYFACTION;
	for k,v in rawpairs(dcdb.Vendor) do
		if (v:find(item,1,true) and v:find(faction,1,true)) then count=count+1; end
	end
	return count;
end
function DropCount.Hook.AddLootStats_CreatureLoot(item)
	local count=0;
	item=dcdb.Item[item]; if (not item or not item.Name) then return 0; end
	for k,v in pairs(item.Name) do count=count+1; end
	return count;
end
function DropCount.Hook.AddLootStats_CreatureProf(item)
	local count=0;
	item=dcdb.Item[item]; if (not item or not item.Skinning) then return 0; end
	for k,v in pairs(item.Skinning) do count=count+1; end
	return count;
end
function DropCount.Hook.AddLootStats_Gathering(item)
	local count=0;
	for k,v in rawpairs(dcdb.Gather.GatherNodes) do
		if (v:find(item,1,true)) then count=count+1; end
	end
	return count;
end

-- insert best looting area in given tooltip
function DropCount.Hook:AddLocationData(frame,item)
	if (dccs.NoTooltip or not item) then return; end
	item=dcdb.Item[item];
	if (item) then
		local best=item.Best or item.BestW;
		if (best) then
			local m,f,s,n=MapPlusNumber_Decode(best);
--			frame:LCAddLine("|cFF9090F8Best known area: "..dcmaps(m)..((s~="" and " - "..s) or "").." at "..n.."%",.6,.6,1,1);	-- 1=wrap text
			frame:Add(hBlue..dcmaps(m)..((s~="" and ", "..s) or "")..": "..n.."%",true);	-- wrap text
		end
		frame:Show();	-- trigger full gametooltip redraw
	end
end

function DropCount:GetQuestNames()
	if (not dcdb.QuestQuery) then return; end
	if (not dccs.DoneQuest) then dccs.DoneQuest={}; end
	-- Remove all that is already okay
	for dqName,dqState in pairs(dccs.DoneQuest) do
		if (type(dqState)=="table") then for queueNum in pairs(dqState) do dcdb.QuestQuery[queueNum]=nil; end
		else dcdb.QuestQuery[dqState]=nil; end
	end
	DropCount.Tracker.ConvertQuests=0;
	for _,_ in pairs(dcdb.QuestQuery) do DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests+1; end
	DropCount.Timer.PrevQuests=3;
end

function DropCount:GetQuestName(link)
	if (not link:find("quest:",1,true)) then return nil; end
	DropCountCacheTooltip:SetParent(WorldFrame);
	DropCountCacheTooltip:SetOwner(WorldFrame, "ANCHOR_NONE"); DropCountCacheTooltip:ClearLines(); DropCountCacheTooltip:SetHyperlink(link);
	local text=_G["DropCountCacheTooltipTextLeft1"]:GetText();
	DropCountCacheTooltip:Hide();
	return text;
end

function DropCountXML.AstrolabeEdge() for _,icon in pairs(mmicons) do if (Astrolabe:IsIconOnEdge(icon)) then icon:SetAlpha(.6); else icon:SetAlpha(1); end end end

function DropCount.Quest:AddLastQG(qGiver)
	if (not dccs.LastQG) then return; end
	local index,found=1,10;
	for index=1,10 do if (dccs.LastQG[index]==qGiver) then found=index; break; end end
	table.remove(dccs.LastQG,found);		-- primitive remove (OOB will silently do nothing)
	table.insert(dccs.LastQG,1,qGiver);		-- primitive insert
end

-- is this lagging now?
function DropCount.Quest:SaveQuest(qName,qGiver)
	if (not qName or not CONST.MYFACTION) then return; end
	if (not dcdb.Quest[CONST.MYFACTION]) then dcdb.Quest[CONST.MYFACTION]={}; end
	local OnlyAddQuest=nil;
	local loc=Location_Code();
	qGiver=strtrim(qGiver or "");
	if (qGiver=="") then
		if (QuestNPCModelNameText:IsVisible()) then					-- the text in the pop-out frame with a 3D model attached to the quest frame
			local fsText=QuestNPCModelNameText:GetText();			-- grab sub-text, most likely name
			if (dcdb.Quest[CONST.MYFACTION][fsText]) then qGiver=fsText; OnlyAddQuest=true; end		-- We have a remote quest with a known quest-giver
		end
		if (strtrim(qGiver)=="") then qGiver="- item - ("..FormatZone(loc,nil,true)..")"; end
	end
	local buf=dcdb.Quest[CONST.MYFACTION][qGiver] or {};
	if (not OnlyAddQuest) then buf._Location_=loc; end
	local qTable={};
	local i=1;
	if (buf.Quests) then
		while (	buf.Quests[i] and ((type(buf.Quests[i])~="table" and buf.Quests[i]~=qName)	-- very old format
				or
				(type(buf.Quests[i])=="table" and buf.Quests[i].Quest~=qName)				-- not the same quest
				) ) do i=i+1; end
	else buf.Quests={}; end
	local newquest=nil;
	if (not buf.Quests[i]) then newquest=true; end
	if (type(buf.Quests[i])~="table") then buf.Quests[i]={}; end
	buf.Quests[i].Quest=qName;

	self:AddLastQG(qGiver);
	while (buf.Quests[i+1]) do							-- It's not the bottom quest
		buf.Quests[i],buf.Quests[i+1]=buf.Quests[i+1],buf.Quests[i];
		newquest=true;
		i=i+1;
	end
	if (newquest) then
		dcdb.Quest[CONST.MYFACTION][qGiver]=buf;
		_debug("debug: "..Basic.."Quest "..Green.."\""..qName.."\""..Basic.." saved for "..Green..qGiver);
	end
end

function DropCount.MT.Quest:Scan()
--_debug(Basic,"Scanning quests...");
	local thislist={};
	if (not dccs.Quests) then dccs.Quests={}; end wipe(dccs.Quests);
	if (dccs.Sheet) then
		-- remove auto-mapped quest items
		for k,v in pairs(dccs.Sheet.Item or {}) do						-- traverse all mapped quest items
			DropCountXML.ClearUnitGridFilter("Item",k,"questitem");
		end
		-- remove auto-mapped quest NPCs
		for k,v in pairs(dccs.Sheet.Creature or {}) do					-- traverse all mapped quest NPCs
			DropCountXML.ClearUnitGridFilter("Creature",k,"questnpc");
		end
	end
	-- Get all current quests
--_debug(Basic,"-- Get all current quests");
	ExpandQuestHeader(0);			-- Expand all quest-headers
	local i=1;
	local lastheader=nil;
	while (GetQuestLogTitle(i)~=nil) do
		local questTitle,_,_,isHeader,_,_,_,questID=GetQuestLogTitle(i);	-- questTitle,level,suggestedGroup,isHeader,isCollapsed,isComplete,frequency,questID,startEvent,displayQuestID,isOnMap,hasLocalPOI,isTask,isStory
		if (not isHeader) then
			MT:Yield(true);
			if (not dccs.Quests[questTitle] or dccs.Quests[questTitle].ID~=tonumber(questID)) then
				dccs.Quests[questTitle]={ ID=tonumber(questID), Header=lastheader, };
				local goal=GetNumQuestLeaderBoards(i) or 0;
				if (goal>0) then
					dccs.Quests[questTitle].Items={};
					local peek,ifound=1,nil;
					while(peek<=goal) do
						local desc,oType,done=GetQuestLogLeaderBoard(peek,i);
						if (oType=="item") then
							local numItems,numNeeded,itemName=desc:match(maskQITEM);
							if (itemName) then
								ifound=true;
								local itemID=getid(itemName,MT.YieldExt);					-- translate to proper itemID, as quests only carry names
								dccs.Quests[questTitle].Items[itemID or itemName]=tonumber(numNeeded);
								-- map quest items
								if (dccs.MapQuestItems and itemName and itemID) then
									DropCountXML.AddUnitToGridFilter("Item",itemName,itemID,nil,"questitem");	-- map item as quest item
								end
						end end
						if (oType=="monster") then
							local _,_,npc=desc:match(maskQNPC);
							if (dccs.MapQuestCreatures and npc) then
								-- map quest NPCs
								DropCountXML.AddUnitToGridFilter("Creature",npc,nil,nil,"questnpc");	-- map npc as quest npc
							end
						end
						peek=peek+1;
						MT:Yield(true);
					end
					if (not ifound) then dccs.Quests[questTitle].Items=nil; end	-- none found, so remove container
			end end
		else lastheader=questTitle; end
		i=i+1;
		ExpandQuestHeader(0);			-- Expand all quest-headers
	end
	if (not DropCount.SpoolQuests) then DropCount.SpoolQuests={}; end
	DropCount.SpoolQuests=copytable(dccs.Quests,DropCount.SpoolQuests);
	-- Book-keeping: Items for each quest
--_debug(Basic,"-- Book-keeping: Items for each quest");
	for quest,qData in pairs(dccs.Quests) do
		MT:Yield();
		if (qData.Items) then
--			-- translate
--			for item,amount in pairs(qData.Items) do
--				MT:Yield(true);
--				nitem=getid(item,MT.YieldExt);			-- translate to proper itemID, as quests only carry names
--				if (nitem) then
--					qData.Items[item]=false;
--					qData.Items[nitem]=amount;
--				end
--			end
--			for item,amount in pairs(qData.Items) do if (qData.Items[item]==false) then qData.Items[item]=nil; end end
			-- add quest to item if not already there
			for item,amount in pairs(qData.Items) do
				MT:Yield(true);
				if (item:find("item:",1,true)) then
					local iData=dcdb.Item[item];		-->> "Ran too long" a couple of times before MT
					if (iData) then
						if (not iData.Quest) then iData.Quest={}; end
						if (not iData.Quest[quest] or iData.Quest[quest]~=amount) then iData.Quest[quest]=amount; dcdb.Item[item]=iData; end
	end end end end end
	-- Shove numbers
--_debug(Basic,"-- Shove numbers");
	i=1;
	if (dcdb.Quest[CONST.MYFACTION]) then
		while(dccs.LastQG[i]) do	-- q-givers list
			local tqg=dcdb.Quest[CONST.MYFACTION][dccs.LastQG[i]];
			if (tqg) then
				local changed=nil;
				if (tqg and tqg.Quests) then				-- Same q-giver from database
					local qi=1;
					while (tqg.Quests[qi] and not changed) do
						MT:Yield(true);
						if (not tqg.Quests[qi].ID) then		-- set (new) quest ID's
							for qname,qnTable in pairs(dccs.Quests) do
								MT:Yield(true);
								if (tqg.Quests[qi].Quest==qname) then tqg.Quests[qi].ID=qnTable.ID; changed=true; end
								if (changed) then break; end	-- This q okay
						end end
						qi=qi+1
				end end
				if (changed) then dcdb.Quest[CONST.MYFACTION][dccs.LastQG[i]]=tqg; end
			end
			i=i+1
	end end
--_debug(Basic,"==> Scan done");
end

-- insert quest headers
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

function DropCount.Tooltip.DCTT_Init(frame,owner)
	owner=owner or UIParent;

--local _p=(WorldMapDetailFrame:IsVisible() and "MT.TheFrameWorldMap") or "UIParent";
--local _o=(owner and owner:GetName()) or tostring(owner);
--local _a=(owner==UIParent and "ANCHOR_CURSOR") or "ANCHOR_TOPLEFT";
--_debug("_p",_p,"_o",_o,"_a",_a);

	frame:ClearLines();
	frame:SetFrameStrata("TOOLTIP");
	frame:SetParent((WorldMapDetailFrame:IsVisible() and MT.TheFrameWorldMap) or UIParent);
--	frame:SetOwner(owner,(owner==UIParent and "ANCHOR_CURSOR") or "ANCHOR_TOPLEFT");
	frame:SetOwner(owner,(owner==UIParent and "ANCHOR_CURSOR") or "ANCHOR_TOPRIGHT");
end

function DropCountXML.OnLeaveIcon(icon)
	DropCountTooltip:Hide();
end

-- WM and MM icons hover
function DropCountXML.OnEnterIcon(icon)
--_debug("DropCountXML:OnEnterIcon(icon)");
--_debug(type(icon.Info.Name),icon.Info.Name,icon.Info.Name:len())
--_debug(type(icon.Info.Units),icon.Info.Units,icon.Info.Units:len())
	if (not icon.Info) then return; end
	local parent=UIParent; if (WorldMapDetailFrame:IsVisible()) then parent=MT.TheFrameWorldMap; end
--	if (not icon.Info.Units:find("+",1,true)) then DropCount:ShowServiceTooltip(icon.Info.Units,parent); return;
	if (not icon.Info.Units:find("+",1,true)) then DropCount:ShowServiceTooltip(icon.Info.Units); return;
	else
--		DropCountTooltip:ClearLines();
----		DropCountTooltip:SetParent(parent);
--		DropCountTooltip:SetOwner(parent,"ANCHOR_CURSOR");
		DropCountTooltip:Init(icon);
		DropCountTooltip:SetText("Contents");
		for _,part in ipairs({strsplit("+",icon.Info.Units)}) do
			DropCountTooltip:Add(DropCount:TranslateService(part));
		end
		DropCountTooltip:Show();
		return;
	end

--	DropCountTooltip:ClearLines();
--	DropCountTooltip:SetOwner(parent,"ANCHOR_CURSOR");
--	DropCountTooltip:SetText(icon.Info.Name);
--	DropCountTooltip:Add(icon.Info.Units:sub(2));
--	DropCountTooltip:Show();
end

-- build dead menu with entries for each service with corresponding tooltips
function DropCountXML.MapIconClicked(icon)
	if (not icon.Info) then return; end
	local menu=DMMenuCreate(icon);
	local added=nil;
	local typ,contents,section;
	-- filtering active, so add removers
	if (dccs.Sheet.Item or dccs.Sheet.Creature) then
		for _,u in ipairs({strsplit("+",icon.Info.Units)}) do
			typ,contents=u:match("^(.)(.+)$"); section=nil;
			if (dccs.Sheet.Creature[contents]) then section="Creature";
			elseif (dccs.Sheet.Item[contents]) then section="Item"; end
			if (section) then
				menu:Add("Remove filter: "..DropCount:TranslateService(u),function() DropCountXML.AddUnitToGridFilter(section,"some name",contents); MT:Run("WM Plot",DropCount.MT.Icons.PlotWorldmap,DropCount.MT.Icons); end,DDT_BUTTON);
				added=true;
			end
		end
	end
	-- multiple units exists in same spot
	if (icon.Info.Units:find("+",1,true)) then
		for _,part in ipairs({strsplit("+",icon.Info.Units)}) do
			menu:Add(DropCount:TranslateService(part),nil,DDT_BUTTON,function(button) DropCount:ShowServiceTooltip(part,button); end);
			added=true;
		end
	end
	if (added) then menu:Show(); end
end

function DropCount:TranslateService(service)
	local typ,contents=service:match("^(.)(.+)$");
	if (typ=="c") then return (dcdb.Count[contents] or {})["Name"] or "Unknown creature"; end
	if (typ=="l") then return (dcdb.Item[contents] or {})["Item"] or "Unknown item"; end
	if (typ=="s") then return (dcdb.Item[contents] or {})["Item"] or "Unknown item"; end
	if (typ=="h") then return "Herb"; end
	if (typ=="o") then return "Ore"; end
	if (typ=="r") then return "Rare: "..((dcdb.Count[contents] or {})["Name"] or "Unknown creature"); end
	if (typ=="b") then return "Book: "..contents; end
	if (typ=="f") then return "Forge"; end
	if (typ=="q") then return "Quest giver: "..contents:sub(2); end
	if (typ=="t") then return ((dcdb.Trainer[CONST.MYFACTION][contents] or dcdb.Trainer.Neutral[contents] or {})["Service"] or "Trainer")..": "..contents; end
	if (typ=="v") then return "Vendor: "..contents; end
	return contents.." ("..typ..")";
end

-- convert hue to red component
local function colour_R(hue)
	hue=hue%360;
	if (hue<60 or hue>=300) then return 1; end
	if (hue>=120 and hue<240) then return 0; end
	if (hue>=240) then return (hue-240)/60; end
	return (119-hue)/60;
end
-- convert hue to green component
local function colour_G(hue)
	hue=hue%360;
	if (hue<120) then return 0; end
	if (hue>=180 and hue<300) then return 1; end
	if (hue<180) then return (hue-120)/60; end
	return (359-hue)/60;
end
-- convert hue to blue component
local function colour_B(hue)
	hue=hue%360;
	if (hue>=240) then return 0; end
	if (hue>=60 and hue<180) then return 1; end
	if (hue<60) then return hue/60; end
	return (239-hue)/60;
end
-- convert hue to rgb
local function hueRGB(hue)
	if (not hue or hue==-1) then return 1,1,1; end				-- special case (rare)
	if (hue==-2) then return 0,0,0,1; end						-- special case (player)
	return colour_R(hue),colour_G(hue),colour_B(hue); end

local function blendspot(m1,m2,list)
	if (not m1 or not m2) then return m1 or m2; end	-- a quickie
	if (m1==m2) then return m1; end				-- a quickie
	if (not list) then list={nil,nil,nil}; end	-- pre-hash to 4
	wipe(list);
	if (m1~="") then for _,m in ipairs({strsplit("+",m1)}) do list[m]=true; end end
	if (m2~="") then for _,m in ipairs({strsplit("+",m2)}) do list[m]=true; end end
	if (not next(list)) then return nil; end	-- nothing
	m1=""; for m in pairs(list) do m1=m1..m.."+"; end
	return m1:sub(1,-2);	-- cut last comma
end

-- intersection of mobs
local function dointersect(m1,m2)
	if (not m1 or not m2) then return nil; end
	local mobs="";
	for _,m in ipairs({strsplit("+",m1)}) do if (m2:find(m,1,true)) then mobs=mobs..m.."+"; end end		-- check every 1 in 2
	if (mobs=="") then return nil; end		-- no intersection
	return mobs:sub(1,-2);	-- cut last delimiter
end

local function equalspot(m1,m2)
	if (not m1 or not m2) then return nil; end
	for _,m in ipairs({strsplit("+",m1)}) do if (not m2:find(m)) then return nil; end end	-- check every 1 in 2
	for _,m in ipairs({strsplit("+",m2)}) do if (not m1:find(m)) then return nil; end end	-- check every 2 in 1
	return true;
end

--	list
--		xxyy = mob,mob,mob
--		xxyy = mob,mob,mob
function DropCount.MT.Icons:CreateSheet(list)
	local oldlist=copytable(list);					-- create work-memory
	local hx,hy,x,y,gx,gy,gs;						-- more work-memory
	local temp={nil,nil,nil};						-- and a pre-hashed work-table
	for spot in pairs(oldlist) do					-- walk all entry-copies and sheetify main data
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
	-- assign colours
	wipe(temp);
	local parts=0;
	for _,service in pairs(list) do if (not temp[service]) then temp[service]=1; parts=parts+1; end MT:Yield(); end
	parts=360/(parts or 1);
	local hue=120;			-- blue
	for service in pairs(temp) do
		if (service:find("r",1,true)==1 or service:find("+r",1,true)) then temp[service]=-1;		-- has a rare mob
		elseif (service:find("p",1,true)==1 or service:find("+p",1,true)) then temp[service]=-2;	-- has a player entry
		else temp[service]=hue; hue=(hue+parts)%360; end
		MT:Yield();
	end
	-- resize sheet pieces
	wipe(oldlist);
	for hy=0,99 do for hx=0,99 do
		local r,g,b,a;
		local spot=xy(hy,hx);
		if (list[spot]) then				-- there's something unhandled here
			local w,h=1,1;
			local sx,sy=xy(spot);			-- get loc
			local tx,ty=sx+1,sy;			-- preset next loc
			local tspot=xy(tx,ty);			-- set test-spot
			-- find first full line
			while(equalspot(list[spot],list[tspot])) do		-- equal, so expandable spot
				list[tspot]=nil;							-- kill spot
				w=w+1;										-- expand left spot to the right
				tx=tx+1; tspot=xy(tx,ty);					-- set next spot
			end
			tx=tx-1;		-- the last broke, so go back
			-- find full lines
			local valid=true;
			repeat
				ty=ty+1;					-- next line
				for scan=sx,tx do
					tspot=xy(scan,ty);		-- set test-spot
					if (not equalspot(list[spot],list[tspot])) then valid=nil; break; end	-- not equal or usable -> not a full line -> we're done here
				end
				if (valid) then
					h=h+1;					-- add one height
					for scan=sx,tx do list[xy(scan,ty)]=nil; end	-- clear base data - width set at first line
				end
			until (not valid);
			r,g,b,a=hueRGB(temp[list[spot]]);
			table.insert(oldlist,"Sheet|"..list[spot].."|"..sx.."|"..sy.."|"..w.."|"..h.."|"..(a or .3).."|"..r.."|"..g.."|"..b.."|Interface\\AddOns\\LootCount_DropCount\\white.tga");
			MT:Yield();
		end
	end MT:Yield(); end				-- hx,hy loops
	wipe(list);						-- wipe old memory
	copytable(oldlist,list);		-- copy data to provided reference
	wipe(oldlist);					-- wipe work-memory
end

function DropCount.MT.Icons:AddIcons_Grid(list,mapID,level,minimal)
	if (not dccs.Sheet) then dccs.Sheet={ Item={}, Creature={}, }; end
	if (not dccs.Sheet.Item) then dccs.Sheet.Item={}; end
	if (not dccs.Sheet.Creature) then dccs.Sheet.Creature={}; end

	local buf=dcdb.Grid[mapID.."_"..level];		-- unpack grid
	if (not buf) then _debug("Missing grid:",mapID.."_"..level); return; end
	local filter=next(dccs.Sheet.Item) or next(dccs.Sheet.Creature);
	if (not DropCount_Local_Code_Enabled and not filter) then return; end				-- unfiltered grid is prohibited
	-- distill mobs
	local allmobs={};																	-- list all mobs
	for _,m in pairs(buf) do for __,sg in ipairs({strsplit(",",m)}) do allmobs[sg]=true; end MT:Yield(); end
	-- lists mobs
	local types={};																		-- list all mobs requested by name
	for m in pairs(allmobs) do
		if (not filter or dccs.Sheet.Creature[m]) then types[m]=true; MT:Yield(); end
	end
	-- list items
	local items={};																		-- list all mobs requested by drop
	for i in pairs(dccs.Sheet.Item or {}) do											-- walk all requested items
		local ibuf=dcdb.Item[i]; if (ibuf) then for sg in pairs(allmobs) do				-- cycle all zone mobs
				if (ibuf.Name and ibuf.Name[sg]) then									-- mob drops item as normal loot
					items[i]=items[i] or {};											-- init item filter
					items[i].n=items[i].n or {};										-- init normal loot list
					table.insert(items[i].n,sg);										-- set mob for normal loot
				end
				if (ibuf.Skinning and ibuf.Skinning[sg]) then							-- mob drops item as profession loot
					items[i]=items[i] or {};											-- init item filter
					items[i].s=items[i].s or {};										-- init profession loot list
					table.insert(items[i].s,sg);										-- set mob for profession loot
				end
				MT:Yield();
	end end end
	-- create entry list
	local part=0;
	for sg in pairs(types) do											-- do all named mobs
		part=part+1;
		for spot,mobs in pairs(buf) do									-- check all known spots
			if (mobs:find(sg)) then
				if (list[spot]) then list[spot]=list[spot].."+"; else list[spot]=""; end
				list[spot]=list[spot].."c"..sg;		-- c Creature
			end
		end
		MT:Yield();
	end
	for i,_ in pairs(items) do											-- do all named items
		part=part+1;
		for spot,mobs in pairs(buf) do									-- check all known spots
			for _,m in ipairs(items[i].n or {}) do							-- do all normal mobs for this item
				if (mobs:find(m)) then
					if (list[spot]) then list[spot]=list[spot].."+"; else list[spot]=""; end
					list[spot]=list[spot].."l"..i;		-- l Loot
				end
			end
			for _,m in ipairs(items[i].s or {}) do						-- do all skinning mobs for this item
				if (mobs:find(m)) then
					if (list[spot]) then list[spot]=list[spot].."+"; else list[spot]=""; end
					list[spot]=list[spot].."s"..i;	 	-- s Skinning
				end
			end
			MT:Yield();
	end end
	wipe(allmobs); wipe(types); wipe(items);		-- done with these
end

function DropCount.MT.Icons:AddIcons_Book(list,mapID,level,minimal)
	if (not mapID or not level) then return; end
	local test=MapTest(mapID,level);
	for book,rawbook in rawpairs(dcdb.Book) do
		if (rawbook:find(test,1,true)) then
			local buf=dcdb.Book[book];
			if (buf[""]) then buf[""]=nil; dcdb.Book[book]=buf; end		-- an old compression-bug clean-up
			for index,bTable in pairs(buf) do
				local _x,_y,_m,_f,_s=Location_Decode(buf[index]);
				if (_m==mapID) then
					table.insert(list,book.."|b"..book.."|".._x.."|".._y.."|0|0|1|1|1|1|Interface\\Spellbook\\Spellbook-Icon");
			end end
			MT:Yield();
	end end
end

function DropCount.MT.Icons:AddIcons_Forge(list,mapID,level,minimal)
	local spot;
	local raw=dcdb.Forge[mapID];
	if (raw) then
		for forge,fRaw in pairs(raw) do
			local x,y=fRaw:match("^(.+)_(.+)$"); x=tonumber(x); y=tonumber(y);
			table.insert(list,"Forge|fF|"..x.."|"..y.."|0|0|1|1|1|1|"..CONST.PROFICON[5]);
	end end
	MT:Yield();
end

function DropCount.MT.Icons:AddIcons_Quest(list,mapID,level,minimal)
	if (not mapID or not level) then return; end
	local test=MapTest(mapID,level);
	local qlevel,r,g,b;
	for npc,nRaw in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
		if (nRaw:find(test,1,true)) then
			local nTable=dcdb.Quest[CONST.MYFACTION][npc];
			if (nTable.Quests) then
				local _x,_y,_m,_f,_s=Location_Decode(nTable._Location_);
				if (_m==mapID and _f==level) then
					qlevel,r,g,b=0,1,1,1;
					for _,qTable in pairs(nTable.Quests) do
						local state=DropCount:GetQuestStatus(qTable.ID,qTable.Quest);
						if (state==CONST.QUEST_NOTSTARTED and qlevel<3) then r,g,b=0,1,0; qlevel=3;
						elseif (state==CONST.QUEST_STARTED and qlevel<2) then r,g,b=1,1,1; qlevel=2;
						elseif (state==CONST.QUEST_DONE and qlevel<1) then r,g,b=0,0,0; qlevel=1;
						elseif (state==CONST.QUEST_UNKNOWN) then r,g,b=1,0,0; qlevel=100; end
					end
					if (qlevel>1 or not minimal) then
						table.insert(list,npc.."|q"..(qlevel%10)..npc.."|".._x.."|".._y.."|0|0|1|"..r.."|"..g.."|"..b.."|Interface\\QuestFrame\\UI-Quest-BulletPoint");
			end end end
			MT:Yield(true);
		end
		MT:Yield();
	end
end

function DropCount.MT:SpecialUsable(item,canyield)
	if (canyield) then												-- we're multi-threading
		if (not GetItemInfo(item)) then								-- unknown item
			DropCount.Cache:AddItem(item);							-- queue for cache
			return nil;
--			canyield=debugprofilestop();
--			while (not GetItemInfo(item) and debugprofilestop()-canyield<10) do MT:Yield(true); end	-- wait for info to arrive
--			if (not GetItemInfo(item)) then return nil; end			-- still nothing, so abort
		end
	end
	local name,link,quality,iLevel,reqLevel,class,subclass,maxStack,equipSlot,texture,vendorPrice=GetItemInfo(item);
	if (maxStack~=1) then return nil; end
	if (equipSlot~="") then return nil; end
	if (iLevel>UnitLevel("player")) then return nil; end
	local p1,p2,p3,p4,p5,p6=GetProfessions();
	local profs=",";
	if (p1) then p1=GetProfessionInfo(p1); profs=profs..p1..","; end
	if (p2) then p2=GetProfessionInfo(p2); profs=profs..p2..","; end
	if (p3) then p3=GetProfessionInfo(p3); profs=profs..p3..","; end
	if (p4) then p4=GetProfessionInfo(p4); profs=profs..p4..","; end
	if (p5) then p5=GetProfessionInfo(p5); profs=profs..p5..","; end
	if (p6) then p6=GetProfessionInfo(p6); profs=profs..p6..","; end
	if (not profs:find(","..subclass..",")) then return nil; end		-- check if any of my own professions match the item subclass
	for _,st in pairs(dccs.Trades or {}) do for known in pairs(st) do
		if (name:find(known,1,true)) then return nil; end	-- the queried item contains a known profession entry completely, so most likely "Recipe: <item-name>"
	end end
	return true;
end

function DropCount.MT.Icons:AddIcons_Vendor(list,mapID,level,minimal)
	if (not mapID or not level) then return; end
	local test=MapTest(mapID,level);
	local vi,vp;
	local filter=(dccs.Filter.VendorItem or dccs.Filter.VendorProfession);
	for vendor,vRaw in rawpairs(dcdb.Vendor) do
		if (vRaw:find(test,1,true) and ((vRaw:find("Neutral",1,true) or vRaw:find(CONST.MYFACTION,1,true)))) then
			if (dccs.Filter.VendorItem) then							-- vendors with a certain item
				vi=nil;
				for k in pairs(dccs.Filter.VendorItem) do
					if (vRaw:find(k,1,true) and dcdb.Vendor[vendor].Items[k]) then
						vi=true; break;
			end end end
			if (dccs.Filter.VendorProfession) then		-- vendors with usable profession items
				vp=nil;
				for k in vRaw:gmatch("(item:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+)") do	-- slow, but does not require unpacking
					if (DropCount.MT:SpecialUsable(k,true)) then vp=true; break; end
			end end
			if (not filter or (dccs.Filter.VendorItem and vi) or (dccs.Filter.VendorProfession and vp)) then
				local buf=dcdb.Vendor[vendor];
				if (buf.Faction=="Neutral" or buf.Faction==CONST.MYFACTION) then
					local _x,_y,_m,_f,_s=Location_Decode(buf._Location_);
					if (_m==mapID and _f==level) then
						table.insert(list,vendor.."|v"..vendor.."|".._x.."|".._y.."|0|0|1|1|1|1|Interface\\GROUPFRAME\\UI-Group-MasterLooter");
			end end end
			MT:Yield(true);
		end
		MT:Yield();
	end
end

-- returns profession icon based on localized profession names
function DropCount:ProfessionIcon(prof)
	for i,p in pairs(CONST.PROFESSIONS) do
		if (p==prof or p:find(prof,1,true) or prof:find(p,1,true)) then return (CONST.PROFICON[i] or "Interface\\Icons\\INV_Misc_QuestionMark"); end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark";
end

function DropCount.MT.Icons:AddIcons_Trainer(list,mapID,level,minimal)
	if (not mapID or not level) then return; end
	local test=MapTest(mapID,level);
	for npc,nRaw in rawpairs(dcdb.Trainer[CONST.MYFACTION]) do
		if (nRaw:find(test,1,true)) then
			local nTable=dcdb.Trainer[CONST.MYFACTION][npc];
			local _x,_y,_m,_f,_s=Location_Decode(nTable._Location_);
			if (_m==mapID and _f==level) then
				table.insert(list,npc.."|t"..npc.."|".._x.."|".._y.."|0|0|1|1|1|1|"..DropCount:ProfessionIcon(nTable.Service));
			end
			MT:Yield(true);
		end
		MT:Yield();
	end
end

function DropCount.MT.Icons:AddIcons_Rare(list,mapID,level,minimal)
	if (not dccs.Sheet) then dccs.Sheet={ Item={}, Creature={}, }; end
	if (not dccs.Sheet.Item) then dccs.Sheet.Item={}; end
	if (not dccs.Sheet.Creature) then dccs.Sheet.Creature={}; end

	local buf=dcdb.Grid[mapID.."_"..level];		-- unpack grid
	if (not buf) then return; end
	-- distill mobs
	local allmobs={};
	for _,m in pairs(buf) do for __,sg in ipairs({strsplit(",",m)}) do allmobs[sg]=true; end MT:Yield(); end
	-- lists mobs
	local types={};
	for m in pairs(allmobs) do
		if (not filter or dccs.Sheet.Creature[m]) then types[m]=true; MT:Yield(true);
	end end
	-- filter out non-rare mobs
	for mob in pairs(types) do
		if (not (dcdb.Count.__DATA__[mob] or ""):find("rare",1,true)) then	-- without unpacking
			local ct=dcdb.Count[mob];
			if (not ct or not ct.C or not ct.C:find("rare",1,true)) then
				types[mob]=nil;
	end end end
	if (not next(types)) then return; end								-- no rare creatures at all
	-- create filtered entry list
	for sg in pairs(types) do											-- do all rares
		for spot,mobs in pairs(buf) do									-- check all known spots
			if (mobs:find(sg)) then
				if (not minimal) then
					if (list[spot]) then list[spot]=list[spot].."+"; else list[spot]=""; end
					list[spot]=list[spot].."r"..sg;			-- r Rare
				else
					local _x,_y=xy(spot);
					table.insert(list,(dcdb.Count[sg].Name or "Unknown creature").."|r"..sg.."|".._x.."|".._y.."|2|2|1|1|1|1|INTERFACE\\Challenges\\ChallengeMode_Medal_Silver");
				end
			end
			MT:Yield();
	end end
	wipe(allmobs); wipe(types);
end

function DropCount.MT.Icons:AddIcons_Herbs(...)
	if (not dcdb.Gather.GatherHERB) then return; end return DropCount.MT.Icons:AddIcons_Gather(dcdb.Gather.GatherHERB,...); end
function DropCount.MT.Icons:AddIcons_Ore(...)
	if (not dcdb.Gather.GatherORE) then return; end return DropCount.MT.Icons:AddIcons_Gather(dcdb.Gather.GatherORE,...); end
function DropCount.MT.Icons:AddIcons_Gather(base,list,mapID,level,minimal)
	local node=(base==dcdb.Gather.GatherHERB and "h") or "o";
	local icon=(base==dcdb.Gather.GatherHERB and CONST.PROFICON[2]) or CONST.PROFICON[3];
	local buf=base[mapID.."_"..level]; if (not buf) then return; end	-- unpack
	local m=DropCount.Painter.maps[mapID.."_"..level];
	local pos=0;					-- bit-position
	local grid=buf.Grid;			-- grab the grid-data
	local i=1;
	local spot;
	repeat
		if (grid:byte(i,i)==0) then i=i+1; pos=pos+(grid:byte(i,i)*8);
		else
			local x,y,skipthis;
			local tmp=grid:byte(i,i);
			for j=1,8 do
				if (bit.band(tmp,1)==1) then
					y,x=xy(pos);		-- NOTE: x/y swap due to TV-type scan
					spot=xy(x,y);		-- create grid-type spot
					if (dccs.Filter.GatherCoverage and m) then
						repeat
							if (y>1) then
								if (x> 1) then skipthis=(m[xy(x-1,y-1)]); if (skipthis) then break; end; end
											   skipthis=(m[xy(x  ,y-1)]); if (skipthis) then break; end;
								if (x<99) then skipthis=(m[xy(x+1,y-1)]); if (skipthis) then break; end; end
							end
							if (x> 1) then skipthis=(m[xy(x-1,y)]); if (skipthis) then break; end; end
										   skipthis=(m[xy(x  ,y)]); if (skipthis) then break; end;
							if (x<99) then skipthis=(m[xy(x+1,y)]); if (skipthis) then break; end; end
							if (y<99) then
								if (x> 1) then skipthis=(m[xy(x-1,y+1)]); if (skipthis) then break; end; end
											   skipthis=(m[xy(x  ,y+1)]); if (skipthis) then break; end;
								if (x<99) then skipthis=(m[xy(x+1,y+1)]); if (skipthis) then break; end; end
							end
						until(true);
					else skipthis=nil; end
					if (not skipthis) then
						if (list[spot]) then list[spot]=list[spot].."+" else list[spot]=""; end
						list[spot]=list[spot]..node..mapID.."_"..level;
					end
				end
				MT:Yield();
				tmp=bit.rshift(tmp,1);
				pos=pos+1;
		end end
		i=i+1;
	until(i>grid:len());
end

function DropCount.MT.Icons:AddIcons_Paint(list,mapID,level,minimal)
	for pos in pairs(DropCount.Painter.maps[mapID.."_"..level] or {}) do
		if (list[pos]) then list[pos]=list[pos].."+" else list[pos]=""; end
		list[pos]=list[pos].."pP";	-- constant (player)
	end
end

function DropCount.MT.Icons:BuildIconList_MM(mapID,level)
	wipe(mmlist);
	-- add singles
	if (dcdb.RareMinimap) then self:AddIcons_Rare(mmlist,mapID,level,true); end
	if (dcdb.BookMinimap) then self:AddIcons_Book(mmlist,mapID,level,true); end
	if (dcdb.ForgeMinimap) then self:AddIcons_Forge(mmlist,mapID,level,true); end
	if (dcdb.QuestMinimap and dcdb.Quest[CONST.MYFACTION]) then self:AddIcons_Quest(mmlist,mapID,level,true); end
	if (dcdb.VendorMinimap or dcdb.RepairMinimap) then self:AddIcons_Vendor(mmlist,mapID,level,true); end
	if (dcdb.TrainerMinimap and dcdb.Trainer[CONST.MYFACTION]) then self:AddIcons_Trainer(mmlist,mapID,level,true); end
end

--	slow code (slightly better (useable?) as of 21.12.2014)
function DropCount.MT.Icons:PlotMinimap()
	local r,g,b=1,1,1;
	if (dccs.Filter.VendorItem) then r,g,b=1,0,0; end
	if (dccs.Filter.VendorProfession) then r,g,b=1,0,0; end
	DropCount_MinimapIcon_ButtonIcon:SetVertexColor(r,g,b,1);
	local mapID,floorNum=CurrentMap();
	local here=GetRealZoneText(); if (not here) then here=" "; end					-- locale name
	if (not dcmaps[GetLocale()]) then dcmaps[GetLocale()]={}; end					-- verify shadow registry
	if (dcmaps[GetLocale()][mapID]~=here) then dcmaps[GetLocale()][mapID]=here; end	-- update if not equal
	DropCount.MT.Icons:BuildIconList_MM(mapID,floorNum);
	for _,icon in pairs(mmicons) do Astrolabe:RemoveIconFromMinimap(icon); end
	local index=1;
	for spot,contents in pairs(mmlist) do
		if (not mmicons[index]) then
			mmicons[index]=CreateFrame("Button",nil,UIParent,"DropCount_MapIcon");
			mmicons[index].icon=mmicons[index]:CreateTexture("ARTWORK");
			mmicons[index]:SetFrameStrata("MEDIUM");
			mmicons[index].Info={};
		end
		local name,service,x,y,_,_,a,r,g,b,icon=strsplit("|",contents);
		x=tonumber(x); y=tonumber(y);
--		w=tonumber(w); w=CONST.WMSQ_W*((w~=0 and w) or (12/CONST.WMSQ_W));
--		h=tonumber(h); h=CONST.WMSQ_H*((h~=0 and h) or (12/CONST.WMSQ_H));
		a=tonumber(a); r=tonumber(r); g=tonumber(g); b=tonumber(b);
		mmicons[index].icon:SetTexture(icon);
		mmicons[index].icon:SetVertexColor(r,g,b,a);
		mmicons[index].icon:SetAllPoints();
		mmicons[index].Info.Name=name;
		mmicons[index].Info.Units=service;
		Astrolabe:PlaceIconOnMinimap(mmicons[index],mapID,floorNum,x/100,y/100);
		index=index+1;
		MT:Yield(true);		-- better slow than choppy
	end
end

function DropCount.MT.Icons:BuildIconList_WM(mapID,level)
	wipe(wmlist);
	-- add sheetables
--	if (dcdb.GridWorldmap and dcdb.Grid[mapID.."_"..level]) then self:AddIcons_Grid(wmlist,mapID,level,nil); end	-- Grid
	self:AddIcons_Grid(wmlist,mapID,level,nil);		-- Grid
	if (dcdb.RareWorldmap) then self:AddIcons_Rare(wmlist,mapID,level,nil); end	-- Rare creatures
	if (dcdb.HerbWorldmap) then self:AddIcons_Herbs(wmlist,mapID,level,nil); end	-- gathering profession
	if (dcdb.OreWorldmap) then self:AddIcons_Ore(wmlist,mapID,level,nil); end	-- gathering profession
	if (dccs.Filter.ShowMovement) then self:AddIcons_Paint(wmlist,mapID,level,nil); end	-- gathering profession
	self:CreateSheet(wmlist);		-- convert to proper indexed list
	-- add singles
	if (dcdb.BookWorldmap) then self:AddIcons_Book(wmlist,mapID,level,nil); end	-- Book
	if (dcdb.ForgeWorldmap) then self:AddIcons_Forge(wmlist,mapID,level,nil); end	-- Forge
	if (dcdb.QuestWorldmap and dcdb.Quest[CONST.MYFACTION]) then self:AddIcons_Quest(wmlist,mapID,level,nil); end	-- Quest
	if (dcdb.VendorWorldmap or dcdb.RepairWorldmap) then self:AddIcons_Vendor(wmlist,mapID,level,nil); end	-- Vendor
	if (dcdb.TrainerWorldmap and dcdb.Trainer[CONST.MYFACTION]) then self:AddIcons_Trainer(wmlist,mapID,level,nil); end	-- Trainer
end

function DropCount.MT.Icons:PlotWorldmap()
	if (not WorldMapDetailFrame) then return; end
	local mapID,floorNum=GetCurrentMapAreaID(),GetCurrentMapDungeonLevel();		-- from map, not player location
	DropCount.MT.Icons:BuildIconList_WM(mapID,floorNum);
	for _,icon in pairs(wmicons) do icon:Hide(); end
	local wmfs=WorldMapDetailFrame:GetFrameStrata();
	local wmifs="MEDIUM";
	if (wmfs=="MEDIUM") then wmifs="HIGH";
	elseif (wmfs=="HIGH") then wmifs="DIALOG";
	elseif (wmfs=="DIALOG") then wmifs="FULLSCREEN";
	elseif (wmfs=="FULLSCREEN") then wmifs="FULLSCREEN_DIALOG";
	elseif (wmfs=="FULLSCREEN_DIALOG") then wmifs="TOOLTIP"; end
	local index=1;
	for spot,contents in pairs(wmlist) do
		if (not wmicons[index]) then
			wmicons[index]=CreateFrame("Button",nil,WorldMapDetailFrame,"DropCount_MapIcon");
			wmicons[index].icon=wmicons[index]:CreateTexture("ARTWORK");
			wmicons[index].Info={};
		end
		wmicons[index]:SetFrameStrata(wmifs);
		local name,service,x,y,w,h,a,r,g,b,icon=strsplit("|",contents);
		x=tonumber(x); y=tonumber(y);
		w=tonumber(w); w=CONST.WMSQ_W*((w~=0 and w) or (12/CONST.WMSQ_W));
		h=tonumber(h); h=CONST.WMSQ_H*((h~=0 and h) or (12/CONST.WMSQ_H));
		a=tonumber(a); r=tonumber(r); g=tonumber(g); b=tonumber(b);
		wmicons[index]:SetWidth(w);
		wmicons[index]:SetHeight(h);
		wmicons[index].icon:SetTexture(icon);
		wmicons[index].icon:SetVertexColor(r,g,b,a);
		wmicons[index].icon:SetAllPoints();
		wmicons[index].Info.Name=name;
		wmicons[index].Info.Units=service;
		Astrolabe:PlaceIconOnWorldMap(	WorldMapDetailFrame,
										wmicons[index],
										mapID,
										floorNum,
										(x/100)+((w/2)/CONST.WM_W),
										(y/100)+((h/2)/CONST.WM_H));
		index=index+1;
		MT:Yield();
	end
end

function DropCount:ReadMerchant(dude)
	local rebuildIcons=nil;
	local numItems=GetMerchantNumItems();
	if (not numItems or numItems<1) then return true; end
	local vData=dcdb.Vendor[dude];
	if (not vData) then vData={ Items={} }; rebuildIcons=true; chat(Basic.."DropCount:|r "..Green.."New vendor added to database|r"); end
	vData._Location_=Location_Code();				-- set current position
	vData.Repair=_G.MerchantRepairAllButton:IsVisible();
	vData.Faction=DropCount.Target.LastFaction;
	-- Remove all permanent items
	if (vData.Items) then
		for item,avail in pairs(vData.Items) do
			if (avail==0 or avail==CONST.PERMANENTITEM) then vData.Items[item]=nil; end
	end end
	-- Add all items
	local ReadOk,index=true,1;
	while (index<=numItems) do
		local link=GetMerchantItemLink(index);
		link=getid(link);
		if (link) then
			local itemName,itemLink=GetItemInfo(link);
			local _,_,_,_,count=GetMerchantItemInfo(index);			-- count==-1 unlimited
			if (not vData.Items) then vData.Items={}; end
			vData.Items[link]=count;
			if (not dcdb.Item[link]) then dcdb.Item[link]={ Item=itemName, }; end	-- add to item database (undropped)
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

function DropCount:GetPlayerPosition()
	local posX,posY=GetPlayerMapPosition("player"); return (floor(posX*100000))/1000,(floor(posY*100000))/1000; end

function DropCount:AddKill(oma,GUID,sguid,mob,reservedvariable,noadd,notransmit,_)
	if (not mob and not sguid) then return; end
	-- Check if already counted
	local i=DropCount.Tracker.QueueSize;
	while (i>0) do if (DropCount.Tracker.TimedQueue[i].GUID==GUID) then return; end i=i-1; end
	local now=time();
	local mTable=dcdb.Count[sguid] or { Kill=0, Name=mob };
	-- name exists already, and one is also supplied, and they are not equal. (could be locale changed or other database follow-problem)
	-- name in registry can be changed directly as the entry key stays the same
	if (type(mob)=="string" and type(mTable.Name)=="string" and mTable.Name~=mob) then
		_debug(Basic.."debug: "..Yellow..mTable.Name..Basic.." renamed to "..Yellow..mob);
		mTable.Name=mob;
	end
	if (not mTable.Name) then mTable.Name=mob; end
	if (sguid==DropCount.Target.ClassificationSGUID and DropCount.Target.Classification~="normal") then mTable.C=DropCount.Target.Classification; end
	if (not noadd) then
		if (not mTable.Kill) then mTable.Kill=0; end
		mTable.Kill=mTable.Kill+1;
		dcdb.Count[sguid]=mTable;
		if (not nagged) then		-- tell about the milestone. send tha stuff!
			if (mTable.Name and (mTable.Kill==50 or mTable.Kill%100==0)) then
				chat(Basic.."DropCount: "..Yellow..mTable.Name..Basic.." has been killed "..Yellow..mTable.Kill..Basic.." times!");
				chat(Basic.."Please consider submitting your SavedVariables file at "..Yellow.."ducklib.com -> DropCount"..Basic..", or sending it to "..Yellow.."dropcount@ducklib.com"..Basic.." to help develop the DropCount addon.");
				nagged=true;
		end end
	else dcdb.Count[sguid]=mTable; return; end
	DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize+1;
	table.insert(DropCount.Tracker.TimedQueue,1,{Mob=sguid,GUID=GUID,Oma=oma,Time=now,KillZone=Map_Code()});
	_debug("TimedQueue size:",DropCount:Length(DropCount.Tracker.TimedQueue));
	if (DropCount.Tracker.QueueSize>=10) then
		MT:Run("MM Update Best "..DropCount.Tracker.TimedQueue[10].Mob,DropCount.MT.UpdateBest,DropCount.MT);
	end
end

--		SLOW CODE (slowish, but mostly useable after quest item cache)
--		A lot better after 21.12.2014 yield tweaks
-- update best areas
function DropCount.MT:UpdateBest()
	local mDB=dcdb.Count[DropCount.Tracker.TimedQueue[10].Mob];
	local zone=DropCount.Tracker.TimedQueue[10].KillZone;
	if (mDB and zone) then
		local list=DropCount.MT:BuildItemList(DropCount.Tracker.TimedQueue[10].Mob);
		for item,percent in pairs(list) do
			MT:Yield(true);
			local iDB=dcdb.Item[item];
MT:Yield(true);				-- double to decrease lag
			local store=nil;
			local m,f,s,n=MapPlusNumber_Decode(iDB.Best);
			if (not m or percent>n or zone==Map_Code(m,f,s)) then iDB.Best=zone.."_"..tostring(percent); store=true; end
			if (not IsInInstance()) then
				m,f,s,n=MapPlusNumber_Decode(iDB.BestW);
				if (not m or percent>n or zone==Map_Code(m,f,s)) then iDB.BestW=zone.."_"..tostring(percent); store=true; end
			end
			if (store) then
				if (iDB.Best==iDB.BestW) then iDB.BestW=nil; end
				dcdb.Item[item]=iDB;
	end end end
end

function DropCount.MT:BuildItemList(mob)
	local list={};
	local slow=0;
	for item,iData in rawpairs(dcdb.Item) do
		slow=slow+1;
		MT:Yield(slow==100);					-- this helps a lot for "Update Best". possibly releasable.
		if (slow==100) then slow=0; end
		if (iData:find(mob,1,true)) then
--			if (not list[item]) then
				list[item]=floor(DropCount:TimedQueueRatio(item)*100);
				if (list[item]<0) then list[item]=nil; end
--			end
			MT:Yield(true);
		end
	end
	return list;
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

--DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count); end
function DropCount:AddLoot(GUID,sguid,mob,item,count,notransmit)
--_debug(GUID,sguid,mob,item,count,notransmit);
	local now,iTable=time(),dcdb.Item[item];
	if (not iTable) then iTable={}; end
	local itemName,itemLink=GetItemInfo(item);
	iTable.Item=itemName; iTable.Time=now;				-- Last point in time for loot of this item
	dcdb.Item[item]=iTable;
	DropCount:AddLootMob(GUID,sguid,mob,item);			-- Make register
	iTable=dcdb.Item[item];
	local skinning,nameTable;
--_debug(DropCount.ProfessionLootMob);
	if (DropCount.ProfessionLootMob) then nameTable=iTable.Skinning; skinning=true;
	else nameTable=iTable.Name; end
--_debug(DropCount.Target.UnSkinned);
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
	if (not item) then return 0,0; end
	if (CONST.QUESTID) then
		local _,_,_,_,_,itemtype=GetItemInfo(item);
		local _,itemID=getid(item);
		if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then return CONST.QUESTRATIO,CONST.QUESTRATIO; end
	end
	local iTable=dcdb.Item[item];
	if (not iTable) then return 0,0,true; end				-- no such item
	if (not dcdb.Count[sguid]) then return 0,0,true; end	-- no such dude
	if (not iTable.Name and not iTable.Skinning) then return 0,0,true; end	-- nothing
	local nKills,nRatio,sKills,sRatio=0,0,0,0;
	local mTable=dcdb.Count[sguid];
	if (iTable.Name) then
		nKills=mTable.Kill;
		if (nKills and nKills>0 and iTable.Name[sguid]) then
			nRatio=iTable.Name[sguid]/nKills;
			if (iTable.Name[sguid]<2) then unsafe=true; end
	end end
	if (iTable.Skinning) then
		sKills=mTable.Skinning;
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
			if (not inqueue[DropCount.Tracker.TimedQueue[i].Mob]) then
				local drop,sD=DropCount:GetRatio(item,DropCount.Tracker.TimedQueue[i].Mob);		-- fast call - no iteration inside - one item and one mob read
				if (not drop or drop==0) then drop=sD; end
				inqueue[DropCount.Tracker.TimedQueue[i].Mob]={ Count=1, Ratio=drop };
			else
				inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count=inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count+1;
			end
			if (not noyield) then MT:Yield(true); end
		end
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
	return ((UnitName("playertarget") and "playertarget") or (UnitName("focus") and "focus")) or nil; end

function DropCount:GetRatioColour(ratio)
	if (not ratio) then ratio=0; end
	if (ratio>1) then ratio=1; elseif (ratio<0) then ratio=0; end
	ratio=string.format("|cFF%02X%02X%02X",128+(ratio*127),128+(ratio*127),128+(ratio*127));		-- AARRGGBB
	return ratio;
end

-- Create list of vendors that carry this item
function DropCount.Tooltip:VendorList(button,getlist)
	if (not dcdb.Converted) then chat(Red.."The DropCount database is currently being converted to the new format. Your data will be available when this is done.|r"); return; end
	if (type(button)=="string") then button={ FreeFloat=true, User={ itemID=button, }, };
	elseif (not button.User or not button.User.itemID) then return; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (not getlist) then
		if (button.FreeFloat) then GameTooltip:Init(UIParent); else GameTooltip:Init(button); end
		GameTooltip:SetText(colour.."["..itemname.."]|r");
	end
	local list,line,droplist={},1,0;
	local ThisZone=MapTest(Map_Decode(Map_Code()));						-- create tester string for current area
	local items;
	for vendor,vTable in rawpairs(dcdb.Vendor) do
		if (vTable and vTable:find(button.User.itemID,1,true)) then
			vTable=dcdb.Vendor[vendor];		-- get it
			if (vTable) then
				items=vTable.Items;
				if (type(items)=="string") then items=dcdb.VendorItems[items] or {}; end
				if (vTable and items[button.User.itemID]) then
					list[line]={};
					local zone=lBlue;
					if (vTable._Location_ and vTable._Location_:find(ThisZone,1,true)==1) then zone=hBlue; end
					local _x,_y,_m=Location_Decode(vTable._Location_);
					zone=zone..dcmaps(_m).." - "..floor(_x or 0)..","..floor(_y or 0).."|r";
					list[line].Ltext=zone.." : "..Yellow..vendor.."|r ";
					list[line].Rtext="";
					if (type(items[button.User.itemID])) then
						if (items[button.User.itemID]>=0) then list[line].Rtext=Red.."*|r";
						elseif (items[button.User.itemID]==CONST.UNKNOWNCOUNT) then list[line].Rtext=Yellow.."*|r";
					end end
					line=line+1;
				end
	end end end
	list=DropCount:SortByNames(list);
	if (getlist) then return copytable(list); end
	if (line==1) then GameTooltip:Add("No known vendors");
	else GameTooltip:Add(list); end
	GameTooltip:Show();
	return true;
end

-- create a list of mobs that drops the item in question
function DropCount.Tooltip:MobList(button,plugin,limit,down,highlight)
	if (type(button)=="string") then							-- link supplied
		button={ FreeFloat=true, User={ itemID=button, } };
	elseif (not button.User or not button.User.itemID) then		-- LootCount button?
--		GameTooltip:Init(button);
		GameTooltip:SetText("Drop an item here");
		GameTooltip:Show();
		return;
	end
	if (not dcdb.Item[button.User.itemID]) then return; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR"); else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
	local iTable=dcdb.Item[button.User.itemID];
	local skinningdrop=iTable.Skinning;
	local normaldrop=iTable.Name;
	local scrap=colour.."["..Highlight(itemname,highlight,colour).."]|r:";
	if (dccs.CompactView) then
		if (skinningdrop) then if (normaldrop) then scrap=scrap.." (L/"..Purple.."P|r)"; else scrap=scrap.." ("..Purple.."P|r)"; end end
	end
	GameTooltip:SetText(scrap);
	if (not dccs.CompactView) then
		if (skinningdrop) then
			if (normaldrop) then scrap=White.."Loot and "..Purple.."profession"; else scrap=Purple.."Profession"; end
			GameTooltip:Add(scrap);
	end end
	if (iTable.Best) then
		local area,pct=FormatBest(iTable.Best);
		local areaW,pctW=FormatBest(iTable.BestW);
		if (not dccs.CompactView) then
			GameTooltip:Add(Basic.."Best drop-area:",Basic..Highlight(area,highlight,Basic).." ("..pct.."\%)");
			if (iTable.BestW) then GameTooltip:Add(" ",Basic..Highlight(areaW,highlight,Basic).." ("..pctW.."\%)"); end
		else
			GameTooltip:Add(Basic..Highlight(area,highlight,Basic).." ("..pct.."\%)");
			if (iTable.BestW) then GameTooltip:Add(Basic..Highlight(areaW,highlight,Basic).." ("..pctW.."\%)"); end
	end end
	-- Do normal loot
	local list,line,droplist,unnamed={},1,0,0;
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
			local isGUID=(mob:match("^%x+$") and true) or nil;
			local mTable=dcdb.Count[mob];									-- grab this mob's numbers
			if (not mTable) then DropCount:RemoveFromItems("Name",mob);		-- no such mob, wipe from database
			elseif (isGUID and not mTable.Name and not dccs.ShowUnnamedMobs) then		-- don't show unnamed mobs
				unnamed=unnamed+1;
			else
				list[line].Count=mTable.Kill or 0;							-- set number of loots
				local saturation=((high-low)/(CONST.KILLS_RELIABLE-CONST.KILLS_UNRELIABLE))*list[line].Count;	-- color me safe
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);	-- AARRGGBB, desaturated red, saturated green, no blue
				list[line].ratio=DropCount:GetRatio(button.User.itemID,mob);	-- normal loot mob/item ratio
				local mobName=mTable.Name or mob;
				list[line].Ltext=colour..pretext..Highlight(mobName,highlight,colour).."|r: ";
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

			local isGUID=(mob:match("^%x+$") and true) or nil;
			local mTable=dcdb.Count[mob];
			if (not mTable) then DropCount:RemoveFromItems("Skinning",mob);
			elseif (isGUID and not mTable.Name and not dccs.ShowUnnamedMobs) then		-- don't show unnamed mobs
				unnamed=unnamed+1;
			else
				dlist[dline].Count=mTable.Skinning or 0;					-- set number of skinnings
				local saturation=((high-low)/(CONST.KILLS_RELIABLE-CONST.KILLS_UNRELIABLE))*dlist[dline].Count;	-- color me safe
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);	-- AARRGGBB, desaturated red, saturated green, no blue
				_,dlist[dline].ratio=DropCount:GetRatio(button.User.itemID,mob); -- skinning loot mob/item ratio
				local mobName=mTable.Name or mob;
				dlist[dline].Ltext=colour..pretext..Highlight(mobName,highlight,colour).."|r: ";
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
			GameTooltip:Add(list[line].Ltext,list[line].Rtext);
			if (not list[line].Show) then count=count+1; end	-- Count all normal entries
		else
			if (list[line].Count<limit) then lowKill=lowKill+1; end
			supressed=supressed+1;
		end
		line=line+1;
	end
	if (unnamed>0) then
		if (supressed>0) then GameTooltip:Add(lPurple..supressed.." additional named creatures"); end
		GameTooltip:Add(lPurple..unnamed.." unnamed mobs hidden");
	elseif (supressed>0) then GameTooltip:Add(lPurple..supressed.." additional creatures"); end
	GameTooltip:Show();
	return true;
end

-- do repeated tests with increasing demands to number of kills/loots ("low").
-- this will remove those with fewer kills
-- stop when list is sufficiently short with said demands.
-- return kill-count demand for said list
function DropCount:FindListLowestByLength(list,length)
	list=copytable(list);			-- detach from original list
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
		if (not tonumber(entry,16)) then o=o+1;					-- not seen
		elseif (not raw:find("r4:Namer",1,true)) then m=m+1;	-- nameless
		else n=n+1; end											-- all good
	end
	chat(Yellow..tonumber(o)..Red.." old "..Basic.."name format");
	chat(Yellow..tonumber(m)..Green.." new "..Basic.."name format, "..hBlue.."missing "..Basic.."name");
	chat(Green..tonumber(n).." new "..Basic.."name format");
end

function DropCount:GetQuestStatus(qId,qName)
	local Dark="|cFF808080";
	if (not qName) then return CONST.QUEST_UNKNOWN,White; end
	if (not dcdb.Quest) then return CONST.QUEST_UNKNOWN,White; end
	-- Check running quests
	if (dccs.Quests) then
		if (dccs.Quests[qName]) then
			if (dccs.Quests[qName].ID) then if (dccs.Quests[qName].ID==qId) then return CONST.QUEST_STARTED,Yellow; end
			else return CONST.QUEST_STARTED,Red; end
	end end
	-- Maybe it's done
	if (dccs.DoneQuest) then
		if (dccs.DoneQuest[qName]) then
			if (dccs.DoneQuest[qName]==qId) then return CONST.QUEST_DONE,Dark;		-- I've done it
			else return CONST.QUEST_DONE,Dark; end		-- I've done it
	end end
	return CONST.QUEST_NOTSTARTED,Green;
end

-- indexed - q Quest    - status+textual name (db key) -> status: 3=not started, 2=started, 1=done, 0=unknown status
function DropCount.Tooltip:QuestList(faction,npc,parent)
	local status,service=0,npc;		-- status=0, service=npc
	local nTable=dcdb.Quest[faction][npc] or {};									-- try service and faction as provided
	if (not nTable.Quests) then nTable=dcdb.Quest["Neutral"][npc] or {};			-- try service and neutral faction
		if (not nTable.Quests) then
			status,npc=service:match("^(.)(.+)$"); status=tonumber(status);			-- split service into status and name
			nTable=dcdb.Quest[faction][npc] or {};									-- try name and faction
			if (not nTable.Quests) then nTable=dcdb.Quest["Neutral"][npc] or {};	-- try name and neutral faction
				if (not nTable.Quests) then return; end								-- nothing panned out
	end end end
	parent=parent or UIParent;
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText(npc);
	if (dcdb.Vendor[npc]) then DropCountTooltip:AddSmall(dYellow.."Vendor available"); end
	for _,qData in pairs(nTable.Quests) do
		local quest,header,id=qData.Quest,qData.Header or "",qData.ID;
		local _,colour=DropCount:GetQuestStatus(id,quest);
		DropCountTooltip:Add("  "..colour..quest,colour..header);
	end
	DropCountTooltip:Show();
	return true;
end

-- called when mouseover for gather map icons
function DropCount.Tooltip:Node(obj,parent,all)
	obj=tonumber(obj);
	local objt=dcdb.Gather.GatherNodes[obj]; if (not objt or not objt.Loot) then return; end	-- no node, or a different kind (like Glowcap wich is same-named item and object)
	if (not parent) then parent=UIParent; end
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText(objt._Name);
	if (all) then
		local data,base,list,listname;
		local ore,herb={},{};
		base=dcdb.Gather.GatherORE;
		list=ore; listname="Ore"
		for i=1,2 do
			for k,v in rawpairs(base) do
				if (v:find(tostring(obj),1,true)) then
					data=base[k];
					if (data.OID[obj]) then
						list[k]=data.OID[obj]/data.Gathers;
					end
				end
			end
			if (next(list)) then
				DropCountTooltip:AddSmall(" "); DropCountTooltip:AddSmall(hBlue..listname);
				for k,v in pairs(list) do
					local map,level=k:match("^(%d+)_(%d+)$");
					if (map and level) then
						map=tonumber(map); level=tonumber(level);
						local text=" ".." ".." ".." "..DropCount:GetRatioColour(v)..floor(v*100).."% |r"..dcmaps(map);
						if (level~=0) then text=text..", floor "..level; end
						DropCountTooltip:AddSmall(text);
					end
				end
			end
			if (base==dcdb.Gather.GatherORE) then
				base=dcdb.Gather.GatherHERB;
				list=herb; listname="Herb"
			end
		end
	end
	-- the monitor will add the node breakdown
	DropCountTooltip:Show();	-- recalc size
	return true;
end

-- called when mouseover for grid map icons
-- supplied is a string of comma-separated sguid looted in this location
function DropCount.Tooltip:Grid_C(typ,sguid,parent)
	local droplist,skinlist={},{};
	local gotmobs=nil;
	for item,iData in rawpairs(dcdb.Item) do						-- cycle all items
--		if (sguid:len()==4 and iData:find(sguid,1,true)) then		-- plain search for mob sguid
		if (iData:find(sguid,1,true)) then							-- plain search for mob sguid
			gotmobs=true;
			local iTable=dcdb.Item[item];							-- read data for proper test
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
					if (questitem) then colour=Yellow; end			-- override with yellow quest colour
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
	end end end end
	-- build tooltip
	local emptyline=nil;
	local anc="ANCHOR_CURSOR";
	if (not parent or parent==UIParent) then parent=UIParent;
	elseif (parent==PlayerFrame) then anc="ANCHOR_BOTTOMLEFT"; end
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText((typ=="c" and "Creature") or "Rare creature");
	if (gotmobs) then
		if (dcdb.Count[sguid]) then DropCountTooltip:AddSmall(dcdb.Count[sguid].Name or sguid); end
		emptyline=true;
	end
	if (next(droplist)) then
		if (emptyline) then DropCountTooltip:AddSmall(" "); end
		DropCountTooltip:AddSmall("Drop");
		for _,txt in pairs(droplist) do DropCountTooltip:AddSmall("    "..txt); end
		DropCountTooltip:AddSmall(Basic.."    (Single dropped items skipped)");
		emptyline=true;
	end
	if (next(skinlist)) then
		if (emptyline) then DropCountTooltip:AddSmall(" "); end
		DropCountTooltip:AddSmall("Profession drop");
		for _,txt in pairs(skinlist) do DropCountTooltip:AddSmall("    "..txt); end
		emptyline=true;
	end
	DropCountTooltip:Show();
	return true;
end

function DropCount.Tooltip:Grid_I(typ,item,parent)
	local anc="ANCHOR_CURSOR";
	if (not parent) then parent=UIParent; elseif (parent==PlayerFrame) then anc="ANCHOR_BOTTOMLEFT"; end
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetHyperlink(item);
	DropCountTooltip:Show();
	return true;
end

function DropCount.Tooltip:Grid_G(typ,map,parent)
	if (not dcdb.Gather.GatherNodes) then return; end	-- broken
	if (typ~="h" and typ~="o") then return; end			-- something unknown
	if (not parent) then parent=UIParent; end
	-- build tooltip
	DropCountTooltip:Init(parent);
	if (typ=="h") then DropCountTooltip:SetText("Herb"); map=dcdb.Gather.GatherHERB[map];
	elseif (typ=="o") then DropCountTooltip:SetText("Ore"); map=dcdb.Gather.GatherORE[map]; end
	for oid,count in pairs(map.OID) do
		if (not dcdb.Gather.GatherNodes[oid] or not dcdb.Gather.GatherNodes[oid]._Name) then return; end	-- broken data
		DropCountTooltip:Add(dcdb.Gather.GatherNodes[oid]._Name,DropCount:FormatPst(count/map.Gathers,"%"));
	end
	DropCountTooltip:Show();
	return true;
end

function DropCount.Tooltip:Forge(service,parent)
	if (not dcdb.Gather.GatherNodes) then return; end	-- broken
	if (not parent) then parent=UIParent; end
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText("Forge");
	DropCountTooltip:Show();
	return true;
end

function DropCount.Tooltip:Trainer(faction,service,parent)
	local buf=dcdb.Trainer[faction][service];
	if (not buf) then buf=dcdb.Trainer.Neutral[service]; if (not buf) then return; end end
	if (not parent) then parent=UIParent; end
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText("Trainer: "..(buf.Service or "Unknown profession"));
	DropCountTooltip:Add(service);
	DropCountTooltip:Show();
	return true;
end

-- argument is a single service denominator
function DropCount:ShowServiceTooltip(service,parent)
--_debug("DropCount:ShowServiceTooltip(service,parent)");
	local typ; typ,service=service:match("^(.)(.+)$");
	if (typ=="c" or typ=="r") then DropCount.Tooltip:Grid_C(typ,service,parent); return; end	-- creature normal/rare
	if (typ=="l" or typ=="s") then DropCount.Tooltip:Grid_I(typ,service,parent); return; end	-- item loot/skinning
	if (typ=="h" or typ=="o") then DropCount.Tooltip:Grid_G(typ,service,parent); return; end	-- gather herb/ore
	if (typ=="b") then DropCount.Tooltip:Book(service,parent); return; end						-- book
	if (typ=="f") then DropCount.Tooltip:Forge(service,parent); return; end						-- forge
	if (typ=="q") then DropCount.Tooltip:QuestList(CONST.MYFACTION,service,parent); return; end	-- quest-giver
	if (typ=="t") then DropCount.Tooltip:Trainer(CONST.MYFACTION,service,parent); return; end	-- trainer
	if (typ=="v") then DropCount.Tooltip:Vendor(service,parent); return; end					-- vendor
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
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText("Book");
	DropCountTooltip:Add(book);
	DropCountTooltip:Add(bStatus);
	DropCountTooltip:Show();
	return true;
end

-- lists items this vendor carries
function DropCount.Tooltip:Vendor(unit,parent,force)
	local vData=dcdb.Vendor[unit];
	if (not vData or not vData.Items) then return; end
	if (not parent) then parent=UIParent; end

	local list={};
	local line=1;
	local missingitems,itemsinlist,item,iTable=0;
	local items=vData.Items;
	if (type(items)=="string") then
		items=dcdb.VendorItems[items] or {};
	end
	for item,iTable in pairs(items) do
		local itemname,_,rarity=GetItemInfo(item);
		if (not itemname or not rarity) then
			DropCount.Cache:AddItem(item);
			missingitems=missingitems+1;
		else
			local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
			list[line]={ Ltext=colour..itemname.."|r ", Rtext="", Licon=GetItemIcon(item) };
			if (iTable>=0) then list[line].Ltext=Red.."* |r"..list[line].Ltext;
			elseif (iTable==CONST.UNKNOWNCOUNT) then list[line].Ltext=Yellow.."* |r"..list[line].Ltext; end
			if (DropCount.MT:SpecialUsable(item)) then list[line].Ltext=Green.."-> "..list[line].Ltext; end
			line=line+1;
			itemsinlist=true;
	end end
	if (missingitems>0) then
		DropCountTooltip.Loading=true;
		return nil;
	end
	DropCountTooltip.Loading=nil;
	if (not itemsinlist) then DropCountTooltip:Hide(); return; end
	list=DropCount:SortByNames(list);
	-- build tooltip
	DropCountTooltip:Init(parent);
	DropCountTooltip:SetText(unit..((vData.Repair and (Green.." (Repair)")) or ""));
	if (dcdb.Quest[CONST.MYFACTION][unit] or dcdb.Quest["Neutral"][unit]) then DropCountTooltip:AddSmall(dYellow.."Quests list available"); end
	DropCountTooltip:Add(list);
	DropCountTooltip:Show();
	return true;
end

function DropCount:ShowNPC(unit,sguid,compact)
	if (DropCountTooltip:IsVisible()) then return; end
	DropCountTooltip.dcdbShown=DropCountTooltip.dcdbShown or "drop";

	if (UnitIsFriend("player",DropCount:GetTargetType() or "mouseover")) then		-- friend
		if ((dcdb.Quest[CONST.MYFACTION][unit] or dcdb.Quest["Neutral"][unit]) and (DropCountTooltip.dcdbShown=="vendor" or not dcdb.Vendor[unit])) then
			_debug(Yellow,"ShowNPC -> QuestList");
			if (DropCount.Tooltip:QuestList(CONST.MYFACTION,unit,nil)) then DropCountTooltip.dcdbShown="quest"; end
		elseif (dcdb.Vendor[unit]) then
			_debug(Yellow,"ShowNPC -> Vendor");
			if (DropCount.Tooltip:Vendor(unit)) then DropCountTooltip.dcdbShown="vendor"; end
		end
	else																			-- enemy
		if (dcdb.Count[sguid]) then
			_debug(Yellow,"ShowNPC -> SetLootlist");
			if (DropCount.Tooltip:SetLootlist(unit,sguid,compact)) then DropCountTooltip.dcdbShown="drop"; end
		end
	end
end

-- list what a creature drops
function DropCount.Tooltip:SetLootlist(unit,sguid,compact)
	if (dcdb.Count[unit]) then DropCount.DB:ConvertMOB(unit,sguid); end
	local mTable=dcdb.Count[sguid]; if (not mTable) then return; end
	if (not mTable.Kill) then mTable.Kill=0; end
	dccs.MouseOver=copytable(mTable);
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
					local thisratio=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=Red.."? "..Basic..(iTable.Item or item).."|r: ", ratio=thisratio, Licon=GetItemIcon(item) };
					if (iTable.Quest) then list[line].Quests=copytable(iTable.Quest); end
					line=line+1;
				elseif (dccs.ShowSingle or questitem or iTable.Name[sguid]~=1) then
					if (dccs.ShowSingle and iTable.Name[sguid]==1) then
						if (not singlelist[rarity]) then singlelist[rarity]=1; else singlelist[rarity]=singlelist[rarity]+1; end
					else
						local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
						local thisratio=DropCount:GetRatio(item,sguid);
						list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, Licon=GetItemIcon(item) };
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
					local thisratio=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=Basic.."? "..(iTable.Item or item).."|r: ", ratio=thisratio, profession=true, Licon=GetItemIcon(item) };
					if (iTable.Quest) then list[line].Quests=copytable(iTable.Quest); end
					line=line+1;
				else
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local _,thisratio=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, profession=true, Licon=GetItemIcon(item) };
					list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext;	-- AARRGGBB
					if (iData.Quest) then list[line].Quests=copytable(iData.Quest); end
					line=line+1;
					itemsinlist=true;
	end end end end
	if (missingitems>0) then
		DropCountTooltip.Loading=true;
		return nil;
	end
	DropCountTooltip.Loading=nil;
	if (not itemsinlist) then DropCountTooltip:Hide(); return; end
	list=DropCount:SortByRatio(list);
	local listcopy=copytable(list);
	for i,raw in ipairs(listcopy) do if (raw.profession) then table.insert(list,copytable(raw)); list[i].delete=true; end end	-- move prof items to the end
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
	-- build tooltip
	local text="";
	DropCountTooltip:Init(UIParent);
	if (not dccs.CompactView) then
		DropCountTooltip:SetText(unit);
		if (mTable.Skinning and mTable.Skinning>0) then text="Profession-loot: "..mTable.Skinning.." times"; end
		DropCountTooltip:Add(lBlue..mTable.Kill.." kills",Purple..text);
	else
		text=unit.." |cFF6666FFK:"..mTable.Kill;
		if (mTable.Skinning and mTable.Skinning>0) then text=text.." |cFFFF00FFP:"..mTable.Skinning; end
		DropCountTooltip:SetText(text);
	end
	line=1;
	while(list[line]) do
		if (list[line].ratio==-100) then
			if (smallspace) then DropCountTooltip:AddSmall(" "); smallspace=nil; end
			DropCountTooltip:AddSmall(list[line].Ltext);
		else
			local li=(list[line].Licon and "|T"..list[line].Licon..":0|t ") or "";
			local ri=(list[line].Ricon and " |T"..list[line].Ricon..":0|t") or "";
			DropCountTooltip:Add(li..list[line].Ltext,(list[line].Rtext and list[line].Rtext..ri) or nil);
		end
		if (((compact and IsShiftKeyDown()) or not compact) and list[line].Quests) then
			for quest,amount in pairs(list[line].Quests) do
				if (dcdb.Quest[CONST.MYFACTION]) then
					for npc,rawData in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
						if (rawData:find(quest,1,true)) then
							local qData=dcdb.Quest[CONST.MYFACTION][npc];
							if (qData.Quests) then
								for _,qListData in ipairs(qData.Quests) do
									if (qListData.Quest==quest) then
										local _x,_y,_m=Location_Decode(qData._Location_);
										if (not qListData.Header) then DropCountTooltip:AddSmall(dBrown.."   "..amount.." for "..quest);
										else DropCountTooltip:AddSmall(dBrown.."   "..amount.." for "..quest.." ("..qListData.Header..")"); end
										DropCountTooltip:AddSmall("   "..Yellow.."   ! "..dBrown..npc.." ("..dcmaps(_m).." - "..floor(_x)..","..floor(_y)..")");
		end end end end end end end end
		line=line+1;
	end
	DropCountTooltip:Show();
	return true;
end

function DropCount.Cache:AddItem(item)
	DropCount.Cache.Retries=0;
	if (not DropCount.Tracker.UnknownItems) then DropCount.Tracker.UnknownItems={}; DropCount.Cache.Timer=.5; end
	if (not DropCount.Tracker.Unretrievable[item]) then
		DropCount.Tracker.UnknownItems[item]=true;
	end
end

-- A blind update will queue a request at the server without any
-- book-keeping at this side.
-- CATACLYSM: Cache has been greatly improved by speed at the server side.
-- CATACLYSM: Blind item spew has been implemented to take advantage of it.
function DropCount.Cache:Execute(item,blind)
	if (type(item)=="number") then item="item:"..item;
	elseif (type(item)~="string") then return true; end
	local name,link=GetItemInfo(item);
	if (not DropCountCacheTooltip:IsVisible()) then
		if (not name) then
--			DropCountCacheTooltip:SetParent(UIParent);
			DropCountCacheTooltip:SetOwner(UIParent); DropCountCacheTooltip:SetHyperlink(item); DropCountCacheTooltip:Hide();
			if (not blind) then DropCount.Cache.Retries=DropCount.Cache.Retries+1; end
			return false;
		else if (not blind) then DropCount.Cache.Retries=0; end end
	end
	return true;
end

-- wrap search in MT
function DropCountXML:GUI_Search()
	MT:Run("GUI SEARCH",DropCount.MT.Search.GUI_Search);
end

function DropCount.MT.Search.GUI_Search()
	local find=LCDC_VendorSearch_FindText:GetText();
	LCDC_VendorSearch_FindText:SetText("Searching...");
	LCDC_ResultListScroll:DMClear();
	LCDC_ResultListScroll.DMItemHeight=13;
	LCDC_VendorSearch.SearchTerm=find;
	DropCount.MT.Search:Do(	LCDC_VendorSearch.SearchTerm,
							LCDC_VendorSearch_UseVendors:GetChecked(),
							LCDC_VendorSearch_UseQuests:GetChecked(),
							LCDC_VendorSearch_UseBooks:GetChecked(),
							LCDC_VendorSearch_UseItems:GetChecked(),
							LCDC_VendorSearch_UseMobs:GetChecked(),
							LCDC_VendorSearch_UseTrainers:GetChecked(),
							LCDC_VendorSearch_UseAreaMobs:GetChecked(),
							LCDC_VendorSearch_UseAreaItems:GetChecked(),
							LCDC_VendorSearch_UseProfItems:GetChecked(),
							LCDC_VendorSearch_UsegatherNode:GetChecked());
	LCDC_VendorSearch_FindText:SetText(find);
	for section,sTable in pairs(DropCount.MT.Search._result) do
		local xml=LCDC_ResultListScroll:DMAdd(section,nil,-1);
		xml.Tooltip=nil;
		wipe(xml.DB);
		for _,entry in pairs(sTable) do
			xml=LCDC_ResultListScroll:DMAdd(entry.Entry,nil,0,entry.Icon);
			if (xml) then xml.Tooltip=entry.Tooltip; wipe(xml.DB); xml.DB=nil; xml.DB=entry.DB; end
			MT:Yield();
	end end

end

function DropCount.MT.Search:Found(section,entry,tooltip,db,icon)
	if (not self._result[section]) then self._result[section]={}; end
	db=db or {};
	if (not db.Section) then db.Section=section; end
	table.insert(self._result[section],{ Entry=entry, Tooltip=tooltip, DB=db, Icon=icon });
end

function DropCount.MT.Search:Do(find,uVen,uQue,uBoo,uIte,uMob,uTra,uZMob,uZItem,uPItem,uGNode)
	if (not find) then return; end
	find=strtrim(find:lower()); if (find=="") then
		uVen,uQue,uBoo,uIte,uMob,uTra,uZMob,uZItem,uGNode=nil,nil,nil,nil,nil,nil,nil,nil,nil;
--		find="there-is-no-search-term-specified";
	end
	wipe(self._result);
	local list,blist,plist,pblist={},{},{},{};
	local useit;
	-- Search items
	if (uIte or uVen or uPItem) then									-- do this for all searches that uses items
		for item,iData in rawpairs(dcdb.Item) do						-- entire item database
			if (iData:lower():find(find,1,true)) then					-- free-text search in this item
				DropCount.Cache:AddItem(item);							-- fire off a cache just in case
				if (uIte) then											-- doing an item search
					local itemData=dcdb.Item[item];						-- so grab item data
					self:Found("Item",itemData.Item,nil,{Section="Item",Entry=item,Data=itemData},GetItemIcon(item));	-- att it to search results
				end
				if (uIte or uVen) then									-- doing item or vendor search
					list[item]=1;										-- add item to list of items matching the search criteria
				end
				if (uPItem and DropCount.MT:SpecialUsable(item,true)) then	-- doing profession items search
					plist[item]=1;											-- add item to list of items matching the search criteria
				end
			end
			MT:Yield();
		end
		for bk,bv in rawpairs(dcdb.VendorItems) do						-- do all vendor item blocks
			for ik in pairs(list) do									-- do all items that match search term
				if (bv:find(ik,1,true)) then blist[bk]=1; break; end
				MT:Yield();												-- inside, as this is bound to be the longer list
			end
			for ik in pairs(plist) do									-- do all items that match search term
				if (bv:find(ik,1,true)) then pblist[bk]=1; break; end
			end
		end
	end
	-- Search vendors
	if (uVen) then
		local buf;
		for vendor,vData in rawpairs(dcdb.Vendor) do					-- do all vendors without unpacking
			useit=nil;													-- no match yet
			if (vendor:lower():find(find,1,true)) then useit=true;		-- check vendor name for match
			elseif (FormatZone(dcdb.Vendor[vendor]._Location_,true):lower():find(find,1,true)) then useit=true;
			else
				for i in pairs(list) do if (vData:lower():find(i,1,true)) then	-- raw-check vendor data for item-list of matching items
					useit=true; break; end end									-- any kind of match will flag for match
				for b in pairs(blist) do if (vData:lower():find(b,1,true)) then			-- raw-check vendor data for block-list of matching items
					if (dcdb.Vendor[vendor].Items==b) then useit=true; break; end end
			end end
			if (useit) then												-- vendor has been flagged for addition to search results
				buf=dcdb.Vendor[vendor];
				if (buf.Faction==CONST.MYFACTION or buf.Faction=="Neutral") then
					local _x,_y,_m=Location_Decode(buf._Location_);
					if (_x) then
						local tt={buf.Faction.." vendor: "..vendor,FormatZone(buf._Location_,true,true)};	-- locstring,full,usecoords
						if (buf.Repair) then table.insert(tt,"Can repair your stuff"); end
						self:Found("Vendor",dcmaps(_m)..": "..vendor,tt,{Section="Vendor",Entry=vendor,Data=vData});
			end end end
			MT:Yield();
	end end
	-- Search vendors for special items
	if (uPItem and next(plist)) then
		local buf;
		for vendor,vData in rawpairs(dcdb.Vendor) do					-- do all vendors without unpacking
			useit=nil;													-- no match yet
			for k in vData:gmatch("(item:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+:%p?%d+)") do	-- slow, but does not require unpacking
				if (DropCount.MT:SpecialUsable(k,true)) then useit=true; break; end
			end
			if (not useit) then															-- not flagged yet
				for b in pairs(pblist) do if (vData:lower():find(b,1,true)) then		-- raw-check vendor data for block-list of matching profession items
					if (dcdb.Vendor[vendor].Items==b) then useit=true; break; end end
			end end
			if (useit) then												-- vendor has been flagged for addition to search results
				buf=dcdb.Vendor[vendor];
				if (buf.Faction==CONST.MYFACTION or buf.Faction=="Neutral") then
					local _x,_y,_m=Location_Decode(buf._Location_);
					if (_x) then
						local tt={buf.Faction.." vendor: "..vendor,FormatZone(buf._Location_,true,true)};	-- locstring,full,usecoords
						if (buf.Repair) then table.insert(tt,"Can repair your stuff"); end
						self:Found("Profession vendor",dcmaps(_m)..": "..vendor,tt,{Section="Vendor",Entry=vendor,Data=vData});
			end end end
			MT:Yield();
	end end
	-- Search quests
	if (uQue) then
		for npc,nData in rawpairs(dcdb.Quest[CONST.MYFACTION]) do
			useit=nil;													-- no match yet
			if (nData:lower():find(find,1,true)) then useit=true;
			elseif (npc:lower():find(find,1,true)) then useit=true;
			elseif (FormatZone(dcdb.Quest[CONST.MYFACTION][npc]._Location_,true):lower():find(find,1,true)) then useit=true;
			end
			if (useit) then
				local npcData=dcdb.Quest[CONST.MYFACTION][npc];
				self:Found("Quest",FormatZone(npcData._Location_)..": "..npc,{"Quest-giver: "..npc,FormatZone(npcData._Location_,true,true)},{Section="Quest",Entry=npc,Data=nData});
			end
			MT:Yield();
	end end
	-- Search books
	if (uBoo) then
		for book,rawbook in rawpairs(dcdb.Book) do
			useit=nil;													-- no match yet
			if (book:lower():find(find,1,true)) then useit=true;
			else
				for _,loc in ipairs(dcdb.Book[book]) do
					if (FormatZone(loc):lower():find(find,1,true)) then useit=true; break; end
				end
			end
			if (useit) then
				local tt={"Book: "..book};
				for _,iData in ipairs(dcdb.Book[book]) do table.insert(tt,FormatZone(iData,true,true)); end
				self:Found("Book",book,tt,{Section="Book",Entry=book});
			end
			MT:Yield();
	end end
	-- Search mobs
	if (uMob) then
		local t;
		for mob,data in rawpairs(dcdb.Count) do
			if (mob:lower():find(find,1,true)) then
				t=dcdb.Count[mob];
				self:Found("Creature",t.Name or mob,nil,{Section="Creature",Entry=mob});
			end
			MT:Yield();
	end end
	-- Search trainers
	if (uTra) then
		for npc,nData in rawpairs(dcdb.Trainer[CONST.MYFACTION]) do
			useit=nil;													-- no match yet
			if (npc:lower():find(find,1,true)) then useit=true;
			elseif (nData:lower():find(find,1,true)) then useit=true;
			elseif (FormatZone(dcdb.Trainer[CONST.MYFACTION][npc]._Location_,true):lower():find(find,1,true)) then useit=true;
			end
			if (useit) then
				local npcData=dcdb.Trainer[CONST.MYFACTION][npc];
				self:Found("Trainer",FormatZone(npcData._Location_)..": "..npc,{"Trainer "..npc..": "..npcData.Service,FormatZone(npcData._Location_,true,true)},{Section="Trainer",Entry=npc,Data=nData});
			end
			MT:Yield();
	end end
	-- search nodes
	if (uGNode) then				-- no switch exists for this option atm
		local lang=GetLocale();
		for objID,od in rawpairs(dcdb.Gather.GatherNodes) do
			local use,t=nil,nil;
			if (od:lower():find(find,1,true)) then
				if (dcdb.Gather.GatherNodes[objID]._Name:lower():find(find,1,true)) then use=true; t=dcdb.Gather.GatherNodes[objID]; end
			end
			if (not use) then
				t=dcdb.Gather.GatherNodes[objID];
				if (t.Loot) then
					for i in pairs(t.Loot) do
						local item=dcdb.Item[i];
						if (item and item.Item and item.Item:lower():find(find,1,true)) then use=true; break; end
			end end end
			if (use) then
				self:Found("Gathering profession",t._Name,objID,nil,t.Icon or "");
			end
			MT:Yield();
	end end
	-- search grid: mobs in area with matching names
	if (uZMob) then			-- OFF for now, as it produces too many results
		local list,tmp={},nil;
		for area,raw in rawpairs(dcdb.Grid) do
			tmp=tonumber(area:match("^(%d+)_%d+$") or 0);
			if (tostring(dcmaps(tmp)):lower():find(find,1,true)) then
				wipe(list);
				for _,spot in pairs(dcdb.Grid[area]) do
					for _,mob in ipairs({strsplit(",",spot)}) do
						list[mob]=1;
					end
				end
				-- NOTE: Section is set to "Creature" to trigger a creature-type mouse-over event
				for mob in pairs(list) do
					local name;
					if (dcdb.Count[mob]) then name=dcdb.Count[mob].Name; end
					if (not name) then name="<Nameless creature>"; end
					self:Found("Map: Creatures",dcmaps(tmp)..": "..name,nil,{Section="Creature",Entry=mob});
				end
			end
			MT:Yield();
		end
	end
	-- search grid: items in area with matching names
	if (uZItem) then			-- OFF for now, as it produces too many results
		local moblist,lootlist,proflist,tmp,buf={},{},{},nil,nil;
		for area,raw in rawpairs(dcdb.Grid) do
			tmp=tonumber(area:match("^(%d+)_%d+$") or 0);
			if (tostring(dcmaps(tmp)):lower():find(find,1,true)) then
				wipe(moblist); wipe(lootlist); wipe(proflist);
				for _,spot in pairs(dcdb.Grid[area]) do
					for _,mob in ipairs({strsplit(",",spot)}) do moblist[mob]=1; end
				end
				for mob in pairs(moblist) do
					for item,raw in rawpairs(dcdb.Item) do
						if (raw:lower():find(mob,1,true)) then
							buf=dcdb.Item[item];
							if (buf.Item) then
								if (buf.Name and buf.Name[mob]) then lootlist[item]=(lootlist[item] or 0)+1; end
								if (buf.Skinning and buf.Skinning[mob]) then proflist[item]=(proflist[item] or 0)+1; end
							end
						end
						MT:Yield();
					end
				end
				-- NOTE: Section is set to "Item" to trigger an item-type mouse-over event
				for item in pairs(lootlist) do
					self:Found("Map: Loot items: Kill",dcmaps(tmp)..": "..dcdb.Item[item].Item,nil,{Section="Item",Entry=item,Data=dcdb.Item[item]},GetItemIcon(item));
				end
				for item in pairs(proflist) do
					self:Found("Map: Loot items: Profession",dcmaps(tmp)..": "..dcdb.Item[item].Item,nil,{Section="Item",Entry=item,Data=dcdb.Item[item]},GetItemIcon(item));
				end
			end
			MT:Yield();
		end
	end
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
	chat(Basic.."DropCount: "..Green..nowitems..Basic.." known book titles");
	nowmobs=0; for _ in rawpairs(dcdb.Vendor) do nowmobs=nowmobs+1; end
	chat(Basic.."DropCount:|r "..Green..nowmobs.."|r known vendors");
	nowmobs=0; for _,fTable in pairs(dcdb.Quest) do for _ in rawpairs(fTable) do nowmobs=nowmobs+1; end end
	chat(Basic.."DropCount:|r "..Green..nowmobs.."|r known quest-givers");
	nowitems=0; for _ in rawpairs(dcdb.Item) do nowitems=nowitems+1; end
	text=text..Green..nowitems.."|r items";
	if (not LootCount_DropCount_StartItems) then LootCount_DropCount_StartItems=nowitems; end
	nowmobs=0; for _ in rawpairs(dcdb.Count) do nowmobs=nowmobs+1; end
	text=text.." -> "..Green..nowmobs.."|r creatures";
	if (not LootCount_DropCount_StartMobs) then LootCount_DropCount_StartMobs=nowmobs; end
	chat(text);
	if (nowitems-LootCount_DropCount_StartItems>0 or nowmobs-LootCount_DropCount_StartMobs>0) then
		chat(Basic.."DropCount:|r New this session: "..Green..nowitems-LootCount_DropCount_StartItems.."|r items, "..Green..nowmobs-LootCount_DropCount_StartMobs.."|r mobs");
	end
	chat(Basic.."Type "..Green..SLASH_DROPCOUNT2..Basic.." to view options");
	chat(Basic.."Please consider submitting your SavedVariables file at "..Yellow.."ducklib.com -> DropCount"..Basic..", or sending it to "..Yellow.."dropcount@ducklib.com"..Basic.." to help develop the DropCount addon.");
end

function DropCount:SaveBook(BookName,loc)
	local silent=true;
	if (not loc) then loc=Location_Code(); silent=nil; end		-- grab current position
	local _x,_y,_m,_f,_s=Location_Decode(loc);
	local i,newBook,updatedBook=1,0,0;
	local buf=dcdb.Book[BookName];								-- load existing title, if any
	if (not buf) then											-- no such book
		if (not silent) then chat(Basic.."Location of new book "..Green.."\""..BookName.."\""..Basic.." saved"); end
		buf={};						-- create new title
		newBook=1;
	else
		local found=nil;
		local test=MapTest(_m,_f);
		while (not found and buf[i]) do
			if (buf[i]:find(test,1,true)) then found=true; updatedBook=1; i=i-1; end		-- Found in same zone
			i=i+1;
	end end
	buf[i]=loc;					-- add or overwrite
	dcdb.Book[BookName]=buf;
	if (not silent) then
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		chat(Basic..BookName..Green.." saved. "..Basic..i.." volumes known.");
	end
	return newBook,updatedBook;
end

function DropCount:SaveTrainer(name,service,loc,faction)
	if (not faction) then faction=CONST.MYFACTION; end
	dcdb.Trainer[faction][name]={Service=service,_Location_=loc};
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
end

function DropCountXML.OnUpdate(frame,elapsednow)
	if (not DropCount.Loaded) then return; end
	if (not DropCount.Tracker.Exited) then return; end	-- block for real MT
	DropCount.Tracker.Exited=nil;

	-- monitor tooltip for actual display and cancel it if it failed
--	if (DropCountTooltip.CreatingFrame and DropCountTooltip.CreatingFrame>0) then		-- there's an attempt at displaying it running
--		DropCountTooltip.CreatingFrame=DropCountTooltip.CreatingFrame-elapsednow;		-- time it
--		if (DropCountTooltip.CreatingFrame<0) then										-- timer done
--			if (not DropCountTooltip:IsVisible()) then DropCountTooltip:Hide(); end		-- it's not visible, so hide it to attempt clean-up
--		end
--	end

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
	if (dccs.Filter.GatherCoverage) then DropCount.OnUpdate:LocationRecorder(); end
	-- the trainer
	if (ClassTrainerFrame and ClassTrainerFrame:IsVisible()) then
		if (not DropCountXML.CTF) then
			DropCountXML.CTF=true;
			local isEnabled=GetTrainerServiceTypeFilter("used");				-- grab player setting
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",1); end	-- set to ON
			local trainerService=GetTrainerServiceSkillLine(1);					-- grab contents
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",0); end	-- set to OFF if player had that
			if (IsTradeskillTrainer()) then		-- this filters out riding trainers
				DropCount:SaveTrainer(DropCount.Target.CurrentAliveFriendClose,trainerService,Location_Code());	-- use current faction
		end end
	elseif (DropCountXML.CTF) then DropCountXML.CTF=nil; end

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
			chat(Basic.."DropCount:|r "..Green.."LootCount detected. DropCount is available from the LootCount menu.");
	end end
	-- hook on to crawler
	if (not DropCount.Crawler.Registered) then
		if (CrawlerXML and CrawlerXML.SetPlugin) then
			CrawlerXML:SetPlugin("DropCount",DropCount.Crawler);
			DropCount.Crawler.Registered=true;
			chat(Basic.."DropCount:|r "..Green.."Crawler detected. DropCount is available as a Crawler plug-in.");
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
			if (not next(DropCount.Tracker.UnknownItems)) then
				if (not WorldMapDetailFrame:IsVisible()) then MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end
			end
			DropCount.Cache.Retries=0;
			local raw=rawget(dcdb.Item.__DATA__,DropCount.Tracker.RequestedItem);
			if (raw and not raw:find(itemname,1,true)) then
				local buf=dcdb.Item[DropCount.Tracker.RequestedItem]; buf.Item=itemname; dcdb.Item[DropCount.Tracker.RequestedItem]=buf;
				_debug(Basic.."Debug: Cache: Renamed item "..Yellow..name);
			end
			if (not dcdb.Converted) then
				-- Counting items
				local i=0;
				for _ in pairs(DropCount.Tracker.UnknownItems) do i=i+1; end
				if (i<6 or (i>5 and i%25==0)) then chat("Converting DropCount database: "..i.." items left...",0,1,1); end
		end end
	end
	if (DropCount.Cache.Retries>=CONST.CACHEMAXRETRIES) then
		local thename=DropCount.Tracker.RequestedItem;
		if (dcdb.Item[DropCount.Tracker.RequestedItem]) then thename=dcdb.Item[DropCount.Tracker.RequestedItem].Item; end
		DropCount.Tracker.Unretrievable[thename]=1;
		_debug("Debug: "..Red.."Can't get information on "..Basic..thename..Red.." from the server.");
		DropCount.Tracker.UnknownItems=nil;			-- Too many tries, so abort
		DropCount.Tracker.RequestedItem=nil;
	end
end

function DropCount.MakeSGUID(txt)
	txt=txt:match(".+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%d+");
	local sguid=string.format("%04X",tonumber(txt));	-- at least 4 digits
--	_debug(txt,type(sguid),sguid);
	return sguid;
end

function DropCount.OnUpdate:RunMouseoverInWorld()
	if (not UnitExists("mouseover") or not IsAltKeyDown()) then
		if (DropCountTooltip.modifierHeld) then
			DropCountTooltip:Hide();
			DropCountTooltip.modifierHeld=false;
		end
	else
		local modifier,unit,sguid=IsAltKeyDown(),UnitName("mouseover"),DropCount.MakeSGUID(UnitGUID("mouseover"));
		if (modifier) then
			if (not DropCountTooltip:IsVisible() or DropCountTooltip.Loading) then
				DropCount:ShowNPC(unit,sguid,DropCountTooltip,dccs.CompactView);
			end
			DropCountTooltip.modifierHeld=true;
			return;
		end
	end
end

function DropCount.OnUpdate:RunTimedQueue()
	local now=time();
	if (now-DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize].Time>CONST.QUEUETIME) then
		table.remove(DropCount.Tracker.TimedQueue,DropCount.Tracker.QueueSize);
		DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize-1;
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
	end
end

function DropCount.OnUpdate:LocationRecorder()
	if (UnitOnTaxi("player")) then return; end
	local x,y=GetPlayerMapPosition("player"); x=floor(x*100); y=floor(y*100);
	if (x==DropCount.Painter.x and y==DropCount.Painter.y) then return; end
	DropCount.Painter.x=x; DropCount.Painter.y=y;
	MT:Run("LocationRecorder_Bookkeeping()",DropCount.MT.LocationRecorder_Bookkeeping,DropCount.MT);
	local _,_,map=CurrentMap();
	local pos=xy(x,y);
	if (not DropCount.Painter.maps[map]) then DropCount.Painter.maps[map]={ }; end
	if (DropCount.Painter.maps[map][pos]) then return; end
	DropCount.Painter.maps[map][pos]=time();
end

function DropCount.MT:LocationRecorder_Bookkeeping()
	local rems=0;
	for _,m in pairs(DropCount.Painter.maps) do
		for pos,stamp in pairs(m) do
			if (time()-stamp>(dccs.PaintTimer or 2)*60) then m[pos]=nil; rems=rems+1; if (rems==3) then return; end end
			MT:Yield(true);
	end end
end

function DropCount.OnUpdate:MonitorGameTooltip()
	if (not GameTooltip or not GameTooltip:IsVisible()) then if (DropCount.Tracker.GameTooltipObjectIdHandled) then DropCount.Tracker.GameTooltipObjectIdHandled=nil; end return; end
	if (not IsControlKeyDown() and not IsAltKeyDown()) then
		local handled=DropCount.Tracker.GameTooltipObjectIdHandled;		-- find previous assignment
		local obj=DropCount:GetCurrentObjectID();						-- find current hover
		DropCount.Tracker.GameTooltipObjectIdHandled=obj;				-- save current hover as active hover
		if (DropCount.Tracker.GameTooltipObjectIdHandled==handled) then return; end		-- no change since last check
		obj=dcdb.Gather.GatherNodes[obj]; if (not obj or not obj.Loot) then return; end	-- no node, or a different kind (like Glowcap wich is same-named item and object)
		GameTooltip:Add(" ");
		if (DropCount.Debug) then GameTooltip:Add(Basic..obj.Count.." gathers (debug-text only)"); end
		local links={};
		for item,count in pairs(obj.Loot) do
			local _,link=GetItemInfo(item);
			if (link and (obj.Count or 0)>0) then table.insert(links,{l=link,r=count/obj.Count}); end
		end
		table.sort(links,function (a,b) return (a.r>b.r); end);
		for _,it in ipairs(links) do GameTooltip:Add("    "..it.l.."  ("..DropCount:FormatPst(it.r).."%)"); end
		GameTooltip:Show();	-- recalc size
		return;
	end
	local _,ThisItem=GameTooltip:GetItem();
	if (not ThisItem) then return; end
	ThisItem=getid(ThisItem);
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
--		DropCount.Quest:Scan();
		MT:Run("Scan Quest List",DropCount.MT.Quest.Scan);
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
				if (dccs.DoneQuest[qName]) then
					if (type(dccs.DoneQuest[qName])~="table") then
						if (dccs.DoneQuest[qName]~=true) then
							local num=dccs.DoneQuest[qName];
							dccs.DoneQuest[qName]=nil;
							dccs.DoneQuest[qName]={[num]=true,[qIndex]=true};
						else dccs.DoneQuest[qName]=qIndex; end
					else dccs.DoneQuest[qName][qIndex]=true; end
				else dccs.DoneQuest[qName]=qIndex; end
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
	_debug(hBlue,"debug: Cleaning import data: "..sects.." sections.");
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		_debug(hBlue,"debug: Cleaning section "..s);
		DropCount.MT.DB.Maintenance:_0x(md,true);			-- Check for WoW 4.2 combatmessage f-up
		DropCount.MT.DB.Maintenance:_NPCQuests(md,true);	-- misplaced quest list
		DropCount.MT.DB.Maintenance:_Forge(md,true);		-- remove double forges
		DropCount.MT.DB.Maintenance:_Skinning(md,true);		-- null profession
		DropCount.Tracker.CleanImport.Okay=0;
		DropCount.MT.DB.Maintenance:_Kill(md,true);			-- null drop
		if (not checkMob) then
			_debug(hBlue,"debug: Cleaning import data done");
			_debug(hBlue,"debug: Deleted: "..DropCount.Tracker.CleanImport.Deleted);
			_debug(hBlue,"debug: Okay: "..DropCount.Tracker.CleanImport.Okay);
			DropCount.Tracker.CleanImport.Cleaned=true;
	end end
end

-- Check for double forges
function DropCount.MT.DB.Maintenance:_Forge(t,y)
	if (not t or not t.Forge) then return; end
	for map,data in dcdbpairs(t.Forge) do								-- walk all maps
		local maps=dcmaps[GetLocale()] or {};			-- grab all names for this locale
		for i,loc in pairs(data) do										-- walk all forges in said map
			local corrected=nil;
			for _i,_loc in pairs(data) do								-- walk all forges in said map again
				if (i~=_i and loc==_loc) then							-- different forge with same location
					data[_i]=""; corrected=true;
					_debug(hBlue,"debug: Duplicate forge removed from "..(maps[map] or "zone "..map));
				end
			end
			if (corrected) then
				local buf={};											-- rebuild here
				for _,loc in pairs(data) do if (loc and loc~="") then table.insert(buf,loc); end end	-- walk all forges in map, valid forge found
				t.Forge[map]=buf;										-- save rebuilt data
			end MT:Yield();
		end MT:Yield(y);
	end
end

-- Check for NPCs with extra data
function DropCount.MT.DB.Maintenance:_NPCQuests(t,y)
	-- mobs with quests
	for m,md in rawpairs(t.Count or {}) do
		if ((type(md)=="string" and md:find("Quests",1,true)) or md.Quests) then
			md=t.Count[m];
			if (md.Quests) then
				md.Quests=nil; t.Count[m]=md;				-- read, clear quest list, store
				Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
				_debug(hBlue,"debug: Deleted quest-list from kill-data for: "..(m.Name or m));
			end
			MT:Yield(y);
		end
		MT:Yield();			-- "slow", or it will never finish
	end
	Table:PurgeCache(DM_WHO);
	-- vendors with quests
	for m,md in rawpairs(t.Vendor or {}) do
		if ((type(md)=="string" and md:find("Quests",1,true)) or md.Quests) then
			md=t.Vendor[m];
			if (md.Quests) then
				md.Quests=nil; t.Vendor[m]=md;				-- read, clear quest list, store
				Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
				_debug(hBlue,"debug: Deleted quest-list from vendor-data for: "..m);
			end
			MT:Yield(y);
		end
		MT:Yield();			-- "slow", or it will never finish
	end
	Table:PurgeCache(DM_WHO);
	-- quest-givers with items
	for _,fd in pairs(t.Quest or {}) do
		for m,md in rawpairs(fd) do
			if ((type(md)=="string" and md:find("Items",1,true)) or md.Items) then
				md=fd[m];
				if (md.Items) then
					md.Items=nil; fd[m]=md;				-- read, clear quest list, store
					Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
					_debug(hBlue,"debug: Deleted item-list from quest-data for: "..m);
				end
				MT:Yield(y);
			end
			MT:Yield();		-- "slow", or it will never finish
		end
	end
	Table:PurgeCache(DM_WHO);
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
			_debug(hBlue,"debug: ("..DropCount.Tracker.CleanImport.Deleted.."/"..DropCount.Tracker.CleanImport.Deleted+DropCount.Tracker.CleanImport.Okay..") "..m.." has been deleted.");
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
	local slow=0;
	if (si=="Kill") then si="Name"; end	-- items do "Name" (of dropper)
	if (s=="Name") then s="Kill"; end	-- mobs do "Kill" (count)
	local mobs=0;
	if (DropCount.Debug) then mobs=DropCount:Length(t.Count.__DATA__); end
	for m,md in rawpairs(t.Count) do
		DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;
		if (type(md)~="string" or md:find(s,1,true)) then	-- possibly had this drop type
			local mt=t.Count[m];
			if (mt and mt[s] and mt[s]>2) then	-- got it
				local foundone=nil;
				for i,id in rawpairs(t.Item) do		-- cycle items
					if (id:find(m,1,true)) then		-- possible mob precense
						local it=t.Item[i];
						if (it and it[si] and it[si][m] and it[si][m]>0) then foundone=true; break; end	-- dropped by said mob and not quest item
					end
--					MT:Yield();		-- must be slow to ever finish
					slow=slow+1; MT:Yield(slow==100); if (slow==100) then slow=0; end					-- clock it down a bit
				end
				if (not foundone) then		-- no skinning drop for skinned mob
					DropCount:RemoveFromItems("Name",m,t,true); MT:Yield(y);
					DropCount:RemoveFromItems("Skinning",m,t,true);
					_debug(hBlue,"debug: "..s.."-drop missing: "..(mt.Name or m).." deleted.");
					t.Count[m]=nil;
					Table:PurgeCache(DM_WHO);		-- must do this to update cache properly
					DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
					DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay-1;		-- remove it again
				else MT:Yield(y); end
			end
		else MT:Yield(y); end
		if (mobs%1000==0) then _debug(dBrown,"mobs",mobs); end
		mobs=mobs-1;
	end
	Table:PurgeCache(DM_WHO);
end

-- Check for Pandaria hotwired addons
function DropCount.MT.DB.Maintenance:_KillHotwiredLoot(t,y)
	local first=time({year=2012,month=8,day=28});
	for i in rawpairs(t.Item) do
		local buf=t.Item[i];
		if (buf and buf.Time and buf.Time>first and buf.Time<time()) then
			if (dcdb.LocalImporter) then _debug("==>> Importer found:",buf.Item or i,date("%c",buf.Time)); end
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
	DropCount.PerformingAction="Removing erroneous quest givers";
	_debug("Running low-impact background database cleaner...");
	if (not dcdb.CleanDatabase_Index) then
		for faction,fTable in pairs(dcdb.Quest) do			-- Remove QG without quests or location 0,0
			for qg,qgd in rawpairs(fTable) do								-- All factions
				local x,y=qg:match("^%- item %- %(.+ %- .+ (%d+)%,(%d+)%)$");
				if (x and y and (x=="0" or y=="0")) then
					fTable[qg]=nil;
					Table:PurgeCache(DM_WHO);
					_debug(hBlue,"Misplaced QG: "..faction..": "..qg.." deleted");
				elseif (not qgd:find("Quests",1,true) and not dcdb.Quest[faction][qg].Quests) then
					fTable[qg]=nil;
					Table:PurgeCache(DM_WHO);
					_debug(hBlue,"Empty QG: "..faction..": "..qg.." deleted");
				end
				MT:Yield(true);		-- maintain low profile ("too long" has happened here)
			end
		end
		Table:PurgeCache(DM_WHO);
		dcdb.CleanDatabase_Index=0;
	end
	DropCount.WeHaveCleanDatabaseQG=true;
	if (dcdb.CleanDatabase_Index==0) then
		DropCount.PerformingAction="Combat message incompatibility clean-up"; _debug(Yellow,DropCount.PerformingAction);
		DropCount.MT.DB.Maintenance:_0x(dcdb,true);			-- Check for WoW 4.2 combatmessage f-up
		dcdb.CleanDatabase_Index=1;
	end
	if (dcdb.CleanDatabase_Index==1) then
		DropCount.PerformingAction="Removing misplaced quest lists"; _debug(Yellow,DropCount.PerformingAction);
		DropCount.MT.DB.Maintenance:_NPCQuests(dcdb,true);	-- misplaced quest list
		dcdb.CleanDatabase_Index=2;
	end
	if (dcdb.CleanDatabase_Index==2) then
		DropCount.PerformingAction="Removing double forges"; _debug(Yellow,DropCount.PerformingAction);
		DropCount.MT.DB.Maintenance:_Forge(dcdb,true);		-- remove double forges
		dcdb.CleanDatabase_Index=3;
	end
	if (dcdb.CleanDatabase_Index==3) then
		DropCount.PerformingAction="Removing no-drop entries: Skinning"; _debug(Yellow,DropCount.PerformingAction);
		DropCount.MT.DB.Maintenance:_Skinning(dcdb,true);	-- null profession
		dcdb.CleanDatabase_Index=4;
	end
	if (dcdb.CleanDatabase_Index==4) then
		DropCount.PerformingAction="Removing no-drop entries: Kill"; _debug(Yellow,DropCount.PerformingAction);
		DropCount.MT.DB.Maintenance:_Kill(dcdb,true);		-- null drop
		DropCount.PerformingAction=nil;
		dcdb.CleanDatabase_Index=5;
	end
	dcdb.CleanDatabase_Index=nil;
	_debug(hBlue,"Cleaning database done.");
end

-- save undropped for ID reference
function DropCount.MT:VerifyItemId()
	local now=debugprofilestop();	-- ms
	while(debugprofilestop()-now<5000) do MT:Yield(true); end
	for bag=0,4 do
		local bagslots=GetContainerNumSlots(bag);
		local link,itemID,raw,name;
		for item=1,bagslots do
			MT:Yield(true);
			link=GetContainerItemLink(bag,item);
			if (link) then
				name=GetItemInfo(link);
				itemID=getid(link,MT.YieldExtFast);
				if (itemID and name) then
					raw=rawget(dcdb.Item.__DATA__,itemID);
					if (not raw) then									-- insert new
						dcdb.Item[itemID]={ Time=time(), Item=name, Name={}, };
						_debug(Basic.."Added undropped "..Yellow..name..Basic.." to database.");
					elseif (not raw:find(name,1,true)) then				-- name not found at this itemID
						local buf=dcdb.Item[itemID]; buf.Item=name; dcdb.Item[itemID]=buf;
						_debug(Basic.."Renamed item "..Yellow..name);
	end end end end end
end

function DropCount.MT.Quest:ScanStartItem()
	local now=debugprofilestop();	-- ms
	while(debugprofilestop()-now<5000) do MT:Yield(true); end
	for bag=0,4 do
		local bagslots=GetContainerNumSlots(bag);
		local link,itemID,raw,name;
		for item=1,bagslots do
			MT:Yield(true);
			link=GetContainerItemLink(bag,item);
			if (link) then
				DropCountCacheTooltip:ClearLines();
--				DropCountCacheTooltip:SetParent(UIParent);
				DropCountCacheTooltip:SetOwner(UIParent,"ANCHOR_CURSOR");
				DropCountCacheTooltip:SetHyperlink(link);
--				DropCountCacheTooltip:Show();
				for i=1,DropCountCacheTooltip:NumLines() do
					if (_G["DropCountCacheTooltipTextLeft"..i]:GetText():find(ITEM_STARTS_QUEST,1,true)) then
						local un=DropCount:GetUniqueID(link);
						if (not DropCount.Tracker.NotifyQuestItem[un]) then
							local icon=GetItemIcon(link);
							if (not icon) then
								chat("===>>>",link,"starts a quest!");
								chat("===>>>",link,"starts a quest!");
								chat("===>>>",link,"starts a quest!");
							else
								chat("|T"..icon..":32|t",link,"starts a quest!");	--|T<path>:size1:size2:xoffset:yoffset|t
							end
							DropCount.Tracker.NotifyQuestItem[un]=time();
						end break;
				end end
				DropCountCacheTooltip:Hide();
	end end end
end

function DropCount.MT.DB:ConvertLocations(db)
	-- book
	_debug("converting book locations...");
	for k,v in dcdbpairs(db.Book) do
		db.Book[k]=DropCount.DB:ConvertLocation_Book(v);		-- write to trigger proper meta storage
		MT:Yield();
	end
	Table:PurgeCache(DM_WHO);
	-- quest
	_debug("converting quest-giver locations...");
	for _,f in dcdbpairs(db.Quest) do
		for k,v in dcdbpairs(f) do
			f[k]=DropCount.DB:ConvertLocation_Generic(v);		-- write to trigger proper meta storage
			MT:Yield();
		end
		Table:PurgeCache(DM_WHO);
	end
	-- vendor
	_debug("converting vendor locations...");
	for k,v in dcdbpairs(db.Vendor) do
		db.Vendor[k]=DropCount.DB:ConvertLocation_Generic(v);	-- write to trigger proper meta storage
		MT:Yield();
	end
	Table:PurgeCache(DM_WHO);
	-- trainer
	_debug("converting trainer locations...");
	for _,f in dcdbpairs(db.Trainer) do
		for k,v in dcdbpairs(f) do
			f[k]=DropCount.DB:ConvertLocation_Generic(v);		-- write to trigger proper meta storage
			MT:Yield();
		end
		Table:PurgeCache(DM_WHO);
	end
	-- item
	_debug("converting item locations...");
	for k,v in dcdbpairs(db.Item) do
		db.Item[k]=DropCount.DB:ConvertLocation_Item(v);		-- write to trigger proper meta storage
		MT:Yield();
	end
	-- creature
	_debug("converting creature locations...");
	for k,v in dcdbpairs(db.Count) do
		db.Count[k]=DropCount.DB:ConvertLocation_Creature(v);	-- write to trigger proper meta storage
		MT:Yield();
	end
	_debug("converting locations DONE");
end

function DropCount.MT.DB:ConvertVendorItems(db)
	if (not db.Vendor) then return; end
	_debug("converting vendor items...");
	for k,v in dcdbpairs(db.Vendor) do
		local converted=nil;
		for item,idata in pairs(v.Items or {}) do
			if (type(idata)=="table") then v.Items[item]=idata.Count; converted=true; end		-- change the old version to the new less memory impact
		end
		if (converted) then db.Vendor[k]=v; end		-- shove it back
		MT:Yield();				-- be fast
	end
	Table:PurgeCache(DM_WHO);
	_debug("vendor items converted");
end

function DropCount.MT.DB:TrimNodes()
	_debug("trimming nodes...");
	local before=DropCountXML:TableBytes(dcdb.Gather.GatherNodes);
	local lang=GetLocale();
	for i,node in dcdbpairs(dcdb.Gather.GatherNodes) do
		if (node.Name and node.Name[lang]) then
			for j in pairs(node.Name) do if (j~=lang) then node.Name[j]=nil; end end	-- remove all other
			dcdb.Gather.GatherNodes[i]=node;		-- put it back where it came from
			MT:Yield(true);			-- be quiet about it
	end end
	Table:PurgeCache(DM_WHO);
	if (DropCount.Debug) then
		local after=DropCountXML:TableBytes(dcdb.Gather.GatherNodes);
		_debug("nodes trimmed:",before,"->",after,"=",Green..string.format("%.0f%%",(100/before)*(before-after)));
	end
end

function DropCount.MT.DB:RemoveZone(db,zone)
	local buf,i;
	local zonename=dcmaps(tonumber(zone));
	-- ore
	for loc in rawpairs(db.Gather.GatherORE) do							-- all known ore zones
		if (loc:match("^"..zone.."_(%d+)$")) then db.Gather.GatherORE[loc]=nil; end
	end
	MT:Yield();
	-- herb
	for loc in rawpairs(db.Gather.GatherHERB) do						-- all known herb zones
		if (loc:match("^"..zone.."_(%d+)$")) then db.Gather.GatherHERB[loc]=nil; end
	end
	MT:Yield();
	-- forge
	for loc in rawpairs(db.Forge) do
		if (loc==tonumber(zone)) then db.Forge[loc]=nil; end
	end
	MT:Yield();
	-- book
	for book,volumes in dcdbpairs(db.Book) do
		for index,loc in pairs(volumes) do
			local _x,_y,_m,_f,_s=Location_Decode(loc);
--if (_m==19) then
--_debug(type(_m),_m,type(zone),zone);
--end
			if (_m==tonumber(zone)) then
				buf=db.Book[book]; buf[index]=nil; db.Book[book]=buf;
			end
		end
	end
	MT:Yield();
	-- quest
	for faction,fdata in pairs(db.Quest) do
		for dude,data in rawpairs(fdata) do
			if (data:match("rA:_Location_r%x+:[%d%.]+_[%d%.]+_"..zone.."_%d+_")) then
				local _x,_y,_m,_f,_s=Location_Decode(fdata[dude]._Location_);
				if (_m==tonumber(zone)) then db.Quest[faction][dude]=nil; end
			elseif (data:find(zonename,1,true)) then
				buf=fdata[dude];
				i=1; while(buf.Quests[i]) do
					if (buf.Quests[i].Header==zonename) then
						table.remove(buf.Quests,i);
					else
						i=i+1;
					end
				end
			end
		end
	end
	MT:Yield();
	-- item
	for item,data in rawpairs(db.Item) do
		if (data:match(":BestWr%x+:"..zone.."_%d+_")) then
			buf=db.Item[item]; buf.BestW=nil; db.Item[item]=buf;
		end
		if (data:match(":Bestr%x+:"..zone.."_%d+_")) then
			buf=db.Item[item]; buf.Best=buf.BestW; buf.BestW=nil; db.Item[item]=buf;
		end
	end
	MT:Yield();
	-- grid
	for loc in rawpairs(db.Grid) do
		if (loc:match("^"..zone.."_(%d+)$")) then db.Grid[loc]=nil; end
	end
	MT:Yield();
	-- vendor
	for dude,data in rawpairs(db.Vendor) do
		if (data:match("rA:_Location_r%x+:[%d%.]+_[%d%.]+_"..zone.."_%d+_")) then
			local _x,_y,_m,_f,_s=Location_Decode(db.Vendor[dude]._Location_);
			if (_m==tonumber(zone)) then db.Vendor[dude]=nil; end
		end
	end
	MT:Yield();
	-- trainer
	for faction,fdata in pairs(db.Trainer) do
		for dude,data in rawpairs(fdata) do
			if (data:match("rA:_Location_r%x+:[%d%.]+_[%d%.]+_"..zone.."_%d+_")) then
				local _x,_y,_m,_f,_s=Location_Decode(fdata[dude]._Location_);
				if (_m==tonumber(zone)) then fdata[dude]=nil; end
			end
		end
	end
	MT:Yield();
	_debug("Zone",zonename,"removed in",(db==dcdb and "dcdb") or "MergeData");
end


function DropCount.MT.DB:CleanDatabaseDD()
	_debug("checking for dual dudes...");
	for name in rawpairs(dcdb.Count) do
		if (tonumber(name,16)) then							-- it's new
			local test=dcdb.Count[name].Name or "";
			if (dcdb.Count[test]) then
				DropCount.MT:ClearMobDrop(test,"Skinning");
				DropCount.MT:ClearMobDrop(test,"Name");
				dcdb.Count[test]=nil;
				_debug("Removed duplicate dude",test,"for sguid",name);
		end end
		MT:Yield(true);
	end
	Table:PurgeCache(DM_WHO);
	_debug("dual dudes done");
end

function DropCount.MT.DB:CleanDatabaseQG()
--	repeat MT:Yield(true); until (DropCount.WeHaveCleanDatabaseQG);		-- wait until QG DB cleaning is done
	_debug("Running QG cleaner...");
	local buf={};
	local slow=0;
	-- Remove duplicate same-zone item quest givers
	for faction,fTable in pairs(dcdb.Quest) do
		local _x,_y,_m,_f,_s,test;
		for qg,qgd in dcdbpairs(fTable) do								-- everyone
			if (qgd._Location_) then
				_x,_y,_m,_f,_s=Location_Decode(qgd._Location_);				-- grab location
				test=MapTest(_m,_f);
				-- spool all item qg for that zone
				wipe(buf);
				for _qg,_qgr in rawpairs(fTable) do							-- spool zone
					if (_qg:find(test,1,true)) then table.insert(buf,_qg); end		-- zone in item QG name
--					MT:Yield();		-- low fps for a fraction of a second as opposed to 10 minutes or lag
					slow=slow+1; MT:Yield(slow==100); if (slow==100) then slow=0; end					-- clock it down a bit
				end
				-- cycle all same-zone item qg
				for _,_qg in pairs(buf) do									-- spool zone
					if (qg~=_qg) then										-- not same dude
						local _qgd=dcdb.Quest[faction][_qg];	-- Get tester item
						local __x,__y,__m,__f,__s=Location_Decode(_qgd._Location_);
						if (_m==__m and _f==__f) then
							-- compare quests to find duplicates and remove them
							local rqgd=rawget(fTable.__DATA__,_qg);				-- get raw data for this quest giver for later string find
							for i,q in ipairs(qgd.Quests) do					-- cycle first quests
								if (rqgd:find(tostring(q.ID)) and rqgd:find(q.Quest) and rqgd:find(q.Header)) then	-- All strings present
									for _i,_q in ipairs(_qgd.Quests) do			-- cycle tester quests
										if (_q.ID==q.ID and _q.Quest==q.Quest and _q.Header==q.Header) then		-- has same quest?
											table.remove(_qgd.Quests,_i);
											_debug(hBlue,"Duplicate "..faction.." QI: ".._qg..", deleted: "..q.Quest.." in "..q.Header);
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
				end end end end
			elseif (DropCount.Debug) then
				_debug(qg,"location missing");
				fTable[qg]=nil;
			end
		end
	end
	Table:PurgeCache(DM_WHO);
	_debug(hBlue,"Cleaning QG database done.");
end

function DropCount.MT:UpgradeDatabaseStorageVersion(t,ver)
	if (not ver) then ver=Table.LastPackerVersion; end
	local dive=nil;
	for name,data in rawpairs(t) do if (type(data)=="table") then dive=true; break; end MT:Yield(); end	-- no unpacked tables within "__DATA__"
	if (dive) then
		for name,data in rawpairs(t) do
			if (type(data)=="table") then _debug(name,"converts to",ver,"..."); DropCount.MT:UpgradeDatabaseStorageVersion(data,ver); end
			MT:Yield(true);
		end
		return;
	end
	-- we're at an end-level compressed table
	for name,data in rawpairs(t) do					-- get raw to check version
		if (type(data)=="string" and data:find("^"..ver)) then MT:Yield();	-- go quickly past correct versions
		else t[name]=t[name]; MT:Yield(true); end	-- read older version, write back with preferred method (if any)
	end
	Table:PurgeCache(DM_WHO);
end

function DropCount:UnpackMergedata(verbose)
--	if (DropCount.__UnpackMergedata) then return; end
--	DropCount.__UnpackMergedata=true;
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		-- Unpack all entries for quick repeated access
		local c;
		c=0; for entry in rawpairs(md.Item) do Table:Unpack(entry,md.Item); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Item"..Yellow..":"..Green,c); end
		c=0; for entry in rawpairs(md.Count) do Table:Unpack(entry,md.Count); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Count"..Yellow..":"..Green,c); end
		c=0; for entry in rawpairs(md.Vendor) do Table:Unpack(entry,md.Vendor); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Vendor"..Yellow..":"..Green,c); end
		c=0; for entry in rawpairs(md.Book) do Table:Unpack(entry,md.Book); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Book"..Yellow..":"..Green,c); end
		c=0; for entry in rawpairs(md.Forge) do Table:Unpack(entry,md.Forge); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Forge"..Yellow..":"..Green,c); end
		c=0; for entry in rawpairs(md.Grid) do Table:Unpack(entry,md.Grid); MT:Yield(); c=c+1; end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Grid"..Yellow..":"..Green,c); end
		c=0; for _,fd in pairs(md.Trainer) do for entry in rawpairs(fd) do Table:Unpack(entry,fd); MT:Yield(); c=c+1; end end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Trainer"..Yellow..":"..Green,c); end
		c=0; for _,fd in pairs(md.Quest) do for entry in rawpairs(fd) do Table:Unpack(entry,fd); MT:Yield(); c=c+1; end end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Quest"..Yellow..":"..Green,c); end
		c=0; for _,sd in pairs(md.Gather) do for entry in rawpairs(sd) do Table:Unpack(entry,sd); MT:Yield(); c=c+1; end end if (verbose) then _debug(Basic,"= = >>",Yellow,"Unpack "..White.."Gather"..Yellow..":"..Green,c); end
	end
end

function DropCount.MT:OverlayDB(mute,indata,goal)
	if (type(indata)~="table" or type(goal)~="table") then
		if (not mute) then chat(Basic,"= = >>",Yellow,"Incompatible types:"..Red,type(indata),Yellow.."and"..Red,type(goal),Yellow.."=>",(indata or "indata") or "goal","selected"); end
		return (indata or goal);
	end
	if (not rawget(indata,"__DATA__")) then				-- not autopacker, so dive
		if (not mute) then chat(Basic,"= = >>",Yellow,"\"indata\" has no "..Basic.."__DATA___"..Yellow..". Performing recursive calls on sub-levels using \"pairs()\"."); end
		local sublevels=0;
		for k in pairs(indata) do
			if (not mute) then chat(Basic,"= = >>",Yellow,"Overlaying sub-level"..Basic,k); end
			goal[k]=self:OverlayDB(mute,indata[k],goal[k]);
			sublevels=sublevels+1;
		end
		if (not mute) then chat(Basic,"= = >>",Yellow,sublevels,"sub-levels:",(sublevels~=0 and Green) or Red,"DONE"); end
		return goal;
	end
	-- set all language specific merge data
	local item=((rawget(goal,"__METADATA__") or {})["sub1"]=="Item");
	local id,gd,m,f,s,n;
	local entries=0;
	for k in rawpairs(indata) do
		if (item) then
			id=indata[k] or {}; gd=goal[k] or {};
			if (id.Best and gd.Best) then
				m,f,_,n=MapPlusNumber_Decode(id.Best); _,_,s,_=MapPlusNumber_Decode(gd.Best); gd.Best=MapPlusNumber_Code(m,f,s,n); id.Best=nil;
			end
			if (id.BestW and gd.BestW) then
				m,f,_,n=MapPlusNumber_Decode(id.BestW); _,_,s,_=MapPlusNumber_Decode(gd.BestW); gd.BestW=MapPlusNumber_Code(m,f,s,n); id.BestW=nil;
			end
			rawset(goal.__DATA__,k,copytable(id,gd));				-- get both, overlay, raw unpacked storage
		else
			rawset(goal.__DATA__,k,copytable(indata[k],goal[k]));	-- get both, overlay, raw unpacked storage
		end
		entries=entries+1;
		MT:Yield();
	end
	if (not mute) then chat(Basic,"= = >>",White,entries,Yellow.."entries:",(entries~=0 and Green) or Red,"DONE"); end
	return goal;
end

DropCount.MT.Debug={};
function DropCount.MT.Debug.SetImportMetatable(mute)
	if (not mute) then chat(Basic,"= = >>",Yellow,"SetImportMetatable() ->"..White,"Start"); end
	for i,t in ipairs(LootCount_DropCount_MergeData) do					-- ipairs to not include other settings
		if (not mute) then chat(Basic,"= = >>",Yellow,"Setting metadata for localized mergedata section"..Green,i); end
		CreateDropcountDB(t);											-- make section autopack
	end
	for i,t in ipairs(LootCount_DropCount_MergeData_overlay) do			-- ipairs to not include other settings
		if (not mute) then chat(Basic,"= = >>",Yellow,"Setting metadata for non-localized mergedata section"..Green,i); end
		CreateDropcountDB(t);											-- make section autopack
	end
	if (not mute) then chat(Basic,"= = >>",Yellow,"SetImportMetatable() ->"..Green,"Done"); end
end

function DropCount.MT.Debug.UnpackLocalizedData(mute)
	if (not mute) then chat(Basic,"= = >>",Yellow,"UnpackLocalizedData() ->"..White,"Start"); end
	DropCount:UnpackMergedata(not mute);
	if (not mute) then chat(Basic,"= = >>",Yellow,"UnpackLocalizedData() ->"..Green,"Done"); end
end

function DropCount.MT.CreateImportData(mute)
	if (not mute) then chat(Basic,"= = >>",Yellow,"CreateImportData() ->"..White,"Start"); end
	LootCount_DropCount_MergeData.indices=LootCount_DropCount_MergeData_indices;	-- set gathering indices reference in mergable data
	LootCount_DropCount_MergeData_indices=nil;										-- kill original table reference
	InsertDropcountDB(LootCount_DropCount_MergeData.indices);						-- make indices autopack
	for i,md in ipairs(LootCount_DropCount_MergeData) do							-- ipairs to not include other settings
		if (not mute) then chat(Basic,"= = >>",Yellow,"Starting localized mergedata section"..Green,i); end
		if (LootCount_DropCount_MergeData_overlay[i]) then							-- if there is such an overlay section in this locale
			if (not mute) then chat(Basic,"= = >>",Yellow,"Found corresponding non-locale section"..Green,i); end
			for k,chunk in pairs(LootCount_DropCount_MergeData_overlay[i]) do		-- walk through all localized data
				if (not mute) then chat(Basic,"= = >>",Yellow,"Starting chunk"..Green,k); end
				md[k]=DropCount.MT:OverlayDB(mute,chunk,md[k]);							-- overlay
			end
		end
	end
	if (not mute) then chat(Basic,"= = >>",Yellow,"CreateImportData() ->"..Green,"Done"); end
end

function DropCount.MT.Debug.SpewTable(t,chunk,entry)
	if (not t[chunk]) then
		chat(Basic,"= = >> Section"..White,section,Basic.."does not exist.");
		return false;
	end
	t=t[chunk];
	if (not rawget(t,"__DATA__")) then				-- not autopacker, so dive
		chat(Basic,"= = >> No __DATA__, reacquiring table to include"..White,CONST.MYFACTION);
		if (not t[CONST.MYFACTION]) then
			chat(Basic,"= = >> Faction"..White,CONST.MYFACTION,Basic.."does not exist.");
			return false;
		end
		t=t[CONST.MYFACTION];
	end
	local buf=t[entry];			-- read by meta of direct or whatever this unknown table would have here
	chat(Basic,"= = >> Entry is of type"..White,type(buf));
	if (type(buf)=="table") then
		DropCount.MT.Debug.SpewTable_(buf);
	end
	return true;
end

function DropCount.MT.Debug.SpewTable_(t,level)
	level=level or "-";
	for k,v in pairs(t) do
		local _v;
		if (type(v)=="string") then
			_v=v:sub(1,20);
			if (_v~=v) then _v=_v.." (...)"; end		-- show it has been cut
			_v=White.._v;
		elseif (type(v)=="table") then
			_v=White.."==>>";
		else
			_v=White..tostring(v);
		end
		chat(Basic,"= = >>",Blue..level,Yellow..type(k):sub(1,1)..White,k,Blue.."="..Yellow..type(v),_v);
		if (type(v)=="table") then
			DropCount.MT.Debug.SpewTable_(v,level.." -");
		end
	end
end

function DropCount.MT:ConvertAndMerge()
	-- Check for really old stuff
	while (DropCount.Loaded<=10) do MT:Yield(true); end
	if (dcdb.MergedData) then
		if (not dcdb.Converted or dcdb.MergedData<5) then	-- need wipe
			dcdb.MergedData=5; dcdb.Converted=7; dcdb.Vendor={}; dcdb.Book={}; dcdb.Item={}; dcdb.Quest={}; dcdb.Count={};
			CreateDropcountDB(dcdb);
--			collectgarbage("collect");
		end
	end

	-- do preliminary local database changes
	if (not dcdb.VendorItemVersion) then
		DropCount.MT.DB:ConvertVendorItems(dcdb);
		dcdb.VendorItemVersion=VERSIONn;
	end
	if (not dcdb.LocationVersion) then
--		local tmp=dcdb.Quest.Horde.Kaylaan;
--		DropCount.DB:ConvertLocation_Generic(tmp);	--debug
--		_debug(tmp._Location_);
--		_debug(tmp.Location);
		DropCount.MT.DB:ConvertLocations(dcdb);
		dcdb.LocationVersion=VERSIONn;
	end

	-- strip unwanted data
	-- single-level
	if (dcdb.DontFollowMobsAndDrops) then wipe(dcdb.Count.__DATA__); end
	if (dcdb.DontFollowVendors) then wipe(dcdb.Vendor.__DATA__); end
	if (dcdb.DontFollowBooks) then wipe(dcdb.Book.__DATA__); end
	if (dcdb.DontFollowForges) then wipe(dcdb.Forge.__DATA__); end
	if (dcdb.DontFollowGrid) then wipe(dcdb.Grid.__DATA__); end
	if (dcdb.DontFollowVendors and dcdb.DontFollowMobsAndDrops) then wipe(dcdb.Item.__DATA__); end
	-- sub-leveled
	if (dcdb.DontFollowTrainers) then for sub in pairs(dcdb.Trainer) do wipe(dcdb.Trainer[sub].__DATA__); end end
	if (dcdb.DontFollowQuests) then for sub in pairs(dcdb.Quest) do wipe(dcdb.Quest[sub].__DATA__); end end
	if (dcdb.DontFollowGather) then for sub in pairs(dcdb.Gather) do wipe(dcdb.Gather[sub].__DATA__); end end
	for _,md in ipairs(LootCount_DropCount_MergeData) do		-- ipairs to not include other settings
		-- single-level
		if (dcdb.DontFollowMobsAndDrops) then wipe(md.Count.__DATA__); end
		if (dcdb.DontFollowVendors) then wipe(md.Vendor.__DATA__); end
		if (dcdb.DontFollowBooks) then wipe(md.Book.__DATA__); end
		if (dcdb.DontFollowForges) then wipe(md.Forge.__DATA__); end
		if (dcdb.DontFollowGrid) then wipe(md.Grid.__DATA__); end
		if (dcdb.DontFollowVendors and dcdb.DontFollowMobsAndDrops) then wipe(md.Item.__DATA__); end
		-- sub-leveled
		if (dcdb.DontFollowTrainers) then for sub in pairs(md.Trainer) do wipe(md.Trainer[sub].__DATA__); end end
		if (dcdb.DontFollowQuests) then for sub in pairs(md.Quest) do wipe(md.Quest[sub].__DATA__); end end
		if (dcdb.DontFollowGather) then for sub in pairs(md.Gather) do wipe(md.Gather[sub].__DATA__); end end
	end
	-- Check for hotwired addons for aoe loot changes
	if (not dcdb.FixedHotWired) then
		DropCount.PerformingAction="Fixing hot-wired items";
		chat("Running post-Pandaria database clean-up...");
		DropCount.MT.DB.Maintenance:_KillHotwiredLoot(dcdb,true);	-- Check for Pandaria hotwired addons
		dcdb.FixedHotWired=time();
		DropCount.PerformingAction=nil;
	end
	-- convert forge zone to mapID before merge
	local maps=dcmaps[GetLocale()] or {};
	for area,raw in pairs(dcdb.Forge.__DATA__) do
		if (type(area)~="number") then
			for map,name in pairs(maps) do if (name==area) then rawset(dcdb.Forge.__DATA__,map,raw); break; end end
			rawset(dcdb.Forge.__DATA__,area,nil);
		end
		MT:Yield(true);
	end
--	if (not dcdb.WoW6RemoveZone19) then
--		DropCount.MT.DB:RemoveZone(dcdb,19);
--		dcdb.WoW6RemoveZone19=VERSIONn;
--	end
	if (not LootCount_DropCount_MergeData) then return; end			-- no point in going further

	if (LootCount_DropCount_MergeData.Version~=dcdb.MergedData) then
		chat("New version of DropCount has been installed.",.6,1,.6);
		if (not dcdb.FixedHotWired) then chat("Due to WoW loot bugs (and some users' unskilled DropCount hacks), an extended database check has been implemented. This is a must for it to work at all with Pandaria.",.7,.7,1);
		else chat("Your database will be checked for errors before merge with the new data can commence.",.7,.7,1); end
		chat("During this time, your fps will drop to about 30. I am sorry for this inconvenience. This will only happen once after installing a new version, so it is recommended to let it finish. You can log out during this period if you so wish, and the operation will restart when you log back in.",.7,.7,1);
		-- create import data
		chat("Building import data for \""..GetLocale().."\"...");
		DropCount.MT.Debug.SetImportMetatable(true);		-- activate import data
		DropCount.MT.Debug.UnpackLocalizedData(true);		-- unpack localized mergedata to cache
		DropCount.MT.CreateImportData(true);			-- merge global and localized
		dcdb.Tracker.Total=0;
		dcdb.Tracker.Goal=0;
		dcdb.Tracker.Mobs=0;
		dcdb.Tracker.MobsGoal=0;
	elseif (LootCount_DropCount_MergeData.Version==VERSIONimportdebug) then
		return;		-- bail out here to not do anything to the data for debug purposes
	end
	wipe(LootCount_DropCount_MergeData_overlay); LootCount_DropCount_MergeData_overlay=nil;

	if (LootCount_DropCount_MergeData.Version~=dcdb.MergedData) then
		-- convert known GUID/name and add "rare"
		DropCount:UnpackMergedata();		-- can be repeatedly called
		DropCount.PerformingAction="Converting names to GUID";
		chat("Running database integrity check...");
		for mdi,md in ipairs(LootCount_DropCount_MergeData) do			-- outer section (complete databases enclosed)
			-- some early conversions
			if (LootCount_DropCount_MergeData.Version~=dcdb.MergedData) then
				DropCount.MT.DB:ConvertVendorItems(md);			-- change import vendor item format
				DropCount.MT.DB:ConvertLocations(md);			-- change location format
			end
			-- do pre-merge updates
			_debug("Setting GUID in mergedata "..mdi.." from local...",0,1,0);
			for name,data in rawpairs(md.Count) do						-- raw import data
--				if ((name:len()~=4 or not tonumber(name,16)) and not dcdb.Count.__DATA__[name]) then	-- it's not converted and local data does not have it
				if (not tonumber(name,16) and not dcdb.Count.__DATA__[name]) then	-- it's not converted and local data does not have it
					for sguid,rawg in rawpairs(dcdb.Count) do
--						if (rawg:find(name,1,true) and sguid:len()==4 and tonumber(sguid,16)) then		-- found same name in converted local data
						if (rawg:find(name,1,true) and tonumber(sguid,16)) then		-- found same name in converted local data
							local datag=dcdb.Count[sguid];
							if (datag.Name==name) then DropCount.DB:ConvertMOB(name,sguid,md,true); break; end	-- convert data for import and keep unpacked
						end MT:Yield();
			end end end
			Table:PurgeCache(DM_WHO);
			_debug("Setting GUID in local from mergedata "..mdi.."...",0,1,0);
			for name,datar in rawpairs(dcdb.Count) do					-- raw local data
--				if ((name:len()~=4 or not tonumber(name,16)) and not md.Count[name]) then		-- it's not converted and it's different in merge-data
				if (not tonumber(name,16) and not md.Count[name]) then		-- it's not converted and it's different in merge-data
					local datan=dcdb.Count[name];								-- read old version
					for sguid,rawg in rawpairs(md.Count) do
--						if ((type(rawg)~="string" or rawg:find(name,1,true)) and sguid:len()==4 and tonumber(sguid,16)) then	-- found same name in converted local data
						if ((type(rawg)~="string" or rawg:find(name,1,true)) and tonumber(sguid,16)) then	-- found same name in converted local data
							local datag=md.Count[sguid];
							if (datag.Name==name) then DropCount.DB:ConvertMOB(name,sguid); break; end		-- convert data for import
						end MT:Yield();
			end end end
			Table:PurgeCache(DM_WHO);
			_debug("Setting C in local from mergedata "..mdi.."...",0,1,0);
			for name,datan in rawpairs(md.Count) do						-- raw import data - UNPACKED
				if (datan and datan.C) then
					local datal=dcdb.Count[name];
					if (datal and datan.C~=datal.C) then datal.C=datan.C; dcdb.Count[name]=datal; end
			end MT:Yield(); end
			Table:PurgeCache(DM_WHO);
			_debug("Setting C in mergedata "..mdi.." from local...",0,1,0);
			for name,datar in rawpairs(dcdb.Count) do					-- raw local data
				if (datar:find("worldboss",1,true) or datar:find("rare",1,true) or datar:find("elite",1,true)) then
					local datan=dcdb.Count[name];							-- read local version
					local datai=md.Count[name];
					if (datan and datai and datan.C~=datai.C) then datai.C=datan.C; md.Count[name]=datai; end
			end MT:Yield(); end
			Table:PurgeCache(DM_WHO);
		end
--		if (DropCount_Local_Code_Enabled) then DropCount.MT.DB:CleanImport(); end
		DropCount.Tracker.CleanImport.Cleaned=true;
		DropCount.MT:MergeDatabase();
		DropCount:ClearMergeTracker();
	end
	wipe(LootCount_DropCount_MergeData); LootCount_DropCount_MergeData=nil;
	dcdb.Tracker=nil;
	-- post-processing
	if (dcdb.MergedData~=dcdb.CleanedData) then
		DropCount.MT.DB:CleanDatabase();
		dcdb.CleanedData=dcdb.MergedData;
	end
	if (dcdb.MergedData~=dcdb.CleanedDataQG) then
		DropCount.PerformingAction="Cleaning quest givers";
		DropCount.MT.DB:CleanDatabaseQG();
		dcdb.CleanedDataQG=dcdb.MergedData;
		DropCount.PerformingAction=nil;
	end
	if (dcdb.PackerSweepCompleted~=Table.LastPackerVersion) then
		DropCount.PerformingAction="Upgrading database storage method";
		DropCount.MT:UpgradeDatabaseStorageVersion(dcdb);
		dcdb.PackerSweepCompleted=Table.LastPackerVersion;
		DropCount.PerformingAction=nil;
	end
	if (dcdb.MergedData~=dcdb.GatherNodeTrim) then
		DropCount.PerformingAction="Cleaning double dudes";
		DropCount.MT.DB:CleanDatabaseDD();		-- do double dudes at some point
		DropCount.PerformingAction="Trimming nodes";
		DropCount.MT.DB:TrimNodes();
		DropCount.PerformingAction=nil;
		dcdb.GatherNodeTrim=dcdb.MergedData;
	end

	-- temporary
--	DropCount.PerformingAction="Removing no-drop entries: Kill";
--	for k,v in pairs(dcdb.Count.__DATA__) do
--		if (k:len()<4) then
--			_debug(k);
--		end
--	end
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
	-- completely remove creatures from database (grid, items, count)
	if (LootCount_DropCount_RemoveData.Count) then
		for k,v in pairs(LootCount_DropCount_RemoveData.Count) do					-- do all
			if (v==false) then														-- there's one for complete removal
				for map,mapdata in pairs(dcdb.Grid.__DATA__) do						-- grab all maps and raw data
					if (mapdata:find(k,1,true)) then								-- if the raw data may contain the mob to remove
						local buf=dcdb.Grid[map];									-- unpack map data
						map,level=map:match("^(%d+)_(%d+)$");						-- grab map/level pair
						map,level=tonumber(map),tonumber(level);					-- make numbers
						for loc,mobs in pairs(buf) do								-- walk through all locations on this map/level
							if (mobs:find(k,1,true)) then							-- if the mob to remove may be in this location, then
								dcdb.Grid[map]=nil;									-- kill this location
								local x,y=xy(loc);									-- grab x/y location
								for _,sguid in ipairs({strsplit(",",mobs)}) do		-- walk all mobs in this location
									if (sguid~=k) then								-- if it's not the one to remove
										DropCount.Grid:Add(sguid,map,level,x,y);	-- add it to location
				end end end end end end
				DropCount:RemoveFromItems("Skinning",k);
				DropCount:RemoveFromItems("Name",k);
				dcdb.Count[k]=nil;
	end end end
	-- delete drops from creatures
	if (LootCount_DropCount_RemoveData.Count) then
		for npc,nData in pairs(LootCount_DropCount_RemoveData.Count) do
			if (nData~=false and dcdb.Count[npc]) then
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
	-- delete vendors
	if (LootCount_DropCount_RemoveData.Vendor) then
		for npc in pairs(LootCount_DropCount_RemoveData.Vendor) do
			if (dcdb.Vendor[npc]) then dcdb.Vendor[npc]=nil; end
	end end
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
	if (DropCount.Debug) then
		local pc;
		if (not mobs) then pc=floor((dcdb.Tracker.Total/dcdb.Tracker.Goal)*100);
		else pc=floor((dcdb.Tracker.Mobs/dcdb.Tracker.MobsGoal)*100); end
		if (pc%10==0 and pc>dcdb.Tracker.Printed) then
				dcdb.Tracker.Printed=floor(pc/10)*10;
				local sat=(0.4/100)*pc;
				if (not mobs) then _debug("Data merged: "..pc.."%",1-sat,.6+sat,.6);
				else _debug("debug: Mobs merged: "..pc.."%",1-sat,.6+sat,.6);
	end end end
	MT:Yield(nil,pc);
end

function DropCount.MT:MergeDatabase()
	if (not LootCount_DropCount_MergeData) then return false; end
	if (not dcdb.MergedData) then dcdb.MergedData=0; end
	if (LootCount_DropCount_MergeData.Version==dcdb.MergedData) then return false; end
	if (dcdb.Tracker.Total==0) then
		local sects=0;
		for _,md in ipairs(LootCount_DropCount_MergeData) do
			sects=sects+1;
			for _ in rawpairs(md.Count) do dcdb.Tracker.MobsGoal=dcdb.Tracker.MobsGoal+1; MT:Yield(); end
			for _ in rawpairs(md.Vendor) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			for _ in rawpairs(md.Item) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			for _,bT in dcdbpairs(md.Book) do
				for _ in pairs(bT) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			end
			for _,qT in pairs(md.Quest) do
				for _ in rawpairs(qT) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			end
			if (not md.Forge) then md.Forge={}; end
			for _ in rawpairs(md.Forge) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			if (not md.Trainer) then md.Trainer={ [CONST.MYFACTION]={}, }; end
			for _,tT in pairs(md.Trainer) do
				for _ in rawpairs(tT) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			end
			for _ in rawpairs(md.Grid) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			for _ in rawpairs(md.Gather.GatherNodes) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			for _ in rawpairs(md.Gather.GatherORE) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
			for _ in rawpairs(md.Gather.GatherHERB) do dcdb.Tracker.Goal=dcdb.Tracker.Goal+1; MT:Yield(); end
		end
		chat(Basic,LOOTCOUNT_DROPCOUNT_VERSIONTEXT);
		chat(lBlue,"There are "..dcdb.Tracker.Goal+dcdb.Tracker.MobsGoal.." entries to merge with your database.");
		chat(lBlue,"This will take some time, depending on the speed of your computer and the state of your current database.");
		chat(lBlue,"You can play while this is running, and you will probably experience lower FPS "..Basic.."while not in combat|r.");
		_debug("===> "..sects.." sections.",1,.6,.6);
	else _debug("===> Continuing data merger after relog...",1,.6,.6); end
	DropCount:UnpackMergedata();
	-- merge mobs
	dcdb.Tracker.Printed=-1;
	for s,md in ipairs(LootCount_DropCount_MergeData) do
--_debug("mob section",s);
		local strict=(dcdb.MergedData==4) or nil;	-- special case override for v4
		for mob in rawpairs(md.Count) do
			local newMob,updatedMob=DropCount.MT:MergeMOB(mob,s,strict);
			dcdb.Tracker.Mob.New=dcdb.Tracker.Mob.New+newMob;
			dcdb.Tracker.Mob.Updated=dcdb.Tracker.Mob.Updated+updatedMob;
			dcdb.Tracker.Mobs=dcdb.Tracker.Mobs+1;
			DropCount.MT:MergeStatus(true);			-- true = mob-merge update
	end end
	Table:PurgeCache(DM_WHO);
	-- merge everything else
	dcdb.Tracker.Printed=-1;
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		-- Gather locations
		local sect="GatherORE";
		repeat
			for mapID,gd in dcdbpairs(md.Gather[sect]) do
				dcdb.Tracker.Total=dcdb.Tracker.Total+1;
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
				dcdb.Tracker.Gather.Updated=dcdb.Tracker.Gather.Updated+1;
			end
			if (sect=="GatherORE") then sect="GatherHERB"; else sect=nil; end
		until(not sect);
		-- Gather nodes
		local lang=GetLocale();
		for oid,od in dcdbpairs(md.Gather.GatherNodes) do			-- do all incoming objectID's
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local buf=dcdb.Gather.GatherNodes[oid] or { Count=0, Loot={}, Name={}, };
			buf.Count=buf.Count or -1; od.Count=od.Count or 0; buf.Name=buf.Name or {};		-- in case of half registered and none-looted
			if (od.Count>buf.Count) then
				buf.Count=od.Count;						-- set higher count directly
				buf.Loot=od.Loot;						-- and use loot for that counter
				dcdb.Tracker.Nodes.Updated=dcdb.Tracker.Nodes.Updated+1;
			end
			buf.Icon=buf.Icon or od.Icon;				-- use other icon only if mine is missing
			if (not buf.Name[lang]) then	-- it's missing
				local ind=LootCount_DropCount_MergeData.indices[oid];
				if (ind.Name[lang]) then	-- exists in indices
					buf.Name[lang]=LootCount_DropCount_MergeData.indices[oid].Name[lang];				-- so set correct one
			end end
			dcdb.Gather.GatherNodes[oid]=buf;					-- save
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		-- Grid
		for z,zd in dcdbpairs(md.Grid) do							-- cycle grid areas
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local map,level=z:match("^(%d+)_(%d+)$"); map=tonumber(map); level=tonumber(level);		-- get area IDs
			for loc,dudes in pairs(zd) do							-- cycle all area entries
				local x,y=xy(loc);									-- get location
				for _,sguid in ipairs({strsplit(",",dudes)}) do DropCount.Grid:Add(sguid,map,level,x,y); end	-- add all location dudes to local database
				dcdb.Tracker.Grid.Updated=dcdb.Tracker.Grid.Updated+1;
				DropCount.MT:MergeStatus();	-- Will handle yield
		end end
		Table:PurgeCache(DM_WHO);
		-- Forges
		for area,merge in dcdbpairs(md.Forge) do repeat
			if (type(area)~="number") then break; end
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local localF=dcdb.Forge[area];
			if (localF) then
				for mi,mData in pairs(merge) do
					local saved,mX,mY=nil,mData:match("(.+)_(.+)"); mX=tonumber(mX); mY=tonumber(mY);
					for index,lData in pairs(localF) do
						MT:Yield();
						local lX,lY=lData:match("(.+)_(.+)"); lX=tonumber(lX); lY=tonumber(lY);
						if (mX>=lX-1 and mX<=lX+1 and mY>=lY-1 and mY<=lY+1) then
							localF[index]=mX.."_"..mY;			-- set new position
							dcdb.Tracker.Forge.Updated=dcdb.Tracker.Forge.Updated+1;
							saved=true;
							break;
						end
					end
					if (not saved) then
						table.insert(localF,mData);		-- add new forge
						dcdb.Tracker.Forge.New=dcdb.Tracker.Forge.New+1;
					end
				end
				dcdb.Forge[area]=localF;			-- save modified area data
			else
				dcdb.Forge[area]=merge;			-- save new area
			end
			DropCount.MT:MergeStatus();	-- Will handle yield
		until(true); end
		Table:PurgeCache(DM_WHO);
		-- Trainers
		for faction,fData in pairs(md.Trainer) do
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			if (not dcdb.Tracker.Trainer.New[faction]) then dcdb.Tracker.Trainer.New[faction]=0; end
			if (not dcdb.Tracker.Trainer.Updated[faction]) then dcdb.Tracker.Trainer.Updated[faction]=0; end
			for trainer,tData in dcdbpairs(fData) do
				if (not dcdb.Trainer[faction][trainer]) then dcdb.Tracker.Trainer.New[faction]=dcdb.Tracker.Trainer.New[faction]+1;
				else dcdb.Tracker.Trainer.Updated[faction]=dcdb.Tracker.Trainer.Updated[faction]+1; end
				dcdb.Trainer[faction][trainer]=tData;
				DropCount.MT:MergeStatus();	-- Will handle yield
		end end
		Table:PurgeCache(DM_WHO);
		-- Vendors
		for vend,vTable in dcdbpairs(md.Vendor) do
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local faction=vTable.Faction or "Unknown";
			if (not dcdb.Tracker.Vendor.New[faction]) then dcdb.Tracker.Vendor.New[faction]=0; end
			if (not dcdb.Tracker.Vendor.Updated[faction]) then dcdb.Tracker.Vendor.Updated[faction]=0; end
			if (not dcdb.Vendor[vend]) then
				dcdb.Vendor[vend]=vTable;
				dcdb.Tracker.Vendor.New[faction]=dcdb.Tracker.Vendor.New[faction]+1;
			else
				local updated,tv=nil,dcdb.Vendor[vend];
				local _x,_y,_m,_f,_s=Location_Decode(vTable._Location_);
				local __x,__y,__m,__f,__s=Location_Decode(tv._Location_);
				if (vTable._Location_ and tv._Location_) then
					if (floor(__x)~=floor(_x) or floor(__y)~=floor(_y) or __m~=_m or __f~=_f) then updated=true; end	-- need to save this
					tv._Location_=vTable._Location_;
					if (vTable.Faction) then tv.Faction=vTable.Faction; end
					if (vTable.Items) then
						if (not tv.Items) then tv.Items=copytable(vTable.Items); updated=true;			-- grab all items
						else
							for item,iTable in pairs(vTable.Items) do
								if (not tv.Items[item]) then tv.Items[item]=iTable; updated=true;
								else
									if (iTable~=-2 and tv.Items[item]==-2) then tv.Items[item]=iTable; updated=true; end
					end end end end
					if (updated) then
						dcdb.Tracker.Vendor.Updated[faction]=dcdb.Tracker.Vendor.Updated[faction]+1;
						dcdb.Vendor[vend]=tv;
					end
				else
					_debug(vend,vTable._Location_,tv._Location_);
					dcdb.Vendor[vend]=nil;
				end
			end
			md.Vendor[vend]=nil;	-- Done this vendor
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		Table:PurgeCache(DM_WHO);
		-- Books
		for title,bTable in dcdbpairs(md.Book) do
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local newB,updB=nil,nil;
			-- new
			for index,loc in pairs(bTable) do
				local newT,updT=DropCount:SaveBook(title,loc);
				if (not newB) then if (newT>0) then newB=true; updB=nil; elseif (updT) then updB=true; end end
			end
			if (newB) then dcdb.Tracker.Book.New=dcdb.Tracker.Book.New+1; end
			if (updB) then dcdb.Tracker.Book.Updated=dcdb.Tracker.Book.Updated+1; end
			DropCount.MT:MergeStatus();	-- Will handle yield
		end
		Table:PurgeCache(DM_WHO);
		-- Quests
		for faction,fTable in pairs(md.Quest) do
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			dcdb.Tracker.Quest.New[faction]=0;
			dcdb.Tracker.Quest.Updated[faction]=0;
			for npc,nTable in dcdbpairs(fTable) do
				if (not dcdb.Quest[faction][npc]) then		-- Don't have it, so take all
					dcdb.Quest[faction][npc]=nTable;
					dcdb.Tracker.Quest.New[faction]=dcdb.Tracker.Quest.New[faction]+1;
				else
					local updated=nil;
					-- Have it, so update location and merge quests
					local tn=dcdb.Quest[faction][npc];
					tn._Location_=nTable._Location_;
					if (not tn.Quests) then tn.Quests={}; end
					for i,qd in pairs(nTable.Quests) do
						for _i,_qd in pairs(tn.Quests) do
							if (qd.Quest==_qd.Quest and qd.Header==_qd.Header) then
								nTable.Quests[i]=false;					-- remove incoming quest as we have it already
							end
						end
					end
					for i,qd in pairs(nTable.Quests) do
						if (type(qd)=="table") then table.insert(tn.Quests,qd); updated=true; end
					end
					if (updated) then
						dcdb.Quest[faction][npc]=tn;
						dcdb.Tracker.Quest.Updated[faction]=dcdb.Tracker.Quest.Updated[faction]+1;
				end end
				DropCount.MT:MergeStatus();
		end end
		Table:PurgeCache(DM_WHO);
		-- item statics
		for item,miData in dcdbpairs(md.Item) do
			dcdb.Tracker.Total=dcdb.Tracker.Total+1;
			local saveit=nil;
			local buf=dcdb.Item[item];
			if (not buf) then
				buf=copytable(miData);
				if (buf.Name) then wipe(buf.Name); end			-- no known mobs
				if (buf.Skinning) then wipe(buf.Skinning); end	-- no known mobs
				dcdb.Tracker.Item.Updated=dcdb.Tracker.Item.Updated-1;	-- compensate
				dcdb.Tracker.Item.New=dcdb.Tracker.Item.New+1;			-- brand new item
				saveit=true;
			else
				-- merge quests
				if (miData.Quest) then buf.Quest=copytable(buf.Quest,miData.Quest); saveit=true; end
				-- merge best areas
				local score1,score2;
				if (miData.Best and buf.Best) then		-- all-round best
					_,_,_,score1=MapPlusNumber_Decode(miData.Best);
					_,_,_,score2=MapPlusNumber_Decode(buf.Best);
					if (score1>score2) then buf.Best=miData.Best; saveit=true; end
				end
				if (miData.BestW and buf.BestW) then	-- no-instance (world) best
					_,_,_,score1=MapPlusNumber_Decode(miData.BestW);
					_,_,_,score2=MapPlusNumber_Decode(buf.BestW);
					if (score1>score2) then buf.BestW=miData.BestW; saveit=true; end
				end
				if (buf.Best and buf.BestW) then		-- use only no-instance if better than all-round data
					_,_,_,score1=MapPlusNumber_Decode(buf.Best);
					_,_,_,score2=MapPlusNumber_Decode(buf.BestW);
					if (score2>score1) then buf.Best=buf.BestW; buf.BestW=nil; saveit=true; end
				end
			end
			if (saveit) then dcdb.Item[item]=buf; dcdb.Tracker.Item.Updated=dcdb.Tracker.Item.Updated+1; end
			DropCount.MT:MergeStatus();
		end
		Table:PurgeCache(DM_WHO);
		-- Maps (not counted in final report)
		if (dcmaps) then		-- I have maps
			for Lang,LTable in pairs(dcmaps) do		-- Check all locales I have
				if (md[Lang]) then		-- Hardcoded has same locale
					dcmaps[Lang]=copytable(md[Lang],dcmaps[Lang]);	-- Blend tables
					MT:Yield();
		end end end
	end
	-- Output result
	dcdb.MergedData=LootCount_DropCount_MergeData.Version;
	local text="";
	-- mobs
	if (dcdb.Tracker.Mob.New>0) then text=text.."\n"..dcdb.Tracker.Mob.New.." new mobs"; end
	if (dcdb.Tracker.Mob.Updated>0) then text=text.."\n"..dcdb.Tracker.Mob.Updated.." updated mobs"; end
	-- Vendors
	local amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Vendor.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new vendors"; end
	amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Vendor.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated vendors"; end
	-- Quests
	amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Quest.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new quest-givers"; end
	amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Quest.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated quest-givers"; end
	-- Books
	if (dcdb.Tracker.Book.New>0) then text=text.."\n"..dcdb.Tracker.Book.New.." new books"; end
	if (dcdb.Tracker.Book.Updated>0) then text=text.."\n"..dcdb.Tracker.Book.Updated.." updated books"; end
	-- Items
	if (dcdb.Tracker.Item.New>0) then text=text.."\n"..dcdb.Tracker.Item.New.." new items"; end
	if (dcdb.Tracker.Item.Updated>0) then text=text.."\n"..dcdb.Tracker.Item.Updated.." updated items"; end
	-- Trainers
	amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Trainer.New) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." new profession trainers"; end
	amount=0;
	for faction,fValue in pairs(dcdb.Tracker.Trainer.Updated) do amount=amount+fValue; MT:Yield(); end
	if (amount>0) then text=text.."\n"..amount.." updated profession trainers"; end
	-- Forges
	if (dcdb.Tracker.Forge.New>0) then text=text.."\n"..dcdb.Tracker.Forge.New.." new forges"; end
	if (dcdb.Tracker.Forge.Updated>0) then text=text.."\n"..dcdb.Tracker.Forge.Updated.." updated forges"; end
	-- nodes
	if (dcdb.Tracker.Nodes.Updated>0) then text=text.."\n"..dcdb.Tracker.Nodes.Updated.." profession node-types updated"; end
	-- gather
	if (dcdb.Tracker.Gather.Updated>0) then text=text.."\nProfession-maps updated"; end
	-- grid
	if (dcdb.Tracker.Grid.Updated>0) then text=text.."\nItem drop-maps updated"; end

	-- done
	chat(Default,"Your DropCount database has been updated.");
--	if (text:len()>0) then
--		text=LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."\nData merge summary:\n"..text;
--		StaticPopupDialogs["LCDC_D_NOTIFICATION"].text=text;
--		StaticPopup_Show("LCDC_D_NOTIFICATION");
--	end
	DropCount:NewVersion();
	Table:PurgeCache(DM_WHO)
	return true;
end

function DropCount.MT:ClearMobDrop(mob,section)
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

function DropCount.MT:MergeMOB(mob,mdSection)
	local newMob,updatedMob=0,0;
	local saveit,grabkill,grabprof=nil,nil,nil;
	local merge=LootCount_DropCount_MergeData[mdSection].Count[mob];	-- get external mob
	local buf=dcdb.Count[mob];									-- get local mob
--	if (not buf) then buf=copytable(merge); buf.Kill=0; buf.Skinning=0; newMob=1; end		-- if no local mob, make copy and set counts to zero
	if (not buf) then
		dcdb.Count.__DATA__[mob]=LootCount_DropCount_MergeData[mdSection].Count.__DATA__[mob];
		buf=dcdb.Count[mob];									-- get local mob
		buf.Kill=0; buf.Skinning=0; newMob=1;
	end
	buf.Kill=buf.Kill or 0;										-- set testable kills
	buf.Skinning=buf.Skinning or 0;								-- set testable skinnings

	if (merge.Kill and merge.Kill>buf.Kill) then				-- external has more kills
		DropCount.MT:ClearMobDrop(mob,"Name");					-- remove this mob from all items' kill-lists
		buf.Kill=merge.Kill;									-- grab the bigger kill-count
		updatedMob=1; grabkill=true;							-- mark and note
	end

	if (merge.Skinning and merge.Skinning>buf.Skinning) then	-- external has more skinnings
		DropCount.MT:ClearMobDrop(mob,"Skinning");				-- remove this mob from all items' skinning-lists
		buf.Skinning=merge.Skinning;							-- grab the bigger skinning-count
		updatedMob=1; grabprof=true;							-- mark and note
	end

	if (not grabkill and not grabprof) then return 0,0; end		-- no better numbers for this mob
	if (buf.Skinning==0) then buf.Skinning=nil; end				-- remove skinning entry if zero
	dcdb.Count[mob]=buf;										-- save updated/new mob locally

	local s;
	for i,item in rawpairs(LootCount_DropCount_MergeData[mdSection].Item) do repeat	-- normal iterator, as data is unpacked + enable break to continue loop
		MT:Yield();
		local saveit=nil;
		if (type(item)~="table" and type(item)~="nil") then
			Table:Unpack(i,LootCount_DropCount_MergeData[mdSection].Item);
			item=LootCount_DropCount_MergeData[mdSection].Item[i];
			if (type(item)~="table" and type(item)~="nil") then
				_debug(Red,"Packed data at key",i,"in merge-data ("..type(item)..")");
				_debug(item);
				break;
			end
		end
		if (i:match("^__.+__$")) then break; end
		s="Name";												-- do the kills
		if (grabkill and item[s] and item[s][mob]) then			-- the mob exists in this item's list
			buf=dcdb.Item[i];									-- grab local item
			if (not buf) then									-- if no local item
				buf=copytable(item);							-- copy external item
				buf.Name=buf.Name or {}; wipe(buf.Name);		-- make empty drop-list
				wipe(buf.Skinning or {});						-- wipe skinning-list if present
			end
			buf[s]=buf[s] or {};								-- prepare list
			buf[s][mob]=item[s][mob];							-- insert mob
			saveit=true;										-- changes made
		end
		s="Skinning";											-- do the skinnings
		if (grabprof and item[s] and item[s][mob]) then			-- the mob exists in this item's list
			buf=dcdb.Item[i];									-- grab local item
			if (not buf) then									-- if no local item
				buf=copytable(item);							-- copy external item
				buf.Name=buf.Name or {}; wipe(buf.Name);		-- make empty drop-list
				wipe(buf.Skinning or {});						-- wipe skinning-list if present
			end
			buf[s]=buf[s] or {};								-- prepare list
			buf[s][mob]=item[s][mob];							-- insert mob
			saveit=true;										-- changes made
		end
		if (saveit) then dcdb.Item[i]=buf; end					-- save changes
	until(true); end

	if (newMob==1) then updatedMob=0; end

	return newMob,updatedMob;
end

function DropCountXML.MinimapOnEnter(frame)
	GameTooltip:SetOwner(frame,"ANCHOR_LEFT");
	GameTooltip:SetText("DropCount");
	GameTooltipTextLeft1:SetTextColor(0,1,0);
	GameTooltip:Add(LOOTCOUNT_DROPCOUNT_VERSIONTEXT);
	GameTooltip:Add(Basic.."<Left-click>|r for menu");
	GameTooltip:Add(Basic.."<Right-click>|r and drag to move");
	GameTooltip:Add(Basic.."<Shift-right-click>|r and drag for free-move");
	if (DropCount.LootCount.Registered) then GameTooltip:Add(Basic.."LootCount: "..Green.."Present"); end
	if (DropCount.Crawler.Registered) then GameTooltip:Add(Basic.."Crawler: "..Green.."Present"); end
	GameTooltip:Show();
end

function DropCountXML.MinimapOnClick(frame)
	local menu=DMMenuCreate(DropCount_MinimapIcon);
	local entry;
	menu:Header("GUI");
	menu:Add("Search...",function() LCDC_VendorSearch:Show(); end);
	menu:Add("Data...",DropCountXML.ShowDataOptionsFrame);
	local omenu=menu:Submenu("Options");
		omenu:Add("Single drop",function() dccs.ShowSingle=(not dccs.ShowSingle and true) or nil; end,DDT_CHECK,dccs.ShowSingle,"Display items that has dropped only once from a creature.");
		omenu:Add("Add to tooltip",function() dccs.NoTooltip=(not dccs.NoTooltip and true) or nil; end,DDT_CHECK,not dccs.NoTooltip,"Display where an item have the best drop chance in items' tooltip.");
		omenu:Add("Compact tooltip",function() dccs.CompactView=(not dccs.CompactView and true) or nil; end,DDT_CHECK,dccs.CompactView,"Enable for more compact tooltips. Some information will not show with this setting enabled.");
		omenu:Add("Map quest items",function() dccs.MapQuestItems=(not dccs.MapQuestItems and true) or nil; MT:Run("Scan Quest List",DropCount.MT.Quest.Scan); end,DDT_CHECK,dccs.MapQuestItems,"Map quest items on the world map.");
		omenu:Add("Map quest creatures",function() dccs.MapQuestCreatures=(not dccs.MapQuestCreatures and true) or nil; MT:Run("Scan Quest List",DropCount.MT.Quest.Scan); end,DDT_CHECK,dccs.MapQuestCreatures,"Map quest creatures on the world map.");
		omenu:Add("Unnamed mobs",function() dccs.ShowUnnamedMobs=(not dccs.ShowUnnamedMobs and true) or nil; end,DDT_CHECK,dccs.ShowUnnamedMobs,"Some mobs may not have a name in the database in your language yet. This option will display them using their internal code if their name is missing.");
	menu:Add(Green.."\"How do I ...\"",DropCount.ShowFAQ);
	menu:Add(Green.."About DropCount...",DropCount.About);
	menu:Separator();
	menu:Header("Display");
	if (not next(dccs.Monitor)) then
		menu:Add("Add item monitor",function () DropCount.GUI.CreateGUI(dccs.LastMonitorMode or "default"); end);
	else
		local tmp=0;
		local smenu=menu:Submenu("Remove monitor");
		for k,v in ipairs(dccs.Monitor) do
			smenu:Add((v.item and (GetItemInfo(v.item) or (dcdb.Item[v.item] and dcdb.Item[v.item].Item))) or "<unknown>",
						function () for _,fr in ipairs(gui) do if (fr.storage==v) then fr:Remove(); end end end );
			tmp=tmp+1;
		end
		if (tmp>1) then
			smenu:Separator();
			smenu:Add("All",function() for k,v in ipairs(gui) do v:Remove(); end end );
		end
	end
	-- add all filtering options
	local sheetinuse; for _,t in pairs(dccs.Sheet or {}) do for _ in pairs(t) do sheetinuse=true; break; end end
	if (not dcdb.DontFollowVendors) then		-- vendor-specific section
		menu:Add("Profession vendors",function(b,c) dccs.Filter.VendorProfession=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dccs.Filter.VendorProfession,nil,nil,0,"Interface\\GROUPFRAME\\UI-Group-MasterLooter");
		if (dccs.Filter.VendorItem) then
			local smenu=menu:Submenu("Vendor item");
			smenu:Add("Remove all",function() dccs.Filter.VendorItem=nil; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end);
			for k in pairs(dccs.Filter.VendorItem) do
				local item; _,_,item=GetItemInfo(k);
				if (item) then _,_,_,item=GetItemQualityColor(item); else item=White; end
				if (not dcdb.Item[k].Item) then item=k;
				else item="|c"..item.."["..dcdb.Item[k].Item.."]|r"; end
				smenu:Add("Remove "..item,function() dccs.Filter.VendorItem[k]=nil; if (not next(dccs.Filter.VendorItem)) then dccs.Filter.VendorItem=nil; end MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end);
			end
		end
	end
	if (sheetinuse) then
		local smenu=menu:Submenu("Worldmap locations");
		smenu:Add("Remove all",function() dccs.Sheet=nil; end);
		for s,st in pairs(dccs.Sheet) do
			for k in pairs(st) do
				local text;
				if (s=="Item") then
					_,_,text=GetItemInfo(k); if (text) then _,_,_,text=GetItemQualityColor(text); else text=""; end
					if (not dcdb.Item[k].Item) then text=k; else text="|c"..text.."["..dcdb.Item[k].Item.."]|r"; end
					if (st[k].questitem) then
						text=text..Basic.." *|r";
					end
				elseif (s=="Creature") then text=(dcdb.Count[k] and dcdb.Count[k].Name) or "Nameless creature";
				else text=k; end
				smenu:Add("Remove "..text,function() dccs.Sheet[s][k]=nil; end);
			end
		end
--	dccs.Sheet[section][code]={icon=icon,name=name};
	end
	entry=menu:Add("Gathering coverage",function(b,c,e) dccs.Filter.GatherCoverage=c; dccs.PaintTimer=floor(tonumber(e) or 2); if (dccs.PaintTimer<1) then dccs.PaintTimer=1; end end,DDT_CHECK,dccs.Filter.GatherCoverage);
		entry:AddEdit(dccs.PaintTimer or 2,25,"min",1,15);
	menu:Separator();
	menu:Header("Minimap");
	if (not dcdb.DontFollowVendors) then menu:Add("Vendors",function(b,c) dcdb.VendorMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.VendorMinimap,nil,nil,0,"Interface\\GROUPFRAME\\UI-Group-MasterLooter"); end
	if (not dcdb.DontFollowVendors) then menu:Add("Repair",function(b,c) dcdb.RepairMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.RepairMinimap,nil,nil,0,"Interface\\GossipFrame\\VendorGossipIcon"); end
	if (not dcdb.DontFollowBooks) then menu:Add("Books",function(b,c) dcdb.BookMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.BookMinimap,nil,nil,0,"Interface\\Spellbook\\Spellbook-Icon"); end
	if (not dcdb.DontFollowQuests) then menu:Add("Quests",function(b,c) dcdb.QuestMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.QuestMinimap,nil,nil,0,"Interface\\QuestFrame\\UI-Quest-BulletPoint"); end
	if (not dcdb.DontFollowTrainers) then menu:Add("Trainers",function(b,c) dcdb.TrainerMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.TrainerMinimap,nil,nil,0,"Interface\\Icons\\INV_Misc_QuestionMark"); end
	if (not dcdb.DontFollowForges) then menu:Add("Forges",function(b,c) dcdb.ForgeMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.ForgeMinimap,nil,nil,0,CONST.PROFICON[5]); end
	if (not dcdb.DontFollowGrid) then menu:Add("Rare creatures",function(b,c) dcdb.RareMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.RareMinimap,nil,nil,0,"INTERFACE\\Challenges\\ChallengeMode_Medal_Silver"); end
	if (DropCount_Local_Code_Enabled) then
		if (not dcdb.DontFollowGrid) then menu:Add("* Grid",function(b,c) dcdb.GridMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.GridMinimap); end
		if (not dcdb.DontFollowGather) then menu:Add("* Ores",function(b,c) dcdb.OreMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.OreMinimap); end
		if (not dcdb.DontFollowGather) then menu:Add("* Herbs",function(b,c) dcdb.HerbMinimap=c; MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap); end,DDT_CHECK,dcdb.HerbMinimap); end
	end
	menu:Separator();
	menu:Header("Worldmap");
	if (not dcdb.DontFollowVendors) then menu:Add("Vendors",function(b,c) dcdb.VendorWorldmap=c; end,DDT_CHECK,dcdb.VendorWorldmap,nil,nil,0,"Interface\\GROUPFRAME\\UI-Group-MasterLooter"); end
	if (not dcdb.DontFollowVendors) then menu:Add("Repair",function(b,c) dcdb.RepairWorldmap=c; end,DDT_CHECK,dcdb.RepairWorldmap,nil,nil,0,"Interface\\GossipFrame\\VendorGossipIcon"); end
	if (not dcdb.DontFollowBooks) then menu:Add("Books",function(b,c) dcdb.BookWorldmap=c; end,DDT_CHECK,dcdb.BookWorldmap,nil,nil,0,"Interface\\Spellbook\\Spellbook-Icon"); end
	if (not dcdb.DontFollowQuests) then menu:Add("Quests",function(b,c) dcdb.QuestWorldmap=c; end,DDT_CHECK,dcdb.QuestWorldmap,nil,nil,0,"Interface\\QuestFrame\\UI-Quest-BulletPoint"); end
	if (not dcdb.DontFollowTrainers) then menu:Add("Trainers",function(b,c) dcdb.TrainerWorldmap=c; end,DDT_CHECK,dcdb.TrainerWorldmap,nil,nil,0,"Interface\\Icons\\INV_Misc_QuestionMark"); end
	if (not dcdb.DontFollowForges) then menu:Add("Forges",function(b,c) dcdb.ForgeWorldmap=c; end,DDT_CHECK,dcdb.ForgeWorldmap,nil,nil,0,CONST.PROFICON[5]); end
	if (not dcdb.DontFollowGrid) then menu:Add("Rare creatures",function(b,c) dcdb.RareWorldmap=c; end,DDT_CHECK,dcdb.RareWorldmap,nil,nil,0,"INTERFACE\\Challenges\\ChallengeMode_Medal_Silver"); end
	if (not dcdb.DontFollowGather) then menu:Add("Ores",function(b,c) dcdb.OreWorldmap=c; end,DDT_CHECK,dcdb.OreWorldmap); end
	if (not dcdb.DontFollowGather) then menu:Add("Herbs",function(b,c) dcdb.HerbWorldmap=c; end,DDT_CHECK,dcdb.HerbWorldmap); end
	if (DropCount_Local_Code_Enabled) then
		if (not dcdb.DontFollowGrid) then menu:Add("* Grid",function(b,c) dcdb.GridWorldmap=c; end,DDT_CHECK,dcdb.GridWorldmap); end
		menu:Add("* Movement",function(b,c) dccs.Filter.ShowMovement=c; end,DDT_CHECK,dccs.Filter.ShowMovement);
	end
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

function DropCount:GetUniqueID(link)
	if (type(link)~="string") then
		if (type(link)~="number") then return 0; end
		_,link=GetItemInfo(link);
	end
	local itemID,ench,g1,g2,g3,g4,suff,uid=link:match("|Hitem:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
	if (not uid) then
		itemID,ench,g1,g2,g3,g4,suff,uid=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)");
	end
	if (not uid) then return 0; end
	return tonumber(uid),uid;
end

-- Multi-threading utility
function MT:Run(name,func,...)
	if (_G["Ac".."cura".."teTime"]) then
		if (_G["Ac".."cura".."teTime"]._debugprofilestop) then debugprofilestop=_G["Ac".."cura".."teTime"]._debugprofilestop; end
		if (_G["Ac".."cura".."teTime"]._debugprofilestart) then debugprofilestart=_G["Ac".."cura".."teTime"]._debugprofilestart; end
	end
	for _,tTable in pairs(self.Threads) do
		if (tTable.orig==func and tTable.name==name) then
--			_debug("debug:",name.."> Already running in another thread. Aborted.");
			return;
	end end
	self.RunningCo=true;
	_debug(Basic,"MT STARTING:",White,name);
	self.Count=self.Count+1;
	self.Threads[self.Count]={ start=debugprofilestop(), name=name, orig=func, cr=coroutine.create(func), };
	self.Threads[self.Count].runtime=0;
	self.LastTime=self.Threads[self.Count].start;
	self.LastStack="Running "..name;
	local succeeded,result=coroutine.resume(self.Threads[self.Count].cr,...);
	if (not succeeded and Swatter) then
		if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
		else chat(result); chat(self.LastStack); end
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
function MT:YieldExtFast() MT:Yield(true); end

function MT:Next()
	if (self.Count<1) then return; end		-- no processes running
	if (self.RunningCo) then return; end	-- Don't if we are already doing it. In case of real MT.
	self.Current=self.Current+1;
	if (not self.Threads[self.Current]) then self.Current=1; end	-- Wrap
	if (not self.Threads[self.Current]) then return; end	-- Nothing to do
	if (coroutine.status(self.Threads[self.Current].cr)=="dead") then
		local removeIt=self.Current;
		local runtime=debugprofilestop()-self.Threads[removeIt].start;
		local amount=(100/runtime)*self.Threads[removeIt].runtime;
		_debug(Green,"MT DONE:",White,self.Threads[removeIt].name,string.format("%s%.2f%%",(amount>=5 and Red) or Green,amount),White,floor(self.Threads[removeIt].runtime),"ms");
		while (self.Threads[removeIt]) do self.Threads[removeIt]=self.Threads[removeIt+1]; removeIt=removeIt+1; end
		self.Current=self.Current-1;
		self.Count=self.Count-1;
		return;
	end
	self.RunningCo=true;
	self.Threads[self.Current].slice=debugprofilestop();
	local succeeded,result=coroutine.resume(self.Threads[self.Current].cr);
	self.Threads[self.Current].runtime=self.Threads[self.Current].runtime+(debugprofilestop()-self.Threads[self.Current].slice);
	if (not succeeded) then
		DropCount.Loaded=nil;		-- crash the main thread
		if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
		else chat(result); chat(self.LastStack); end
	end
	self.RunningCo=nil;
end

function MT:Processes() return self.Count; end

-- "match" will fail due to miscount in this if byte-coding for the saved file has been changed.
-- speedy version
function Table.v03.DecodeTable(s)
	local _match,_tonumber,_settype,_sub,_byte=string.match,tonumber,Table.v03.SetType,string.sub,string.byte;	-- make everything local
	local nTY,nLE,name,dTY,dLE;
	local pos,maxlen,t=1,s:len(),{};
	repeat
		nTY=_byte(s,pos);													-- get type with numeric representation to not create a new string
		nLE,pos=_match(s,".(%x-):().*",pos); nLE=_tonumber(nLE,16);			-- capture data-length,position - convert length to number
		name=_settype(nTY,_sub(s,pos,pos+(nLE-1))); pos=pos+nLE;			-- grab it and advance to next
		dTY=_byte(s,pos);													-- get type with numeric representation to not create a new string
		dLE,pos=_match(s,".(%x-):().*",pos); dLE=_tonumber(dLE,16);			-- empty capture reads character position
		t[name]=_settype(dTY,_sub(s,pos,pos+(dLE-1))); pos=pos+dLE;			-- grab, shove, advance
	until (pos>maxlen);
	return t;
end

-- third letter of native type string - lower case, hex representation for avoiding string
function Table.v03.SetType(ty,da)
	if (ty==0x72) then return tostring(da); end		-- st-r-ing
	if (ty==0x6D) then return tonumber(da); end		-- nu-m-ber
	if (ty==0x6F) then return (da=="true"); end		-- bo-o-l
	if (ty==0x62) then if (da=="") then return {}; end return Table.v03.DecodeTable(da); end	-- ta-b-le
	if (ty==0x6C) then return nil; end				-- ni-l-
	if (ty==0x6E) then return loadstring(da); end	-- fu-n-ction
	return da;
end

-- this function:
--   accesses all global functions locally for speed
--   uses table concat for extreme speed in repetetive storage, like cloth with 700+ creatures codes in well under 5ms
--   In case of further timing problems: further work can be to store all strings separately to remove all string concatenations
function Table.v03.CodeTable(t)
	local _string_format,_codetable,_tostring,_type,_len,_sub,_dump=string.format,Table.v03.CodeTable,tostring,type,string.len,string.sub,string.dump;	-- make everything local
	local list={};
	local tmp,add;
	for en,ed in pairs(t) do
		tmp=_tostring(en);
--		if (_type(ed)=="table") then add=_codetable(ed); else add=_tostring(ed); end
		if (_type(ed)=="table") then add=_codetable(ed); elseif (_type(ed)=="function") then add=_dump(ed); else add=_tostring(ed); end
		list[#list + 1]=_sub(_type(en),3,3).._string_format("%X",_len(tmp))..":"..tmp.._sub(_type(ed),3,3).._string_format("%X",_len(add))..":"..add;
	end
	return table.concat(list);
end

--function Table:Init(who,UseCache,Base)
--	if (who=="Default") then return; end
--	if (not Base) then return nil; end
--	if (not self.Default[who]) then self.Default[who]={}; end
--	wipe(self.Default[who]);
--	self.Default[who].UseCache	= UseCache;
--	self.Default[who].Base		= Base;
--	self.Default[who].Cache		= {};
--end

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
	chat(Yellow.."List of slowest v3 compressions:");
	for i,d in ipairs(Table.tableSlowCompress) do chat(i,Red..string.format("%.1f",d.t).." ms",Green..d.s,Yellow..d.e); end
end

function Table:DecompressV3(ref,cString,anon)
	if (cString=="") then ref={}; return ref; end
	ref=Table.v03.DecodeTable(cString);			-- store at given reference
	return ref;
end

-- applies correct compressor and handles cache
-- Table:Write(DM_WHO,k,v,t);
function Table:Write(_,entry,raw,base)
	local sub1,sub2=base.__METADATA__.sub1,base.__METADATA__.sub2;
	local cache=self:GetCache(base,sub1,sub2);
	base=base.__DATA__;
	if (raw) then
		base[entry]="03"..self:CompressV3(raw,sub1,entry);	-- timing debug -> section, entry
	else base[entry]=nil; end
	if (cache) then cache[entry]=raw; end
	if (sub2=="GatherNodes" and type(raw)=="table") then
		setmetatable(raw,dropcountnodemeta);
	end
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

-- Unpack an entry from meta and store it back unpacked. Import-data only.
function Table:Unpack(entry,base)
	if (not base) then return; end
	local raw=base.__DATA__;
	if (not raw or not raw[entry]) then return; end
	if (type(raw[entry])~="string") then return; end
	rawset(raw,entry,base[entry]);				-- store unpacked by meta over packed
	if (type(raw[entry])~="table") then
		chat("Unpacker did not unpack ("..type(raw[entry])..")");
	end
end

function Table:GetCache(base,sub1,sub2)
	if (base==dcdb[sub1] or (sub2 and base==dcdb[sub1][sub2])) then				-- only cache for base data
		if (not Table.Cache[sub1]) then Table.Cache[sub1]={}; end				-- create level 1 if absent
		if (not sub2) then return Table.Cache[sub1]; end						-- no level 2, use level 1 cache only
		if (not Table.Cache[sub1][sub2]) then Table.Cache[sub1][sub2]={}; end	-- create level 2 if absent
		return Table.Cache[sub1][sub2];											-- use this cache
	end
	return nil;																	-- no cache for this entry
end

-- applies correct decompressor and handles cache
-- Table:Read(DM_WHO,k,t,t.__METADATA__.sub1,t.__METADATA__.sub2);
function Table:Read(_,entry,root)
	local cache=self:GetCache(root,root.__METADATA__.sub1,root.__METADATA__.sub2);
	if (cache and cache[entry]) then return cache[entry]; end			-- got it, so use it
	if (not root.__DATA__[entry]) then return nil; end					-- entry does not exist, so nil
	local base=root.__DATA__;											-- go to raw level
	if (type(base[entry])~="string") then								-- not a packed entry
		if (type(base[entry])=="table") then return base[entry]; end	-- use unpacked entry directly
		_debug("debug: Got "..type(base[entry]).." as entry");
		return nil;														-- wrong entry type
	end
	local fnDecompress=self["DecompressV"..(base[entry]:sub(2,2) or "0")];	-- find decompressor
	if (not fnDecompress) then return nil; end							-- no decompressor for this data
	if (not cache) then wipe(self.Scrap); cache=self.Scrap; end			-- not using cache, so use scrapbook for decompression
	cache[entry]=fnDecompress(self,{},base[entry]:sub(3),true);			-- decompress to cache/scrap
	if (root.__METADATA__.sub2=="GatherNodes") then
		setmetatable(cache[entry],dropcountnodemeta);
	end
	return cache[entry];
end

function Table:PurgeCache(_,_) wipe(Table.Cache); end

-- Drop grid
DropCount.Grid={};
function DropCount.Grid:Add(sguid,map,level,x,y)
	if (not sguid or sguid==0 or not dcdb.Count[sguid] or not dcdb.Count[sguid].Name) then return; end	-- no dude
	map=map or 0; level=level or 0; x=x or 0; y=y or 0;								-- make legal
	if (map==0) then map,level=CurrentMap(); end									-- none provided, use current
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
	dcdb.Grid[map]=buf;					-- pack and store
end

-- toggle tooltipped item or creature
function DropCountXML:ToggleGridFilter()
	if (DropCountXML:ToggleGridFilter_Item()) then return; end
	DropCountXML:ToggleGridFilter_Creature();
end

-- toggle tooltipped item grid inclusion
function DropCountXML:ToggleGridFilter_Creature()
	local unit,sguid=UnitName("mouseover"),DropCount.MakeSGUID(UnitGUID("mouseover")); if (not unit or not sguid) then return nil; end
	if (DropCountXML.AddUnitToGridFilter("Creature",unit,sguid)) then			-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
		chat(Basic.."Creature "..Yellow..unit..Basic.." is now "..Green.."shown"..Basic.." on the worldmap.");
	else
		chat(Basic.."Creature "..Yellow..unit..Basic.." has been "..Red.."removed"..Basic.." from the worldmap.");
	end
	return true;
end

-- toggle tooltipped item grid inclusion
function DropCountXML:ToggleGridFilter_Item()
	if (not GameTooltip:IsVisible()) then return nil; end
	local name,item=GameTooltip:GetItem(); item=getid(item); if (not item or not name) then return nil; end
	if (DropCountXML.AddUnitToGridFilter("Item",name,item)) then			-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
		chat(Basic.."Item "..Yellow..name..Basic.." is now "..Green.."shown"..Basic.." on the worldmap.");
	else
		chat(Basic.."Item "..Yellow..name..Basic.." has been "..Red.."removed"..Basic.." from the worldmap.");
	end
	return true;
end

function DropCountXML:TableBytes(t)
	local bytes=40; for _,raw in rawpairs(t) do if (type(raw)=="table") then bytes=bytes+self:TableBytes(raw); else bytes=bytes+tostring(raw):len()+17; end end return bytes;
end

-- grab copy, wipe storage, recreate everything
function DropCount.GUI:reCreateGUI()
	local buf=dccs.Monitor; dccs.Monitor={};
	for _,reg in ipairs(buf) do
		local frame=DropCount.GUI:CreateGUI(reg.mode);		-- creates and links to real storage
		frame.storage=copytable(reg,frame.storage);
		frame:SetItem(frame.storage.item);
		frame:PositionMonitor(frame.storage.left,frame.storage.bottom);
	end
end

function DropCount.GUI.PositionMonitor(frame,L,B)
	frame.storage.left=L or (UIParent:GetWidth()/2)
	frame.storage.bottom=B or (UIParent:GetHeight()*0.75);
	frame:ClearAllPoints();
	frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",frame.storage.left or (UIParent:GetWidth()/2),frame.storage.bottom or (UIParent:GetHeight()*0.75));
end

-- tag all monitors glued to the supplied monitor - must use "glue edge" setting, snapped position is not enought
function DropCount.GUI.TagFrameGroup(frame,tag,verticalOnly)
	local fL,fB=frame.storage.left,frame.storage.bottom;
	local frL,frB;
	local grouped=nil;
	local slack=.5;			-- WoW "pixels" operates with fractions
	for _,fr in ipairs(gui) do
		if (fr[tag]) then grouped=true; end
		if (fr~=frame and fr:IsVisible() and not fr.storage.freemove and not fr[tag]) then
			frL,frB=fr.storage.left,fr.storage.bottom;
			if (frL>fL-slack and frL<fL+slack) then							-- same horisontal
				if (frB>(fB+frame:GetHeight())-slack and frB<(fB+frame:GetHeight())+slack) then fr[tag]=true; grouped=true; fr:TagFrameGroup(tag,verticalOnly); end
				if (frB>(fB-frame:GetHeight())-slack and frB<(fB-frame:GetHeight())+slack) then fr[tag]=true; grouped=true; fr:TagFrameGroup(tag,verticalOnly); end
			end
			if (not verticalOnly and frB>fB-slack and frB<fB+slack) then	-- same vertical
				if (frL>(fL+frame:GetWidth())-slack and frL<(fL+frame:GetWidth())+slack) then fr[tag]=true; grouped=true; fr:TagFrameGroup(tag,verticalOnly); end
				if (frL>(fL-frame:GetWidth())-slack and frL<(fL-frame:GetWidth())+slack) then fr[tag]=true; grouped=true; fr:TagFrameGroup(tag,verticalOnly); end
			end
		end
	end
	frame[tag]=grouped;			-- tag yourself if there are others
	return grouped;
end

-- untag all monitors and re-evaluate position for all grouped monitors
function DropCount.GUI.UntagFrameGroup(frame,tag,reposition)
	local found=nil;
	for _,fr in ipairs(gui) do
		if (fr~=frame and fr:IsVisible() and fr[tag]) then
			if (reposition) then
				fr:PositionMonitor(frame.storage.left-fr.osL,frame.storage.bottom-fr.osB);	-- offset to dragged frame
			end
			found=true;
		end
		fr.startL=nil; fr.startB=nil; fr[tag]=nil; fr.osL=nil; fr.osB=nil;
	end
	return found;
end

function DropCount.GUI:AssignAutoItems()
	local hval,hitem,foundslot;
	wipe(guiitemswork); guiitemswork=copytable(guiitems);
	-- prep gui
	for _,fr in ipairs(gui) do
		if (fr:IsVisible()) then
			if (fr.storage.autoitem) then fr.storage.autoitem=true;				-- reset auto-assigned items
			elseif (fr.FollowItem) then guiitemswork[fr.FollowItem]=nil; end	-- remove any auto-items that is manually placed elsewhere
		else
			fr.storage.autoitem=nil;				-- then I don't have to check IsVisible() again later
		end
	end
	-- grab auto-items' percentage
	for item in pairs(guiitemswork) do
		guiitemswork[item]=(DropCount:TimedQueueRatio(getid(item),true) or 0)*100;
	end
	-- select by loot yield
	repeat
		hval,hitem,foundslot=0,nil,nil;
		for item,pct in pairs(guiitemswork) do
			if (pct>hval) then hval=pct; hitem=item; end
		end
		if (hitem) then
			for _,fr in ipairs(gui) do						-- walks through it in creation order
				if (fr.storage.autoitem==true) then			-- wants item and still unassigned
					fr.storage.autoitem=hitem;
					fr:SetItem(hitem);
					foundslot=true;
					break;
				end
			end
			guiitemswork[hitem]=nil;						-- assigned now, so remove for next iteration
		end
	until(not foundslot or not next(guiitemswork));			-- as long as there are free slots and unassigned items
	-- clean up auto-slots
	if (foundslot) then												-- it assigned all items, so there could be more slots than items
		for _,fr in ipairs(gui) do									-- walks through it in creation order
			if (fr.storage.autoitem==true) then fr:SetItem(); end	-- clear unassigned monitors
		end
	end
end

function DropCount.GUI:CreateGUI(mode)
	mode=mode or dccs.LastMonitorMode;
	local reuse,frame=nil,nil;
	for _,fr in ipairs(gui) do if (not fr:IsVisible()) then frame=fr; reuse=true; end end		-- reuse a hidden monitor
	if (not reuse) then
		frame=CreateFrame("Frame",nil,UIParent);
		frame:EnableMouse(true);
		frame:SetMovable(true);
		frame._LCDC={};
		frame._LCDC.Icon=frame:CreateTexture();
		frame._LCDC.Header=frame:CreateFontString();
		frame._LCDC.Header:SetFontObject("GameFontNormal");
		frame._LCDC.Counter=frame:CreateFontString();
		frame._LCDC.Counter:SetFontObject("GameFontNormal");
		frame._LCDC.Bar=frame:CreateTexture("BACKGROUND");
		frame.FullWidth=1;
		addclass(DropCount.GUI,frame);
	end
	frame._LCDC.Bar:SetTexture("Interface\\AddOns\\LootCount_DropCount\\white.tga");
	frame._LCDC.Bar:SetVertexColor(.4,.4,1,.6);		-- r,g,b,a
	frame.Ticker=0;
	dccs.Monitor[#(dccs.Monitor)+1]={  };
	frame.storage=dccs.Monitor[#(dccs.Monitor)];
	frame.storage.autoitem=true;			-- default
	frame.storage.max=0;
	frame:SetMode(mode);
	frame:PositionMonitor();
	frame:SetScript("OnUpdate",DropCount.GUI._OnUpdate);
	frame:SetScript("OnMouseDown",DropCount.GUI._OnClick);
	frame:SetScript("OnReceiveDrag",function(frame) if (frame.storage.locked) then return; end frame.storage.autoitem=nil; local item,_,link=GetCursorInfo(); ClearCursor(); if (item=="item") then frame:SetItem(link); frame.Ticker=0; end end );
	frame:SetScript("OnDragStart",function(frame,LR)
			if (frame.storage.locked) then return; end
			if (LR=="LeftButton") then
				frame:StartMoving();
				if (not frame.storage.freemove) then frame:TagFrameGroup("glued"); end		-- got glue on edges?
			end
		end);
	frame:SetScript("OnDragStop",function(frame,LR)
			frame:StopMovingOrSizing();
			frame:PositionMonitor(frame.startL+DropCount.GUI.offsetL,frame.startB+DropCount.GUI.offsetB);
			if (not frame:UntagFrameGroup("glued",true)) then frame:Snap(); end		-- none glued, snap normally
		end);
	frame:RegisterForDrag("LeftButton");	-- moving
	if (not reuse) then table.insert(gui,frame); end
	frame._LCDC.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
	frame:SetItem();
	frame:SetPercent(0);
	return frame;
end

function DropCount.GUI.Snap(frame)
	local snap,snapL,snapT=15,nil,nil;
	frame.storage.left=frame:GetLeft(); frame.storage.bottom=frame:GetBottom();
	-- left
	local span,tmp=frame:GetWidth();
	for _,reg in ipairs(dccs.Monitor) do if (reg~=frame.storage) then		-- don't snap to yourself
		tmp=frame.storage.left-reg.left;
		if (tmp<span+snap and tmp>span-snap) then
			frame:PositionMonitor(reg.left+span,frame.storage.bottom);
			snapL=true;
		end
		tmp=reg.left-frame.storage.left;
		if (tmp<span+snap and tmp>span-snap) then
			frame:PositionMonitor(reg.left-span,frame.storage.bottom);
			snapL=true;
		end
		if (abs(frame.storage.left-reg.left)<snap) then
			frame:PositionMonitor(reg.left,frame.storage.bottom);
			snapL=true;
		end
	end end
	-- bottom
	span=frame:GetHeight();
	for _,reg in ipairs(dccs.Monitor) do if (reg~=frame.storage) then		-- don't snap to yourself
		tmp=frame.storage.bottom-reg.bottom;
		if (tmp<span+snap and tmp>span-snap) then
			frame:PositionMonitor(frame.storage.left,reg.bottom+span);
			snapT=true;
		end
		tmp=reg.bottom-frame.storage.bottom;
		if (tmp<span+snap and tmp>span-snap) then
			frame:PositionMonitor(frame.storage.left,reg.bottom-span);
			snapT=true;
		end
		if (abs(frame.storage.bottom-reg.bottom)<snap) then
			frame:PositionMonitor(frame.storage.left,reg.bottom);
			snapT=true;
		end
	end end
	-- edge
	if (not snapL) then
		if (frame.storage.left<(snap/2)) then
			frame:PositionMonitor(0,frame.storage.bottom);
			snapL=true;
		elseif (frame.storage.left+frame:GetWidth()>frame:GetParent():GetRight()-(snap/2)) then
			frame:PositionMonitor(frame:GetParent():GetRight()-frame:GetWidth(),frame.storage.bottom);
			snapL=true;
		end
	end
	if (not snapT) then
		if (frame.storage.bottom<(snap/2)) then
			frame:PositionMonitor(frame.storage.left,0);
			snapT=true;
		elseif (frame.storage.bottom+frame:GetHeight()>frame:GetParent():GetTop()-(snap/2)) then
			frame:PositionMonitor(frame.storage.left,frame:GetParent():GetTop()-frame:GetHeight());
			snapT=true;
		end
	end
	-- parked
	for _,reg in ipairs(dccs.Monitor) do if (reg~=frame.storage) then		-- don't snap to yourself
		if (frame.storage.left==reg.left and frame.storage.bottom==reg.bottom) then
			frame:PositionMonitor();
			snapL=true; snapT=true;
		end
	end end

	frame:Regroup();

	return snapL or snapT;
end

-- equalize all bar sizes and modes within all groups
function DropCount.GUI.Regroup(master)
	-- set all modes
	for _,mon in ipairs(gui) do											-- do all monitors
		if (mon:IsVisible() and mon:TagFrameGroup("group")) then			-- locate this monitor's group, if any
			-- grab settings from the group
			for _,fr in ipairs(gui) do if (fr.group and fr~=m) then		-- grab anyone else from the group
				if (master.group) then fr=master; end					-- we're doing the master's group
				-- override all
				for _,frm in ipairs(gui) do if (frm.group) then			-- walk all tagged monitors
					frm.storage.max=fr.storage.max;						-- copy max bar setting
					frm:SetMode(fr.storage.mode);						-- copy display mode
				end end
				break;
			end end
			mon:UntagFrameGroup("group");								-- remove tag
		end
	end

	-- set all sizes
	for _,mon in ipairs(gui) do											-- do all monitors
		if (mon:IsVisible() and mon:TagFrameGroup("group",true)) then		-- locate this monitor's vertical group members, if any
			local width,bw=0,0;
			-- find biggest
			for _,fr in ipairs(gui) do if (fr.group) then				-- walk all tagged monitors
				bw=fr:GetBarWidth(); if (bw>width) then					-- find widest monitor
					width=bw; master=fr;								-- set alignment master
				end
				fr:SetMode(fr.storage.mode);							-- re-initialise to get fresh layout
			end end
			for _,fr in ipairs(gui) do if (fr.group) then				-- walk all tagged monitors
				fr.FullWidth=width;
			end end
			master.alignColumn=true;									-- flag it for realignment
--_debug(floor(width));
			mon:UntagFrameGroup("group");								-- remove tag
		end
	end
end

function DropCount.GUI.Remove(frame)
	frame:Hide();
	for i,reg in ipairs(dccs.Monitor) do if (reg==frame.storage) then table.remove(dccs.Monitor,i); return; end end
end

function DropCount.GUI._OnClick(frame,LR,down)
	local setmaxpct=function(b,c,e)
		local e=floor(tonumber(e) or 100);
		if (e<5) then e=5; end
		frame.storage.max=e;
		frame.Ticker=0;
		frame:Regroup();
	end
	local addmonitor=function(ofr,count,ox,oy)
		repeat
			local fr=DropCount.GUI:CreateGUI();							-- create a new monitor
			fr.storage.freemove=ofr.storage.freemove;					-- copy lock
			fr:PositionMonitor(ofr.storage.left+ox,ofr.storage.bottom+oy);	-- place it as requested
			fr:Snap();													-- snap in place
			ofr=fr;														-- set new monitor as original source for sequential creation
			count=count-1;												-- one down, maybe more to go
		until(count<1);
	end
	if (LR=="RightButton") then
		local menu=DMMenuCreate(frame);
		if (frame.storage.locked) then
			menu:Button("Unlock",function() for _,fr in ipairs(gui) do fr.storage.locked=nil; end end);	-- also do invisible ones
		else
			local subm;
			subm=menu:Submenu("Bar scale");
				subm:Radiobutton("Max percent:",setmaxpct,frame.storage.max~=0,nil,nil,nil,nil,1):AddEdit(((frame.storage.max==0 and 100) or frame.storage.max),40,"%",5,999);
				subm:Radiobutton("Automatic",function() frame.storage.max=0; frame.Ticker=0; frame:Regroup(); end,frame.storage.max==0,nil,nil,nil,nil,1);
			subm=menu:Submenu("Layout");
				subm:Button("Default",function() frame:SetMode("default"); frame:Regroup(); end);
				subm:Button("Compact",function() frame:SetMode("compact"); frame:Regroup(); end);
			subm=menu:Submenu("Add monitor");
				subm:Button("Below",function(b,c,e) addmonitor(frame,e,0,0-frame:GetHeight()); end):AddEdit(1,25,"",1,10,true);
				subm:Button("Above",function(b,c,e) addmonitor(frame,e,0,frame:GetHeight()); end):AddEdit(1,25,"",1,10,true);
				subm:Button("Right",function(b,c,e) addmonitor(frame,e,frame:GetWidth(),0); end):AddEdit(1,25,"",1,10,true);
				subm:Button("Left",function(b,c,e) addmonitor(frame,e,0-frame:GetWidth(),0); end):AddEdit(1,25,"",1,10,true);
			menu:Button("Lock",function() for _,fr in ipairs(gui) do if (fr:IsVisible()) then fr.storage.locked=true; end end end);
			menu:Button("Lock this only",function() frame.storage.locked=true; end);
			menu:Checkbox("Glue sides",function(b,c) frame.storage.freemove=c; end,not frame.storage.freemove);
			menu:Checkbox("Auto-assign item",function(b,c) frame.storage.autoitem=true; end,frame.storage.autoitem);
			menu:Checkbox("Show items per minute",function(b,c) frame.storage.dropspeed=true; end,frame.storage.dropspeed);
			menu:Checkbox("Set timed goal",function(b,c,e) if (c) then frame.storage.goal=e; else frame.storage.goal=nil; end end,frame.storage.goal):AddEdit(frame.storage.goal or 20,45,"",1,1000);
			menu:Separator();
			menu:Button("Remove",function() frame:Remove(); end);
		end
		menu:Show();
	elseif (LR=="LeftButton") then
		frame.startL=frame:GetLeft();
		frame.startB=frame:GetBottom();
--		for _,fr in ipairs(gui) do if (fr:IsVisible() and fr~=frame) then
		for _,fr in ipairs(gui) do
			fr.osL=frame.startL-fr:GetLeft();
			fr.osB=frame.startB-fr:GetBottom();
--		end end
		end
	end
end

function DropCount.GUI.GetBarWidth(frame)
	return frame._LCDC.Header:GetWidth();
--	return frame._LCDC.Header:GetTextWidth();
end

function DropCount.GUI.SetMode(frame,mode)
	mode=(mode or "default"):lower();
	frame.storage.mode=mode;
	dccs.LastMonitorMode=mode;
--	frame:ClearAllPoints();
	frame._LCDC.Icon:ClearAllPoints();
	frame._LCDC.Header:ClearAllPoints();
	frame._LCDC.Counter:ClearAllPoints();
	frame._LCDC.Bar:ClearAllPoints();
	if (mode=="compact") then		-- mode: compact
		frame:SetBackdrop(nil);
		frame:SetSize(32,32);
		frame._LCDC.Icon:SetPoint("TOPLEFT",frame,"TOPLEFT");
		frame._LCDC.Icon:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT");
		frame._LCDC.Counter:SetJustifyH("RIGHT");
		frame._LCDC.Counter:SetPoint("BOTTOMLEFT",frame._LCDC.Icon,"BOTTOMLEFT");
		frame._LCDC.Counter:SetPoint("RIGHT",frame._LCDC.Icon,"RIGHT");
		frame._LCDC.Bar:SetPoint("TOPLEFT",frame._LCDC.Counter,"TOPLEFT");
		frame._LCDC.Bar:SetPoint("BOTTOM",frame._LCDC.Counter,"BOTTOM");
		frame._LCDC.Bar:SetWidth(0);
		frame._LCDC.Header:Hide();
	else							-- mode: default
		frame:SetBackdrop(nil);
		frame:SetSize(32,32);
		frame._LCDC.Icon:SetPoint("TOPLEFT",frame,"TOPLEFT");
		frame._LCDC.Icon:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT");
		frame._LCDC.Header:SetPoint("LEFT",frame._LCDC.Icon,"RIGHT",3,0);
		frame._LCDC.Header:SetPoint("BOTTOM",frame._LCDC.Icon,"CENTER");
		frame._LCDC.Counter:SetJustifyH("LEFT");
		frame._LCDC.Counter:SetPoint("TOP",frame._LCDC.Icon,"CENTER");
		frame._LCDC.Counter:SetPoint("LEFT",frame._LCDC.Header,"LEFT");
		frame._LCDC.Bar:SetPoint("TOPLEFT",frame._LCDC.Counter,"TOPLEFT");
		frame._LCDC.Bar:SetPoint("BOTTOM",frame._LCDC.Counter,"BOTTOM");
		frame._LCDC.Bar:SetWidth(0);
		frame._LCDC.Header:Show();
	end
	frame:Show();
end

function DropCount.GUI.SetItem(frame,item)
	if (frame.FollowItem==item) then frame.Ticker=1; return; end		-- same item set again, just update
	if (frame.storage.autoitem) then frame.storage.item=nil; else frame.storage.item=item; end
	frame.FollowItem=item;
	frame._LCDC.Icon:SetTexture((item and GetItemIcon(tonumber(item:match("item:(%d+)")))) or "Interface\\Icons\\INV_Misc_QuestionMark");
	if (not item) then
		frame._LCDC.Header:SetText("");
		frame._LCDC.Counter:SetText("");
		return;
	end
	if (not DropCount.Tracker.MaxSessionValue[item]) then DropCount.Tracker.MaxSessionValue[item]=0; end
	if (not GetItemInfo(item)) then								-- unknown item
		frame.ItemNotInCache=true;
		DropCount.Cache:AddItem(item);							-- queue for cache
		return;
	end
	frame.ItemNotInCache=nil;
	local name=GetItemInfo(item);
	frame._LCDC.Header:SetText(name);
	frame:SetPercent((DropCount:TimedQueueRatio(getid(frame.FollowItem),true) or 0)*100);		-- item,noyield
	frame:Regroup();
end

function DropCount.GUI.SetPercent(frame,value)
	value=value or 0;
	if (value<0) then frame._LCDC.Counter:SetText("Quest"); frame._LCDC.Bar:SetWidth(0); return; end
	local fmt=(value<10 and "%.1f") or "%.0f";
	if (frame.storage.mode~="compact") then
		fmt=fmt.."%%";
		if (frame.storage.dropspeed) then
		end
	end
	frame._LCDC.Counter:SetText(fmt:format(value));
	frame.Ticker=CONST.GUIREFRESH;
	local thismax=1;
	if (frame.FollowItem) then
		if (value>(DropCount.Tracker.MaxSessionValue[frame.FollowItem] or -10)) then DropCount.Tracker.MaxSessionValue[frame.FollowItem]=value; end
		thismax=DropCount.Tracker.MaxSessionValue[frame.FollowItem];	-- assume auto-max
	end
	if (frame.storage.max>0) then thismax=frame.storage.max; end		-- set fixed
	if (thismax<1) then thismax=1; end									-- low clip
	if (value>thismax) then value=thismax; end							-- high clip
	if (value<0.01) then value=0.01; end

	frame._LCDC.Bar:SetWidth((frame.FullWidth/thismax)*value);

--	local part=value/frame.MaxSessionValue;
--	frame._LCDC.Bar:SetTexture("Interface\\AddOns\\LootCount_DropCount\\white.tga");
--	frame._LCDC.Bar:SetVertexColor(1-part,part,.4,.25);		-- r,g,b,a
--_debug(1-part,part,.4);
end

function DropCount.GUI._OnUpdate(frame,elapsed)
	if (frame.startL) then	-- moving
		DropCount.GUI.offsetL=frame:GetLeft()-frame.startL;
		DropCount.GUI.offsetB=frame:GetBottom()-frame.startB;
	end
	if (frame.glued) then	-- following one that moves
		frame:ClearAllPoints();
		frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",frame.storage.left+DropCount.GUI.offsetL or (UIParent:GetWidth()/2),frame.storage.bottom+DropCount.GUI.offsetB or (UIParent:GetHeight()*0.75));
	end
	if (frame.alignColumn) then											-- frame is master for column realignment
		if (frame:TagFrameGroup("group",true)) then						-- locate this monitor's vertical group members
--			for _,fr in ipairs(gui) do if (fr.group and fr~=frame) then	-- walk all tagged monitors
--				fr._LCDC.Header:GetStringWidth();
----				fr._LCDC.Header:SetPoint("RIGHT",frame._LCDC.Header,"RIGHT",0,0);	-- anchor it to my own header's right edge
--			end end
			frame:UntagFrameGroup("group");
		end
		frame.alignColumn=nil;
	end
	if (frame.ItemNotInCache) then frame:SetItem(frame.FollowItem); return; end
	frame.Ticker=frame.Ticker-elapsed; if (frame.Ticker>0) then return; end
	frame.Ticker=frame.Ticker+CONST.GUIREFRESH;
	local now=debugprofilestop();
	frame:SetPercent((DropCount:TimedQueueRatio(getid(frame.FollowItem),true) or 0)*100);		-- item,noyield
	now=debugprofilestop()-now;
	if (now>10) then _debug("SetPercent:",string.format("%.2fms",now)); end
end

function DropCount.ShowFAQ()
	local sf=_G["DropCount_DataOptionsFrame_List"];
	DropCount_DataOptionsFrame_Info:SetJustifyH("CENTER");
	DropCount_DataOptionsFrame_Info:SetJustifyV("CENTER");
	DropCount_DataOptionsFrame_Info:SetText(Basic.."How do I ...");
	sf.DMItemHeight=14; sf.DMSpacing=0; sf:DMClear();
	sf.defaultSort=nil;

	-- Add loot monitors
	sf:DMAdd(Basic.."Add loot monitors:",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Display: Add",DM_STATE_LIST,1);
		sf:DMAdd(Green.."or:",DM_STATE_LIST,0);
		sf:DMAdd("1. Right-click a monitor.",DM_STATE_LIST,0);
		sf:DMAdd("2. Select \"Add monitor\".",DM_STATE_LIST,0);
	-- Use gathering coverage
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Use gathering coverage:",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Gathering coverage",DM_STATE_LIST,1);
		sf:DMAdd("Optionally change the coverage timer for when",DM_STATE_LIST,0);
		sf:DMAdd("nodes should reappear on the map.",DM_STATE_LIST,0);
		sf:DMAdd("REMEMBER: Switch on world map view of herbs or",DM_STATE_LIST,0);
		sf:DMAdd("ore.",DM_STATE_LIST,0);
	-- Find vendors for my profession(s)
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Find vendors for my profession(s):",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Profession vendors",DM_STATE_LIST,1);
	-- Find the best zone to gather ore or herb
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Find the best zone to gather ore or herb:",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Search...",DM_STATE_LIST,1);
		sf:DMAdd("1. Search for what you need.",DM_STATE_LIST,0);
		sf:DMAdd("2. Hold mouse over profession result.",DM_STATE_LIST,0);
	-- Find the best place to get more items I already have
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Find the best place to get more items I already have:",DM_STATE_LIST,-1);
		sf:DMAdd("1. Hold mouse over the icon. The tooltip will",DM_STATE_LIST,0);
		sf:DMAdd("contain info for best drop area if available.",DM_STATE_LIST,0);
			sf:DMAdd("-> If this is switched off in \""..hBlue.."Options...|r\", hold",DM_STATE_LIST,1);
			sf:DMAdd("<Alt> while hovering the icon.",DM_STATE_LIST,1);
	-- Find the best place to get items I do not have
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Find the best place to get items I do not have:",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Search...",DM_STATE_LIST,1);
		sf:DMAdd("1. Search for the item you need.",DM_STATE_LIST,0);
		sf:DMAdd("2. Hold mouse over an item search result.",DM_STATE_LIST,0);
	-- Map vendors with a certain item
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Map vendors with a certain item",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Search...",DM_STATE_LIST,1);
		sf:DMAdd("1. Search for what you need.",DM_STATE_LIST,0);
		sf:DMAdd("2. Press right mouse button on the item you want.",DM_STATE_LIST,0);
		sf:DMAdd("3. Select \"Show vendors with this item\".",DM_STATE_LIST,0);
	-- View something on the world map
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."View something on the world map",DM_STATE_LIST,-1);
		sf:DMAdd("Hold the mouse over an item in a bag or a",DM_STATE_LIST,0);
		sf:DMAdd("creature in the world and press your hotkey.",DM_STATE_LIST,0);
		sf:DMAdd(Green.."or:",DM_STATE_LIST,0);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Search...",DM_STATE_LIST,1);
		sf:DMAdd("1. Search for what you need.",DM_STATE_LIST,0);
		sf:DMAdd("2. Press right mouse button on the item you want.",DM_STATE_LIST,0);
		sf:DMAdd("3. Select \"Track on worldmap\".",DM_STATE_LIST,0);
	-- Cut memory usage
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Cut memory usage",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."Minimap menu -> Data...",DM_STATE_LIST,1);
		sf:DMAdd("1. Uncheck data you do not want.",DM_STATE_LIST,0);
	-- Assign hotkeys
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Basic.."Assign hotkeys:",DM_STATE_LIST,-1);
		sf:DMAdd("Select option:",DM_STATE_LIST,0);
			sf:DMAdd(hBlue.."System menu (Esc) -> Key bindings",DM_STATE_LIST,1);
		sf:DMAdd("Scroll down to the DropCount section.",DM_STATE_LIST,0);

	_G["DropCount_DataOptionsFrame_TotalBytes"]:SetText("");
	DropCount_DataOptionsFrame:Show();
end

function DropCount.About()
	local sf=_G["DropCount_DataOptionsFrame_List"];
	DropCount_DataOptionsFrame_Info:SetJustifyH("LEFT");
	DropCount_DataOptionsFrame_Info:SetJustifyV("TOP");
	DropCount_DataOptionsFrame_Info:SetText(Basic.."The Evil Duck had a vision. He wanted to know. So he created DropCount. And he saw that it was good. So he built upon it, further adding data until the knowledge became near unbearable. But the knowledge brought new powers. He could take more. So he added more. And he shared with his fellow man. And they shared with him.\nAnd thus, a community for the good of all WoW was born.");
	sf.DMItemHeight=14; sf.DMSpacing=0; sf:DMClear();
	sf.defaultSort=nil;

	sf:DMAdd(Green.."About: Sharing data",DM_STATE_LIST,-1);
		sf:DMAdd("Plain and simple, DropCount benefits from players'",DM_STATE_LIST,0);
		sf:DMAdd("own data, and any help you can give is",DM_STATE_LIST,0);
		sf:DMAdd("appreciated.",DM_STATE_LIST,0);
		sf:DMAdd("To make the process of sending your data as",DM_STATE_LIST,0);
		sf:DMAdd("simple as possible, two options are available:",DM_STATE_LIST,0);
			sf:DMAdd("1) By email to \""..Basic.."dropcount@ducklib.com|r\"",DM_STATE_LIST,1);
			sf:DMAdd("2) Visit \""..Basic.."ducklib.com|r\", select",DM_STATE_LIST,1);
		sf:DMAdd("\"DropCount\" from the menu, and upload your",DM_STATE_LIST,0);
		sf:DMAdd("database from there.",DM_STATE_LIST,0);
		sf:DMAdd("- Both options will of course require you to locate",DM_STATE_LIST,0);
		sf:DMAdd("your database file. The most general method is to",DM_STATE_LIST,0);
		sf:DMAdd("search your computer for a file named",DM_STATE_LIST,0);
		sf:DMAdd("\"LootCount_DropCount.lua\". Several files will be",DM_STATE_LIST,0);
		sf:DMAdd("found, and the database is the largest one.",DM_STATE_LIST,0);
		sf:DMAdd("- Some players like to contribute on a regular basis.",DM_STATE_LIST,0);
		sf:DMAdd("To submit data once per month is enough. Any",DM_STATE_LIST,0);
		sf:DMAdd("more often serves little purpose.",DM_STATE_LIST,0);
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Green.."About: Memory management",DM_STATE_LIST,-1);
		sf:DMAdd("DropCount maintains its huge amount of data by",DM_STATE_LIST,0);
		sf:DMAdd("compressing unused data. You will see that",DM_STATE_LIST,0);
		sf:DMAdd("DropCount will typically orbit the 20MB area all",DM_STATE_LIST,0);
		sf:DMAdd("depending on what you are doing today.",DM_STATE_LIST,0);
		sf:DMAdd("This number will be quite a bit bigger the first few",DM_STATE_LIST,0);
		sf:DMAdd("minutes after logging in, and a whole lot bigger",DM_STATE_LIST,0);
		sf:DMAdd("when you have installed a new version until data",DM_STATE_LIST,0);
		sf:DMAdd("merging has finished.",DM_STATE_LIST,0);
		sf:DMAdd("Some players sees this as too much and has asked",DM_STATE_LIST,0);
		sf:DMAdd("for a leaner version. You can select what data you",DM_STATE_LIST,0);
		sf:DMAdd("want to use, but there is a give and take in it; If you",DM_STATE_LIST,0);
		sf:DMAdd("want data, it will require storage. It's as simple as",DM_STATE_LIST,0);
		sf:DMAdd("that.",DM_STATE_LIST,0);
	sf:DMAdd(" ",DM_STATE_LIST,-1);
	sf:DMAdd(Green.."About: System load",DM_STATE_LIST,-1);
		sf:DMAdd("DropCount has two main modes of operation:",DM_STATE_LIST,0);
			sf:DMAdd("1) Day-to-day usage",DM_STATE_LIST,1);
			sf:DMAdd("2) Fresh install and upgrades",DM_STATE_LIST,1);
		sf:DMAdd("- In normal day-to-day usage, DropCount will stay",DM_STATE_LIST,0);
		sf:DMAdd("nicely in the background, and you should never",DM_STATE_LIST,0);
		sf:DMAdd("notice it in terms of system load. It blends quite",DM_STATE_LIST,0);
		sf:DMAdd("nicely in with any other addon, and will yield",DM_STATE_LIST,0);
		sf:DMAdd("computing power if the need should arise.",DM_STATE_LIST,0);
		sf:DMAdd("- With fresh installs and upgrades, the new",DM_STATE_LIST,0);
		sf:DMAdd("DropCount comes with a brand new database. This",DM_STATE_LIST,0);
		sf:DMAdd("new data will be merged with the data you already",DM_STATE_LIST,0);
		sf:DMAdd("have, and this is definitely not a straight forward",DM_STATE_LIST,0);
		sf:DMAdd("copy or overlay. Many calculations and",DM_STATE_LIST,0);
		sf:DMAdd("considerations needs to be made, and lots of data",DM_STATE_LIST,0);
		sf:DMAdd("needs constant crosschecking.",DM_STATE_LIST,0);
		sf:DMAdd("Above all, this takes time. Lots of time.",DM_STATE_LIST,0);
		sf:DMAdd("I'll not bore you with the math, so suffice to say",DM_STATE_LIST,0);
		sf:DMAdd("DropCount will drop your fps to about 30 while",DM_STATE_LIST,0);
		sf:DMAdd("performing a database merge. This is considered",DM_STATE_LIST,0);
		sf:DMAdd("playable for normal tasks.",DM_STATE_LIST,0);
		sf:DMAdd("However - if you enter combat, DropCount will",DM_STATE_LIST,0);
		sf:DMAdd("relinquish any and all \"excess\" CPU usage. You'll",DM_STATE_LIST,0);
		sf:DMAdd("get your normal fps back instantly.",DM_STATE_LIST,0);

	_G["DropCount_DataOptionsFrame_TotalBytes"]:SetText("");
	DropCount_DataOptionsFrame:Show();
end

function DropCountXML.ShowDataOptionsFrame()
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

-- "Item"|"Creature","Runecloth","item:14047:0:0:0:0:0:0"
function DropCountXML.AddUnitToGridFilter(section,name,code,icon,extra)
	if (not code) then
		if (section=="Item") then
			code=getid(name);						-- translate if need be
		elseif (section=="Creature") then
--			_debug(name);
			for k,v in rawpairs(dcdb.Count) do		-- traverse all
				if (v:find(name,1,true) and dcdb.Count[k].Name==name) then
					code=k; break;					-- found it
				end
			end
		end
		if (not code) then return; end				-- could not find proper database ID
	end
	extra=extra or "-";
	if (not dccs.Sheet) then dccs.Sheet={}; end
	if (not dccs.Sheet[section]) then dccs.Sheet[section]={}; end
	if (dccs.Sheet[section][code] and dccs.Sheet[section][code][extra]) then
--_debug(Basic,"Removing",name,code,"as",extra);
		dccs.Sheet[section][code]=nil;
	else
--_debug(Basic,"Adding",name,code,"as",extra);
		dccs.Sheet[section][code]={icon=icon,name=name,[extra]=1};
	end
	return (dccs.Sheet[section][code]~=nil) or nil;
end

function DropCountXML.ClearUnitGridFilter(section,code,extra)
	if (not dccs.Sheet or not dccs.Sheet[section] or not dccs.Sheet[section][code]) then return; end
	extra=extra or "-";
	if (dccs.Sheet[section][code][extra]) then
--_debug(Basic,"Removing",code,"as",extra);
		dccs.Sheet[section][code]=nil;
	end
end

-- database meta
dropcountnonfailtable={
	__index = function (t,k)
		if (not rawget(t,k) and k~="__DATA__" and k~="__METADATA__") then
			rawset(t,k,{}); InsertDropcountDB(rawget(t,k),k);
		end
		return rawget(t,k);
	end,
}
dropcountdatabasemetacode={
	__index = function (t,k)
		if (k==nil) then return nil; end
		if (not rawget(t,"__DATA__")) then return nil; end
		if (not rawget(rawget(t,"__DATA__"),k)) then						-- don't have this item key
			if (rawget(rawget(t,"__METADATA__"),"sub1")=="Item") then		-- the question is an item
				if (k:find("item:",1,true)) then return nil; end			-- query is item code, so don't have it
				-- traverse for name (case sensitive)
				for item,iRaw in rawpairs(t) do					-- traverse without unpacking
					if (iRaw:find(k,1,true)) then				-- textual search
						local thisItem=t[item];					-- proper read -> recursive metatable
						if (thisItem.Item==k) then				-- found item by name
							return thisItem;					-- return unpacked data
			end end end end
			return nil;
		end
		return Table:Read(DM_WHO,k,t);
	end,
	__newindex = function (t,k,v)
		if (not rawget(t,"__METADATA__")) then return nil; end
		if (rawget(rawget(t,"__METADATA__"),"nouse")~=nil) then return nil; end						-- section not activated
		if (rawget(rawget(t,"__METADATA__"),"sub1")=="Item" and not k:find("item:",1,true)) then	-- key is item but not item code
			-- traverse for name
			local lowk=k:lower();
			for item,iRaw in rawpairs(t) do						-- traverse without unpacking
				if (iRaw:lower():find(lowk,1,true)) then		-- textual search
					local thisItem=t[item];						-- proper read -> recursive metatable
					if (thisItem.Item and thisItem.Item:lower()==lowk) then	-- found item by name
						k=item; break;							-- set true key and proceed as normal
			end end end
			if (not k:find("item:",1,true)) then return nil; end	-- key is still not item code
		end
		return Table:Write(DM_WHO,k,v,t);
	end,
	__tostring = function (t)
		return "DropCount "..t.__METADATA__.sub1.." database";
	end,
-- metamethod "__len" cannot be redefined.
}
dropcountmapmeta={
	__call = function (t,q)
		t=t[GetLocale()] or {};
		if (type(q)=="number") then return t[q] or ""; end			-- it's a mapID, so normal look-up
		for k,v in pairs(t) do if (v==q) then return k; end end		-- same-named map, so return mapID
		return "";
	end,
}
dropcountnodemeta={
	__index = function (t,k)
		if (k=="_Name") then
			if (not t.Name) then return nil; end
			return t.Name[GetLocale()] or t.Name.enUS or "<Unknown gather node>";
		end
		return nil;
	end,
}

function InsertDropcountDB(db,sub1,sub2)	-- sublevels
--_debug(sub1,sub2);
	if (not db) then return nil; end
	sub1=sub1 or "no-cache";
	setmetatable(db,nil);			-- remove whatever is there
	-- old section for conversion (it assumes old data is compressed already)
	if (not db.__METADATA__) then
		db.__DATA__={};
		for k,v in pairs(db) do
			if (k~="__DATA__" and k~="__METADATA__") then	-- not one of the new ones
				db.__DATA__[k]=v;							-- so set it
				db[k]=nil;									-- remove old (hash will retain for pairs function)
	end end end
	db.__METADATA__=copytable({sub1=sub1, sub2=sub2},db.__METADATA__);
	if (not sub1) then db.__METADATA__.sub1=nil; end
	if (not sub2) then db.__METADATA__.sub2=nil; end
	db.__METADATA__.cache=nil;								-- obsolete
	return setmetatable(db,dropcountdatabasemetacode);
end

function CreateDropcountDB(db)
	if (not db) then return; end
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
	if (not db.VendorItems) then db.VendorItems={}; end InsertDropcountDB(db.VendorItems,"VendorItems");
	-- trainer > faction > trainer
	if (not db.Trainer) then db.Trainer={}; end
	setmetatable(db.Trainer,dropcountnonfailtable);
	for faction in pairs(db.Trainer) do InsertDropcountDB(db.Trainer[faction],"Trainer",faction); end
	-- quest > faction > quest giver
	if (not db.Quest) then db.Quest={}; end
	setmetatable(db.Quest,dropcountnonfailtable);
	for faction in pairs(db.Quest) do InsertDropcountDB(db.Quest[faction],"Quest",faction); end
	-- gather > GatherTYPE > zone
	if (not db.Gather) then db.Gather={}; end
	setmetatable(db.Gather,dropcountnonfailtable);
	for gather in pairs(db.Gather) do InsertDropcountDB(db.Gather[gather],"Gather",gather); end
	-- make nonfail
	if (db~=dcdb) then setmetatable(db,dropcountnonfailtable); end	-- not for local database
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
		DropCount.MT.Search:Do(data,true,true,true,true,true,true,nil,nil,true,true);
		-- build the WN code
		local page=pageTOP..pageSRC;
		for section,sTable in pairs(DropCount.MT.Search._result) do
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
