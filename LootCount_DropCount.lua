--[[****************************************************************
	LootCount DropCount v1.30

	Author: Evil Duck
	****************************************************************

	For the game World of Warcraft
	Stand-alone addon, and plug-in for the add-on LootCount.

	****************************************************************]]

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


-- TODO (? Maybe, ! Important, - Normal (not done), + Done)
-- + Change quest faction to player's own faction
-- + Remember merge with neutral quests for the v7 non-neutral DB
-- + Merge the new dual best area
-- + purge cache after merge
-- + Extra tooltip on search listbox click
-- + Quests stored by qID for separation of the few same-named quests.

-- CATACLYSM
-- http://forums.worldofwarcraft.com/thread.html?topicId=25626580975&sid=1
-- - Optional include of supplied database



LOOTCOUNT_DROPCOUNT_VERSIONTEXT = "DropCount v1.30";
LOOTCOUNT_DROPCOUNT = "DropCount";
SLASH_DROPCOUNT1 = "/dropcount";
SLASH_DROPCOUNT2 = "/lcdc";
local DM_WHO="LCDC";
local DuckLib=DuckMod[2.0204];

--DropCount={
local DropCount={
	Loaded=nil,
	Debug=nil,
	Registered=nil,
	Update=0,
	ThisBuffer=nil,
	VendorProblem=nil,
	Profession=nil,
	ItemTextFrameHandled,
	Convert={},
	Com={},
	LootCount={},
	Tooltip={},
	TooltipExtras={},
	Event={},
	Edit={},
	OnUpdate={},
	Hook={},
	Font={},
	Map={},
	Icons={
		MakeMM={},
		MakeWM={},
	},
	Quest={
		LastScan={},
	},
	DB={
		Vendor={ Fast={} },
		Quest={ Fast={ MD={}, } },
		Count={ Fast={ MD={}, } },
		Item={ Fast={ MD={}, } },
	},
	Target={
		MyKill=nil,
		GUID="0x0",
		Skin=nil,
		UnSkinned=nil,
		LastAlive=nil,
		LastFaction=nil,
		CurrentAliveFriendClose=nil,
		OpenMerchant=nil,
	},
	Tracker={
		Looted={},
		Skinned={},
		SkinnedIn={ A="none", B="none", C="none", },
		LootList={},
		TimedQueue={},
		QueueSize=0,
		ConvertQuests=0,		-- Quests to convert to new format
		UnknownItems=nil,
		RequestedItem=nil,
		Merge={
			Burst=5,
			BurstFlow=0,
			FPS={
				Time=0,
				Frames=0,
			},
			Total=-1,
			Goal=0,
			Book={ Source=0, New=0, Updated=0, },
			Quest={ Source=0, New={}, Updated={}, },
			Vendor={ Source=0, New={}, Updated={}, },
			Mob={ Source=0, New=0, Updated=0, },
			Item={ Updated=0, },
		},
		MobList={
			button=nil,
		},
		ClearMobDrop={
			amount=1000;
			Done={ [1]={}, [2]={}, [3]={}, [4]={}, [5]={}, [6]={}, [7]={}, [8]={}, [9]={}, [10]={}, },
		},
		CleanImport={
			Cleaned=nil,
			LastMob=nil,
			Okay=0,
			Deleted=0,
		},
	},
	Cache={
		Timer=6,
		Retries=0,
		CachedConvertItems=0,	-- Items requested from server when converting DB
	},
	Search={
		Item=nil,
		mobItem=nil,
	},
	Timer={
		VendorDelay=-1,
		StartupDelay=5,
		PrevQuests=-1,
	},
	Menu={
		Minimap=nil,
	},
};
DropCountXML={
	Icon={
		Vendor={},
		VendorMM={},
		Book={},
		BookMM={},
		Quest={};
		QuestMM={};
	},
	Menu={
	},
};

local CONST={
	LOOTEDAGE=1200,
	PERMANENTITEM=-1,
	UNKNOWNCOUNT=-2,
	C_BASIC="|cFF00FFFF",	-- AARRGGBB
	C_GREEN="|cFF00FF00",
	C_RED="|cFFFF0000",
	C_LBLUE="|cFF6060FF",
	C_HBLUE="|cFEA0A0FF",		-- highlight
	C_YELLOW="|cFFFFFF00",
	C_WHITE="|cFFFFFFFF",
	LISTLENGTH=25,
	KILLS_HIDE=10,
	KILLS_SAFE=50,
	RESCANQUESTS=1.5,
	QUEUETIME=900,
	QUESTID=nil,
	CACHESPEED=1/3,
	CACHEMAXRETRIES=10,
	QUESTRATIO=-1,
	PROFESSIONS={},
	ZONES=nil,
	MYFACTION=nil,
	QUEST_UNKNOWN=0,
	QUEST_DONE=1,
	QUEST_STARTED=2,
	QUEST_NOTSTARTED=3,
	SEP1="\1",
	SEP2="\2",
	SEP3="\3",
	SEP4="\4",
	SEP5="\5",
	SEP6="\6",
	SEP7="\7",
	SEP8="\8",
	SEP9="\9",
	BURSTSIZE=0.5,
	FONT={
		NORM=nil,
		SMALL=nil,
	},
};
local COM={
	PREFIX="LcDc",
	SEPARATOR=",",
	MOBKILL="MOB_KILL",
	MOBLOOT="MOB_LOOT",
};
local nagged=nil;


-- Saved per character
LootCount_DropCount_Character={
	Skinning=nil,
	ShowZone=true,
};
-- Global save
LootCount_DropCount_DB={
	Item={},
	Count={},
	Vendor={},
	Book={},
	Quest={},
};
LootCount_DropCount_Maps={}
LootCount_DropCount_NoQuest = {
	[2735] = true,
	[10593] = true,
	[2751] = true,
	[8705] = true,
	[21377] = true,
	[8391] = true,
	[2799] = true,
	[8392] = true,
	[16656] = true,
	[8393] = true,
	[11512] = true,
	[8394] = true,
	[8396] = true,
	[25719] = true,
	[5113] = true,
	[12840] = true,
	[22528] = true,
	[22529] = true,
	[28452] = true,
	[29209] = true,
	[2730] = true,
	[24401] = true,
	[25433] = true,
	[18944] = true,
	[24291] = true,
	[11018] = true,
	[12841] = true,
	[10450] = true,
	[4582] = true,
	[24449] = true,
	[5117] = true,
	[35188] = true,
	[2732] = true,
	[2740] = true,
	[2748] = true,
	[5134] = true,
	[29740] = true,
	[29739] = true,
	[29426] = true,
	[2725] = true,
	[31812] = true,
	[2738] = true,
	[2749] = true,
	[38551] = true,
	[30809] = true,
	[30810] = true,
	[29425] = true,
	[11407] = true,
	[2734] = true,
	[2742] = true,
	[2750] = true,
	[22527] = true,
	[21383] = true,
	[22526] = true,
	[8483] = true,
	[2744] = true,
}


-- reference to the Astrolabe mapping library
local Astrolabe = DongleStub("Astrolabe-1.0");



-- Set up for handling
function DropCountXML:OnLoad(frame)
	frame:RegisterEvent("ADDON_LOADED");
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED");
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");
	frame:RegisterEvent("CHAT_MSG_ADDON");
	frame:RegisterEvent("CHAT_MSG_CHANNEL");
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
	frame:RegisterEvent("QUEST_QUERY_COMPLETE");

	local name;
	name=GetSpellInfo(8613); CONST.PROFESSIONS[1]=name;	-- Skinning
	name=GetSpellInfo(2366); CONST.PROFESSIONS[2]=name;	-- Herb gathering
	name=GetSpellInfo(2575); CONST.PROFESSIONS[3]=name;	-- Mining
	name=GetSpellInfo(49383); CONST.PROFESSIONS[4]=name;	-- Salvaging

	StaticPopupDialogs["LCDC_D_NOTIFICATION"] = {
		text="Text",
		button1="Close",
		OnAccept = function()
			StaticPopup_Hide ("LCDC_D_NOTIFICATION");
		end,
		timeout=0,
		whileDead=1,
		hideOnEscape=1,
	};

	SlashCmdList["DROPCOUNT"]=function(msg) DropCountXML.Slasher(msg) end;

	DropCount.Menu.Minimap=CreateFrame("Frame","DropCount_Menu_Minimap_Frame",Minimap,"UIDropDownMenuTemplate");
	DropCount.Menu.Minimap:SetPoint("LEFT",Minimap);
	UIDropDownMenu_Initialize(DropCount.Menu.Minimap,DropCountXML.Menu.MinimapInitialise,"MENU");

	DropCount.TooltipExtras:SetFunctions(GameTooltip);
	DropCount.TooltipExtras:SetFunctions(LootCount_DropCount_TT);
	DropCount.TooltipExtras:SetFunctions(LootCount_DropCount_CF);

	DuckLib:Init();
end

-- There's slashing to be done
function DropCountXML.Slasher(msg)
	if (not msg) then msg=""; end
	local fullmsg=msg;
	if (strlen(msg)>0) then msg=strlower(msg); end

	if (msg=="guild") then
		LootCount_DropCount_DB.GUILD=true;
		LootCount_DropCount_DB.RAID=nil;
		DuckLib:Chat("DropCount: Sharing data with guild");
		return;
	elseif (msg=="raid" or msg=="group") then
		LootCount_DropCount_DB.GUILD=nil;
		LootCount_DropCount_DB.RAID=true;
		DuckLib:Chat("DropCount: Sharing data with party/raid");
		return;
	elseif (msg=="noshare") then
		LootCount_DropCount_DB.GUILD=nil;
		LootCount_DropCount_DB.RAID=nil;
		DuckLib:Chat("DropCount: Data-sharing OFF");
		return;
	elseif (msg=="zone") then
		DropCount.Menu.ToggleZoneMobs()
		if (LootCount_DropCount_Character.ShowZoneMobs) then
			DuckLib:Chat("DropCount: Showing drop-data from current zone only");
		else
			DuckLib:Chat("DropCount: Showing drop-data from all zones");
		end
		return;
	elseif (string.find(msg,"item",1,true)==1) then
		msg=string.sub(msg,5);
		msg=strtrim(msg);
		DropCount.Search.Item=msg;
		local number=tonumber(DropCount.Search.Item);
		number=tostring(number);
		if (DropCount.Search.Item==number) then
			DropCount.Search.Item="item:"..DropCount.Search.Item..":0:0:0:0:0:0";
		end
		if (GetItemInfo(DropCount.Search.Item)) then			-- Fastest check
			DropCount:VendorsForItem();
		else
			if (not string.find(DropCount.Search.Item,"item:",1,true)) then	-- Not ID, not link, assume name
				DropCount.Search.Item=DropCount:VendorItemByName(DropCount.Search.Item);
				if (not DropCount.Search.Item) then				-- Can't find by name
					DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Information not available for this item. A link or itemID is required.");
					DropCount.Search.Item=nil;
					return;
				end
			end
			DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_LBLUE.."Getting item information...");
			DropCount.Cache:AddItem(DropCount.Search.Item);
		end
		return;
	elseif (msg:find("area",1,true)==1) then
		msg=msg:sub(5);
		msg=strtrim(msg);
		DropCount.Search.mobItem=msg;
		local number=tonumber(DropCount.Search.mobItem);
		number=tostring(number);
		if (DropCount.Search.mobItem==number) then
			DropCount.Search.mobItem="item:"..DropCount.Search.mobItem..":0:0:0:0:0:0";
		end
		if (GetItemInfo(DropCount.Search.mobItem)) then			-- Fastest check
			DropCount:AreaForItem();
		else
			if (not DropCount.Search.mobItem:find("item:",1,true)) then	-- Not ID, not link, assume name
				DropCount.Search.mobItem=DropCount:VendorItemByName(DropCount.Search.mobItem);
				if (not DropCount.Search.mobItem) then				-- Can't find by name
					DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Information not available for this item. A link or itemID is required.");
					DropCount.Search.mobItem=nil;
					return;
				end
			end
			DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_LBLUE.."Getting item information...");
			DropCount.Cache:AddItem(DropCount.Search.mobItem);
		end
		return;
	elseif (string.find(msg,"book",1,true)==1) then
		msg=string.sub(msg,5);
		msg=strtrim(msg);
		if (msg=="zone") then
			DropCount:ListZoneBooks();
		else
			DropCount:ListBook(msg);
		end
		return;
	elseif (msg=="gui") then
		LCDC_VendorSearch:Show();
		return;
	elseif (msg=="stats") then
		DropCount:ShowStats();
		return;
	elseif (msg=="health") then
		DropCount:ShowDBHealth();
		return;
	elseif (msg=="health loc") then
		DropCount:ShowDBHealth(true);
		return;
	elseif (msg=="single") then
		DropCount:ToggleSingleDrop();
		return;
	elseif (msg=="loc") then
		local X,Y=DropCount:GetPLayerPosition();
		DuckLib:Chat("X,Y: "..X..","..Y);
		return;
	elseif (msg=="tooltip") then
		if (LootCount_DropCount_Character.NoTooltip) then
			LootCount_DropCount_Character.NoTooltip=nil;
			DuckLib:Chat("Tooltip info is now: ON");
		else
			LootCount_DropCount_Character.NoTooltip=true;
			DuckLib:Chat("Tooltip info is now: OFF");
		end
		return;
	elseif (string.find(msg,"delete",1,true)==1) then
		local npc=DropCount.Target.LastAlive;
		msg=msg:sub(8);
		msg=msg:trim();
		if (msg~="") then
			npc=msg;
		end
		DropCount:RemoveFromItem("Name",npc)
		DropCount:RemoveFromItem("Skinning",npc)
		LootCount_DropCount_DB.Count[npc]=nil;
		DuckLib:Chat(npc.." has been deleted.");
--		DuckLib:Chat(npc.." selected for deletion",1);
		return;
	end

	if (msg=="debug") then
		if (DropCount.Debug) then
			DropCount.Debug=nil;
			DuckLib:Chat("DropCount: Debug: OFF");
		else
			DropCount.Debug=true;
			DuckLib:Chat("DropCount: Debug: ON");
		end
		return;
	elseif (string.find(msg,"e ",1,true)==1) then
		msg=string.sub(fullmsg,3);
		DuckLib:Chat("DropCount edit-command: "..msg,1,1);
		local params={strsplit("*",msg);}
		for index,iData in ipairs(params) do
			iData=iData.."   ";		-- Make it at least 3 characters
			local par=string.lower(string.sub(iData,1,2));
			params[par]=strtrim(string.sub(iData,3));
			params[index]=nil;
		end
		if (DropCount.Edit:Quest(params)) then return; end
		DuckLib:Chat("Your query could not be fulfilled.",1);
		DuckLib:Chat("Check for spelling and missing information.",1);
		return;
	end

	DuckLib:Chat(CONST.C_BASIC..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."|r");
	if (msg=="?") then
		DropCount:CleanDB();
		if (LootCount_DropCount_DB.GUILD) then DuckLib:Chat(CONST.C_BASIC.."DC:|r Currently sharing data with "..CONST.C_GREEN.."guild|r");
		elseif (LootCount_DropCount_DB.RAID) then DuckLib:Chat(CONST.C_BASIC.."DC:|r Currently sharing data with "..CONST.C_LBLUE.."party/raid|r");
		else DuckLib:Chat(CONST.C_BASIC.."DC:|r Currently "..CONST.C_RED.."not|r sharing data"); end
		return;
	end

	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." ?|r -> Statistics");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." single|r -> Show/hide items that has only dropped once");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." guild|r -> Share data with guild");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." raid|r -> Share data with party/raid");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." noshare|r -> Do not share data");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." item <item-ID\|link\|name>|r -> List vendors with this item");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." book <title>|r -> List location(s) of this book");
	DuckLib:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." book zone -> List all known books in current zone");
end

function DropCount.Edit:Quest(p)
	if (p["?q"]) then
		if (p["+z"]) then
			for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
				for npc,nData in pairs(fData) do
					if (string.find(nData,p["?q"],1,true)) then
						local npcData=DropCount.DB.Quest:Read(faction,npc);
						for index,iData in pairs(npcData.Quests) do
							if (iData.Quest==p["?q"]) then
								iData.Header=p["+z"];
								DropCount.DB.Quest:Write(npc,npcData,faction);
							end
						end
					end
				end
			end
			DuckLib:Chat("Quest :\""..p["?q"].."\" has been set to \""..p["+z"].."\"");
			return true;
		end
		for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
			for npc,nData in pairs(fData) do
				if (string.find(nData,p["?q"],1,true)) then
					local npcData=DropCount.DB.Quest:Read(faction,npc);
					for index,iData in pairs(npcData.Quests) do
						if (iData.Quest==p["?q"]) then
							if (iData.Header) then
								DuckLib:Chat("Quest :"..p["?q"].." is \""..iData.Header.."\"");
							end
						end
					end
				end
			end
		end
		return true;
	end
end

--function DropCount.Event.COMBAT_LOG_EVENT_UNFILTERED(_,how,_,source,_,_,GUID,mob)
function DropCount.Event.COMBAT_LOG_EVENT_UNFILTERED(_,how,_,source,_,_,_,GUID,mob)
	if (how=="PARTY_KILL" and (bit.band(source,COMBATLOG_OBJECT_TYPE_PET) or bit.band(source,COMBATLOG_OBJECT_TYPE_PLAYER))) then
		if (GetNumPartyMembers()<1) then
			DropCount:AddKill(true,GUID,mob,LootCount_DropCount_Character.Skinning);
		end
		if (DropCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
	end
end

function DropCount.Event.PLAYER_FOCUS_CHANGED(...) DropCount.Event.PLAYER_TARGET_CHANGED(...); end
function DropCount.Event.PLAYER_TARGET_CHANGED()
	local targettype=DropCount:GetTargetType();
--	if (not targettype) then
--		DropCount.Target.MyKill=nil;
--		DropCount.Target.Skin=nil;
--		DropCount.Target.UnSkinned=nil;
--		DropCount.Target.CurrentAliveFriendClose=nil;
--		return;
--	end
	DropCount.Profession=nil;
	DropCount.Target.MyKill=nil;
	DropCount.Target.Skin=nil;
	DropCount.Target.UnSkinned=nil;
	DropCount.Target.CurrentAliveFriendClose=nil;
	if (not targettype) then
		return;
	end
	DropCount.Target.MyKill=nil;
	if (not UnitIsDead(targettype)) then
		DropCount.Target.LastFaction=UnitFactionGroup(targettype);
		if (not DropCount.Target.LastFaction) then
			DropCount.Target.LastFaction="Neutral";
		end
		DropCount.Target.LastAlive=UnitName(targettype);
		DropCount.Target.CurrentAliveFriendClose=nil;
		if (CheckInteractDistance(targettype,2)) then	-- Trade-distance
			DropCount.Target.CurrentAliveFriendClose=DropCount.Target.LastAlive;
		end
		return;
	end
	if (UnitIsFriend("player",targettype)) then return; end
	DropCount.Target.CurrentAliveFriendClose=nil;
	DropCount.Target.GUID=UnitGUID(targettype);
	DropCount.Target.Skin=UnitName(targettype);				-- Get current valid target
	DropCount.Target.UnSkinned=DropCount.Target.Skin;	-- Set unit for skinning-drop
	if (UnitIsTapped(targettype)) and (not UnitIsTappedByPlayer(targettype)) then return; end	-- Not my kill (in case of skinning)
	DropCount.Target.MyKill=DropCount.Target.Skin;			-- Save name of dead targetted/focused enemy
end

function DropCount.Event.LOOT_OPENED()
	DropCount.Tracker.LootList=nil; DropCount.Tracker.LootList={};
	local slots=GetNumLootItems();
	if (slots<1) then DuckLib:Chat("Zero-loot",1); end
	for i=1,slots do
		DropCount.Tracker.LootList[i]={};
		_,_,DropCount.Tracker.LootList[i].Count=GetLootSlotInfo(i);	-- Returns icon path, item name, and item quantity for the item in the given loot window slot
		DropCount.Tracker.LootList[i].Item=DuckLib:GetID(GetLootSlotLink(i));	-- Returns an itemLink for the item in the given loot window slot
	end
	local mTable=DropCount.Tracker.Looted;	-- Set normal loot mobs
	if (DropCount.Profession) then
		mTable=DropCount.Tracker.Skinned;		-- Set skinning loot mobs
	else
		-- It's normal, so check if it has already been skinned
		if (DropCount.Tracker.Skinned[DropCount.Target.GUID]) then return; end			-- Loot already done for this one
	end
	if (mTable[DropCount.Target.GUID]) then return; end			-- Loot already done for this one
	if (DropCount.Profession and DropCount.Target.MyKill) then		-- If my kill (or pet or something that makes me loot it)
		DropCount:AddKill(true,DropCount.Target.GUID,DropCount.Target.MyKill);
	elseif (not DropCount.Profession) then
		DropCount:AddKill(true,DropCount.Target.GUID,DropCount.Target.UnSkinned);	-- Add the targetted dead dude that I didn't have the killing blow on
	end

	local now=time();
	-- Save loot
	mTable[DropCount.Target.GUID]=now;							-- Set it
	for i=1,slots do
		if (DropCount.Tracker.LootList[i].Count>0) then			-- Not money
			if (DropCount.Target.MyKill) then
				DropCount:AddLoot(DropCount.Target.GUID,DropCount.Target.MyKill,DropCount.Tracker.LootList[i].Item,DropCount.Tracker.LootList[i].Count);
			elseif (DropCount.Target.Skin) then
				DropCount:AddLoot(DropCount.Target.GUID,DropCount.Target.Skin,DropCount.Tracker.LootList[i].Item,DropCount.Tracker.LootList[i].Count);
			end
		end
	end
	DropCount.Profession=nil;			-- Set normal type loot
	-- Remove old mobs
	for guid,when in pairs(mTable) do
		if (now-when>CONST.LOOTEDAGE) then mTable[guid]=nil; end
	end
end

function DropCount.Event.CHAT_MSG_ADDON(prefix,text,channel,sender)
	if (prefix~=COM.PREFIX) then return; end
	if (LootCount_DropCount_DB.RAID) then
		if (channel~="RAID" and channel~="PARTY") then return; end
	elseif (LootCount_DropCount_DB.GUILD) then
		if (channel~="GUILD") then return; end
	else return; end

	if (sender==UnitName("player")) then return; end
	DropCount.Com:ParseMessage(text,sender);
end

function DropCount.Event.MERCHANT_SHOW()
	DropCount.Target.OpenMerchant=DropCount.Target.LastAlive;
	DropCount.Timer.VendorDelay=.5;
end

function DropCount.Event.MERCHANT_CLOSED()
	DropCount.Timer.VendorDelay=-1;
	DropCount.VendorProblem=nil;
end

function DropCount.Event.WORLD_MAP_UPDATE()
	if (not WorldMapDetailFrame:IsVisible()) then return; end
	DropCount.Icons:Plot();
end

function DropCount.Event.ZONE_CHANGED_NEW_AREA()
	DropCount.Icons.MakeMM:Vendor();
	DropCount.Icons.MakeMM:Book();
	DropCount.Icons.MakeMM:Quest();
end

function DropCount.Event.QUEST_DETAIL()
	local qName=GetTitleText();
	local target=DropCount:GetTargetType();
	if (target) then
		target=CheckInteractDistance(DropCount:GetTargetType(),3);	-- Duel - 9,9 yards
	end
	if (not target) then		-- No target, or too far away
		DropCount.Target.CurrentAliveFriendClose=nil;
	end
	if (qName) then DropCount.Quest:SaveQuest(qName,DropCount.Target.CurrentAliveFriendClose); end
end

function DropCount.Event.QUEST_COMPLETE()
	local qName=GetTitleText();
	local qID=true;
	if (LootCount_DropCount_Character.Quests[qName]) then
		qID=LootCount_DropCount_Character.Quests[qName].ID;
	end
	if (not LootCount_DropCount_Character.DoneQuest) then LootCount_DropCount_Character.DoneQuest={}; end
	if (not LootCount_DropCount_Character.DoneQuest[qName]) then
		DuckLib:Chat("Quest \""..qName.."\" completed",0,1,0);
		LootCount_DropCount_Character.DoneQuest[qName]=qID;
	else
		if (type(LootCount_DropCount_Character.DoneQuest[qName])=="table") then
			if (qID and qID~=true) then
				LootCount_DropCount_Character.DoneQuest[qName][qID]=true;
			end
		elseif (qID and qID~=true) then
			local num=LootCount_DropCount_Character.DoneQuest[qName];
			LootCount_DropCount_Character.DoneQuest[qName]=nil;
			LootCount_DropCount_Character.DoneQuest[qName]={};
			LootCount_DropCount_Character.DoneQuest[qName][qID]=true;
		end
	end
	LCDC_RescanQuests=CONST.RESCANQUESTS;
end

--function DropCount.Event.QUEST_FINISHED()		-- Also when frame is closed (apparently)
function DropCount.Event.QUEST_ACCEPTED()
	LCDC_RescanQuests=CONST.RESCANQUESTS;
end
--function DropCount.Event.UNIT_QUEST_LOG_CHANGED()
--	LCDC_RescanQuests=CONST.RESCANQUESTS;
--end

function DropCount.Event.UNIT_SPELLCAST_START(name,spell)
	if (name~="player") then return; end		-- Someone else in party
	if (spell==CONST.PROFESSIONS[1] or spell==CONST.PROFESSIONS[2] or
		spell==CONST.PROFESSIONS[3] or spell==CONST.PROFESSIONS[4]) then
		if (DropCount.Target.Skin) then			-- Casting on a skinning-target
			DropCount.Profession=spell;			-- Set loot-by-profession type
		end
	else
		DropCount.Profession=nil;			-- Set normal type loot
	end
end

function DropCount.Event.QUEST_QUERY_COMPLETE()
	LootCount_DropCount_DB.QuestQuery={};
	LootCount_DropCount_DB.QuestQuery=GetQuestsCompleted();
	DropCount:GetQuestNames();
end

-- An event has been received
function DropCountXML:OnEvent(dummyself,event,...)
	if (DropCount.Event[event]) then DropCount.Event[event](...); return; end
	local frame,index=...;

	if (event=="ADDON_LOADED" and frame=="LootCount_DropCount") then
		DuckLib.Table:Init(DM_WHO,true,LootCount_DropCount_DB);	-- Set defaults for compressing database
		DropCount.Hook.TT_SetBagItem=GameTooltip.SetBagItem; GameTooltip.SetBagItem=DropCount.Hook.SetBagItem;
		if (LootCount_DropCount_Character.ShowZoneMobs==nil) then LootCount_DropCount_Character.ShowZoneMobs=false; end
		if (LootCount_DropCount_Character.ShowZone==nil) then LootCount_DropCount_Character.ShowZone=true; end
		if (not LootCount_DropCount_DB.CHANNELSET) then
			LootCount_DropCount_DB.CHANNELSET=true;
		end
		if (LootCount_DropCount_DB.IconX and LootCount_DropCount_DB.IconY) then DropCount:MinimapSetIconAbsolute(LootCount_DropCount_DB.IconX,LootCount_DropCount_DB.IconY);
		else
			if (not LootCount_DropCount_DB.IconPosition) then LootCount_DropCount_DB.IconPosition=180; end
			DropCount:MinimapSetIconAngle(LootCount_DropCount_DB.IconPosition);
		end
		CONST.MYFACTION=UnitFactionGroup("player");
		if (not LootCount_DropCount_Character.LastQG) then
			LootCount_DropCount_Character.LastQG={};
		end
		DropCount:ConvertBookFormat();
		DropCount.Icons.MakeMM:Vendor();
		DropCount.Icons.MakeMM:Book();
		DropCount.Icons.MakeMM:Quest();
		Astrolabe:Register_OnEdgeChanged_Callback(DropCountXML.AstrolabeEdge,1);
		LootCount_DropCount_DB.RAID=nil;
		if (IsInGuild()) then LootCount_DropCount_DB.GUILD=true; else LootCount_DropCount_DB.GUILD=nil; end
		DropCount:RemoveFromDatabase();
		LootCount_DropCount_RemoveData=nil;
		QueryQuestsCompleted();
		DropCount.Loaded=0;
		DropCount.Icons:Plot();
		LCDC_ResultListScroll:DMClear();		-- Prep search-list
		LCDC_VendorSearch_UseVendors:SetText("Vendors"); LCDC_VendorSearch_UseVendors:SetChecked(true);
		LCDC_VendorSearch_UseQuests:SetText("Quests"); LCDC_VendorSearch_UseQuests:SetChecked(true);
		LCDC_VendorSearch_UseBooks:SetText("Books"); LCDC_VendorSearch_UseBooks:SetChecked(true);
		LCDC_VendorSearch_UseItems:SetText("Items"); LCDC_VendorSearch_UseItems:SetChecked(true);
		LCDC_VendorSearch_UseMobs:SetText("Creatures"); LCDC_VendorSearch_UseMobs:SetChecked(true);
	end
	if (event=="DMEVENT_LISTBOX_ITEM_ENTER") then
		local entry=frame.DMTheList[index];
		if (entry.Tooltip) then
			GameTooltip:SetOwner(frame,"ANCHOR_CURSOR");
			GameTooltip:SetText(entry.Tooltip[1]);
			local i=2;
			while(entry.Tooltip[i]) do
				GameTooltip:LCAddLine(entry.Tooltip[i],.6,.6,1,0);	-- 1=wrap text
				i=i+1;
			end

			-- Vendor
			local found=nil;
			if (entry.DB.Section=="Vendor") then
				local eData=DropCount.DB.Vendor:Read(nil,entry.DB.Data);
				if (eData) then				-- In case of empty vendors
					for _,iTable in pairs(eData.Items) do
						if (iTable.Name) then
							local test=iTable.Name; test=test:lower();
							if (test:find(LCDC_VendorSearch.SearchTerm)) then
								if (not found) then
									found=true;
									GameTooltip:LCAddLine(" ",1,1,1,0);
									GameTooltip:LCAddLine("Matches:",1,1,1,0);
								end
								GameTooltip:LCAddLine("	"..iTable.Name,1,1,1,0);
							end
						end
					end
				end
			elseif (entry.DB.Section=="Quest") then
				local eData=DropCount.DB.Quest:Read(CONST.MYFACTION,entry.DB.Entry);
				if (eData and eData.Quests) then
					for _,iTable in ipairs(eData.Quests) do
						local useit=nil;
						local test=iTable.Quest; test=test:lower();
						if (test:find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
						if (iTable.Header) then
							test=iTable.Header; test=test:lower();
							if (test:find(LCDC_VendorSearch.SearchTerm)) then useit=true; end
						end
						if (useit) then
							if (not found) then
								found=true;
								GameTooltip:LCAddLine(" ",1,1,1,0);
								GameTooltip:LCAddLine("Matches:",1,1,1,0);
							end
							GameTooltip:LCAddDoubleLine("   "..iTable.Quest,iTable.Header,1,1,1,1,1,1);
						end
					end
				end
			end
			GameTooltip:Show();
		elseif (entry.DB.Section=="Item") then
			DropCount.Tooltip:MobList(entry.DB.Entry,nil,nil,nil,LCDC_VendorSearch.SearchTerm);
		elseif (entry.DB.Section=="Creature") then
			DropCount:SetLootlist(entry.DB.Entry,GameTooltip);
		end
	end
	if (event=="DMEVENT_LISTBOX_ITEM_LEAVE") then
		GameTooltip:Hide();
	end
	if (event=="DMEVENT_LISTBOX_ITEM_CLICKED") then
		local entry=frame.DMTheList[index];
		if (entry.DB.Section=="Vendor") then
			GameTooltip:Hide();
			DropCount.Tooltip:SetNPCContents(entry.DB.Entry,frame,GameTooltip,true);
		elseif (entry.DB.Section=="Quest") then
			GameTooltip:Hide();
			DropCount.Tooltip:QuestList(CONST.MYFACTION,entry.DB.Entry,frame,GameTooltip);
		elseif (entry.DB.Section=="Item") then
			SetItemRef(entry.DB.Entry);
		end
	end
end

function DropCount.Hook.SetBagItem(self,bag,slot)
	local hasCooldown,repairCost=DropCount.Hook.TT_SetBagItem(self,bag,slot);

	local _,item=GameTooltip:GetItem();
	DropCount.Hook:AddLocationData(GameTooltip,item);
	return hasCooldown,repairCost;
end

function DropCount.Hook:AddLocationData(frame,item)
	if (LootCount_DropCount_Character.NoTooltip) then return; end
	local ThisItem=DuckLib:GetID(item);
	if (ThisItem) then
		local iData=DropCount.DB.Item:Read(ThisItem);
		if (iData) then
			local text="|cFFF89090B|cFFF09098e|cFFE890A0s|cFFE090A8t |cFFD890B0k|cFFD090B8n|cFFC890C0o|cFFC090C8w|cFFB890D0n |cFFB090D8a|cFFA890E0r|cFFA090E8e|cFF9890F0a: |cFF9090F8";
			if (iData.BestW) then
				frame:LCAddLine(text..iData.BestW.Location.." at "..iData.BestW.Score.."%",.6,.6,1,1);	-- 1=wrap text
			elseif (iData.Best) then
				frame:LCAddLine(text..iData.Best.Location.." at "..iData.Best.Score.."%",.6,.6,1,1);	-- 1=wrap text
			end
		end
		frame:Show();
	end
end

function DropCount:ToggleSingleDrop()
	if (LootCount_DropCount_Character.ShowSingle) then
		LootCount_DropCount_Character.ShowSingle=nil;
	else
		LootCount_DropCount_Character.ShowSingle=true;
	end
end

function DropCount:ShowDBHealth(here)
	-- Vendors with missing coords
	local count=0;
	for vendor,vData in pairs(LootCount_DropCount_DB.Vendor) do
		local X,Y,Zone,Faction=DropCount.DB.Vendor:ReadBaseData(vendor);
		if (X~=0 and Y~=0) then
			if (not here or DropCount:GetFullZone():find(Zone)) then
				if (count==0) then DuckLib:Chat("Vendors without coordinates:"); end
				count=count+1;
				local text=vendor;
				if (Zone and Zone~=" ") then text=text.." in "..Zone; end
				if (Faction and Faction~=" ") then text=text.." ("..Faction..")"; end
				DuckLib:Chat(text);
			end
		end
	end
	if (count==0) then
		DuckLib:Chat("All vendors accounted for");
	else
		DuckLib:Chat(count.." vendors found");
	end
end

function DropCount:ShowStats(length)
	if (not length or length<2) then length=3; end
	local top={ { kill=0, name="", zone="" } };
	local index=2;
	while(index<=length) do
		top[index]=DuckLib:CopyTable(top[1]);
		index=index+1;
	end
	-- Kills
	for mob,_ in pairs(LootCount_DropCount_DB.Count) do
		local mTable=DropCount.DB.Count:Read(mob);
		if (mTable.Kill) then
			if (mTable.Kill>top[length].kill) then
				top[length].kill=mTable.Kill;
				top[length].name=mob;
				top[length].zone=mTable.Zone;
				index=length;
				while (index>=2) do
					if (top[index].kill>top[index-1].kill) then
						top[index-1],top[index]=top[index],top[index-1];
					end
					index=index-1;
				end
			end
		end
	end

	DuckLib:Chat(CONST.C_BASIC..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.." stats:");
	if (top[1].kill>0) then
		index=1;
		while (top[index] and top[index].kill>0) do
			DuckLib:Chat(CONST.C_BASIC.."Most kills "..index..": "..CONST.C_GREEN..top[index].kill.." "..CONST.C_YELLOW..top[index].name..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
			index=index+1;
		end
	else
		DuckLib:Chat(CONST.C_RED.."No stats available");
		return;
	end
	-- Skinning
	index=1;
	while(index<=length) do top[index].kill=0; index=index+1; end
	for mob,_ in pairs(LootCount_DropCount_DB.Count) do
		local mTable=DropCount.DB.Count:Read(mob);
		if (mTable.Skinning) then
			if (mTable.Skinning>top[length].kill) then
				top[length].kill=mTable.Skinning;
				top[length].name=mob;
				top[length].zone=mTable.Zone;
				index=length;
				while (index>=2) do
					if (top[index].kill>top[index-1].kill) then
						top[index-1],top[index]=top[index],top[index-1];
					end
					index=index-1;
				end
			end
		end
	end
	if (top[1].kill>0) then
		index=1;
		while (top[index] and top[index].kill>0) do
			DuckLib:Chat(CONST.C_BASIC.."Most prof. loot "..index..": "..CONST.C_GREEN..top[index].kill.." "..CONST.C_YELLOW..top[index].name..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
			index=index+1;
		end
	end
	-- Highest normal loot drop-rate
	index=1;
	while(index<=length) do top[index].kill=0; index=index+1; end
	for item,_ in pairs(LootCount_DropCount_DB.Item) do
		local iTable=DropCount.DB.Item:Read(item);
		if (iTable.Name and iTable.Item) then
			for mob,val in pairs(iTable.Name) do
				local mTable=DropCount.DB.Count:Read(mob);
				if (mTable and mTable.Kill and mTable.Kill>=CONST.KILLS_HIDE and
					val>0 and (val/mTable.Kill)<5 and (val/mTable.Kill)>top[length].kill ) then
					top[length].kill=val/mTable.Kill;
					top[length].name=iTable.Item;
					top[length].mob=mob;
					top[length].zone=mTable.Zone;
					index=length;
					while (index>=2) do
						if (top[index].kill>top[index-1].kill) then
							top[index-1],top[index]=top[index],top[index-1];
						end
						index=index-1;
					end
				end
			end
		end
	end
	if (top[1].kill>0) then
		index=1;
		while (top[index] and top[index].kill>0) do
			DuckLib:Chat(CONST.C_BASIC.."Highest drop-rate "..index..": "..CONST.C_GREEN..math.floor(top[index].kill*100).."\% "..CONST.C_WHITE..top[index].name..CONST.C_BASIC.." from "..CONST.C_YELLOW..top[index].mob..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
			index=index+1;
		end
	end
end

function DropCount:GetQuestNames()
	if (not LootCount_DropCount_DB.QuestQuery) then return; end
	if (not LootCount_DropCount_Character.DoneQuest) then
		LootCount_DropCount_Character.DoneQuest={};
	end
	-- Remove all that is already okay
	for dqName,dqState in pairs(LootCount_DropCount_Character.DoneQuest) do
		if (type(dqState)=="table") then
			for queueNum,_ in pairs(dqState) do
				if (LootCount_DropCount_DB.QuestQuery[queueNum]) then
					LootCount_DropCount_DB.QuestQuery[queueNum]=nil;
				end
			end
		else
			if (LootCount_DropCount_DB.QuestQuery[dqState]) then
				LootCount_DropCount_DB.QuestQuery[dqState]=nil;
			end
		end
	end
	DropCount.Tracker.ConvertQuests=0;
	for _,_ in pairs(LootCount_DropCount_DB.QuestQuery) do
		DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests+1;
	end

	DropCount.Timer.PrevQuests=3;
end

function DropCount:GetQuestName(link)
	if (not string.find(link,"quest:",1,true)) then return nil; end

	LootCount_DropCount_CF:SetOwner(WorldFrame, "ANCHOR_NONE");
	LootCount_DropCount_CF:ClearLines();
	LootCount_DropCount_CF:SetHyperlink(link);

	local text=_G["LootCount_DropCount_CFTextLeft1"]:GetText();
	LootCount_DropCount_CF:Hide();
	return text;
end

function DropCountXML.AstrolabeEdge()
	local v,icon;
	for v,icon in pairs(DropCountXML.Icon.VendorMM) do
		if (Astrolabe:IsIconOnEdge(icon)) then icon:SetAlpha(.6);
		else icon:SetAlpha(1); end
	end
	for v,icon in pairs(DropCountXML.Icon.BookMM) do
		if (Astrolabe:IsIconOnEdge(icon)) then icon:SetAlpha(.6);
		else icon:SetAlpha(1); end
	end
	for v,icon in pairs(DropCountXML.Icon.QuestMM) do
		if (Astrolabe:IsIconOnEdge(icon)) then icon:SetAlpha(.6);
		else icon:SetAlpha(1); end
	end
end

function DropCount.Quest:AddLastQG(qGiver)
	if (not LootCount_DropCount_Character.LastQG) then return; end
	local index=1;
	local found=0;
	-- Find same q-giver
	while (index<=10 and found==0) do
		if (LootCount_DropCount_Character.LastQG[index] and LootCount_DropCount_Character.LastQG[index]==qGiver) then
			found=index;
		end
		index=index+1;
	end
	if (found>=1) then
		-- Move this q-giver to top
		while (found>1) do
			LootCount_DropCount_Character.LastQG[found]=LootCount_DropCount_Character.LastQG[found-1];
			found=found-1;
		end
	else
		-- Insert at the top
		index=10;
		while (index>1) do
			LootCount_DropCount_Character.LastQG[index]=LootCount_DropCount_Character.LastQG[index-1];
			index=index-1;
		end
	end
	LootCount_DropCount_Character.LastQG[1]=qGiver;
end

--				<FontString name="QuestNPCModelNameText" inherits="GameFontNormal">
function DropCount.Quest:SaveQuest(qName,qGiver,qLevel)
	local OnlyAddQuest=nil;
	if (not qName) then return; end
	if (not qLevel) then qLevel=0; end
	if (not CONST.MYFACTION) then return; end
	if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
	if (not LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then LootCount_DropCount_DB.Quest[CONST.MYFACTION]={}; end

	if (not qZone) then qZone="Unknown"; end
	local qX,qY,qZone;
	qX,qY=DropCount:GetPLayerPosition();
	qZone=DropCount:GetFullZone();
	if (not qGiver or qGiver=="") then
		qGiver="- item - ("..DropCount:GetFullZone().." "..math.floor(qX)..","..math.floor(qY)..")";
		if (QuestNPCModelNameText:IsVisible()) then
			local fsText=QuestNPCModelNameText:GetText();
			if (LootCount_DropCount_DB.Quest[CONST.MYFACTION][fsText]) then
				-- We have a remote quest with a known quest-giver
				qGiver=fsText;
				OnlyAddQuest=true;
				DuckLib:Chat("DEBUG Q-DUDE: "..qGiver,1);
			end
		end
	end
	local qTable={
		[qGiver]=DropCount.DB.Quest:Read(CONST.MYFACTION,qGiver);
	};

	if (not qTable[qGiver]) then qTable[qGiver]={}; end
	if (not OnlyAddQuest) then
		qTable[qGiver].Zone=qZone;
	end
	if (not qTable[qGiver].X or not qTable[qGiver].Y or (qTable[qGiver].X and qX~=0 and qTable[qGiver].Y and qY~=0)) then
		if (not OnlyAddQuest) then
			qTable[qGiver].X=qX;
			qTable[qGiver].Y=qY;
		end
	end
	qTable[qGiver].Map=DropCount:GetMapTable();
	local i=1;
	if (qTable[qGiver].Quests) then
		while (	qTable[qGiver].Quests[i] and
				( (
					type(qTable[qGiver].Quests[i])~="table" and qTable[qGiver].Quests[i]~=qName
				  ) or (
					type(qTable[qGiver].Quests[i])=="table" and qTable[qGiver].Quests[i].Quest~=qName
				  ) )
				) do i=i+1; end
	else
		qTable[qGiver].Quests={};
	end
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
		DropCount.DB.Quest:Write(qGiver,qTable[qGiver]);
		if (DropCount.Debug) then DuckLib:Chat(CONST.C_BASIC.."New Quest "..CONST.C_GREEN.."\""..qName.."\""..CONST.C_BASIC.." saved for "..CONST.C_GREEN..qGiver); end
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
			LootCount_DropCount_Character.Quests[questTitle]={
				ID=tonumber(questID),
				Header=lastheader,
			};
			local goal=GetNumQuestLeaderBoards();
			if (goal and goal>0) then
				LootCount_DropCount_Character.Quests[questTitle].Items={};
				local peek,found=1,nil;
				while(peek<=goal) do
					local desc,oType,done=GetQuestLogLeaderBoard(peek);
					if (oType=="item") then
						local _,_,itemName,numItems,numNeeded=string.find(desc, "(.*):%s*([%d]+)%s*/%s*([%d]+)");
						if (itemName) then
							found=true;
							LootCount_DropCount_Character.Quests[questTitle].Items[itemName]=tonumber(numNeeded);
						end
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
	DropCount.SpoolQuests=DuckLib:CopyTable(LootCount_DropCount_Character.Quests,DropCount.SpoolQuests);

	-- Book-keeping: Items for each quest
	for quest,qData in pairs(LootCount_DropCount_Character.Quests) do
		if (qData.Items) then
			for item,amount in pairs(qData.Items) do
				local iData,iLink=DropCount.DB.Item:ReadByName(item);
				if (iData) then
					if (not iData.Quest) then iData.Quest={}; end
					iData.Quest[quest]=amount;
					DropCount.DB.Item:Write(iLink,iData);
				end
			end
		end
	end

	-- Shove numbers
	i=1;
	while(LootCount_DropCount_Character.LastQG[i]) do	-- q-givers list
		if (LootCount_DropCount_DB.Quest[CONST.MYFACTION][LootCount_DropCount_Character.LastQG[i]]) then
			local tqg=DropCount.DB.Quest:Read(CONST.MYFACTION,LootCount_DropCount_Character.LastQG[i]);
			local changed=nil;
			if (tqg and tqg.Quests) then				-- Same q-giver from database
				local qi=1;
				while (tqg.Quests[qi] and not changed) do
					if (not tqg.Quests[qi].ID) then
						for qname,qnTable in pairs(LootCount_DropCount_Character.Quests) do
--							if (tqg.Quests[qi].Quest==qname and tqg.Quests[qi].Header==qnTable.Header) then
							if (tqg.Quests[qi].Quest==qname) then
								tqg.Quests[qi].ID=qnTable.ID;	-- Set ID
								changed=true;
							end
							if (changed) then break; end	-- This q okay
						end
					end
					qi=qi+1
				end
			end
			if (changed) then
				DropCount.DB.Quest:Write(LootCount_DropCount_Character.LastQG[i],tqg,CONST.MYFACTION);
			end
		end
		i=i+1
	end
end


function DropCount:WalkQuests()
	if (not DropCount.SpoolQuests) then return; end
	-- Stuff all known headers
	local converted=nil;
	if (not LootCount_DropCount_DB.Quest) then return; end
	for quest,qTable in pairs(DropCount.SpoolQuests) do
		for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
			if (faction=="Neutral" or faction==CONST.MYFACTION) then
				for npc,nData in pairs(fTable) do
					if (DropCount.DB:PreCheck(nData,quest)) then
						local nTable=DropCount.DB.Quest:Read(faction,npc);
						if (nTable.Quests) then
							local changed=nil;
							for index,qData in pairs(nTable.Quests) do
								if (type(qData)~="table") then
									nTable.Quests[index]={ Quest=qData, };
									converted=true;
									changed=true;
								end
								if (nTable.Quests[index].Quest==quest) then
									if (not nTable.Quests[index].Header or
										(qTable.Header and nTable.Quests[index].Header~=qTable.Header)) then
										nTable.Quests[index].Header=qTable.Header;
										changed=true;
									end
								end
							end
							if (changed) then
								DropCount.DB.Quest:Write(npc,nTable,faction);
							end
						end
					end
				end
			end
		end
		DropCount.SpoolQuests[quest]=nil;
		return;
	end
	if (empty) then DropCount.SpoolQuests=nil; end
end

function DropCount.Icons.MakeMM:Quest()
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();
	for npc,nTable in pairs(DropCountXML.Icon.QuestMM) do
		Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.QuestMM[npc]);
	end
	if (not LootCount_DropCount_DB.Quest) then return; end
	if (not LootCount_DropCount_DB.QuestMinimap) then return; end
	local count=1;
	if (LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then
		for npc,nRaw in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
			if (DropCount.DB:PreCheck(nRaw,ZoneName)) then
				local nTable=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
				if (nTable.Quests) then
					if (nTable.Zone and string.find(nTable.Zone,ZoneName,1,true)==1) then
						local r,g,b=1,1,1;
						local level=0;
						for _,qTable in pairs(nTable.Quests) do
							local state=DropCount:GetQuestStatus(qTable.ID,qTable.Quest);
							if (state==CONST.QUEST_NOTSTARTED and level<3) then r,g,b=0,1,0; level=3; end
							if (state==CONST.QUEST_STARTED and level<2) then r,g,b=1,1,1; level=2; end
							if (state==CONST.QUEST_DONE and level<1) then r,g,b=0,0,0; level=1; end
							if (state==CONST.QUEST_UNKNOWN) then r,g,b=1,0,0; level=100; end
						end
						if (level>1) then
							if (not _G["LCDC_MapQuestMM"..count]) then
								DropCountXML.Icon.QuestMM[npc]=CreateFrame("Button","LCDC_MapQuestMM"..count,UIParent,"LCDC_VendorFlagTemplate");
								DropCountXML.Icon.QuestMM[npc].icon=DropCountXML.Icon.QuestMM[npc]:CreateTexture("ARTWORK");
								DropCountXML.Icon.QuestMM[npc].icon:SetTexture("Interface\\QuestFrame\\UI-Quest-BulletPoint");
								DropCountXML.Icon.QuestMM[npc].icon:SetAllPoints();
							else
								DropCountXML.Icon.QuestMM[npc]=_G["LCDC_MapQuestMM"..count];
							end
							DropCountXML.Icon.QuestMM[npc].icon:SetVertexColor(r,g,b);
							DropCountXML.Icon.QuestMM[npc].NPC={
								Name=npc,
								Map=mapID,
								Floor=floorNum,
								Faction=CONST.MYFACTION,
							}
							DropCount:SetQuestMMPosition(npc,nTable.X,nTable.Y);
							count=count+1;
						end
					end
				end
			end
		end
	end
end

function DropCount.Icons.MakeWM:Quest(mapID,floorNum,ZoneName)
	for npc,nTable in pairs(DropCountXML.Icon.Quest) do
		nTable.NPC.Unused=true;
	end
	if (not mapID or not floorNum or not ZoneName) then return; end
	if (not LootCount_DropCount_DB.Quest) then return; end
	if (not LootCount_DropCount_DB.QuestWorldmap) then return; end
	local count=1;
	for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
		if (faction==CONST.MYFACTION or faction=="Neutral") then
			for npc,nRaw in pairs(fTable) do
				if (DropCount.DB:PreCheck(nRaw,ZoneName)) then
					local nTable=DropCount.DB.Quest:Read(faction,npc);
					if (nTable.Quests) then
						if (nTable.Zone and string.find(nTable.Zone,ZoneName,1,true)==1) then
							local r,g,b=1,1,1;
							local level=0;
							for _,qTable in pairs(nTable.Quests) do
								local state=DropCount:GetQuestStatus(qTable.ID,qTable.Quest);
								if (state==CONST.QUEST_NOTSTARTED and level<3) then r,g,b=0,1,0; level=3; end
								if (state==CONST.QUEST_STARTED and level<2) then r,g,b=1,1,1; level=2; end
								if (state==CONST.QUEST_DONE and level<1) then r,g,b=0,0,0; level=1; end
								if (state==CONST.QUEST_UNKNOWN) then r,g,b=1,0,0; level=100; end
							end
							if (not _G["LCDC_MapQuest"..count]) then
								DropCountXML.Icon.Quest[npc]=CreateFrame("Button","LCDC_MapQuest"..count,WorldMapDetailFrame,"LCDC_VendorFlagTemplate");
								DropCountXML.Icon.Quest[npc].icon=DropCountXML.Icon.Quest[npc]:CreateTexture("ARTWORK");
								DropCountXML.Icon.Quest[npc].icon:SetTexture("Interface\\QuestFrame\\UI-Quest-BulletPoint");
								DropCountXML.Icon.Quest[npc].icon:SetAllPoints();
							else
								DropCountXML.Icon.Quest[npc]=_G["LCDC_MapQuest"..count];
							end
							DropCountXML.Icon.Quest[npc].icon:SetVertexColor(r,g,b);
							DropCountXML.Icon.Quest[npc].NPC={
								Name=npc,
								X=nTable.X/100,
								Y=nTable.Y/100,
								Map=mapID,
								Floor=floorNum,
								Faction=faction,
								Unused=nil,
							}
							count=count+1;
						end
					end
				end
			end
		end
	end
end

function DropCount.Icons:Plot()
	if (not WorldMapDetailFrame) then return; end
	local m=GetCurrentMapAreaID();
	local f=GetCurrentMapDungeonLevel();
	local zn=LootCount_DropCount_Maps[GetLocale()]
	if (zn) then zn=zn[m]; end

	DropCount.Icons.MakeWM:Vendor(m,f,zn);
	for entry,eIcon in pairs(DropCountXML.Icon.Vendor) do
		if (not eIcon.Vendor.Unused and (LootCount_DropCount_DB.VendorWorldmap or LootCount_DropCount_DB.RepairWorldmap) and eIcon.Vendor.Map==m and eIcon.Vendor.Floor==f) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,m,f,eIcon.Vendor.X,eIcon.Vendor.Y);
		else
			eIcon:Hide();
		end
	end

	DropCount.Icons.MakeWM:Book(m,f,zn);
	for entry,eIcon in pairs(DropCountXML.Icon.Book) do
		if (not eIcon.Book.Unused and LootCount_DropCount_DB.BookWorldmap and eIcon.Book.Map==m and eIcon.Book.Floor==f) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,m,f,eIcon.Book.X,eIcon.Book.Y);
		else
			eIcon:Hide();
		end
	end

	DropCount.Icons.MakeWM:Quest(m,f,zn);
	for entry,eIcon in pairs(DropCountXML.Icon.Quest) do
		if (not eIcon.NPC.Unused and LootCount_DropCount_DB.QuestWorldmap and eIcon.NPC.Map==m and eIcon.NPC.Floor==f) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,m,f,eIcon.NPC.X,eIcon.NPC.Y);
		else
			eIcon:Hide();
		end
	end
end

function DropCountXML:OnEnterIcon(frame)
	LCDC_VendorFlag_Info=true;
	if (frame.Vendor) then DropCount.Tooltip:SetNPCContents(frame.Vendor.Name); end
	if (frame.Book) then DropCount.Tooltip:Book(frame.Book.Name,parent); end
	if (frame.NPC) then DropCount.Tooltip:QuestList(frame.NPC.Faction,frame.NPC.Name,parent); end
end

function DropCount:SetQuestMMPosition(npc,xPos,yPos)
	if (not DropCountXML.Icon.QuestMM[npc]) then return; end
	local icon=DropCountXML.Icon.QuestMM[npc];
	icon.NPC.X=xPos/100;
	icon.NPC.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(icon,icon.NPC.Map,icon.NPC.Floor,icon.NPC.X,icon.NPC.Y);
end
function DropCount:SetVendorMMPosition(dude,xPos,yPos)
	if (not DropCountXML.Icon.VendorMM[dude]) then return; end
	DropCountXML.Icon.VendorMM[dude].Vendor.X=xPos/100;
	DropCountXML.Icon.VendorMM[dude].Vendor.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(DropCountXML.Icon.VendorMM[dude],DropCountXML.Icon.VendorMM[dude].Vendor.Map,DropCountXML.Icon.VendorMM[dude].Vendor.Floor,DropCountXML.Icon.VendorMM[dude].Vendor.X,DropCountXML.Icon.VendorMM[dude].Vendor.Y);
end
function DropCount:SetBookMMPosition(book,xPos,yPos)
	if (not DropCountXML.Icon.BookMM[book]) then return; end
	DropCountXML.Icon.BookMM[book].Book.X=xPos/100;
	DropCountXML.Icon.BookMM[book].Book.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(DropCountXML.Icon.BookMM[book],DropCountXML.Icon.BookMM[book].Book.Map,DropCountXML.Icon.BookMM[book].Book.Floor,DropCountXML.Icon.BookMM[book].Book.X,DropCountXML.Icon.BookMM[book].Book.Y);
end

function DropCount:ListBook(bookin)
	if (not LootCount_DropCount_DB.Book) then return; end
	local book=string.lower(bookin);
	for title,bTable in pairs(LootCount_DropCount_DB.Book) do
		if (book==string.lower(title)) then
			DuckLib:Chat(title);
			for loc,lTable in pairs(bTable) do
				DuckLib:Chat(CONST.C_HBLUE..lTable.Zone..CONST.C_YELLOW.." ("..string.format("%.0f,%.0f",lTable.X,lTable.Y)..")");
			end
			return;
		end
	end

	DuckLib:Chat(CONST.C_YELLOW.."Unknown book: "..bookin.."|r");
end

function DropCount:ListZoneBooks()
	if (not LootCount_DropCount_DB.Book) then return; end
	local found=nil;
	local here=GetRealZoneText();
	local clip=string.len(here)+3+1;
	DuckLib:Chat(here);
	for title,bTable in pairs(LootCount_DropCount_DB.Book) do
		for index,iTable in pairs(bTable) do
			if (iTable.Zone) then
				if (string.find(iTable.Zone,here,1,true)==1) then
					local subzone=string.sub(iTable.Zone,clip);
					if (not subzone) then subzone=""; end
					DuckLib:Chat(CONST.C_HBLUE..title.." |r- "..CONST.C_YELLOW..subzone.." ("..string.format("%.0f,%.0f",iTable.X,iTable.Y)..")");
					found=true;
				end
			end
		end
	end
	if (not found) then DuckLib:Chat(CONST.C_YELLOW.."No known books in "..here.."|r"); end
end

function DropCount.Icons.MakeMM:Book()
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();
	for book,bTable in pairs(DropCountXML.Icon.BookMM) do
		Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.BookMM[book]);
	end
	if (not LootCount_DropCount_DB.Book) then return; end
	if (not LootCount_DropCount_DB.BookMinimap) then return; end
	local index;
	local count=1;
	for book,vTable in pairs(LootCount_DropCount_DB.Book) do
		for index,bTable in pairs(vTable) do
			if (bTable.Zone and string.find(bTable.Zone,ZoneName,1,true)==1) then
				if (not _G["LCDC_MapBookMM"..count]) then
					DropCountXML.Icon.BookMM[book..index]=CreateFrame("Button","LCDC_MapBookMM"..count,UIParent,"LCDC_VendorFlagTemplate");
					DropCountXML.Icon.BookMM[book..index].icon=DropCountXML.Icon.BookMM[book..index]:CreateTexture("ARTWORK");
					DropCountXML.Icon.BookMM[book..index].icon:SetTexture("Interface\\Spellbook\\Spellbook-Icon");
					DropCountXML.Icon.BookMM[book..index].icon:SetAllPoints();
				else
					DropCountXML.Icon.BookMM[book..index]=_G["LCDC_MapBookMM"..count];
				end
				DropCountXML.Icon.BookMM[book..index].Book={
					Name=book,
					Map=mapID,
					Floor=floorNum,
				}
				DropCount:SetBookMMPosition(book..index,bTable.X,bTable.Y);
				count=count+1;
			end
		end
	end
end

function DropCount.Icons.MakeWM:Book(mapID,floorNum,ZoneName)
	for book,bTable in pairs(DropCountXML.Icon.Book) do
		bTable.Book.Unused=true;
	end
	if (not mapID or not floorNum or not ZoneName) then return; end
	if (not LootCount_DropCount_DB.Book) then return; end
	local index;
	local count=1;
	for book,vTable in pairs(LootCount_DropCount_DB.Book) do
		for index,bTable in pairs(vTable) do
			if (bTable.Zone and string.find(bTable.Zone,ZoneName,1,true)==1) then
				if (not _G["LCDC_MapBook"..count]) then
					DropCountXML.Icon.Book[book..index]=CreateFrame("Button","LCDC_MapBook"..count,WorldMapDetailFrame,"LCDC_VendorFlagTemplate");
					DropCountXML.Icon.Book[book..index].icon=DropCountXML.Icon.Book[book..index]:CreateTexture("ARTWORK");
					DropCountXML.Icon.Book[book..index].icon:SetTexture("Interface\\Spellbook\\Spellbook-Icon");
					DropCountXML.Icon.Book[book..index].icon:SetAllPoints();
				else
					DropCountXML.Icon.Book[book..index]=_G["LCDC_MapBook"..count];
				end
				DropCountXML.Icon.Book[book..index].Book={
					Name=book,
					X=bTable.X/100,
					Y=bTable.Y/100,
					Map=mapID,
					Floor=floorNum,
				}
				count=count+1;
			end
		end
	end
end

function DropCount.Icons.MakeMM:Vendor()
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();
	for vendor,vTable in pairs(DropCountXML.Icon.VendorMM) do
		Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.VendorMM[vendor]);
	end
	if (not LootCount_DropCount_DB.Vendor) then return; end
	if (not LootCount_DropCount_DB.VendorMinimap and not LootCount_DropCount_DB.RepairMinimap) then return; end
	local count=1;
	for vendor,_ in pairs(LootCount_DropCount_DB.Vendor) do
		local x,y,zone,faction,repair=DropCount.DB.Vendor:ReadBaseData(vendor);
		if (faction=="Neutral" or faction==CONST.MYFACTION) then
			if (LootCount_DropCount_DB.VendorMinimap or
			  (LootCount_DropCount_DB.RepairMinimap and repair)) then
				if (zone and string.find(zone,ZoneName,1,true)==1) then
					if (not _G["LCDC_MapVendorMM"..count]) then
						DropCountXML.Icon.VendorMM[vendor]=CreateFrame("Button","LCDC_MapVendorMM"..count,UIParent,"LCDC_VendorFlagTemplate");
						DropCountXML.Icon.VendorMM[vendor].icon=DropCountXML.Icon.VendorMM[vendor]:CreateTexture("ARTWORK");
						DropCountXML.Icon.VendorMM[vendor].icon:SetAllPoints();
					else
						DropCountXML.Icon.VendorMM[vendor]=_G["LCDC_MapVendorMM"..count];
					end
					local texture="Interface\\GROUPFRAME\\UI-Group-MasterLooter";
					if (repair) then texture="Interface\\GossipFrame\\VendorGossipIcon"; end
					DropCountXML.Icon.VendorMM[vendor].icon:SetTexture(texture);
					DropCountXML.Icon.VendorMM[vendor].Vendor={
						Name=vendor,
						Map=mapID,
						Floor=floorNum,
						Faction=faction,
					}
					DropCount:SetVendorMMPosition(vendor,x,y);
					count=count+1;
				end
			end
		end
	end
end

function DropCount.Icons.MakeWM:Vendor(mapID,floorNum,ZoneName)
	for vendor,vTable in pairs(DropCountXML.Icon.Vendor) do
		vTable.Vendor.Unused=true;
	end
	if (not mapID or not floorNum or not ZoneName) then return; end
	if (not LootCount_DropCount_DB.Vendor) then return; end
	if (not LootCount_DropCount_DB.VendorWorldmap and not LootCount_DropCount_DB.RepairWorldmap) then return; end
	local count=1;
	for vendor,_ in pairs(LootCount_DropCount_DB.Vendor) do
		local x,y,zone,faction,repair=DropCount.DB.Vendor:ReadBaseData(vendor);
		if (faction=="Neutral" or faction==CONST.MYFACTION) then
			if (LootCount_DropCount_DB.VendorWorldmap or
			  (LootCount_DropCount_DB.RepairWorldmap and repair)) then
				if (zone and string.find(zone,ZoneName,1,true)==1) then
					if (not _G["LCDC_MapVendor"..count]) then
						DropCountXML.Icon.Vendor[vendor]=CreateFrame("Button","LCDC_MapVendor"..count,WorldMapDetailFrame,"LCDC_VendorFlagTemplate");
						DropCountXML.Icon.Vendor[vendor].icon=DropCountXML.Icon.Vendor[vendor]:CreateTexture("ARTWORK");
						DropCountXML.Icon.Vendor[vendor].icon:SetAllPoints();
					else
						DropCountXML.Icon.Vendor[vendor]=_G["LCDC_MapVendor"..count];
					end
					local texture="Interface\\GROUPFRAME\\UI-Group-MasterLooter";
					if (repair) then texture="Interface\\GossipFrame\\VendorGossipIcon"; end
					DropCountXML.Icon.Vendor[vendor].icon:SetTexture(texture);
					DropCountXML.Icon.Vendor[vendor].Vendor={
						Name=vendor,
						X=x/100,
						Y=y/100,
						Map=mapID,
						Floor=floorNum,
						Faction=faction,
						Unused=nil,
					}
					count=count+1;
				end
			end
		end
	end
end

function DropCount:VendorItemByName(name)
	if (not LootCount_DropCount_DB.Vendor) then return nil; end
	name=string.lower(name);
	local vData;

	for vendor,_ in pairs(LootCount_DropCount_DB.Vendor) do
		vData=DropCount.DB.Vendor:Read(vendor);
		if (vData.Items) then
			for item,iTable in pairs(vData.Items) do
				if (iTable.Name and name==string.lower(iTable.Name)) then
					return item;
				end
			end
		end
	end
	return nil;
end

function DropCount.DB.Quest:Read(faction,npc,base)
	if (not base) then base=LootCount_DropCount_DB.Quest end
	if (not base[faction]) then base[faction]={}; end
	if (base) then base=base[faction]; end
	return DuckLib.Table:Read(DM_WHO,npc,base);
end

function DropCount.DB.Quest:Write(npc,nData,faction)
	if (not faction) then faction=CONST.MYFACTION; end
	if (not LootCount_DropCount_DB.Quest[faction]) then LootCount_DropCount_DB.Quest[faction]={}; end
	DuckLib.Table:Write(DM_WHO,npc,nData,LootCount_DropCount_DB.Quest[faction]);
end

function DropCount.DB.Vendor:ReadBaseData(npc,base)
	if (not base) then base=LootCount_DropCount_DB.Vendor; end
	local vendor=DropCount.DB.Vendor:Read(npc,base);
	if (not vendor) then return nil; end
	return vendor.X,vendor.Y,vendor.Zone,vendor.Faction,vendor.Repair;
end

function DropCount.DB.Vendor:Read(npc,base)
	if (not base) then base=LootCount_DropCount_DB.Vendor; end
	return DuckLib.Table:Read(DM_WHO,npc,base);
end

function DropCount.DB.Vendor:Write(npc,nData)
	DuckLib.Table:Write(DM_WHO,npc,nData,LootCount_DropCount_DB.Vendor);
end

function DropCount.DB.Count:Write(mob,nData,base)
	if (not base) then base=LootCount_DropCount_DB.Count; end
	DuckLib.Table:Write(DM_WHO,mob,nData,base);
end

function DropCount.DB.Count:Read(mob,base)
	if (not base) then base=LootCount_DropCount_DB.Count; end
	return DuckLib.Table:Read(DM_WHO,mob,base);
end

function DropCount.DB.Item:Write(item,iData,base)
	if (not base) then base=LootCount_DropCount_DB.Item; end
	DuckLib.Table:Write(DM_WHO,item,iData,base);
end

function DropCount.DB.Item:ReadByName(name)
	if (not LootCount_DropCount_DB.Item) then return nil; end
	for item,iRaw in pairs(LootCount_DropCount_DB.Item) do
		if (iRaw:find(name,1,true)) then
			local thisItem=self:Read(item);
			if (thisItem.Item==name) then
				return thisItem,item;
			end
		end
	end
	return nil;
end

function DropCount.DB.Item:Read(item,base)
	if (not base) then base=LootCount_DropCount_DB.Item; end
	if (not base[item]) then return nil; end
	return DuckLib.Table:Read(DM_WHO,item,base);
end

function DropCount:VendorsForItem()
	if (not DropCount.Search.Item) then return; end

	local itemName,itemLink=GetItemInfo(DropCount.Search.Item);
	if (itemLink) then
		local itemID=DuckLib:GetID(itemLink);
		local list=DropCount.Tooltip:VendorList(itemID,true);

		-- Type list
		local line=1;
		while(list[line]) do
			if (line==1) then DuckLib:Chat(itemLink); end
			DuckLib:Chat(list[line].Ltext.." "..list[line].Rtext);
			line=line+1;
		end

		if (line==1) then
			DuckLib:Chat(CONST.C_YELLOW.."No known vendors for "..itemName.."|r");
		end
	end
end

function DropCount:AreaForItem()
	if (not DropCount.Search.mobItem) then return; end
	if (not LootCount_DropCount_DB.Item) then return; end

	local itemName,itemLink=GetItemInfo(DropCount.Search.mobItem);
	if (not itemLink) then return; end
	local item=DuckLib:GetID(itemLink);
	if (not LootCount_DropCount_DB.Item[item]) then
		DuckLib:Chat(CONST.C_YELLOW.."Unknown drop: "..itemName.."|r");
		return;
	end
	item=DropCount.DB.Item:Read(item);
	if (not item.Best) then
		DuckLib:Chat(CONST.C_YELLOW.."No known drop-area for "..itemName.."|r");
		return;
	end
	DuckLib:Chat(itemLink);
	DuckLib:Chat("Drops in "..item.Best.Location.." at "..item.Best.Score.."%");
	if (item.BestW) then
		DuckLib:Chat("and in "..item.BestW.Location.." at "..item.BestW.Score.."%");
	end
end

function DropCount:GetMapTable()
	local map={}
	map.ID,map.Floor,_,_=Astrolabe:GetCurrentPlayerPosition();
	return map
end

-- Updating...
function DropCount:ReadMerchant(dude)
	local rebuildIcons=nil;
	local numItems=GetMerchantNumItems();
	if (not numItems or numItems<1) then return true; end
	if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end

	local vData;
	if (not LootCount_DropCount_DB.Vendor[dude]) then
		vData={ Items={} };
		rebuildIcons=true;
		DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN.."New vendor added to database|r");
	else
		vData=DropCount.DB.Vendor:Read(dude);
	end

	local posX,posY=DropCount:GetPLayerPosition();
	vData.Repair=_G.MerchantRepairAllButton:IsVisible();
	vData.Zone=DropCount:GetFullZone();
	vData.X=posX;
	vData.Y=posY;
	vData.Faction=DropCount.Target.LastFaction;
	vData.Map=DropCount:GetMapTable();

	DropCount:SetVendorMMPosition(dude,posX,posY);

	-- Remove all permanent items
	if (vData.Items) then
		for item,avail in pairs(vData.Items) do
			if (not avail or not avail.Count or avail.Count==0 or avail.Count==CONST.PERMANENTITEM) then
				vData.Items[item]=nil;
			end
		end
	end

	-- Add all items
	local ReadOk=true;
	local index=1;
	while (index<=numItems) do
		local link=GetMerchantItemLink(index);
		link=DuckLib:GetID(link);
		if (link) then
			local itemName,itemLink=GetItemInfo(link);
			local _,_,_,_,count=GetMerchantItemInfo(index);			-- count==-1 unlimited
			if (not vData.Items) then vData.Items={}; end
			vData.Items[link]={};		-- Create
			vData.Items[link].Name=itemName;
			vData.Items[link].Count=count;
		else
			ReadOk=nil;
		end
		index=index+1;
	end
	if (not ReadOk) then
		if (not DropCount.VendorProblem) then
--			DuckLib:Chat("Unchached item(s) at this vendor. Look through the vendor-pages to load missing items from the server.",1);
			DropCount.VendorProblem=true;
		end
	else
		DropCount.DB.Vendor:Write(dude,vData);
		if (DropCount.VendorProblem) then
--			DuckLib:Chat("Vendor saved",0,1,0);
			rebuildIcons=true;
		end
		if (rebuildIcons) then
			DropCount.Icons.MakeMM:Vendor();
		end
--DuckLib:Chat("Debug save: Vendor saved");
--LootCount_DropCount_DB.LastVendor=DuckLib:CopyTable(vData);
	end
	return ReadOk;
end

function DropCount.Com:Transmit(GUID,mob,item,count,source)
	local channel;
	if (LootCount_DropCount_DB.GUILD) then channel="GUILD";
	elseif (LootCount_DropCount_DB.RAID) then channel="RAID";
	else return; end

	local text;
	if (item and count) then
		text=COM.MOBLOOT..COM.SEPARATOR..GUID..COM.SEPARATOR..mob..COM.SEPARATOR..item..COM.SEPARATOR..count;
		if (source) then	-- Anything but normal loot
			text=text..COM.SEPARATOR.."SKIN";
		else				-- Normal loot
			text=text..COM.SEPARATOR.."LOOT";
		end
	else
		text=COM.MOBKILL..COM.SEPARATOR..GUID..COM.SEPARATOR..mob;
	end

	SendAddonMessage(COM.PREFIX,text,channel);
end

-- COM.MOBKILL - GUID - MOBNAME - ZONE
-- COM.MOBLOOT - GUID - MOBNAME - ITEM - COUNT
function DropCount.Com:ParseMessage(text,sender)
	local header,guid,mob,item,count,source=strsplit(COM.SEPARATOR,text);
	if (header==COM.MOBKILL) then
		DropCount:AddKill(nil,guid,mob,nil,nil,true,item);
		if (DropCount.Debug) then
			DuckLib:Chat(sender.." kill: \'"..mob.."\'",0,1,0);
		end
	elseif (header==COM.MOBLOOT) then
		if (not count or not item) then return; end
		if (source=="SKIN") then
			DropCount.Profession=source;
			if (not DropCount.Com:HaveReceivedSkin(guid)) then
				DropCount.Target.UnSkinned=mob;
			end
		end
		DropCount:AddLoot(guid,mob,item,count,true);
		local itemname=GetItemInfo(item);
		if (not itemname) then _,itemname=DuckLib:GetID(item); end
		if (DropCount.Debug) then
			DuckLib:Chat(sender.." drop: \'"..mob.."\' -> \'"..itemname.."\'x"..count,0,1,0);
		end
	end
end

function DropCount.Com:HaveReceivedSkin(GUID)
	if (DropCount.Tracker.SkinnedIn.A~=GUID and
		DropCount.Tracker.SkinnedIn.B~=GUID and
		DropCount.Tracker.SkinnedIn.C~=GUID) then
		DropCount.Tracker.SkinnedIn.C=DropCount.Tracker.SkinnedIn.B;
		DropCount.Tracker.SkinnedIn.B=DropCount.Tracker.SkinnedIn.A;
		DropCount.Tracker.SkinnedIn.A=GUID;
		return nil;
	end
	return true;
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
	local here=GetRealZoneText();			-- Set zone for last kill
	if (not here or here=="") then return nil; end
	local ss=GetSubZoneText();										-- Set subzone/area for last kill
	if (ss=="") then ss=nil; end
	if (ss) then here=here.." - "..ss; end
	return here;
end

function DropCount:GetPLayerPosition()
	local posX,posY=GetPlayerMapPosition("player");
	posX=(floor(posX*100000))/1000;
	posY=(floor(posY*100000))/1000;
	if (posX==0 or posY==0) then
		DuckLib:Chat("Invalid player position",1);
	end
	return posX,posY;
end

function DropCount:AddKill(oma,GUID,mob,reservedvariable,noadd,notransmit,otherzone)
	if (not mob) then return; end
	-- Check if already counted
	local i=DropCount.Tracker.QueueSize;
	while (i>0) do
		if (DropCount.Tracker.TimedQueue[i].GUID==GUID) then return; end
		i=i-1;
	end

	local now=time();
	local mTable=DropCount.DB.Count:Read(mob);
	if (not mTable) then mTable={ Kill=0 }; end
	if (not otherzone) then otherzone=DropCount:GetFullZone(); end
	mTable.Zone=otherzone;		-- Set zone for last kill
	if (not noadd) then
		if (not mTable.Kill) then mTable.Kill=0; end
		mTable.Kill=mTable.Kill+1;
		if (not nagged) then
			if ((mTable.Kill<=50 and mod(mTable.Kill,10)==0) or mTable.Kill==(math.floor(mTable.Kill/100)*100)) then
				DuckLib:Chat(CONST.C_BASIC.."DropCount: "..CONST.C_YELLOW..mob..CONST.C_BASIC.." has been killed "..CONST.C_YELLOW..mTable.Kill..CONST.C_BASIC.." times!");
				DuckLib:Chat(CONST.C_BASIC.."Please consider sending your SavedVariables file to "..CONST.C_YELLOW.."dropcount@ybeweb.com"..CONST.C_BASIC.." to help develop the DropCount addon.");
				nagged=true;
			end
		end
		if (not notransmit) then DropCount.Com:Transmit(GUID,mob); end
		DropCount.DB.Count:Write(mob,mTable);
	else
		DropCount.DB.Count:Write(mob,mTable);
		return;
	end

	DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize+1;
	DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize]={};
	i=DropCount.Tracker.QueueSize;
	while (i>1) do
		DropCount.Tracker.TimedQueue[i].Mob=DropCount.Tracker.TimedQueue[i-1].Mob;
		DropCount.Tracker.TimedQueue[i].GUID=DropCount.Tracker.TimedQueue[i-1].GUID;
		DropCount.Tracker.TimedQueue[i].Oma=DropCount.Tracker.TimedQueue[i-1].Oma;
		DropCount.Tracker.TimedQueue[i].Time=DropCount.Tracker.TimedQueue[i-1].Time;
		i=i-1;
	end
	DropCount.Tracker.TimedQueue[1].Mob=mob;
	DropCount.Tracker.TimedQueue[1].GUID=GUID;
	DropCount.Tracker.TimedQueue[1].Oma=oma;
	DropCount.Tracker.TimedQueue[1].Time=now;

--DuckLib:Chat("Queue: "..DropCount.Tracker.QueueSize,1);
	if (DropCount.Tracker.QueueSize>9) then
		local list=DropCount:BuildItemList(DropCount.Tracker.TimedQueue[10].Mob);
		local mDB=DropCount.DB.Count:Read(DropCount.Tracker.TimedQueue[10].Mob);
		if (mDB and mDB.Zone) then
			for item,percent in pairs(list) do
				local iDB=DropCount.DB.Item:Read(item);
				local store=nil;
				if (not iDB.Best) then
					iDB.Best={ Location=mDB.Zone, Score=percent };
					store=true;
				else
					if (percent>iDB.Best.Score or mDB.Zone==iDB.Best.Location) then
						iDB.Best={ Location=mDB.Zone, Score=percent };
						store=true;
					end
				end
				if (not IsInInstance()) then
					if (not iDB.BestW) then
						iDB.BestW={ Location=mDB.Zone, Score=percent };
						store=true;
					else
						if (percent>iDB.BestW.Score or mDB.Zone==iDB.BestW.Location) then
							iDB.BestW={ Location=mDB.Zone, Score=percent };
							store=true;
						end
					end
				end
				if (store) then
					if (iDB.Best and iDB.BestW) then
						if (iDB.Best.Location==iDB.BestW.Location and iDB.Best.Score==iDB.BestW.Score) then
							iDB.BestW=nil;
						end
					end
					DropCount.DB.Item:Write(item,iDB);
--DuckLib:Chat(iDB.Item,1);
				end
			end
		end
	end
end

function DropCount:AddLootMob(GUID,mob,item)
	local nameTable;
	local iTable=DropCount.DB.Item:Read(item);
	if (DropCount.Profession) then
		if (not iTable.Skinning) then iTable.Skinning={}; end
		nameTable=iTable.Skinning;
	else
		if (not iTable.Name) then iTable.Name={}; end
		nameTable=iTable.Name;
	end
	-- New stuff, so make database ready
	if (not nameTable[mob]) then		-- Mob not in drop-list
		nameTable[mob]=0;				-- Not looted, but make entry (will be added later)
	end
	DropCount.DB.Item:Write(item,iTable);
	if (not LootCount_DropCount_DB.Count[mob]) then					-- Mob not in kill-list
		DropCount:AddKill(nil,GUID,mob,nil,true,true,"");	-- Add it with zero kills
	end
end

function DropCount:AddLoot(GUID,mob,item,count,notransmit)
	if (not notransmit) then DropCount.Com:Transmit(GUID,mob,item,count,DropCount.Profession); end
	local now=time();
	local iTable=DropCount.DB.Item:Read(item);
	if (not iTable) then iTable={}; end
	local itemName,itemLink=GetItemInfo(item);
	iTable.Item=itemName;
	iTable.Time=now;				-- Last point in time for loot of this item
	DropCount.DB.Item:Write(item,iTable);
	DropCount:AddLootMob(GUID,mob,item);			-- Make register
	iTable=DropCount.DB.Item:Read(item,nil,true);
	local skinning=nil;
	local nameTable;
	if (DropCount.Profession) then
		nameTable=iTable.Skinning;
		skinning=true;
	else
		nameTable=iTable.Name;
	end
	nameTable[mob]=nameTable[mob]+count;
	DropCount.DB.Item:Write(item,iTable);

	if (skinning) then		-- Skinner-loot, so add it as a skinning-kill
		if (DropCount.Target.UnSkinned and DropCount.Target.UnSkinned==mob) then
			local mTable=DropCount.DB.Count:Read(mob);
			if (not mTable.Skinning) then mTable.Skinning=0; end
			mTable.Skinning=mTable.Skinning+1;
			DropCount.Target.UnSkinned=nil;					-- Added, so next loot on this target is more than one items from same skinning
			DropCount.DB.Count:Write(mob,mTable);
		end
	end
	if (DropCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
end

function DropCount:GetRatio(item,mob)
	if (CONST.QUESTID) then
		local _,_,_,_,_,itemtype=GetItemInfo(item);
		local _,itemID=DuckLib:GetID(item);
		if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then return CONST.QUESTRATIO,CONST.QUESTRATIO; end
	end

	local nosafe=nil;
	local nKills,nRatio=0,0;
	local sKills,sRatio=0,0;
	if (not LootCount_DropCount_DB.Item[item]) then return 0,0,true; end
	local iTable=DropCount.DB.Item:Read(item);
	if (not iTable.Name and not iTable.Skinning) then return 0,0,true; end
	if (iTable.Name and not iTable.Name[mob]) then nRatio=0; end
	if (iTable.Skinning and not iTable.Skinning[mob]) then sRatio=0; end
	if (not LootCount_DropCount_DB.Count[mob]) then return 0,0,true; end

	local mTable=DropCount.DB.Count:Read(mob);
	if (iTable.Name) then
		nKills=mTable.Kill;
		if (not nKills or nKills<1) then nRatio=0;
		else
			if (iTable.Name[mob]) then
				nRatio=iTable.Name[mob]/nKills;
				if (iTable.Name[mob]<2) then unsafe=true; end
			else
				nRatio=0;
			end
		end
	end
	if (iTable.Skinning) then
		sKills=mTable.Skinning;
		if (not sKills or sKills<1) then sRatio=0;
		else
			if (iTable.Skinning[mob]) then
				sRatio=iTable.Skinning[mob]/sKills;
				if (iTable.Skinning[mob]<2) then unsafe=true; end
			else
				sRatio=0;
			end
		end
	end

	return nRatio,sRatio,nosafe;
end

-- Callback
function DropCount.LootCount.UpdateButton(button)
	if (not button) then return; end			-- End of iteration

	if (not button.User or not button.User.Texture) then return; end
	local texture=_G[button:GetName().."IconTexture"];
	texture:SetTexture(button.User.Texture);			-- Set texture from item
	if (not LootCount_DropCount_DB.Item[button.User.itemID]) then return; end			-- Nothing assigned yet
	local iTable=DropCount.DB.Item:Read(button.User.itemID);
	if (not iTable.Name and not itable.Skinning) then return; end	-- No known droppers

	local ratio=DropCount:TimedQueueRatio(button.User.itemID);

	local goalvalue=nil;
	if (button.goal and button.goal>0) then
		local amount=LootCount_GetItemCount(button.User.itemID);
		if (amount>=button.goal) then goalvalue="OK";
		else
			goalvalue=button.goal-amount;
			if (ratio>0) then goalvalue=math.ceil(goalvalue/ratio);
			else goalvalue=""; end
		end
	end

	if (DropCount.Registered) then LootCountAPI.SetData(LOOTCOUNT_DROPCOUNT,button,DropCount:FormatPst(ratio),goalvalue); end
end

function DropCount:TimedQueueRatio(item)
	local inqueue={};
	local i=1;
	while (i<=DropCount.Tracker.QueueSize and DropCount.Tracker.TimedQueue[i]) do
		if (DropCount.Tracker.TimedQueue[i].Oma) then
			if (not inqueue[DropCount.Tracker.TimedQueue[i].Mob]) then
				local drop,sD=DropCount:GetRatio(item,DropCount.Tracker.TimedQueue[i].Mob);
				if (not drop or drop==0) then drop=sD; end
				inqueue[DropCount.Tracker.TimedQueue[i].Mob]={ Count=1, Ratio=drop };
			else
				inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count=inqueue[DropCount.Tracker.TimedQueue[i].Mob].Count+1;
			end
		end
		i=i+1;
	end

	local ratio=0;
	local count=0;
	for mob,mTable in pairs(inqueue) do
		count=count+mTable.Count;
		ratio=ratio+(mTable.Count*mTable.Ratio);
	end
	if (count<1) then return; end
	ratio=ratio/count;
	return ratio;
end

function DropCount:FormatPst(ratio,addition)
	if (not ratio) then ratio=0; end
	if (ratio<0) then return "Quest"; end
	if (not addition) then addition=""; end
	local text;
	local pc=ratio*100;
	if (pc>=100) then text=string.format("%.0f",pc);
	elseif (pc>=10) then text=string.format("%.0f",pc);
	elseif (pc>=1) then text=string.format("%.1f",pc);
	elseif (pc==0) then return "0"..addition;
	else text=string.format("%.02f",pc);
	end
	return text..addition;
end

function DropCount.LootCount:SetButtonInfo(button,itemID,clearit)
	if (not button.User) then button.User = { };
	elseif (clearit) then DuckLib:ClearTable(button.User);
	end
	if (not button.User.itemID or itemID) then
		if (not itemID) then return nil; end
		button.User.itemID=itemID;
	end
	return true;
end

-- Callback
function DropCount.LootCount.DropItem(button,itemID)
	DropCount.LootCount:SetButtonInfo(button,itemID,true);						-- Start counting from now
	_,_,_,_,_,_,_,_,_,button.User.Texture=GetItemInfo(itemID);					-- Set custom texture
end

function DropCount:GetTargetType()
	local targettype="playertarget";
	local mobname=UnitName(targettype);
	if (not mobname) then
		mobname=UnitName("focus"); if (not mobname) then return nil; end
		targettype="focus";
	end
	return targettype;
end

-- Callback
function DropCount.LootCount.IconClicked(button,LR,count)
	if (count~=1) then return; end
	if (LR=="RightButton") then
		DropCount.LootCount:ToggleMenu(button);
	end
end

function DropCount:GetRatioColour(ratio)
	if (not ratio) then ratio=0; end
	if (ratio>1) then ratio=1; elseif (ratio<0) then ratio=0; end
	ratio=string.format("|cFF%02X%02X%02X",128+(ratio*127),128+(ratio*127),128+(ratio*127));		-- AARRGGBB
	return ratio;
end

function DropCount.Tooltip:VendorList(button,getlist)
	if (not LootCount_DropCount_DB.Converted) then
		DuckLib:Chat(CONST.C_RED.."The DropCount database is currently being converted to the new format. Your data will be available when this is done.|r");
		return;
	end

	if (type(button)=="string") then
		button={
			FreeFloat=true;
			User={
				itemID=button;
			};
		};
	elseif (not button.User or not button.User.itemID) then
		return;
	end
	if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (not getlist) then
		if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR");
		else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
		GameTooltip:SetText(colour.."["..itemname.."]|r");
	end
	local currentzone=GetRealZoneText();
	if (not currentzone) then
		currentzone="";
	elseif (LootCount_DropCount_Character.ShowZoneMobs) then
		if (not getlist) then
			GameTooltip:LCAddDoubleLine("Showing vendors from "..currentzone.." only","",0,1,1,0,1,1);
		end
	end

	local ThisZone=GetRealZoneText();
	local list={};
	local line=1;
	local droplist=0;
	local vTable;
	for vendor,vEntry in pairs(LootCount_DropCount_DB.Vendor) do
		if ((type(vEntry)=="table" and vEntry.Items and vEntry.Items[button.User.itemID]) or
			(string.find(vEntry,button.User.itemID,1,true))) then

			vTable=DropCount.DB.Vendor:Read(vendor);
			list[line]={};
			local zone=CONST.C_LBLUE;
			if (vTable.Zone and string.find(vTable.Zone,ThisZone,1,true)==1) then zone=CONST.C_HBLUE; end
			zone=zone..vTable.Zone.." - "..floor(vTable.X)..","..floor(vTable.Y).."|r";
			list[line].Ltext=zone.." : "..CONST.C_YELLOW..vendor.."|r ";
			list[line].Rtext="";
			if (type(vTable.Items[button.User.itemID])=="table") then
				if (vTable.Items[button.User.itemID].Count>=0) then list[line].Rtext=CONST.C_RED.."*|r";
				elseif (vTable.Items[button.User.itemID].Count==CONST.UNKNOWNCOUNT) then list[line].Rtext=CONST.C_YELLOW.."*|r";
				end
				if (LootCount_DropCount_Character.ShowZoneMobs and vTable.Zone and currentzone and string.find(vTable.Zone,currentzone,1,true)~=1) then
					list[line]=nil;
					line=line-1;
				end
			end
			line=line+1;
		end
	end

	list=DropCount:SortByNames(list);
	if (getlist) then return DuckLib:CopyTable(list); end
	if (line==1) then
		GameTooltip:LCAddLine("No known vendors",1,1,1);
	else
		-- Type list
		line=1;
		while(list[line]) do
			GameTooltip:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
			line=line+1;
		end
	end

	GameTooltip:Show();
end

function DropCount:SaveDebug(variable,name)
	if (not LootCount_DropCount_DB.DebugData) then LootCount_DropCount_DB.DebugData={}; end
	if (type(variable)=="table") then
		LootCount_DropCount_DB.DebugData[name]=DuckLib:CopyTable(variable);
	else
		LootCount_DropCount_DB.DebugData[name]=variable;
	end
end

function DropCount.LootCount.Tooltip(button)
	DropCount.Tooltip:MobList(button,true);
end

function DropCount:Highlight(text,highlight,terminate)
	if (not highlight) then return text; end
	if (not terminate) then terminate="|r"; end
	local test=text; test=test:lower();
	highlight=highlight:lower();
	local start,stop=test:find(highlight);
	if (not start) then return text; end
	local sf,sm,se="","","";
	if (start>1) then sf=text:sub(1,start-1); end
	sm=text:sub(start,stop);
	se=text:sub(stop+1);
	return sf.."|cFFFFFF00"..sm..terminate..se;
end

function DropCount.Tooltip:MobList(button,plugin,limit,down,highlight)
--	if (not limit) then limit=0; end
	if (type(button)=="string") then
		button={
			FreeFloat=true;
			User={
				itemID=button,
			};
		};
	elseif (not button.User or not button.User.itemID) then
		GameTooltip:SetOwner(button,"ANCHOR_RIGHT");
		GameTooltip:SetText("Drop an item here");
		GameTooltip:Show();
		return;
	end
	if (not LootCount_DropCount_DB.Item[button.User.itemID]) then return; end
	local itemname,_,rarity=GetItemInfo(button.User.itemID);
	if (not itemname or not rarity) then DropCount.Cache:AddItem(button.User.itemID) return; end
	local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
	if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR");
	else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
	GameTooltip:SetText(colour.."["..DropCount:Highlight(itemname,highlight,colour).."]|r:");
	local currentzone=GetRealZoneText();
	if (not currentzone) then
		currentzone="";
	elseif (LootCount_DropCount_Character.ShowZoneMobs) then
		GameTooltip:LCAddDoubleLine("Showing mobs from "..currentzone.." only","",0,1,1,0,1,1);
	end
	local iTable=DropCount.DB.Item:Read(button.User.itemID);
	local skinningdrop=iTable.Skinning;
	local normaldrop=iTable.Name;
	if (skinningdrop) then
		if (normaldrop) then GameTooltip:LCAddDoubleLine("Loot and |cFFFF00FFprofession","",1,1,1,1,1,1);
		else GameTooltip:LCAddDoubleLine("Profession","",1,0,1,1,0,1); end
	end
	if (iTable.Best) then
		GameTooltip:LCAddDoubleLine("Best drop-area:",DropCount:Highlight(iTable.Best.Location,highlight).." ("..iTable.Best.Score..")",0,1,1,0,1,1);
		if (iTable.BestW) then
			GameTooltip:LCAddDoubleLine(" ",DropCount:Highlight(iTable.BestW.Location,highlight).." ("..iTable.BestW.Score..")",0,1,1,0,1,1);
		end
	end

	-- Init raw list
	local list={};
	local line=1;
	local droplist=0;

	-- Do normal loot
	if (normaldrop) then
		for mob,drops in pairs(iTable.Name) do
			local pretext="";
			local i=1;
			local Show=nil;
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
			list[line]={};

			local mTable=DropCount.DB.Count:Read(mob);
			if (not mTable) then
--DuckLib:Chat(mob.." does not exist (drop)",1);
				DropCount:RemoveFromItem("Name",mob);
			else
				if (mTable.Kill) then
					list[line].Count=mTable.Kill;
				else
					list[line].Count=0;
				end
				local saturation=((high-low)/(CONST.KILLS_SAFE-CONST.KILLS_HIDE))*list[line].Count;
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);			-- AARRGGBB
				list[line].ratio=DropCount:GetRatio(button.User.itemID,mob);	-- Normal

				local zone="";
				if (LootCount_DropCount_Character.ShowZone and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end

				list[line].Ltext=colour..pretext..DropCount:Highlight(mob,highlight,colour)..zone.."|r: ";
				list[line].Show=Show;
				if (LootCount_DropCount_Character.ShowZoneMobs and mTable.Zone and currentzone and string.find(mTable.Zone,currentzone,1,true)~=1) then
					list[line]=nil;
					line=line-1;
				end
				line=line+1;
			end
		end
	end

	-- Do profession-loot
	if (skinningdrop) then
		for mob,drops in pairs(iTable.Skinning) do
			local pretext="";
			local i=1;
			local Show=nil;
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
			list[line]={};

			local mTable=DropCount.DB.Count:Read(mob);
			if (not mTable) then
--DuckLib:Chat(mob.." does not exist (skinning)",1);
				DropCount:RemoveFromItem("Skinning",mob);
			else
				if (mTable.Skinning) then
					list[line].Count=mTable.Skinning;
				else
					list[line].Count=0;
				end
				local saturation=((high-low)/(CONST.KILLS_SAFE-CONST.KILLS_HIDE))*list[line].Count;
				if (saturation<0) then saturation=0;
				elseif (saturation>(high-low)) then saturation=(high-low); end
				local colour=string.format("|cFF%02X%02X%02X",high-saturation,low+saturation,0);			-- AARRGGBB
				_,list[line].ratio=DropCount:GetRatio(button.User.itemID,mob); -- Skinning

				local zone="";
				if (LootCount_DropCount_Character.ShowZone and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end

				list[line].Ltext=colour..pretext..DropCount:Highlight(mob,highlight,colour)..zone.."|r";
				if (normaldrop) then list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext; end
				list[line].Show=Show;
				if (LootCount_DropCount_Character.ShowZoneMobs and mTable.Zone and currentzone and string.find(mTable.Zone,currentzone,1,true)~=1) then
					list[line]=nil;
					line=line-1;
				end
				line=line+1;
			end
		end
	end
	list=DropCount:SortByRatio(list);
	if (not limit) then
		limit=DropCount:FindListLowestByLength(list,CONST.LISTLENGTH-droplist);
	end

	-- Type list
	local count=0;
	local supressed=0;
	local lowKill=0;
	local goal=CONST.LISTLENGTH-droplist;						-- Subtract hi-pri entry
	line=1;
	while(list[line]) do
		if ((count<goal and list[line].Count>=limit) or list[line].Show) then
			GameTooltip:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
			if (not list[line].Show) then count=count+1; end	-- Count all normal entries
		else
			if (list[line].Count<limit) then lowKill=lowKill+1; end
			supressed=supressed+1;
		end
		line=line+1;
	end
--[[
	if (not IsShiftKeyDown()) then
		DropCount.Tracker.MobList.button=button;
		DropCount.Tracker.MobList.plugin=plugin;
		if (not down) then
			if (lowKill<supressed) then
				if (limit<1) then limit=1; end
				DropCount.Tracker.MobList.limit=limit*1.5;
				DropCount.Tracker.MobList.down=nil;
			else
				DropCount.Tracker.MobList.limit=limit*0.95;
				DropCount.Tracker.MobList.down=true;
			end
			GameTooltip:Hide();
			return;
		else
			if (lowKill>supressed) then
				DropCount.Tracker.MobList.limit=limit*0.95;
				DropCount.Tracker.MobList.down=true;
				GameTooltip:Hide();
				return;
			end
		end
	end
]]
	DropCount.Tracker.MobList.button=nil;

	if (supressed>0) then
		GameTooltip:LCAddDoubleLine(supressed.." more entries","",1,.5,1,1,1,1);
	end

	GameTooltip:Show();
end

function DropCount:SwapListTables(thelist,A,B)
	thelist[A],thelist[B]=thelist[B],thelist[A];
end

function DropCount:FindListLowestByLength(list,length)
	list=DuckLib:CopyTable(list);
	local low=-1;
	local curLength;
	repeat
		curLength=0;
		low=low+1;
		for index,iData in pairs(list) do
			if (iData.Count) then
				if (iData.Count<low) then list[index]=nil;		-- Remove entry
				else curLength=curLength+1; end					-- Count it
			end
		end
	until(curLength<=length);
	return low;
end

function DropCount:SortByRatio(list)
	local line=1;
	while(list[line+1]) do
		if (list[line].ratio<list[line+1].ratio) then
			DropCount:SwapListTables(list,line,line+1);
			if (line>1) then line=line-2; end
		end
		line=line+1;
	end
	local line=1;
	while(list[line]) do
		local addin=DropCount:FormatPst(list[line].ratio,"%|r");
		if (list[line].NoSafe) then addin="<"..addin; end
		list[line].Rtext=DropCount:GetRatioColour(list[line].ratio)..addin;
		line=line+1;
	end
	return list;
end

function DropCount:SortByCount(list)
	local line=1;
	while(list[line+1]) do
		if (list[line].Count>list[line+1].Count) then
			DropCount:SwapListTables(list,line,line+1);
			if (line>1) then line=line-2; end
		end
		line=line+1;
	end
	return list;
end

function DropCount:SortByNames(list)
	local line=1;
	while(list[line+1]) do
		if (list[line].Ltext>list[line+1].Ltext) then
			DropCount:SwapListTables(list,line,line+1);
			if (line>1) then line=line-2; end
		end
		line=line+1;
	end
	return list;
end

function DropCount:GetQuestStatus(qId,qName)
	local White="|cFFFFFFFF";
	local Yellow="|cFFFFFF00";
	local Red="|cFFFF0000";
	local Green="|cFF00FF00";
	local bBlue="|cFFA0A0FF";		-- Bright blue
	local Dark="|cFF808080";

	if (not qName) then return CONST.QUEST_UNKNOWN,White; end
	if (not LootCount_DropCount_DB.Quest) then return CONST.QUEST_UNKNOWN,White; end

	-- Check running quests
	if (LootCount_DropCount_Character.Quests) then
		if (LootCount_DropCount_Character.Quests[qName]) then
			if (LootCount_DropCount_Character.Quests[qName].ID) then
				if (LootCount_DropCount_Character.Quests[qName].ID==qId) then
					return CONST.QUEST_STARTED,Yellow;	-- I have it
				end
			else
				return CONST.QUEST_STARTED,Red;	-- It does not have an ID
			end
		end
	end
	-- Maybe it's done
	if (LootCount_DropCount_Character.DoneQuest) then
		if (LootCount_DropCount_Character.DoneQuest[qName]) then
			if (LootCount_DropCount_Character.DoneQuest[qName]==qId) then
				return CONST.QUEST_DONE,Dark;		-- I've done it
			else
				return CONST.QUEST_DONE,Dark;		-- I've done it
			end
		end
	end

	return CONST.QUEST_NOTSTARTED,Green;
end

function DropCount.Tooltip:QuestList(faction,npc,parent,frame)
	if (not frame) then frame=LootCount_DropCount_TT; end
	local nTable=DropCount.DB.Quest:Read(faction,npc);
	if (not nTable) then return; end
	if (not nTable.Quests) then return; end

	frame:ClearLines();
	if (not parent) then parent=UIParent; end
	frame:SetOwner(parent,"ANCHOR_CURSOR");
	frame:SetText(npc);
	for _,qData in pairs(nTable.Quests) do
		local quest,header,id;
		quest=qData.Quest; header=qData.Header; id=qData.ID;
		if (not header) then header=""; end
		local _,colour=DropCount:GetQuestStatus(id,quest);
		frame:LCAddDoubleLine("  "..colour..quest,colour..header,1,1,1,1,1,1);
	end
	frame:Show();
end


function DropCount.Tooltip:Book(book,parent)
	if (not LootCount_DropCount_DB.Book) then return; end

	local bStatus=CONST.C_RED.."Need to read|r";
	local count=GetAchievementNumCriteria(1244);
	while (count>0) do
		bName,_,hasRead,_,_,playername,_,_,_,_=GetAchievementCriteriaInfo(1244,count);
		if (playername==UnitName("player")) then
			if (bName==book) then
				if (hasRead==true) then bStatus=CONST.C_GREEN.."Done with this book|r"; end
				count=1;
			end
		end
		count=count-1;
	end

	LootCount_DropCount_TT:ClearLines();
	if (not parent) then parent=UIParent; end
	LootCount_DropCount_TT:SetOwner(parent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText("Book");
	LootCount_DropCount_TT:LCAddLine(book,1,1,1);
	LootCount_DropCount_TT:LCAddLine(bStatus,1,1,1);
	LootCount_DropCount_TT:Show();
end

function DropCount.Tooltip:SetNPCContents(unit,parent,frame,force)
	local breakit=nil;
	if (not frame) then frame=LootCount_DropCount_TT; end
	if (not force) then
		if (LootCount_DropCount_DB.Quest and LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then
			for npc,nTable in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
				if (npc==unit) then
					breakit=true;
					DropCount.Tooltip:QuestList(CONST.MYFACTION,unit,parent,frame);
				end
				if (breakit) then break; end
			end
		end
	end
	if (not LootCount_DropCount_DB.Vendor) then return; end
	if (not LootCount_DropCount_DB.Vendor[unit]) then return; end

	local vData=DropCount.DB.Vendor:Read(unit);
	if (not vData) then return; end
	if (not vData.Items) then return; end

	frame:ClearLines();
	if (not parent) then parent=UIParent; end
	frame:SetOwner(parent,"ANCHOR_CURSOR");
	local line=unit;
	if (vData.Repair) then line=line..CONST.C_GREEN.." (Repair)"; end
	frame:SetText(line);

	local list={};
	line=1;
	local missingitems=0;
	local itemsinlist=nil;
	local item,iTable;
	for item,iTable in pairs(vData.Items) do
		local itemname,_,rarity=GetItemInfo(item);
		if (not itemname or not rarity) then
			DropCount.Cache:AddItem(item);
			missingitems=missingitems+1;
		else
			local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
			list[line]={ Ltext=colour..itemname.."|r ", Rtext="" };
			if (iTable.Count>=0) then list[line].Ltext=CONST.C_RED.."* |r"..list[line].Ltext;
			elseif (iTable.Count==CONST.UNKNOWNCOUNT) then list[line].Ltext=CONST.C_YELLOW.."* |r"..list[line].Ltext;
			end
			line=line+1;
			itemsinlist=true;
		end
	end
	if (missingitems>0) then
		frame:LCAddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		frame:LCAddDoubleLine("Loading...","",1,0,0,0,0,0);
		frame:Show();
		frame.Loading=true;
		return;
	end
	frame.Loading=nil;
	if (not itemsinlist) then frame:Hide(); return; end

	list=DropCount:SortByNames(list);
	line=1;
	while(list[line]) do
		frame:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
		line=line+1;
	end
	frame:Show();
end

function DropCount:SetLootlist(unit,AltTT)
	if (not LootCount_DropCount_DB.Count[unit]) then
		DropCount.Tooltip:SetNPCContents(unit);
		return;
	end

	if (not AltTT) then AltTT=LootCount_DropCount_TT; end
	AltTT:ClearLines();
	AltTT:SetOwner(UIParent,"ANCHOR_CURSOR");
	AltTT:SetText(unit);
	local text="";
	local mTable=DropCount.DB.Count:Read(unit);
	if (mTable.Skinning and mTable.Skinning>0) then text="Profession-loot: "..mTable.Skinning.." times"; end
	if (not mTable.Kill) then mTable.Kill=0; end
	AltTT:LCAddDoubleLine(mTable.Kill.." kills",text,.4,.4,1,1,0,1);

	local list={};
	local line=1;
	local missingitems=0;
	local itemsinlist=nil;
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (iData:find(unit,1,true)) then		-- Plain search
			local iTable=DropCount.DB.Item:Read(item);
			if (iTable.Name and iTable.Name[unit]) then
				local itemname,_,rarity,_,_,itemtype=GetItemInfo(item);
				local questitem=nil;
				if (CONST.QUESTID) then
					if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then
						questitem=true;
					end
				end
				if (not itemname or not rarity) then
					DropCount.Cache:AddItem(item);
					missingitems=missingitems+1;
				elseif (LootCount_DropCount_Character.ShowSingle or questitem or iTable.Name[unit]~=1) then
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local thisratio,_,thissafe=DropCount:GetRatio(item,unit);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
					if (iTable.Quest) then list[line].Quests=DuckLib:CopyTable(iTable.Quest); end
					line=line+1;
					itemsinlist=true;
				end
			end
			if (iTable.Skinning and iTable.Skinning[unit]) then
				local itemname,_,rarity=GetItemInfo(item);
				if (not itemname or not rarity) then
					DropCount.Cache:AddItem(item);
					missingitems=missingitems+1;
				else
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local _,thisratio,thissafe=DropCount:GetRatio(item,unit);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
					list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext;	-- AARRGGBB
					if (iData.Quest) then list[line].Quests=DuckLib:CopyTable(iData.Quest); end
					line=line+1;
					itemsinlist=true;
				end
			end
		end
	end
	if (missingitems>0) then
		AltTT:LCAddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		AltTT:LCAddDoubleLine("Loading...","",1,0,0,0,0,0);
		AltTT:Show();
		AltTT.Loading=true;
		return;
	end
	AltTT.Loading=nil;
	if (not itemsinlist) then AltTT:Hide(); return; end

	-- Build the window on screen
	list=DropCount:SortByRatio(list);
	line=1;
	while(list[line]) do
		AltTT:LCAddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
		if (list[line].Quests) then
			for quest,amount in pairs(list[line].Quests) do
				if (LootCount_DropCount_DB.Quest and LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then
					for npc,rawData in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
						if (rawData:find(quest,1,true)) then
							local qData=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
							if (qData.Quests) then
								for _,qListData in ipairs(qData.Quests) do
									if (qListData.Quest==quest) then
										AltTT:LCAddSmallLine("   "..amount.." for "..quest.." ("..qListData.Header..")",.5,.3,.2);
										AltTT:LCAddSmallLine("   "..DuckLib.Color.Yellow.."   ! |r"..npc.." ("..qData.Zone.." - "..math.floor(qData.X)..","..math.floor(qData.Y)..")",.5,.3,.2);
									end
								end
							end
						end
					end
				end
			end
		end
		line=line+1;
	end
	AltTT:Show();
end

function DropCount.TooltipExtras:SetFunctions(widget)
	widget.LCAddLine=DropCount.TooltipExtras.AddLine
	widget.LCAddDoubleLine=DropCount.TooltipExtras.AddDoubleLine
	widget.LCAddSmallLine=DropCount.TooltipExtras.AddSmallLine
	widget:AddLine("1"); widget:AddLine("2");
	widget.LCFont,widget.LCSize,widget.LCFlags=_G[widget:GetName().."TextLeft"..widget:NumLines()]:GetFont();
--DuckLib:Chat("NORM: "..widget.LCSize);
end

function DropCount.TooltipExtras:AddLine(text,r,g,b,a)
	self:AddLine(text,r,g,b,a);
	_G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags);
end

function DropCount.TooltipExtras:AddSmallLine(text,r,g,b,a)
	self:AddLine(text,r,g,b,a);
	_G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize*.75,self.LCFlags);
end

function DropCount.TooltipExtras:AddDoubleLine(textL,textR,rL,gL,bL,rR,gR,bR)
	self:AddDoubleLine(textL,textR,rL,gL,bL,rR,gR,bR);
	_G[self:GetName().."TextLeft"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags);
	_G[self:GetName().."TextRight"..self:NumLines()]:SetFont(self.LCFont,self.LCSize,self.LCFlags);
end

function DropCount.Cache:AddItem(item)
	DropCount.Cache.Retries=0;
	if (not DropCount.Tracker.UnknownItems) then DropCount.Tracker.UnknownItems={}; DropCount.Cache.Timer=.5; end
	DropCount.Tracker.UnknownItems[item]=true;
end

-- A blind update will queue a request at the server without any
-- book-keeping at this side.
-- CATACLYSM: Cache has been greatly improved by speed at the server side.
function DropCount.Cache:Execute(item,blind)
	if (type(item)=="number") then item="item:"..item;
	elseif (type(item)~="string") then return true; end
	local name=GetItemInfo(item);
	if (not LootCount_DropCount_CF:IsVisible()) then
		if (not name) then
			LootCount_DropCount_CF:SetOwner(UIParent); LootCount_DropCount_CF:SetHyperlink(item); LootCount_DropCount_CF:Hide();
			if (not blind) then
				DropCount.Cache.Retries=DropCount.Cache.Retries+1;
			end
			return false;
		else
			if (not blind) then DropCount.Cache.Retries=0; end
		end
	end
	return true;
end

function DropCount.LootCount:ToggleMenu(button)
	DropCount.ThisBuffer=button;
	ToggleDropDownMenu(1,nil,LootCount_DropCount_MenuOptions,button,0,0);
end

function DropCountXML:GUI_Search()
	local find=LCDC_VendorSearch_FindText:GetText();
	find=strtrim(find); if (find=="") then return; end
	LCDC_ResultListScroll:DMClear();
	if (not find) then return; end
	find=find:lower();
	LCDC_VendorSearch.SearchTerm=find;

	-- Search vendors
	local entry;
	local started=nil;
	if (LCDC_VendorSearch_UseVendors:GetChecked()) then
		for vendor,vData in pairs(LootCount_DropCount_DB.Vendor) do
			local testdata=vData; testdata=testdata:lower();
			if (testdata:find(find)) then
				local X,Y,Zone,Faction,Repair=DropCount.DB.Vendor:ReadBaseData(vendor);
				if (Faction==CONST.MYFACTION or Faction=="Neutral") then
					if (not started) then
						entry=LCDC_ResultListScroll:DMAdd("Vendors",nil,nil,-1);
						entry.Tooltip=nil;
						wipe(entry.DB);
						started=true;
					end
					entry=LCDC_ResultListScroll:DMAdd(Zone..": "..vendor,nil,nil,0);
					wipe(entry.DB);
					if (not entry.Tooltip) then entry.Tooltip={}; end
					entry.Tooltip[1]=Faction.." vendor: "..vendor;
					entry.Tooltip[2]=Zone..string.format(" (%.0f,%.0f)",X,Y);
					if (Repair) then entry.Tooltip[3]="Can repair your stuff"; end
					entry.DB.Section="Vendor";
					entry.DB.Entry=vendor;
					entry.DB.Data=vData;
				end
			end
		end
	end

	-- Search quests
	if (LCDC_VendorSearch_UseQuests:GetChecked()) then
		started=nil;
		for npc,nData in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
			local testdata=nData; testdata=testdata:lower();
			if (testdata:find(find)) then
				if (not started) then
					entry=LCDC_ResultListScroll:DMAdd("Quests",nil,nil,-1);
					entry.Tooltip=nil;
					wipe(entry.DB);
					started=true;
				end
				local npcData=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
				entry=LCDC_ResultListScroll:DMAdd(npcData.Zone..": "..npc,nil,nil,0);
				wipe(entry.DB);
				if (not entry.Tooltip) then entry.Tooltip={}; end
				entry.Tooltip[1]="Quest-giver: "..npc;
				entry.Tooltip[2]=npcData.Zone..string.format(" (%.0f,%.0f)",npcData.X,npcData.Y);
				entry.DB.Section="Quest";
				entry.DB.Entry=npc;
				entry.DB.Data=nData;
			end
		end
	end

	-- Search books
	if (LCDC_VendorSearch_UseBooks:GetChecked()) then
		started=nil;
		for book,bData in pairs(LootCount_DropCount_DB.Book) do
			local include=nil;
			local testdata=book; testdata=testdata:lower();
			if (testdata:find(find)) then include=true;
			else
				for _,iData in ipairs(bData) do
					local testdata=iData.Zone; testdata=testdata:lower();
					if (testdata:find(find)) then include=true; break; end
				end
			end
			if (include) then
				if (not started) then
					entry=LCDC_ResultListScroll:DMAdd("Books",nil,nil,-1);
					entry.Tooltip=nil;
					wipe(entry.DB);
					started=true;
				end
				entry=LCDC_ResultListScroll:DMAdd(book,nil,nil,0);
				wipe(entry.DB);
				if (not entry.Tooltip) then entry.Tooltip={}; end
				entry.Tooltip[1]="Book: "..book;
				for index,iData in ipairs(bData) do
					entry.Tooltip[index+1]=iData.Zone..string.format(" (%.0f,%.0f)",iData.X,iData.Y);
				end
				entry.DB.Section="Book";
				entry.DB.Entry=book;
			end
		end
	end

	-- Search items
	if (LCDC_VendorSearch_UseItems:GetChecked()) then
		started=nil;
		for item,iData in pairs(LootCount_DropCount_DB.Item) do
			local testdata=iData; testdata=testdata:lower();
			if (testdata:find(find)) then
				if (not started) then
					entry=LCDC_ResultListScroll:DMAdd("Items",nil,nil,-1);
					entry.Tooltip=nil;
					wipe(entry.DB);
					started=true;
				end
				DropCount.Cache:AddItem(item);
				local itemData=DropCount.DB.Item:Read(item);
--				entry=LCDC_ResultListScroll:DMAdd(itemData.Item,nil,nil,0);
				entry=LCDC_ResultListScroll:DMAdd(itemData.Item,nil,nil,0,GetItemIcon(item));
				wipe(entry.DB);
				entry.DB.Section="Item";
				entry.DB.Entry=item;
				entry.DB.Data=itemData;
			end
		end
	end

	-- Search mobs
	if (LCDC_VendorSearch_UseMobs:GetChecked()) then
		started=nil;
		for mob,mData in pairs(LootCount_DropCount_DB.Count) do
			local testdata=mob; testdata=testdata:lower();
			if (testdata:find(find)) then
				if (not started) then
					entry=LCDC_ResultListScroll:DMAdd("Creatures",nil,nil,-1);
					entry.Tooltip=nil;
					wipe(entry.DB);
					started=true;
				end
				entry=LCDC_ResultListScroll:DMAdd(mob,nil,nil,0);
				wipe(entry.DB);
				entry.DB.Section="Creature";
				entry.DB.Entry=mob;
			end
		end
	end
end

function DropCountXML:BuildMenu(button)
	DropCount.ThisBuffer=button;
	UIDropDownMenu_Initialize(LootCount_DropCount_MenuOptions,DropCountXML.MenuLoad,"MENU");
end

function DropCountXML.MenuLoad()
	local info={};
	info.textR=1; info.textG=1; info.textB=1;
	if (CONST.QUESTID and DropCount.ThisBuffer.User and DropCount.ThisBuffer.User.itemID) then
		local _,_,_,_,_,itemtype=GetItemInfo(DropCount.ThisBuffer.User.itemID);
		if (itemtype and itemtype==CONST.QUESTID) then
			info.isTitle=1; info.checked=nil; info.func=nil; info.text="Setting for this item:"; UIDropDownMenu_AddButton(info,1); info.isTitle=nil; info.disabled=nil;
			local _,thisid=DuckLib:GetID(DropCount.ThisBuffer.User.itemID);
			if (not LootCount_DropCount_NoQuest[thisid]) then info.checked=true; end
			info.text="Only drops when on a quest"; info.value=thisid; info.func=DropCount.Menu.ToggleQuestItem; UIDropDownMenu_AddButton(info,1);

			info.isTitle=1; info.checked=nil; info.func=nil; info.text=" "; UIDropDownMenu_AddButton(info,1);
		end
	end

	info.isTitle=1; info.checked=nil; info.func=nil; info.text="Global settings for "..LOOTCOUNT_DROPCOUNT_VERSIONTEXT..":"; UIDropDownMenu_AddButton(info,1); info.isTitle=nil; info.disabled=nil;

	info.func=DropCount.Menu.ToggleZone;
	info.text="Show zone"; info.checked=LootCount_DropCount_Character.ShowZone; UIDropDownMenu_AddButton(info,1);
	info.func=DropCount.Menu.ToggleZoneMobs;
	info.text="Only list mobs from current zone"; info.checked=LootCount_DropCount_Character.ShowZoneMobs; UIDropDownMenu_AddButton(info,1);
	info.func=DropCount.LootCount.MenuSetGoal;
	info.text="Set goal"; info.checked=nil; UIDropDownMenu_AddButton(info,1);

	info.func=DropCount.Menu.ToggleChannel;
	info.text="Guild data-sharing"; info.value="GUILD"; info.checked=LootCount_DropCount_DB[info.value]; UIDropDownMenu_AddButton(info,1);
	info.text="Group/raid data-sharing"; info.value="RAID"; info.checked=LootCount_DropCount_DB[info.value]; UIDropDownMenu_AddButton(info,1);
	info.checked=nil;
end

function DropCount.Menu.ToggleZoneMobs()
	if (LootCount_DropCount_Character.ShowZoneMobs) then LootCount_DropCount_Character.ShowZoneMobs=false;
	else LootCount_DropCount_Character.ShowZoneMobs=true; end
end

function DropCount.Menu.ToggleZone()
	if (LootCount_DropCount_Character.ShowZone) then LootCount_DropCount_Character.ShowZone=false;
	else LootCount_DropCount_Character.ShowZone=true; end
end

function DropCount.Menu.ToggleQuestItem(frame)
	if (LootCount_DropCount_NoQuest[frame.value]) then LootCount_DropCount_NoQuest[frame.value]=nil; return; end
	LootCount_DropCount_NoQuest[frame.value]=true;
end

function DropCount.Menu.ToggleChannel(frame)
	if (LootCount_DropCount_DB[frame.value]) then LootCount_DropCount_DB[frame.value]=nil; else LootCount_DropCount_DB[frame.value]=true; end
	if (frame.value=="GUILD") then LootCount_DropCount_DB.RAID=nil; end
	if (frame.value=="RAID") then LootCount_DropCount_DB.GUILD=nil; end
end

function DropCount.LootCount.MenuSetGoal()
	if (not DropCount.Registered) then return; end
	local user=LootCountAPI.User(DropCount.ThisBuffer);
	LootCount_SetGoalPopup(DropCount.ThisBuffer);
end

function DropCount:CleanDB()
	local text=CONST.C_BASIC.."DropCount:|r ";

	if (DropCount.Debug) then
		collectgarbage("collect");
		UpdateAddOnMemoryUsage();
		local usage=GetAddOnMemoryUsage("LootCount_DropCount");
		usage=string.format("%.0fKB",usage);
		text="DropCount memory usage: "..usage.." -> ";
	end

	-- List key-data
	local nowitems,nowmobs;
	if (LootCount_DropCount_DB.Book) then
		nowitems=0;
		local volumes=0;
		for vendor,vTable in pairs(LootCount_DropCount_DB.Book) do
			for i,iTable in pairs(vTable) do volumes=volumes+1; end
			nowitems=nowitems+1;
		end
		DuckLib:Chat(CONST.C_BASIC.."DropCount: "..CONST.C_GREEN..nowitems..CONST.C_BASIC.." known books ("..CONST.C_GREEN..volumes..CONST.C_BASIC.." total volumes)");
	end
	if (LootCount_DropCount_DB.Vendor) then
		nowmobs=0;
		for vendor,vTable in pairs(LootCount_DropCount_DB.Vendor) do nowmobs=nowmobs+1; end
		DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN..nowmobs.."|r known vendors");
	end
	if (LootCount_DropCount_DB.Quest) then
		nowmobs=0;
		for _,fTable in pairs(LootCount_DropCount_DB.Quest) do
			for _,nTable in pairs(fTable) do
				nowmobs=nowmobs+1;
			end
		end
		DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN..nowmobs.."|r known quest-givers");
	end
	nowitems=0;
	if (LootCount_DropCount_DB.Item) then
		for item,iData in pairs(LootCount_DropCount_DB.Item) do
			nowitems=nowitems+1;
		end
		text=text..CONST.C_GREEN..nowitems.."|r items";
	end
	if (not LootCount_DropCount_StartItems) then LootCount_DropCount_StartItems=nowitems; end
	nowmobs=0;
	if (LootCount_DropCount_DB.Count) then
		for creature,cTable in pairs(LootCount_DropCount_DB.Count) do nowmobs=nowmobs+1; end
		text=text.." -> "..CONST.C_GREEN..nowmobs.."|r creatures";
	end
	if (not LootCount_DropCount_StartMobs) then LootCount_DropCount_StartMobs=nowmobs; end
	DuckLib:Chat(text);

	if (nowitems-LootCount_DropCount_StartItems>0 or nowmobs-LootCount_DropCount_StartMobs>0) then
		DuckLib:Chat(CONST.C_BASIC.."DropCount:|r New this session: "..CONST.C_GREEN..nowitems-LootCount_DropCount_StartItems.."|r items, "..CONST.C_GREEN..nowmobs-LootCount_DropCount_StartMobs.."|r mobs");
	end
	DuckLib:Chat(CONST.C_BASIC.."Type "..CONST.C_GREEN..SLASH_DROPCOUNT2..CONST.C_BASIC.." to view options");
	DuckLib:Chat(CONST.C_BASIC.."Please consider sending your SavedVariables file to "..CONST.C_YELLOW.."dropcount@ybeweb.com"..CONST.C_BASIC.." to help develop the DropCount addon.");
end

function DropCount:ConvertBookFormat()
	if (not LootCount_DropCount_DB.Book) then return; end
	local book,bTable;
	for book,bTable in pairs(LootCount_DropCount_DB.Book) do
		if (LootCount_DropCount_DB.Book[book].Zone) then
			LootCount_DropCount_DB.Book[book][1]= {};
			LootCount_DropCount_DB.Book[book][1].X=LootCount_DropCount_DB.Book[book].X;
			LootCount_DropCount_DB.Book[book][1].Y=LootCount_DropCount_DB.Book[book].Y;
			LootCount_DropCount_DB.Book[book][1].Zone=LootCount_DropCount_DB.Book[book].Zone;
			LootCount_DropCount_DB.Book[book].X=nil;
			LootCount_DropCount_DB.Book[book].Y=nil;
			LootCount_DropCount_DB.Book[book].Zone=nil;
		end
	end
end

function DropCount:SaveBook(BookName,bZone,bX,bY,Map)
	if (not LootCount_DropCount_DB.Book) then LootCount_DropCount_DB.Book={}; end

	local silent=true;
	if (not bX or not bY or not bZone) then
		bX,bY=DropCount:GetPLayerPosition();
		bZone=DropCount:GetFullZone();
		Map=DropCount:GetMapTable()
		silent=nil;
	end
	if (not bZone) then bZone="Unknown"; end
	local i=1;
	local newBook,updatedBook=0,0;
	if (not LootCount_DropCount_DB.Book[BookName]) then
		if (not silent) then DuckLib:Chat(CONST.C_BASIC.."Location of new book "..CONST.C_GREEN.."\""..BookName.."\""..CONST.C_BASIC.." saved"); end
		LootCount_DropCount_DB.Book[BookName]={};
		newBook=1;
	else
		local found=nil;
		while (not found and LootCount_DropCount_DB.Book[BookName][i]) do
			if (LootCount_DropCount_DB.Book[BookName][i].Zone==bZone) then		-- Found in same zone
				found=true;
				updatedBook=1;
				i=i-1;
			end
			i=i+1;
		end
	end
	LootCount_DropCount_DB.Book[BookName][i]={
		X=bX,
		Y=bY,
		Zone=bZone,
		Map=Map,

	};
	if (not silent) then
		DropCount.Icons.MakeMM:Book();
		DuckLib:Chat(CONST.C_BASIC..BookName..CONST.C_GREEN.." saved. "..CONST.C_BASIC..i.." volumes known.");
	end
	return newBook,updatedBook;
end

function DropCountXML:OnUpdate(frame,elapsed)
	if (not DropCount.Loaded) then return; end

	DropCount.Loaded=DropCount.Loaded+elapsed;

	if (DropCount.Loaded>10) then
		DropCount.Update=DropCount.Update+elapsed;
		if (DropCount.Update>=20) then
			DropCount.Update=0;
			if (DropCountXML.ARL and DropCountXML.ARL.Importing==false) then
				DropCountXML.ARL:Import()
			end
		end
	end

	if (not DuckLib) then return; end				-- Library is missing

	if (not CONST.QUESTID and (not DropCount.Tracker.UnknownItems or not DropCount.Tracker.UnknownItems["item:31812"])) then
		_,_,_,_,_,CONST.QUESTID=GetItemInfo("item:31812");
		if (not CONST.QUESTID) then
			DropCount.Cache:AddItem("item:31812")
--		else
--			DropCount.Convert:One();
		end
	end

	DropCount.OnUpdate:RunUnknownItems(elapsed);
	DropCount.OnUpdate:PollVendor(elapsed);
	DropCount.OnUpdate:RunMouseoverInWorld(elapsed);
	DropCount.OnUpdate:RunTimedQueue(elapsed);
	DropCount.OnUpdate:MonitorGameTooltip(elapsed);
	DropCount.OnUpdate:MonitorReadableTexts(elapsed);
	DropCount.OnUpdate:RunMobList();
	DropCount.OnUpdate:RunStartup(elapsed);
	DropCount.OnUpdate:RunQuestScan(elapsed);
	DropCount.OnUpdate:WalkOldQuests(elapsed);
	DropCount.OnUpdate:RunConvertAndMerge(elapsed);
	DropCount.OnUpdate:RunClearMobListMT(elapsed);

	if (DropCount.SpoolQuests) then
		DropCount:WalkQuests();
	end

	if (DropCount.Registered) then
--> Old fight-code removed
	elseif (LootCountAPI and LootCountAPI.Register and LootCount_Loaded) then
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

		LootCount_DropCount_DB.RAID=nil;
		if (IsInGuild()) then LootCount_DropCount_DB.GUILD=true; else LootCount_DropCount_DB.GUILD=nil; end
		LootCountAPI.Register(info);
		DropCount.Registered=true;
		DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN.."LootCount detected. DropCount is available from the LootCount menu.");
	end
end

function DropCount.OnUpdate:RunClearMobListMT(elapsed)
	if (not DropCount.Tracker.ClearMobDrop.item) then return; end
	if (elapsed>(1/20)) then
		DropCount.Tracker.ClearMobDrop.amount=DropCount.Tracker.ClearMobDrop.amount/2;
	elseif (elapsed<(1/25)) then
		DropCount.Tracker.ClearMobDrop.amount=DropCount.Tracker.ClearMobDrop.amount*1.2;
	end
	if (DropCount.Tracker.ClearMobDrop.amount<100) then
		DropCount.Tracker.ClearMobDrop.amount=100;
	end
	DropCount:ClearMobDropMT(DropCount.Tracker.ClearMobDrop.amount);
end

function DropCount.OnUpdate:RunMobList()
	if (not DropCount.Tracker.MobList.button) then return; end
	DropCount.Tooltip:MobList(	DropCount.Tracker.MobList.button,
								DropCount.Tracker.MobList.plugin,
								DropCount.Tracker.MobList.limit,
								DropCount.Tracker.MobList.down);
end

function DropCount.OnUpdate:RunUnknownItems(elapsed)
	if (DropCount.Tracker.UnknownItems) then
		DropCount.Cache.Timer=DropCount.Cache.Timer-elapsed;
		if (DropCount.Cache.Timer<=0) then
			DropCount.Cache.Timer=CONST.CACHESPEED;
			if (not DropCount.Tracker.RequestedItem) then
				local counter=0;
				for unknown,value in pairs(DropCount.Tracker.UnknownItems) do
					if (not DropCount.Tracker.RequestedItem) then
						DropCount.Tracker.RequestedItem=unknown;
					end
					DropCount.Cache:Execute(unknown,true);	-- Blind (pre) update
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
				if (DropCount.Search.Item==DropCount.Tracker.RequestedItem) then
					DropCount:VendorsForItem();
				elseif (DropCount.Search.mobItem==DropCount.Tracker.RequestedItem) then
					DropCount:AreaForItem();
				end
				DropCount.Tracker.RequestedItem=nil;
				DropCount.Cache.Retries=0;
				if (not LootCount_DropCount_DB.Converted) then
					-- Counting items
					local val,vTable,i;
					i=0;
					for val,vTable in pairs(DropCount.Tracker.UnknownItems) do i=i+1; end
					if (i<6 or (i>5 and (floor(i/25)*25)==i)) then
						DuckLib:Chat("Converting DropCount database: "..i.." items left...",0,1,1);
					end
				end
			end
		end
		if (DropCount.Cache.Retries>=CONST.CACHEMAXRETRIES) then
			if (DropCount.Search.Item==DropCount.Tracker.RequestedItem) then
				DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Could not retrieve information for this item from the server.");
				DropCount.Search.Item=nil;
			elseif (DropCount.Search.mobItem==DropCount.Tracker.RequestedItem) then
				DuckLib:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Could not retrieve information for this item from the server.");
				DropCount.Search.mobItem=nil;
			end
			DuckLib:Chat("Not retrievable: "..DropCount.Tracker.RequestedItem,1);
			if (LootCount_DropCount_DB.Item and
					LootCount_DropCount_DB.Item[DropCount.Tracker.RequestedItem]) then
				local iTable=DropCount.DB.Item:Read(DropCount.Tracker.RequestedItem);
				if (iTable.Item) then
					DuckLib:Chat("\""..DropCount.Tracker.RequestedItem.."\" seem to be \""..iTable.Item.."\"",1);
				end
			end
			DuckLib:Chat("This can happen if it has not been seen on the server since last server restart.",1);
			DropCount.Tracker.UnknownItems=nil;			-- Too many tries, so abort
			DropCount.Tracker.RequestedItem=nil;
		end
	elseif (DropCount.Cache.CachedConvertItems>0) then
--		DropCount.Convert:One();
	end
end

function DropCount.OnUpdate:PollVendor(elapsed)
	if (DropCount.Timer.VendorDelay>=0) then
		DropCount.Timer.VendorDelay=DropCount.Timer.VendorDelay-elapsed;
		if (DropCount.Timer.VendorDelay<0) then
			if (not DropCount:ReadMerchant(DropCount.Target.OpenMerchant)) then
				DropCount.Timer.VendorDelay=.5;
			end
		end
	end
end

function DropCount.OnUpdate:RunMouseoverInWorld(elapsed)
	if (IsAltKeyDown() and UnitExists("mouseover")) then
		if (not LootCount_DropCount_TT:IsVisible()) then DropCount:SetLootlist(UnitName("mouseover"));
		elseif (LootCount_DropCount_TT.Loading) then
			LootCount_DropCount_TT:Hide();
			DropCount:SetLootlist(UnitName("mouseover"));
		end
	elseif (not LCDC_VendorFlag_Info) then
		if (LootCount_DropCount_TT:IsVisible()) then LootCount_DropCount_TT:Hide(); end
	end
end

function DropCount.OnUpdate:RunTimedQueue(elapsed)
	if (DropCount.Tracker.QueueSize>0) then
		local now=time();
		if (DropCount.Tracker.QueueSize>0 and now-DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize].Time>CONST.QUEUETIME) then
			DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize]=nil;
			DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize-1;
			if (DropCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
		end
	end
end

--[[
	list
		item1 = percent
		item2 = percent
]]
function DropCount:BuildItemList(mob)
	local list={};
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (string.find(iData,mob,1,true)) then
			list[item]=math.floor(DropCount:TimedQueueRatio(item)*100);
			if (list[item]<0) then list[item]=nil; end
		end
	end
	return list;
end

function DropCount.OnUpdate:MonitorGameTooltip(elapsed)
	if (GameTooltip and GameTooltip:IsVisible()) then
		if (IsControlKeyDown() or IsAltKeyDown()) then
			local _,ThisItem=GameTooltip:GetItem();
			if (ThisItem) then
				ThisItem=DuckLib:GetID(ThisItem);
				if (ThisItem) then
					if (IsControlKeyDown()) then DropCount.Tooltip:VendorList(ThisItem);
					elseif (IsAltKeyDown()) then DropCount.Tooltip:MobList(ThisItem);
					else
					end
				end
			end
		end
	end
end

function DropCount.OnUpdate:MonitorReadableTexts(elapsed)
	if (ItemTextFrame and ItemTextFrame:IsVisible()) then
		if (not DropCount.ItemTextFrameHandled) then
			if (ItemTextGetCreator()) then							-- A player created text
				DropCount.ItemTextFrameHandled=true;						-- Do nothing more
			elseif (ItemTextTitleText) then							-- There's a header
				local material=ItemTextGetMaterial();
				if (not material) then material="Parchment"; end
				if (material=="Parchment") then						-- It's partchment
					if (ItemTextNextPageButton:IsVisible()) then	-- Multi-page
						local theItem=ItemTextTitleText:GetText();
						if (theItem) then							-- There's something in the header
							if (not GetItemInfo(theItem)) then		-- It's not an item name
								DropCount:SaveBook(theItem);
								DropCount.ItemTextFrameHandled=true;		-- Do nothing more
							end
						end
					end
				end
			end
		end
	elseif (DropCount.ItemTextFrameHandled) then
		DropCount.ItemTextFrameHandled=nil;
	end
end

function DropCount.OnUpdate:RunStartup(elapsed)
	if (DropCount.Timer.StartupDelay and DropCount.Timer.StartupDelay>0) then
		DropCount.Timer.StartupDelay=DropCount.Timer.StartupDelay-elapsed;
		if (DropCount.Timer.StartupDelay<=0) then
			DropCount.Timer.StartupDelay=nil;
			Astrolabe:CalculateMinimapIconPositions();
--			DropCount:CleanDB();
			LCDC_RescanQuests=CONST.RESCANQUESTS;
		end
	end
end

function DropCount.OnUpdate:RunQuestScan(elapsed)
	if (LCDC_RescanQuests) then
		LCDC_RescanQuests=LCDC_RescanQuests-elapsed;
		if (LCDC_RescanQuests<0) then
			LCDC_RescanQuests=nil;
			DropCount.Quest:Scan();
			DropCount.Icons.MakeMM:Quest();
		end
	end
end

function DropCount.OnUpdate:WalkOldQuests(elapsed)
	if (not LootCount_DropCount_DB.QuestQuery) then return; end
	if (DropCount.Timer.PrevQuests>=0) then
		DropCount.Timer.PrevQuests=DropCount.Timer.PrevQuests-elapsed;
		return;
	end
	if (DropCount.Timer.PrevQuests<0 and LootCount_DropCount_DB.QuestQuery) then
		local count=nil;
		for qIndex,_ in pairs(LootCount_DropCount_DB.QuestQuery) do
			count=true;
			local qName=DropCount:GetQuestName("quest:"..qIndex);
			if (qName) then
				if (LootCount_DropCount_Character.DoneQuest[qName]) then
					if (type(LootCount_DropCount_Character.DoneQuest[qName])~="table") then
						if (LootCount_DropCount_Character.DoneQuest[qName]~=true) then
							local num=LootCount_DropCount_Character.DoneQuest[qName];
							LootCount_DropCount_Character.DoneQuest[qName]=nil;
							LootCount_DropCount_Character.DoneQuest[qName]={};
							LootCount_DropCount_Character.DoneQuest[qName][num]=true;
							LootCount_DropCount_Character.DoneQuest[qName][qIndex]=true;
						else
							LootCount_DropCount_Character.DoneQuest[qName]=qIndex;
						end
					else
						LootCount_DropCount_Character.DoneQuest[qName][qIndex]=true;
					end
				else
					LootCount_DropCount_Character.DoneQuest[qName]=qIndex;
				end
				LootCount_DropCount_DB.QuestQuery[qIndex]=nil;
				DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests-1;
			else
				if (type(LootCount_DropCount_DB.QuestQuery[qIndex])~="number") then
					LootCount_DropCount_DB.QuestQuery[qIndex]=10;
				else
					LootCount_DropCount_DB.QuestQuery[qIndex]=LootCount_DropCount_DB.QuestQuery[qIndex]-1;
					if (LootCount_DropCount_DB.QuestQuery[qIndex]<0) then
						LootCount_DropCount_DB.QuestQuery[qIndex]=nil;
						DropCount.Tracker.ConvertQuests=DropCount.Tracker.ConvertQuests-1;
					end
				end
			end
			DropCount.Timer.PrevQuests=(1/3);
			break;
		end
		if (not count) then
			LootCount_DropCount_DB.QuestQuery=nil;
			LCDC_RescanQuests=CONST.RESCANQUESTS;
		end
	end
end

--[[
["Young Panther"] {
	Skinning 32
	Kill 26
	Zone Northern Stranglethorn
}
["item:25367:0:0:0:0:0:0"] {
	Item Eroded Mail Boots
	Time 1303003446
	Name {
		Bleeding Hollow Tormentor 1
	}
	Best {
		Location Hellfire Peninsula
		Score 0
	}
}
]]
function DropCount.DB:CleanImport()
	if (not LootCount_DropCount_MergeData.Count) then DropCount.Tracker.CleanImport.Cleaned=true; return; end
	-- DropCount.Tracker.CleanImport.LastMob inits to nil

--if (not DropCount.Tracker.CleanImport.LastMob) then
--	DuckLib:Chat("Cleaning import data starting",.8,.8,1);
--end

	local checkMob,mRaw=next(LootCount_DropCount_MergeData.Count,DropCount.Tracker.CleanImport.LastMob);
	if (not checkMob) then
		if (DropCount.Debug) then
			DuckLib:Chat("Cleaning import data done",.8,.8,1);
			DuckLib:Chat("Deleted: "..DropCount.Tracker.CleanImport.Deleted,.8,.8,1);
			DuckLib:Chat("Okay: "..DropCount.Tracker.CleanImport.Okay,.8,.8,1);
		end
		DropCount.Tracker.CleanImport.Cleaned=true;
		collectgarbage("collect");
		return;
	end
	-- Check for skinned items
	if (self:PreCheck(mRaw,"Skinning")) then
		local nTable=DropCount.DB.Count:Read(checkMob,LootCount_DropCount_MergeData.Count);
		if (nTable and nTable.Skinning and nTable.Skinning>0) then
			for iName,iRaw in pairs(LootCount_DropCount_MergeData.Item) do
				if (self:PreCheck(iRaw,checkMob)) then
					local iTable=DropCount.DB.Item:Read(iName,LootCount_DropCount_MergeData.Item);
					if (iTable and iTable.Skinning and iTable.Skinning[checkMob]) then
						DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;
						DropCount.Tracker.CleanImport.LastMob=checkMob;
						return;		-- Found one, so not very broken
					end
				end
			end

			DropCount:RemoveFromItem("Name",checkMob,LootCount_DropCount_MergeData)
			DropCount:RemoveFromItem("Skinning",checkMob,LootCount_DropCount_MergeData)
			LootCount_DropCount_MergeData.Count[checkMob]=nil;
			DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
			if (DropCount.Debug) then
				DuckLib:Chat("("..DropCount.Tracker.CleanImport.Deleted.."/"..DropCount.Tracker.CleanImport.Deleted+DropCount.Tracker.CleanImport.Okay..") "..DropCount.Tracker.CleanImport.LastMob.." has been deleted from import data.",.8,.8,1);
--				DuckLib:Chat(checkMob.." - Skinning: "..nTable.Skinning.." and no drop",.8,.8,1);
			end
			return;
		end
	end
	-- Check for no-loot items
	if (self:PreCheck(mRaw,"Kill")) then
		local nTable=DropCount.DB.Count:Read(checkMob,LootCount_DropCount_MergeData.Count);
		if (nTable and nTable.Kill and nTable.Kill>4) then
			for iName,iRaw in pairs(LootCount_DropCount_MergeData.Item) do
				if (self:PreCheck(iRaw,checkMob)) then
					local iTable=DropCount.DB.Item:Read(iName,LootCount_DropCount_MergeData.Item);
					if (iTable.Name and iTable.Name[checkMob]) then 
						if (iTable.Name[checkMob]>0) then	-- Not quest-tem
							DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;
							DropCount.Tracker.CleanImport.LastMob=checkMob;
							return;		-- Found one, so not very broken
						end
					end
				end
			end
			DropCount:RemoveFromItem("Name",checkMob,LootCount_DropCount_MergeData)
			DropCount:RemoveFromItem("Skinning",checkMob,LootCount_DropCount_MergeData)
			LootCount_DropCount_MergeData.Count[checkMob]=nil;
			DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
			if (DropCount.Debug) then
				DuckLib:Chat("("..DropCount.Tracker.CleanImport.Deleted.."/"..DropCount.Tracker.CleanImport.Deleted+DropCount.Tracker.CleanImport.Okay..") "..DropCount.Tracker.CleanImport.LastMob.." has been deleted from import data.",.8,.8,1);
--				DuckLib:Chat(checkMob.." - Kill: "..nTable.Kill.." and no drop",.8,.8,1);
			end
			return;
		end
	end
	DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;
	DropCount.Tracker.CleanImport.LastMob=checkMob;
--DuckLib:Chat(checkMob,.8,.8,1);
end

function DropCount.OnUpdate:RunConvertAndMerge(elapsed)
	if (not LootCount_DropCount_DB.Converted or LootCount_DropCount_DB.MergedData<5) then
		LootCount_DropCount_DB.MergedData=5;
		LootCount_DropCount_DB.Converted=7;
		LootCount_DropCount_DB.Vendor={};
		LootCount_DropCount_DB.Book={};
		LootCount_DropCount_DB.Item={};
		LootCount_DropCount_DB.Quest={};
		LootCount_DropCount_DB.Count={};
		collectgarbage("collect");
	elseif (DropCount.Loaded>10) then
--		if (LootCount_DropCount_DB.Converted==7) then
--			DropCount.Convert:One(); return;
--		end
		if (LootCount_DropCount_MergeData and not DropCount.Tracker.ClearMobDrop.item) then
			DropCount.Tracker.Merge.FPS.Frames=DropCount.Tracker.Merge.FPS.Frames+1;
			DropCount.Tracker.Merge.FPS.Time=DropCount.Tracker.Merge.FPS.Time+elapsed;
			if (DropCount.Tracker.Merge.FPS.Time>=CONST.BURSTSIZE) then
				DropCount.Tracker.Merge.FPS.Time=DropCount.Tracker.Merge.FPS.Time-CONST.BURSTSIZE;
				if (DropCount.Tracker.Merge.FPS.Frames>(30*CONST.BURSTSIZE)) then
					DropCount.Tracker.Merge.Burst=DropCount.Tracker.Merge.Burst*1.05;
				elseif (DropCount.Tracker.Merge.FPS.Frames<(25*CONST.BURSTSIZE)) then
					DropCount.Tracker.Merge.Burst=DropCount.Tracker.Merge.Burst/2;
					if (DropCount.Tracker.Merge.Burst<CONST.BURSTSIZE/25) then DropCount.Tracker.Merge.Burst=CONST.BURSTSIZE/25; end
				end
				-- This looks a bit weird, but it will in effect leave a portion
				-- of the last frame to make better use of the average.
				DropCount.Tracker.Merge.FPS.Frames=DropCount.Tracker.Merge.FPS.Time-CONST.BURSTSIZE;
			end

			DropCount.Tracker.Merge.BurstFlow=DropCount.Tracker.Merge.BurstFlow+DropCount.Tracker.Merge.Burst;
			if (DropCount.Tracker.Merge.BurstFlow>=1) then
				if (not DropCount.Tracker.CleanImport.Cleaned) then
					if (DropCount_Local_Code_Enabled) then
						DropCount.DB:CleanImport();
					else
						DropCount.Tracker.CleanImport.Cleaned=true;
					end
				elseif (DropCount:MergeDatabase()) then
					LootCount_DropCount_MergeData=nil;
					collectgarbage("collect");
				end
			end
		end
	end
end

function DropCount:RemoveFromDatabase()
	-- Delete from database
	if (LootCount_DropCount_RemoveData.Quest and LootCount_DropCount_DB.Quest) then
		for faction,fTable in pairs(LootCount_DropCount_RemoveData.Quest) do
			for npc,_ in pairs(fTable) do
				local nTable=DropCount.DB.Quest:Read(faction,npc,LootCount_DropCount_RemoveData.Quest);
				if (not nTable.Quests) then			-- Remove entire NPC
					if (LootCount_DropCount_DB.Quest[faction]) then
						LootCount_DropCount_DB.Quest[faction][npc]=nil;
					end
				else								-- Remove specific quest
					for _,qTable in pairs(nTable.Quests) do
						if (LootCount_DropCount_DB.Quest[faction] and
							LootCount_DropCount_DB.Quest[faction][npc]) then
							local index=1;
							local tempTable=DropCount.DB.Quest:Read(faction,npc);
							local found=nil;
							while (tempTable.Quests[index] and not found) do
								if (tempTable.Quests[index].Quest==qTable.Quest) then
									found=true;
								end
								index=index+1;
							end
							if (found) then
								index=index-1;
								while (tempTable.Quests[index+1]) do
									tempTable.Quests[index]=DuckLib:CopyTable(tempTable.Quests[index+1]);
									index=index+1;
								end
								tempTable.Quests[index]=nil;
								DropCount.DB.Quest:Write(npc,tempTable,faction);
							end
						end
					end
				end
			end
		end
	end
	if (LootCount_DropCount_RemoveData.Count and LootCount_DropCount_DB.Count) then
		for npc,nTable in pairs(LootCount_DropCount_RemoveData.Count) do
			if (LootCount_DropCount_DB.Count[npc]) then
				for entry,_ in pairs(nTable) do
					local mTable=DropCount.DB.Count:Read(npc);
					if (mTable[entry]) then
						mTable[entry]=nil;	-- Kill it
						DropCount.DB.Count:Write(npc,mTable);
						if (entry=="Kill") then entry="Name"; end
						DropCount:RemoveFromItem(entry,npc);
					end
				end
			end
		end
	end

	while (not DropCount:IsEmpty(LootCount_DropCount_RemoveData.Generic)) do
		DropCount:SeekAndDestroy_Start(LootCount_DropCount_RemoveData.Generic,LootCount_DropCount_DB);
	end

	-- Remove qgivers in neutral if it's in horde or alliance as well
	if (LootCount_DropCount_DB.Quest and LootCount_DropCount_DB.Quest.Neutral) then
		for npc,_ in pairs(LootCount_DropCount_DB.Quest.Neutral) do
			for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
				if (faction~="Neutral") then
					if (fData[npc]) then LootCount_DropCount_DB.Quest.Neutral[npc]=nil; end
				end
			end
		end
	end
end

function DropCount:SeekAndDestroy_Start(seekTable,goalTable)
	local access;
	for topLevel,tTable in pairs(seekTable) do
		if (DropCount:IsEmpty(tTable) or not goalTable[topLevel]) then
			seekTable[topLevel]=nil;
			return;
		end
		if (DropCount.DB[topLevel]) then access=DropCount.DB[topLevel];
		else access=DropCount.DB.Generic; end
		for entry,eData in pairs(tTable) do
			if (type(eData)~="table") then
				seekTable[topLevel][entry]=nil;
				goalTable[topLevel][entry]=nil;
				return;
			elseif (DropCount:IsEmpty(eData) or not goalTable[topLevel][entry]) then
				seekTable[topLevel][entry]=nil;
				return;
			end
			local dTable=access:Read(entry,goalTable[topLevel]);
			DropCount:SeekAndDestroy_Seek(tTable[entry],dTable);
			access:Write(entry,dTable);
			return;
		end
	end
end

function DropCount:SeekAndDestroy_Seek(seekTable,goalTable)
	for entry,eData in pairs(seekTable) do
		if (type(eData)~="table") then
			seekTable[entry]=nil;
			goalTable[entry]=nil;					-- Deleted something
			return;
		elseif (DropCount:IsEmpty(eData) or not goalTable[entry]) then
			seekTable[entry]=nil;					-- Book-keeping only
			return;
		end
		DropCount:SeekAndDestroy_Seek(seekTable[entry],goalTable[entry]);
		return;
	end
end

function DropCount:IsEmpty(check)
	if (not check) then return true; end
	for _,_ in pairs(check) do return nil; end
	return true;
end

function DropCount:RemoveFromItem(section,npc,base)
	if (not base) then base=LootCount_DropCount_DB; end
	if (not base.Item) then return; end
	for item,iData in pairs(base.Item) do
		if (string.find(iData,npc,1,true)) then
			local iTable=DropCount.DB.Item:Read(item,base.Item);
			if (iTable[section]) then
				iTable[section][npc]=nil;					-- Kill it
				DropCount.DB.Item:Write(item,iTable,base.Item);
			end
		end
	end
end

function DropCount:MergeStatus(amount)
	if (not amount) then amount=1; end
	DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+amount;
	local pc=math.floor((DropCount.Tracker.Merge.Total/DropCount.Tracker.Merge.Goal)*100);
	if (pc>DropCount.Tracker.Merge.Printed and pc==math.floor(pc/10)*10) then
		DropCount.Tracker.Merge.Printed=pc;
		if (DropCount.Debug) then
			local tex="Merged: "..pc.."%";
			tex=tex..string.format(" (%.2f)",DropCount.Tracker.Merge.Burst);
			DuckLib:Chat(tex,1,.6,.6);
		end
	end
	DropCount.Tracker.Merge.BurstFlow=DropCount.Tracker.Merge.BurstFlow-amount;
	if (DropCount.Tracker.Merge.BurstFlow<=0) then return nil; end
	return true;
end

function DropCount.Convert:Seven()
	local f1,f2=nil,nil;
	if (LootCount_DropCount_DB.Quest and LootCount_DropCount_DB.Quest.Neutral) then
		for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
			if (faction~="Neutral") then
				if (not f1) then f1=faction;
				elseif (not f2) then f2=faction; end
			end
		end
		for npc,nData in pairs(LootCount_DropCount_DB.Quest.Neutral) do
			if (not LootCount_DropCount_DB.Quest[f1][npc]) then
				LootCount_DropCount_DB.Quest[f1][npc]=nData;
			end
			if (not LootCount_DropCount_DB.Quest[f2][npc]) then
				LootCount_DropCount_DB.Quest[f2][npc]=nData;
			end
		end
		LootCount_DropCount_DB.Quest.Neutral=nil;
	end
	if (LootCount_DropCount_DB.Converted==6) then
		LootCount_DropCount_DB.Converted=7;
		collectgarbage("collect");
	end
end

function DropCount:MergeDatabase()
	if (not LootCount_DropCount_MergeData) then return true; end
	if (not LootCount_DropCount_DB.MergedData) then LootCount_DropCount_DB.MergedData=0; end
	if (LootCount_DropCount_MergeData.Version==LootCount_DropCount_DB.MergedData) then return true; end

	if (DropCount.Tracker.Merge.Total==-1) then
		DropCount.Tracker.Merge.Total=0;
		DropCount.Tracker.Merge.Goal=0;
		DropCount.Tracker.Merge.Printed=-1;
		for _,_ in pairs(LootCount_DropCount_MergeData.Vendor) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; end
		for _,_ in pairs(LootCount_DropCount_MergeData.Count) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; end
		for _,_ in pairs(LootCount_DropCount_MergeData.Item) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; end
		for _,bT in pairs(LootCount_DropCount_MergeData.Book) do
			for _,_ in pairs(bT) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; end
		end
		for _,qT in pairs(LootCount_DropCount_MergeData.Quest) do
			for _,_ in pairs(qT) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; end
		end
		if (DropCount.Tracker.Merge.Goal>0) then
			DuckLib:Chat(LOOTCOUNT_DROPCOUNT_VERSIONTEXT,1,.3,.3);
			DuckLib:Chat("There are "..DropCount.Tracker.Merge.Goal.." entries to merge with your database.",1,.6,.6);
			DuckLib:Chat("A summary will be presented when the process is done.",1,.6,.6);
			DuckLib:Chat("This will take a few minutes, depending on the speed of your computer.",1,.6,.6);
			DuckLib:Chat("You can play WoW while this is running is the background, even thought you may experience some lag.",1,.6,.6);
		end
	end

	-- Vendors
	if (LootCount_DropCount_MergeData.Vendor) then
		if (self:IsEmpty(LootCount_DropCount_MergeData.Vendor)) then
			LootCount_DropCount_MergeData.Vendor=nil;
			return;
		end
		if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end
		for vend,_ in pairs(LootCount_DropCount_MergeData.Vendor) do
			local vTable=DropCount.DB.Vendor:Read(vend,LootCount_DropCount_MergeData.Vendor);
			local faction=vTable.Faction;
			if (not faction) then
				_,_,_,faction,_=DropCount.DB.Vendor:ReadBaseData(vend);
				if (not faction) then faction="Unknown"; end			-- Unknown faction
			end
			if (not DropCount.Tracker.Merge.Vendor.New[faction]) then DropCount.Tracker.Merge.Vendor.New[faction]=0; end
			if (not DropCount.Tracker.Merge.Vendor.Updated[faction]) then DropCount.Tracker.Merge.Vendor.Updated[faction]=0; end
			if (not LootCount_DropCount_DB.Vendor[vend]) then
				DropCount.DB.Vendor:Write(vend,vTable);
				DropCount.Tracker.Merge.Vendor.New[faction]=DropCount.Tracker.Merge.Vendor.New[faction]+1;
			else
				local updated=nil;
				local tv=DropCount.DB.Vendor:Read(vend);
				if (not vTable.X or not vTable.Y) then vTable.X=0; vTable.Y=0; end
				if (vTable.X>0 or vTable.Y>0) then
					if (math.floor(tv.X)~=math.floor(vTable.X) or
						math.floor(tv.Y)~=math.floor(vTable.Y) or
						tv.Zone~=vTable.Zone) then
						updated=true;
					end
					tv.X=vTable.X; tv.Y=vTable.Y; tv.Zone=vTable.Zone;
					if (vTable.Faction) then tv.Faction=vTable.Faction; end
					if (vTable.Map) then tv.Map=vTable.Map; end
				end
				if (vTable.Items) then
					if (not tv.Items) then
						tv.Items=DuckLib:CopyTable(vTable.Items);
						updated=true;
					else
						for item,iTable in pairs(vTable.Items) do
							if (not tv.Items[item]) then
								tv.Items[item]=DuckLib:CopyTable(iTable);
								updated=true;
							else
								if (iTable.Count~=-2 and tv.Items[item].Count==-2) then
									tv.Items[item].Count=iTable.Count;
									updated=true;
								end
							end
						end
					end
				end
				if (updated) then
					DropCount.Tracker.Merge.Vendor.Updated[faction]=DropCount.Tracker.Merge.Vendor.Updated[faction]+1;
					DropCount.DB.Vendor:Write(vend,tv);
				end
			end
			LootCount_DropCount_MergeData.Vendor[vend]=nil;	-- Done this vendor
			if (not DropCount:MergeStatus()) then return; end
		end
	end

	-- Books
	if (LootCount_DropCount_MergeData.Book) then
		if (self:IsEmpty(LootCount_DropCount_MergeData.Book)) then
			LootCount_DropCount_MergeData.Book=nil;
			return;
		end
		if (not LootCount_DropCount_DB.Book) then LootCount_DropCount_DB.Book={}; end
		for title,bTable in pairs(LootCount_DropCount_MergeData.Book) do
			local newB,updB=nil,nil;
			for index,vTable in pairs(bTable) do
				local newT,updT=DropCount:SaveBook(title,vTable.Zone,vTable.X,vTable.Y,vTable.Map);
				if (not newB) then
					if (newT>0) then newB=true; updB=nil;
					elseif (updT) then updB=true; end
				end
			end
			if (newB) then DropCount.Tracker.Merge.Book.New=DropCount.Tracker.Merge.Book.New+1; end
			if (updB) then DropCount.Tracker.Merge.Book.Updated=DropCount.Tracker.Merge.Book.Updated+1; end
			LootCount_DropCount_MergeData.Book[title]=nil;	-- Done this volume
			if (not DropCount:MergeStatus()) then return; end
		end
	end

	-- Quests
	if (LootCount_DropCount_MergeData.Quest) then
		if (self:IsEmpty(LootCount_DropCount_MergeData.Quest)) then
			LootCount_DropCount_MergeData.Quest=nil;
			return;
		end
		if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
		-- Traverse hardcoded
		for faction,fTable in pairs(LootCount_DropCount_MergeData.Quest) do
			if (not LootCount_DropCount_DB.Quest[faction]) then
				-- Don't have this faction, so take all.
				LootCount_DropCount_DB.Quest[faction]=DuckLib:CopyTable(fTable);
			else
				DropCount.Tracker.Merge.Quest.New[faction]=0;
				DropCount.Tracker.Merge.Quest.Updated[faction]=0;
				-- Traverse hardcoded npcs in this faction
				for npc,nEntry in pairs(fTable) do
					local nTable=DropCount.DB.Quest:Read(faction,npc,LootCount_DropCount_MergeData.Quest);
					if (not LootCount_DropCount_DB.Quest[faction][npc]) then
						-- Don't have it, so take all
						DropCount.DB.Quest:Write(npc,nTable,faction);
						DropCount.Tracker.Merge.Quest.New[faction]=DropCount.Tracker.Merge.Quest.New[faction]+1;
					else
						local updated=nil;
						-- Have it, so update location and merge quests
						local tn=DropCount.DB.Quest:Read(faction,npc);
						tn.X=nTable.X; tn.Y=nTable.Y;
						if (nTable.Map) then tn.Map=nTable.Map; end
						tn.Zone=nTable.Zone;
						if (not tn.Quests) then tn.Quests={}; end
						local fromIndex=1;
						while (nTable.Quests[fromIndex]) do
							local toIndex=1;
							while (tn.Quests[toIndex]) do
								if (type(tn.Quests[toIndex])~="table") then return; end
								if (tn.Quests[toIndex].Quest==nTable.Quests[fromIndex].Quest) then
									if (nTable.Quests[fromIndex].Header and not tn.Quests[toIndex].Header) then
										tn.Quests[toIndex].Header=nTable.Quests[fromIndex].Header;
									end
									toIndex=1000;		-- It is already here
								end
								toIndex=toIndex+1;
							end
							-- Check if it was already there or not
							if (toIndex<1000) then
								tn.Quests[toIndex]=DuckLib:CopyTable(nTable.Quests[fromIndex]);
								updated=true;
							end
							fromIndex=fromIndex+1;
						end
						if (updated) then
							DropCount.DB.Quest:Write(npc,tn,faction);
							DropCount.Tracker.Merge.Quest.Updated[faction]=DropCount.Tracker.Merge.Quest.Updated[faction]+1;
						end
					end
					LootCount_DropCount_MergeData.Quest[faction][npc]=nil;
					if (not DropCount:MergeStatus()) then return; end
				end
			end
		end
	end
	DropCount.Convert:Seven();

	-- Merge drops
	if (LootCount_DropCount_MergeData.Count and LootCount_DropCount_MergeData.Item) then
		if (self:IsEmpty(LootCount_DropCount_MergeData.Count)) then
			LootCount_DropCount_MergeData.Count=nil;
			return;
		end
		local strict=nil; if (LootCount_DropCount_DB.MergedData==4) then strict=true; end
		if (not LootCount_DropCount_DB.Count) then LootCount_DropCount_DB.Count={}; end
		if (not LootCount_DropCount_DB.Item) then LootCount_DropCount_DB.Item={}; end
		for mob,mTable in pairs(LootCount_DropCount_MergeData.Count) do
			local newMob,updatedMob=DropCount:MergeMOB(mob,strict);
			if (newMob<0) then return; end
			DropCount.Tracker.Merge.Mob.New=DropCount.Tracker.Merge.Mob.New+newMob;
			DropCount.Tracker.Merge.Mob.Updated=DropCount.Tracker.Merge.Mob.Updated+updatedMob;
			LootCount_DropCount_MergeData.Count[mob]=nil;
			if (not DropCount:MergeStatus()) then return; end
		end
	end

	-- Merge best areas
	if (LootCount_DropCount_MergeData.Item and LootCount_DropCount_DB.Item) then
		if (self:IsEmpty(LootCount_DropCount_MergeData.Item)) then
			LootCount_DropCount_MergeData.Item=nil;
			return;
		end
		for item,iData in pairs(LootCount_DropCount_MergeData.Item) do
			if (LootCount_DropCount_DB.Item[item]) then
				local miData=DropCount.DB.Item:Read(item,LootCount_DropCount_MergeData.Item);
				if (miData and miData.Best) then
					local store=nil;
					local saveit=nil;
					local liData=DropCount.DB.Item:Read(item);
					if (liData) then
						if (not liData.Best) then store=true;
						else
							if (liData.Best.Location==miData.Best.Location) then store=true; end
							if (miData.Best.Score>liData.Best.Score) then store=true; end
						end
						if (store) then liData.Best=miData.Best; saveit=true; store=nil; end
						if (not liData.BestW) then store=true;
						elseif (miData.BestW) then
							if (liData.BestW.Location==miData.BestW.Location) then store=true; end
							if (miData.BestW.Score>liData.BestW.Score) then store=true; end
						end
						if (store) then liData.BestW=miData.BestW; saveit=true; store=nil; end
						if (liData.Best and liData.BestW) then
							if (liData.BestW.Score>=liData.Best.Score) then
								liData.Best=liData.BestW;
								liData.BestW=nil;
								saveit=true;
							end
						end
						if (saveit) then
							DropCount.DB.Item:Write(item,liData);
							DropCount.Tracker.Merge.Item.Updated=DropCount.Tracker.Merge.Item.Updated+1;
						end
					end
				end
			end
			LootCount_DropCount_MergeData.Item[item]=nil;
			if (not DropCount:MergeStatus()) then return; end
		end
	end

	-- Maps
	if (LootCount_DropCount_Maps) then		-- I have maps
		for Lang,LTable in pairs(LootCount_DropCount_Maps) do		-- Check all locales I have
			if (LootCount_DropCount_MergeData.Maps[Lang]) then		-- Hardcoded has same locale
				-- Blend tables
				LootCount_DropCount_Maps[Lang]=DuckLib:CopyTable(LootCount_DropCount_MergeData.Maps[Lang],LootCount_DropCount_Maps[Lang])
			end
		end
	end

	-- Output result
	LootCount_DropCount_DB.MergedData=LootCount_DropCount_MergeData.Version;
	local text="";
	-- mobs
	if (DropCount.Tracker.Merge.Mob.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Mob.New.." new mobs"; end
	if (DropCount.Tracker.Merge.Mob.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Mob.Updated.." updated mobs"; end
	-- Vendors
	local amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Vendor.New) do amount=amount+fValue; end
	if (amount>0) then text=text.."\n"..amount.." new vendors"; end
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Vendor.Updated) do amount=amount+fValue; end
	if (amount>0) then text=text.."\n"..amount.." updated vendors"; end
	-- Quests
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Quest.New) do amount=amount+fValue; end
	if (amount>0) then text=text.."\n"..amount.." new quest-givers"; end
	amount=0;
	for faction,fValue in pairs(DropCount.Tracker.Merge.Quest.Updated) do amount=amount+fValue; end
	if (amount>0) then text=text.."\n"..amount.." updated quest-givers"; end
	-- Books
	if (DropCount.Tracker.Merge.Book.New>0) then text=text.."\n"..DropCount.Tracker.Merge.Book.New.." new books"; end
	if (DropCount.Tracker.Merge.Book.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Book.Updated.." updated books"; end
	-- Items
	if (DropCount.Tracker.Merge.Item.Updated>0) then text=text.."\n"..DropCount.Tracker.Merge.Item.Updated.." updated items"; end

	DuckLib:Chat("Your DropCount database has been updated.",1,.6,.6);
	if (string.len(text)>0) then
		text=LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."\nData merge summary:\n"..text;
		StaticPopupDialogs["LCDC_D_NOTIFICATION"].text=text;
		StaticPopup_Show("LCDC_D_NOTIFICATION");
	end

	DropCount.Icons.MakeMM:Vendor();
	DropCount.Icons.MakeMM:Book();
	DropCount.Icons.MakeMM:Quest();

	DuckLib.Table:PurgeCache(DM_WHO)

	return true;
end

function DropCount.DB:PreCheck(raw,contents)
	if (type(raw)=="string") then
		if (not raw:find(contents,1,true)) then return nil; end
	end
	return true;
end

function DropCount:ClearMobDrop(mob,section)
	for item,iRaw in pairs(LootCount_DropCount_DB.Item) do
		self:RemoveMobFromItem(item,iRaw,mob,section);
	end
end

-- The call next(t, k), where k is a key of the table t, returns a next
-- key in the table, in an arbitrary order. (It returns also the value
-- associated with that key, as a second return value.)
-- The call next(t, nil) returns a first pair. When there are no more
-- pairs, next returns nil.
function DropCount:ClearMobDropMT(amount,mob,section)
	local init=nil;
	if (not DropCount.Tracker.ClearMobDrop.item) then
		DropCount.Tracker.ClearMobDrop.mob=mob;
		DropCount.Tracker.ClearMobDrop.section=section;
		init=true;
	end
	local count=0;
	while (count<amount and (DropCount.Tracker.ClearMobDrop.item or init)) do
		init=nil;
		local iRaw;
		DropCount.Tracker.ClearMobDrop.item,iRaw=
				next(LootCount_DropCount_DB.Item,DropCount.Tracker.ClearMobDrop.item);
		if (DropCount.Tracker.ClearMobDrop.item) then
			DropCount:RemoveMobFromItem(	DropCount.Tracker.ClearMobDrop.item,
											iRaw,
											DropCount.Tracker.ClearMobDrop.mob,
											DropCount.Tracker.ClearMobDrop.section);
		end
		count=count+1;
	end

	if (not DropCount.Tracker.ClearMobDrop.item) then
		local i=10;
		while (i>1) do
			DropCount.Tracker.ClearMobDrop.Done[i].mob=DropCount.Tracker.ClearMobDrop.Done[i-1].mob;
			DropCount.Tracker.ClearMobDrop.Done[i].section=DropCount.Tracker.ClearMobDrop.Done[i-1].section;
			i=i-1;
		end
		DropCount.Tracker.ClearMobDrop.Done[1].mob=DropCount.Tracker.ClearMobDrop.mob;
		DropCount.Tracker.ClearMobDrop.Done[1].section=DropCount.Tracker.ClearMobDrop.section;
	end
end

function DropCount:RemoveMobFromItem(item,iRaw,mob,section)
	if (DropCount.DB:PreCheck(iRaw,mob)) then
		local iTable=DropCount.DB.Item:Read(item);
		if (iTable[section] and iTable[section][mob]) then
			iTable[section][mob]=nil;
			DropCount.DB.Item:Write(item,iTable);
		end
	end
end


function DropCount:IsMobDropCleared(mob,section)
	for _,mData in pairs(DropCount.Tracker.ClearMobDrop.Done) do
		if (mData.mob and mData.mob==mob and mData.section==section) then return true; end
	end
	return nil;
end


-- Check mobs and insert anything that is missing
-- IMPORTANT: Do not merge counts! Only insert missing!
--
-- o Check if new data has more kills/skinnings than me
--   If I don't have it at all, mine is set up as zero.
function DropCount:MergeMOB(mob,strict)
	local newMob,updatedMob=0,0;
	local kill,skinning=nil,nil;
	local tester;

	local mData=DropCount.DB.Count:Read(mob,LootCount_DropCount_MergeData.Count);
	local cData=DropCount.DB.Count:Read(mob,LootCount_DropCount_DB.Count);
	-- Create the mob if it doesn't exist
	if (not cData) then
		cData=DuckLib:CopyTable(mData);
		cData.Kill=nil;
		cData.Skinning=nil;
		newMob=1;
	end
	-- Merge kills
	if (mData.Kill) then
		if (not cData.Kill) then
			cData.Kill=0;
		end
		tester=cData.Kill; if (strict) then tester=tester-1; end
		if (mData.Kill>tester) then
			if (not self:IsMobDropCleared(mob,"Name")) then
				self:ClearMobDropMT(DropCount.Tracker.ClearMobDrop.amount,mob,"Name");	-- New (and higher) count, so remove old drops
				return -1;
			end
			kill=mData.Kill;
			cData.Kill=kill;
			if (newMob==0) then updatedMob=1; end
		end
	end
	-- Merge skinning (all professions)
	if (mData.Skinning) then
		if (not cData.Skinning) then
			cData.Skinning=0;
		end
		tester=cData.Skinning; if (strict) then tester=tester-1; end
		if (mData.Skinning>tester) then
			if (not self:IsMobDropCleared(mob,"Skinning")) then
				self:ClearMobDropMT(DropCount.Tracker.ClearMobDrop.amount,mob,"Skinning");
				return -1;
			end
			skinning=mData.Skinning;
			cData.Skinning=skinning;
			if (newMob==0) then updatedMob=1; end
		end
	end

	-- Traverse hardcoded items
	-- Do normal kill/loot
	if (kill) then
		for item,iRaw in pairs(LootCount_DropCount_MergeData.Item) do
			if (DropCount.DB:PreCheck(iRaw,mob)) then
				local iTable=DropCount.DB.Item:Read(item,LootCount_DropCount_MergeData.Item);
				if (iTable.Name and iTable.Name[mob]) then	-- Exists in source
					local miTable;
					if (not LootCount_DropCount_DB.Item[item]) then		-- Unknown item in target
						miTable=DuckLib:CopyTable(iTable);	-- Copy item to target
						if (miTable.Name) then wipe(miTable.Name); end			-- Remove mobs
						if (miTable.Skinning) then wipe(miTable.Skinning); end	-- Remove mobs
					else
						miTable=DropCount.DB.Item:Read(item);
					end
					if (not miTable.Name) then miTable.Name={}; end		-- Make it if not there
					miTable.Name[mob]=iTable.Name[mob];					-- Insert this mob
					if (iTable.Best) then				-- Incoming contains this info
						local store=nil;
						if (not miTable.Best) then store=true;
						else
							if (iTable.Best.Score>miTable.Best.Score or miTable.Best.Zone==iTable.Best.Location) then store=true; end
						end
						if (store) then
							miTable.Best={ Location=iTable.Best.Location, Score=iTable.Best.Score };
						end
					end
					if (iTable.Quest) then			-- Merge quest data, if any
						miTable.Quest=DuckLib:CopyTable(iTable.Quest,miTable.Quest);
					end
					DropCount.DB.Item:Write(item,miTable);				-- Copy item to target
				end
			end
		end
	end
	-- Do profession-loot
	if (skinning) then
		for item,iRaw in pairs(LootCount_DropCount_MergeData.Item) do
			if (DropCount.DB:PreCheck(iRaw,mob)) then
				local iTable=DropCount.DB.Item:Read(item,LootCount_DropCount_MergeData.Item);
				if (iTable.Skinning and iTable.Skinning[mob]) then	-- Exists in source
					local miTable;
					if (not LootCount_DropCount_DB.Item[item]) then		-- Unknown item in target
						miTable=DuckLib:CopyTable(iTable);	-- Copy item to target
						if (miTable.Name) then wipe(miTable.Name); end			-- Remove mobs
						if (miTable.Skinning) then wipe(miTable.Skinning); end	-- Remove mobs
					else
						miTable=DropCount.DB.Item:Read(item);
					end
					if (not miTable.Skinning) then	-- Check for mob-list
						miTable.Skinning={};			-- Make it if not there
					end
					miTable.Skinning[mob]=iTable.Skinning[mob];	-- Insert this mob
					if (iTable.Best) then				-- Incoming contains this info
						local store=nil;
						if (not miTable.Best) then store=true;
						else
							if (iTable.Best.Score>miTable.Best.Score or miTable.Best.Zone==iTable.Best.Location) then store=true; end
						end
						if (store) then
							miTable.Best={ Location=iTable.Best.Location, Score=iTable.Best.Score };
						end
					end
					if (iTable.Quest) then			-- Merge quest data, if any
						miTable.Quest=DuckLib:CopyTable(iTable.Quest,miTable.Quest);
					end
					DropCount.DB.Item:Write(item,miTable);				-- Copy item to target
				end
			end
		end
	end

	if (not cData.Kill and not cData.Skinning) then cData=nil; end
	DropCount.DB.Count:Write(mob,cData);

	return newMob,updatedMob;
end

function DropCount.Menu:AddHeader(text,icon)
	local info=UIDropDownMenu_CreateInfo();
	info.text=CONST.C_LBLUE..text;
	info.icon=icon;
	UIDropDownMenu_AddButton(info,1);
end
function DropCount.Menu:AddChecker(text,value,func,icon)
	local info=UIDropDownMenu_CreateInfo();
	info.text=CONST.C_BASIC..text;
	if (value) then info.text=info.text..CONST.C_GREEN.."ON"; else info.text=info.text..CONST.C_RED.."OFF"; end
	info.func=func;
	info.icon=icon;
	UIDropDownMenu_AddButton(info,1);
end
function DropCount.Menu:AddButton(text,func,icon)
	local info=UIDropDownMenu_CreateInfo();
	info.text=CONST.C_BASIC..text;
	info.func=func;
	info.icon=icon;
	UIDropDownMenu_AddButton(info,1);
end

function DropCountXML.Menu.MinimapInitialise()
	DropCount.Menu:AddHeader("GUI");
	DropCount.Menu:AddButton("Open search-window",DropCount.Menu.OpenSearchWindow,"");

	DropCount.Menu:AddHeader(" ");
	DropCount.Menu:AddHeader("Minimap");
	DropCount.Menu:AddChecker("Vendors: ",LootCount_DropCount_DB.VendorMinimap,DropCount.Menu.ToggleVendorsMinimap,"Interface\\GROUPFRAME\\UI-Group-MasterLooter");
	DropCount.Menu:AddChecker("Repair: ",LootCount_DropCount_DB.RepairMinimap,DropCount.Menu.ToggleRepairMinimap,"Interface\\GossipFrame\\VendorGossipIcon");
	DropCount.Menu:AddChecker("Books: ",LootCount_DropCount_DB.BookMinimap,DropCount.Menu.ToggleBookMinimap,"Interface\\Spellbook\\Spellbook-Icon");
	DropCount.Menu:AddChecker("Quests: ",LootCount_DropCount_DB.QuestMinimap,DropCount.Menu.ToggleQuestMinimap,"Interface\\QuestFrame\\UI-Quest-BulletPoint");

	DropCount.Menu:AddHeader(" ");
	DropCount.Menu:AddHeader("Worldmap");
	DropCount.Menu:AddChecker("Vendors: ",LootCount_DropCount_DB.VendorWorldmap,DropCount.Menu.ToggleVendorsWorldmap,"Interface\\GROUPFRAME\\UI-Group-MasterLooter");
	DropCount.Menu:AddChecker("Repair: ",LootCount_DropCount_DB.RepairWorldmap,DropCount.Menu.ToggleRepairWorldmap,"Interface\\GossipFrame\\VendorGossipIcon");
	DropCount.Menu:AddChecker("Books: ",LootCount_DropCount_DB.BookWorldmap,DropCount.Menu.ToggleBookWorldmap,"Interface\\Spellbook\\Spellbook-Icon");
	DropCount.Menu:AddChecker("Quests: ",LootCount_DropCount_DB.QuestWorldmap,DropCount.Menu.ToggleQuestWorldmap,"Interface\\QuestFrame\\UI-Quest-BulletPoint");
end

function DropCount.Menu.ToggleRepairMinimap()
	if (LootCount_DropCount_DB.RepairMinimap) then LootCount_DropCount_DB.RepairMinimap=nil;
	else LootCount_DropCount_DB.RepairMinimap=true; end
	DropCount.Icons.MakeMM:Vendor();
end
function DropCount.Menu.ToggleRepairWorldmap()
	if (LootCount_DropCount_DB.RepairWorldmap) then LootCount_DropCount_DB.RepairWorldmap=nil;
	else LootCount_DropCount_DB.RepairWorldmap=true; end
	DropCount.Icons.MakeWM:Vendor();
	DropCount.Icons:Plot();
end
function DropCount.Menu.ToggleVendorsMinimap()
	if (LootCount_DropCount_DB.VendorMinimap) then LootCount_DropCount_DB.VendorMinimap=nil;
	else LootCount_DropCount_DB.VendorMinimap=true; end
	DropCount.Icons.MakeMM:Vendor();
end
function DropCount.Menu.ToggleVendorsWorldmap()
	if (LootCount_DropCount_DB.VendorWorldmap) then LootCount_DropCount_DB.VendorWorldmap=nil;
	else LootCount_DropCount_DB.VendorWorldmap=true; end
	DropCount.Icons.MakeWM:Vendor();
	DropCount.Icons:Plot();
end
function DropCount.Menu.ToggleBookMinimap()
	if (LootCount_DropCount_DB.BookMinimap) then LootCount_DropCount_DB.BookMinimap=nil;
	else LootCount_DropCount_DB.BookMinimap=true; end
	DropCount.Icons.MakeMM:Book();
end
function DropCount.Menu.ToggleBookWorldmap()
	if (LootCount_DropCount_DB.BookWorldmap) then LootCount_DropCount_DB.BookWorldmap=nil;
	else LootCount_DropCount_DB.BookWorldmap=true; end
	DropCount.Icons.MakeWM:Book();
	DropCount.Icons:Plot();
end
function DropCount.Menu.ToggleQuestMinimap()
	if (LootCount_DropCount_DB.QuestMinimap) then LootCount_DropCount_DB.QuestMinimap=nil;
	else LootCount_DropCount_DB.QuestMinimap=true; end
	DropCount.Icons.MakeMM:Quest();
end
function DropCount.Menu.ToggleQuestWorldmap()
	if (LootCount_DropCount_DB.QuestWorldmap) then LootCount_DropCount_DB.QuestWorldmap=nil;
	else LootCount_DropCount_DB.QuestWorldmap=true; end
	DropCount.Icons.MakeWM:Quest();
	DropCount.Icons:Plot();
end
function DropCount.Menu.OpenSearchWindow()
	LCDC_VendorSearch:Show();
end

--[[	Minimap icon stuff	]]
function DropCountXML.MinimapOnEnter(frame)
	GameTooltip:SetOwner(frame,"ANCHOR_LEFT");
	GameTooltip:SetText("DropCount");
	GameTooltipTextLeft1:SetTextColor(0,1,0);
	GameTooltip:LCAddLine(LOOTCOUNT_DROPCOUNT_VERSIONTEXT);
	GameTooltip:LCAddLine(CONST.C_BASIC.."<Left-click>|r for menu");
	GameTooltip:LCAddLine(CONST.C_BASIC.."<Right-click>|r and drag to move");
	GameTooltip:LCAddLine(CONST.C_BASIC.."<Shift-right-click>|r and drag for free-move");
	if (DropCount.Registered) then
		GameTooltip:LCAddLine(CONST.C_BASIC.."LootCount: "..CONST.C_GREEN.."Present");
	end
	GameTooltip:Show();
end

function DropCountXML.MinimapOnClick(frame)
	ToggleDropDownMenu(1,nil,DropCount.Menu.Minimap,frame:GetParent(),0,0);
end

-- Thanks to Yatlas and Gello for the initial code
function DropCountXML.MinimapBeingDragged()
	-- Thanks to Gello for this code
	local xpos,ypos=GetCursorPosition();
	local xmin,ymin=Minimap:GetLeft(),Minimap:GetBottom();

	if (IsShiftKeyDown()) then
		LootCount_DropCount_DB.IconPosition=nil;
		xpos=(xpos/UIParent:GetScale()-xmin)-16;
		ypos=(ypos/UIParent:GetScale()-ymin)+16;
		DropCount:MinimapSetIconAbsolute(xpos,ypos);
		return;
	end
	LootCount_DropCount_DB.IconX=nil;
	LootCount_DropCount_DB.IconY=nil;

	xpos=xmin-xpos/UIParent:GetScale()+70
	ypos=ypos/UIParent:GetScale()-ymin-70

	DropCount:MinimapSetIconAngle(math.deg(math.atan2(ypos,xpos)));
end

function DropCount:MinimapSetIconAngle(v)
	if (v<0) then v=v+360; end
	if (v>=360) then v=v-360; end

	LootCount_DropCount_DB.IconPosition=v;
	DropCount_MinimapIcon:SetPoint("TOPLEFT","Minimap","TOPLEFT",54-(78*cos(LootCount_DropCount_DB.IconPosition)),(78*sin(LootCount_DropCount_DB.IconPosition))-55);
	DropCount_MinimapIcon:Show();
end

function DropCount:MinimapSetIconAbsolute(x,y)
	LootCount_DropCount_DB.IconX=x;
	LootCount_DropCount_DB.IconY=y;
	DropCount_MinimapIcon:SetPoint("TOPLEFT","Minimap","BOTTOMLEFT",x,y);
end

DropCountXML.CA=DropCount.Cache.AddItem;
DropCountXML.RV=DropCount.DB.Vendor.Read;
DropCountXML.WV=DropCount.DB.Vendor.Write;
