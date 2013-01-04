--[[****************************************************************
	LootCount DropCount v1.40

	Author: Evil Duck
	****************************************************************

	For the game World of Warcraft
	Stand-alone addon, and plug-in for the add-on LootCount.

	****************************************************************]]

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


-- TODO (? Maybe, ! Important, - Normal (not done), + Done)
-- - Walk quests and remove same ID quests from items when mobs have them.


-- CATACLYSM
-- http://forums.worldofwarcraft.com/thread.html?topicId=25626580975&sid=1
-- - Optional include of supplied database


local debugtimerthing,debugtimerthingbig=0,0;

local _;
LOOTCOUNT_DROPCOUNT_VERSIONTEXT = "DropCount v1.40";
LOOTCOUNT_DROPCOUNT = "DropCount";
SLASH_DROPCOUNT1 = "/dropcount";
SLASH_DROPCOUNT2 = "/lcdc";
local DM_WHO="LCDC";

--DropCount={			-- profiling
local DropCount={		-- release
	Loaded=nil,
	Debug=nil,
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
	Crawler={},
	MT={
		Icons={},
		DB={
			Maintenance={},
		},
	},
	Quest={
		LastScan={},
	},
	DB={
		Vendor={ Fast={} },
		Quest={ Fast={ MD={}, } },
		Count={ Fast={ MD={}, } },
		Item={ Fast={ MD={}, } },
		Forge={ Fast={ MD={}, } },
		Trainer={ Fast={ MD={}, } },
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
		Elapsed=0,
		Exited=true,
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
			Forge={ New=0, Updated=0, },
			Trainer={ New={}, Updated={}, },
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
--			LastMob=nil,
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
	WoW5={},
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
	PROFICON={},
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

-- Table handling
-- v1
local Table={
	Scrap={},
	Default={
		Default={
			UseCache=true,
			Base=nil,
		},
	},
	CV=2,
	[1]={
		Entry ="\1",			--  prints as pipe after 4.3
			String="\1\1",
			Number="\1\2",
			Bool  ="\1\3",
			Nil   ="\1\4",
			Other ="\1\9",
		sTable="\2",			-- 
		eTable="\3",			-- 
		Version="\4",			-- 
			ThisVersion="1",
		Last="\4",
	},
	[2]={
		Entry ="\2",			-- 
			String="\2\7",
			Number="\2\2",
			Bool  ="\2\3",
			Nil   ="\2\4",
			Other ="\2\9",
		sTable="\3",			-- 
		eTable="\4",			-- 
		Version="\7",			--
			ThisVersion="2",
		Last="\7",
	},
	-- Same as last active
	Entry ="\2",			-- 
		String="\2\7",
		Number="\2\2",
		Bool  ="\2\3",
		Nil   ="\2\4",
		Other ="\2\9",
	sTable="\3",			-- 
	eTable="\4",			-- 
	Version="\7",
		ThisVersion="2",
	Last="\7",
};
-- Broken in WoW 4.3:
-- \1 \6

local MT={
	LastStack="",
	Current=0,
	Count=0,
	Speed=(1/30)*1000,
--	Speed=(1/30),			-- regular, noticable by user
	FastMT=(1/100)*1000,	-- adaptable, virtually un-noticable
--	FastMT=(1/100),			-- adaptable, virtually un-noticable
	LastTime=0,
	Threads={
	},
};


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
	Forge={},
	Trainer={},
};
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

	CONST.PROFESSIONS[1],_,CONST.PROFICON[1]=GetSpellInfo(8613);	-- Skinning
	CONST.PROFESSIONS[2],_,CONST.PROFICON[2]=GetSpellInfo(2366);	-- Herb gathering
	CONST.PROFESSIONS[3],_,CONST.PROFICON[3]=GetSpellInfo(2575);	-- Mining
	CONST.PROFESSIONS[4],_,CONST.PROFICON[4]=GetSpellInfo(49383);	-- Salvaging
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

	if (not MT.TheFrameWorldMap) then
		MT.TheFrameWorldMap=CreateFrame("Frame","DropCount-MT-WM-Messager",WorldMapDetailFrame);
		if (not MT.TheFrameWorldMap) then
			DropCount:Chat("Could not create a DuckMod frame (2)",1);
			return;
		end
	end
	MT.TheFrameWorldMap:SetScript("OnUpdate",DropCountXML.HeartBeat);
end

-- There's slashing to be done
function DropCountXML.Slasher(msg)
	if (not msg) then msg=""; end
	local fullmsg=msg;
	if (strlen(msg)>0) then msg=strlower(msg); end

	if (msg=="guild") then
		LootCount_DropCount_DB.GUILD=true;
		LootCount_DropCount_DB.RAID=nil;
		DropCount:Chat("DropCount: Sharing data with guild");
		return;
	elseif (msg=="raid" or msg=="group") then
		LootCount_DropCount_DB.GUILD=nil;
		LootCount_DropCount_DB.RAID=true;
		DropCount:Chat("DropCount: Sharing data with party/raid");
		return;
	elseif (msg=="noshare") then
		LootCount_DropCount_DB.GUILD=nil;
		LootCount_DropCount_DB.RAID=nil;
		DropCount:Chat("DropCount: Data-sharing OFF");
		return;
	elseif (msg=="zone") then
		DropCount.Menu.ToggleZoneMobs()
		if (LootCount_DropCount_Character.ShowZoneMobs) then
			DropCount:Chat("DropCount: Showing drop-data from current zone only");
		else
			DropCount:Chat("DropCount: Showing drop-data from all zones");
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
					DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Information not available for this item. A link or itemID is required.");
					DropCount.Search.Item=nil;
					return;
				end
			end
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_LBLUE.."Getting item information...");
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
					DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Information not available for this item. A link or itemID is required.");
					DropCount.Search.mobItem=nil;
					return;
				end
			end
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_LBLUE.."Getting item information...");
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
		local X,Y=DropCount:GetPlayerPosition();
		DropCount:Chat("X,Y: "..X..","..Y);
		return;
	elseif (msg=="imtt") then
		if (LootCount_DropCount_Character.InvertMobTooltip) then
			LootCount_DropCount_Character.InvertMobTooltip=nil;
			DropCount:Chat("Mob tooltip is now default: OFF");
		else
			LootCount_DropCount_Character.InvertMobTooltip=true;
			DropCount:Chat("Mob tooltip is now default: ON");
		end
		return;
	elseif (msg=="tooltip") then
		if (LootCount_DropCount_Character.NoTooltip) then
			LootCount_DropCount_Character.NoTooltip=nil;
			DropCount:Chat("Tooltip info is now: ON");
		else
			LootCount_DropCount_Character.NoTooltip=true;
			DropCount:Chat("Tooltip info is now: OFF");
		end
		return;
	elseif (string.find(msg,"delete",1,true)==1) then
		local npc=DropCount.Target.LastAlive;
		msg=msg:sub(8);
		msg=msg:trim();
		if (msg~="") then
			npc=msg;
		end
		DropCount:RemoveFromItems("Name",npc)
		DropCount:RemoveFromItems("Skinning",npc)
		LootCount_DropCount_DB.Count[npc]=nil;
		DropCount:Chat(npc.." has been deleted.");
		return;
	end

	if (msg=="debug") then
		if (DropCount.Debug) then
			DropCount.Debug=nil;
			DropCount:Chat("DropCount: Debug: OFF");
		else
			DropCount.Debug=true;
			DropCount:Chat("DropCount: Debug: ON");
		end
		return;
	elseif (string.find(msg,"e ",1,true)==1) then
		msg=string.sub(fullmsg,3);
		DropCount:Chat("DropCount edit-command: "..msg,1,1);
		local params={strsplit("*",msg);}
		for index,iData in ipairs(params) do
			iData=iData.."   ";		-- Make it at least 3 characters
			local par=string.lower(string.sub(iData,1,2));
			params[par]=strtrim(string.sub(iData,3));
			params[index]=nil;
		end
		if (DropCount.Edit:Quest(params)) then return; end
		DropCount:Chat("Your query could not be fulfilled.",1);
		DropCount:Chat("Check for spelling and missing information.",1);
		return;
	end

	DropCount:Chat(CONST.C_BASIC..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."|r");
	if (msg=="?") then
		DropCount:CleanDB();
		if (LootCount_DropCount_DB.GUILD) then DropCount:Chat(CONST.C_BASIC.."DC:|r Currently sharing data with "..CONST.C_GREEN.."guild|r");
		elseif (LootCount_DropCount_DB.RAID) then DropCount:Chat(CONST.C_BASIC.."DC:|r Currently sharing data with "..CONST.C_LBLUE.."party/raid|r");
		else DropCount:Chat(CONST.C_BASIC.."DC:|r Currently "..CONST.C_RED.."not|r sharing data"); end
		return;
	end

	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." ?|r -> Statistics");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." single|r -> Show/hide items that has only dropped once");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." guild|r -> Share data with guild");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." raid|r -> Share data with party/raid");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." noshare|r -> Do not share data");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." item <item-ID\|link\|name>|r -> List vendors with this item");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." book <title>|r -> List location(s) of this book");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." book zone -> List all known books in current zone");
	DropCount:Chat(CONST.C_GREEN..SLASH_DROPCOUNT2.." imtt -> Toggle automatic mouse-over mob tooltip");
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
			DropCount:Chat("Quest :\""..p["?q"].."\" has been set to \""..p["+z"].."\"");
			return true;
		end
		for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
			for npc,nData in pairs(fData) do
				if (string.find(nData,p["?q"],1,true)) then
					local npcData=DropCount.DB.Quest:Read(faction,npc);
					for index,iData in pairs(npcData.Quests) do
						if (iData.Quest==p["?q"]) then
							if (iData.Header) then
								DropCount:Chat("Quest :"..p["?q"].." is \""..iData.Header.."\"");
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
	DropCount.WoW5:ConvertMOB(mob,GUID:sub(7,10));
	if (how=="PARTY_KILL" and (bit.band(source,COMBATLOG_OBJECT_TYPE_PET) or bit.band(source,COMBATLOG_OBJECT_TYPE_PLAYER))) then
-- Mop
--		if (GetNumPartyMembers()<1) then
--			DropCount:AddKill(true,GUID,mob,LootCount_DropCount_Character.Skinning);
		if (GetNumGroupMembers()<1) then
			DropCount:AddKill(true,GUID,GUID:sub(7,10),mob,LootCount_DropCount_Character.Skinning);
		end
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
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
	DropCount.Profession=nil;		-- only zero on new target, not on removal of target
	DropCount.Target.MyKill=nil;
	if (not UnitIsDead(targettype)) then
		DropCount.Target.LastFaction=UnitFactionGroup(targettype);
		if (not DropCount.Target.LastFaction) then
			DropCount.Target.LastFaction="Neutral";
		end
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
	DropCount.Target.GUID=UnitGUID(targettype);
	DropCount.Target.Skin=UnitName(targettype);					-- Get current valid target
	DropCount.Target.UnSkinned=DropCount.Target.GUID:sub(7,10);	-- Set unit for skinning-drop
	if (UnitIsTapped(targettype)) and (not UnitIsTappedByPlayer(targettype)) then return; end	-- Not my kill (in case of skinning)
	DropCount.Target.MyKill=DropCount.Target.Skin;			-- Save name of dead targetted/focused enemy
end

--== MoP change
--== GetLootSourceInfo(slot) - will return a list of creature GUIDs and count.

--for i=1,GetNumLootItems() do
--	local t={GetLootSourceInfo(i)}
--	print("loot #",i,"=",#t/2,"units:")
--	for j=1,#t,2 do
--		print("    ",t[j],"=",tonumber(t[j]:sub(6,10),16),"=",t[j+1])
--	end
--end

function DropCount.WoW5:ConvertMOB(name,sguid,base)
	if (not base) then base=LootCount_DropCount_DB; end
	if (not base.Count or not base.Count[name]) then return; end
	if (sguid=="0000") then return; end
	local mdata=DropCount.DB.Count:Read(name,base.Count);	-- get old data
	mdata.Name=name;										-- add textual name
	DropCount.DB.Count:Write(sguid,mdata,base.Count);		-- write it at short guid
	base.Count[name]=nil;									-- remove old entry
	if (not base.Item) then return; end
	for item,idata in pairs(base.Item) do					-- do all items
		if (idata:find(name,1,true)) then					-- look for this mob by name
			idata=DropCount.DB.Item:Read(item,base.Item);	-- read the item
			if (idata.Name and idata.Name[name]) then		-- look for mob by name
				idata.Name[sguid]=idata.Name[name];			-- copy it to short guid
				idata.Name[name]=nil;						-- remove by name
			end
			if (idata.Skinning and idata.Skinning[name]) then
				idata.Skinning[sguid]=idata.Skinning[name];
				idata.Skinning[name]=nil;
			end
			DropCount.DB.Item:Write(item,idata,base.Item);	-- write item
		end
	end
--print("Converted:",name,sguid);
end

--["item:29580:0:0:0:0:0:0"]
--	Name
--		Morcrush 2
--		Son of Corok 7
--		Farahlon Breaker 8
--		Karrog 1
--	Time 1327834129
--	Item Crystal Fragments
--	Best
--		Location Netherstorm - Netherstone
--		Score 12
--	BestW
--		Location Blade's Edge Mountains - Scalewing Shelf
--		Score 5

function DropCount:FixLootAmounts()
	local slots=GetNumLootItems();
	if (slots<1) then DropCount:Chat("Zero-loot",1); return; end

	-- item list
	local items={};
	for i=1,slots do
		local thisi=DropCount:GetID(GetLootSlotLink(i));
		if (thisi) then
			_,_,items[thisi]=GetLootSlotInfo(i);	-- icon, name, quantity
		end
	end
-- item list
--   item = number
--   item = number

	-- mob list
	local mobs={};
	for i=1,slots do
		local item=DropCount:GetID(GetLootSlotLink(i));
		local t={GetLootSourceInfo(i)};
		for j=1,#t,2 do
			if (not mobs[t[j] ]) then mobs[t[j] ]={}; end
			local buf={ Count=t[j+1], Item=item };		-- create LootList-type table per unit
			if (DropCount.Profession) then				-- don't resolve aoe loot on prof-loot
				buf.Count=items[item];					-- use total count
			end
			table.insert(mobs[t[j] ],buf);				-- create LootList-type table per unit
		end
	end
-- mob list
--   guid 1 Count = number
--          Item = string
--        2 Count = number
--          Item = string
--   guid ...

	-- create individual amounts
	local vitems={};
	for m,d in pairs(mobs) do		-- guid
		for _,mi in pairs(d) do		-- indexed mob items
			if (not vitems[mi.Item]) then
				vitems[mi.Item]={ mobs=1, amount=mi.Count, guid={ m } };
			else
				vitems[mi.Item].mobs=vitems[mi.Item].mobs+1;
				vitems[mi.Item].amount=vitems[mi.Item].amount+mi.Count;
				table.insert(vitems[mi.Item].guid,m);
			end
		end
	end

	-- check individual amounts
--print(CONST.C_BASIC.."Loot summary:");
	for i,d in pairs(items) do
local show;
local it=DropCount.DB.Item:Read(i); if (it and it.Item) then it=it.Item; else it=i; end
local txt=CONST.C_HBLUE.."    "..it.."  Real:"..tostring(d).."  Mobs:"..tostring(vitems[i].amount);
		if (vitems[i]) then
			if (d~=vitems[i].amount) then
txt=txt..CONST.C_RED.." -> "..vitems[i].amount-d;
				if (vitems[i].mobs==1) then						-- only one mob and it's wrong
--					mobs[vitems[i].guid[1] ].Count=d;			-- set correct (GetLootSlotInfo)
					for _,mi in pairs(mobs[vitems[i].guid[1] ]) do	-- indexed mob items
						if (mi.Item==i) then
							mi.Count=d;							-- set correct (GetLootSlotInfo)
						end
					end
txt=txt..CONST.C_GREEN.." FIXED (1m)";
show=true;
				else											-- multiple mobs, wrong total
					-- distilled guid -> sguid list
					local fi=nil;
					local num=0;
					local mt={};								-- mob type list
					for _m,_d in pairs(mobs) do					-- do all mobs
						for _,mi in pairs(_d) do					-- indexed mob items
							if (mi.Item==i) then					-- > that drops this item
								local sg=_m:sub(7,10);				-- get sguid
								if (not mt[sg]) then
									mt[sg]={ c=mi.Count, n=1, guid={_m} };
									num=num+1;
									if (not fi) then fi=_m; end
								else
									mt[sg].c=mt[sg].c+mi.Count;		-- add up for this sguid/type
									mt[sg].n=mt[sg].n+1;			-- number of this type
									table.insert(mt[sg].guid,_m);	-- add guid
								end
							end
						end
					end
local ctxt;
					if (num==1) then							-- only one mob type
--ctxt=CONST.C_BASIC.."? "..i.." ->"; for d_m,d_d in pairs(mobs) do ctxt=ctxt..CONST.C_LBLUE..d_m:sub(7,10); for _,d_mi in pairs(d_d) do if (d_mi.Item==i) then ctxt=ctxt.."|r : "..CONST.C_WHITE..d_mi.Count.." "; end end end print(ctxt);
						for _,mi in pairs(mobs[fi]) do			-- indexed mob items
							if (mi.Item==i) then
								mi.Count=mi.Count+(d-vitems[i].amount);	-- set all correction on one mob
							end
						end
--ctxt=CONST.C_BASIC.."! "..i.." ->"; for d_m,d_d in pairs(mobs) do ctxt=ctxt..CONST.C_LBLUE..d_m:sub(7,10); for _,d_mi in pairs(d_d) do if (d_mi.Item==i) then ctxt=ctxt.."|r : "..CONST.C_WHITE..d_mi.Count.." "; end end end print(ctxt);
txt=txt..CONST.C_GREEN.." FIXED (1t)";
show=true;
					else
						-- multiple types and wrong total
						local tr=0;								-- total ratio
						for _m,_d in pairs(mt) do				-- get all previous ratios
							mt[_m].r=DropCount:GetRatio(i,_m);	-- 1 = 100% (kill, skin, nosafe)
							mt[_m].r=mt[_m].r*mt[_m].n;			-- multiply by mobs of this type
							tr=tr+mt[_m].r;
							if (mt[_m].r==0) then mt[_m].r=.01; end	-- accept no zeros
						end
						local all=0;
						for _m,_d in pairs(mt) do				-- get all previous ratios
							mt[_m].a=(mt[_m].r/tr)*d;			-- fractional result
							mt[_m].a=math.floor(mt[_m].a+.5);	-- integer result
							all=all+mt[_m].a;					-- total verificator
						end
						if (all~=d) then						-- calculation differs from real total
							all=d-all;
local diff=all;
							if (all>0) then						-- items unaccounted for
								repeat
									local lom,lod;				-- low mob/data
									for _m,_d in pairs(mt) do				-- get all previous ratios
										if (not lom or mt[_m].a<lod) then	-- smaller found, or first
											lom=_m; lod=_d.a;				-- save mob and aprx.data
										end
									end
									mt[lom].a=mt[lom].a+1;		-- add 1 to lowest count
									all=all-1;					-- it's counted
								until (all==0);
							else
								repeat
									local him,hid;				-- high mob/data
									for _m,_d in pairs(mt) do				-- get all previous ratios
										if (not him or mt[_m].a>hid) then	-- higher found, or first
											him=_m; hid=_d.a;				-- save mob and aprx.data
										end
									end
									mt[him].a=mt[him].a-1;		-- remove 1 from highest count
									all=all+1;					-- it's counted
								until (all==0);
							end
txt=txt..CONST.C_YELLOW.." APPROXIMATED ("..tostring(diff)..")";
show=true;
						else
txt=txt..CONST.C_YELLOW.." CALCULATED";
show=true;
						end
-- 1 zero for all mobs
-- 2 apply mt to one of each mob types
--ctxt=CONST.C_BASIC.."? "..i.." ->"; for d_m,d_d in pairs(mobs) do ctxt=ctxt..CONST.C_LBLUE..d_m:sub(7,10); for _,d_mi in pairs(d_d) do if (d_mi.Item==i) then ctxt=ctxt.."|r : "..CONST.C_WHITE..d_mi.Count.." "; end end end print(ctxt);
						-- zero all mobs for this item
						for _,mi in pairs(mobs) do
							for _,mid in pairs(mi) do
								if (mid.Item==i) then mid.Count=0; end
							end
						end
						-- set mt to one of each type
						for sg,sgd in pairs(mt) do
							for m,mi in pairs(mobs) do
								if (m:sub(7,10)==sg) then	-- correct type
									local stopit=nil;
									for _,mid in pairs(mi) do
										if (mid.Item==i) then mid.Count=sgd.a; stopit=true; break; end
									end
									if (stopit) then break; end
								end
							end
						end
--ctxt=CONST.C_BASIC.."! "..i.." ->"; for d_m,d_d in pairs(mobs) do ctxt=ctxt..CONST.C_LBLUE..d_m:sub(7,10); for _,d_mi in pairs(d_d) do if (d_mi.Item==i) then ctxt=ctxt.."|r : "..CONST.C_WHITE..d_mi.Count.." "; end end end print(ctxt);
					end
				end
			end
		else
txt=txt..CONST.C_RED.." ==>> missing from mobs";		-- never observed to happen. yet.
show=true;
		end
--if (show) then print(txt); end
	end

-- mob list
--   guid 1 Count = number
--          Item = string
--        2 Count = number
--          Item = string
--   guid ...

	-- loot list
	local ret={};
	for guid,gL in pairs(mobs) do			-- guid
		for _,i in pairs(gL) do				-- index
			if (not ret[i.Item]) then ret[i.Item]={}; end
			ret[guid]=i.Count;
		end
	end
	ret.GetLootFormat=function(t,i)
		local lft={};
		if (type(i)=="string") then i=DropCount:GetID(i);
		else i=DropCount:GetID(GetLootSlotLink(i)); end
		if (not i or not t[i]) then return; end				-- unknown request
		for g,c in pairs(t[i]) do table.insert(lft,g); table.insert(lft,c); end
		return unpack(lft);
	end
	return ret,mobs;
end

function DropCount.Event.LOOT_OPENED()
	local i,mobs=DropCount:FixLootAmounts();
	if (not mobs) then return; end

	if (not DropCount.OldQuestsVerified) then
		LootCount_DropCount_DB.QuestQuery=GetQuestsCompleted();
		DropCount:GetQuestNames();
		DropCount.OldQuestsVerified=true;
	end

-- MoP
	for guid,list in pairs(mobs) do
		local skipit=nil;
		local sguid=guid:sub(7,10);
		-- pre-MoP modified for variable names
		---- DropCount.Target.GUID -> guid
		---- DropCount.Tracker.LootList -> list
		---- DropCount.Target.UnSkinned -> sguid
		local mTable=DropCount.Tracker.Looted;	-- Set normal loot mobs
		if (DropCount.Profession) then
			mTable=DropCount.Tracker.Skinned;		-- Set skinning loot mobs
		else
			-- It's normal, so check if it has already been skinned
			if (DropCount.Tracker.Skinned[guid]) then skipit=true; end	-- Loot already done for this one
		end
		if (mTable[guid]) then skipit=true; end			-- Loot already done for this one
		if (not skipit) then
			if (DropCount.Profession and DropCount.Target.MyKill) then		-- If my kill (or pet or something that makes me loot it)
	--			DropCount:AddKill(true,guid,DropCount.Target.MyKill);
				DropCount:AddKill(true,guid,sguid);
			elseif (not DropCount.Profession) then
				DropCount:AddKill(true,guid,sguid);	-- Add the targetted dead dude that I didn't have the killing blow on
			end
--print("Looting:",sguid);
			local now=time();
			-- Save loot
			mTable[guid]=now;							-- Set it
	--		for i=1,slots do
			for i=1,#list do
--local it=DropCount.DB.Item:Read(list[i].Item);
--if (it and it.Item) then print("    ",it.Item,list[i].Count); else print("    ",list[i].Item,list[i].Count); end
				if (list[i].Item and list[i].Count==0) then
					list[i].Count=1;
--if (it) then print("    ","Zero-count",it.Item,"set to 1"); end
				end
				if (list[i].Count>0) then			-- Not money
					if (DropCount.Target.MyKill) then
						DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count);
					elseif (DropCount.Target.Skin) then
						DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count);
					end
				end
			end
			DropCount.Profession=nil;			-- Set normal type loot
			-- Remove old mobs
			for guid,when in pairs(mTable) do
				if (now-when>CONST.LOOTEDAGE) then mTable[guid]=nil; end
			end
		end
	end		-- MoP
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
	MT:Run("WM Plot",DropCount.MT.Icons.PlotWorldmap);		--	DropCount.Icons:Plot();
end

function DropCount.Event.ZONE_CHANGED_NEW_AREA()
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
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
		DropCount:Chat("Quest \""..qName.."\" completed",0,1,0);
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

	local skillName=GetTradeSkillLine();
	if (skillName and skillName==CONST.PROFESSIONS[3]) then		-- Mining
		if (GetTradeSkillSelectionIndex()==0) then return; end
		skillName=GetTradeSkillInfo(GetTradeSkillSelectionIndex());
--print("Selected:"..skillName..", Casted:"..spell);
		if (not skillName or skillName~=spell) then return; end
		local fZone=GetRealZoneText();
		local forges=DropCount.DB.Forge:Read(fZone);
		if (not forges) then forges={}; end
		local saved=nil;
		local fX,fY=DropCount:GetPlayerPosition();
		for forge,fRaw in pairs(forges) do
			local x,y=fRaw:match("(.+)_(.+)"); x=tonumber(x); y=tonumber(y);
			if (fX>=x-1 and fX<=x+1 and fY>=y-1 and fY<=y+1) then
				forges[forge]=fX.."_"..fY;
				saved=true;
			end
		end
		if (not saved) then
			table.insert(forges,fX.."_"..fY);
		end
--print("Forge at "..fX..","..fY);
		DropCount.DB.Forge:Write(fZone,forges);
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
	end
end

-- An event has been received
--function DropCountXML:OnEvent(dummyself,event,...)
function DropCountXML:OnEvent(_,event,...)
	if (DropCount.Event[event]) then DropCount.Event[event](...); return; end
	local frame,index,checked=...;

	if (event=="ADDON_LOADED" and frame=="LootCount_DropCount") then
		if (DropCount_Local_Code_Enabled) then DropCount.Debug=true; end
		Table:Init(DM_WHO,true,LootCount_DropCount_DB);	-- Set defaults for compressing database
--		Table:Init(DM_WHO,false,LootCount_DropCount_DB);	-- Set defaults for compressing database
		DropCount.Hook.TT_SetBagItem=GameTooltip.SetBagItem; GameTooltip.SetBagItem=DropCount.Hook.SetBagItem;
		if (LootCount_DropCount_Character.ShowZoneMobs==nil) then LootCount_DropCount_Character.ShowZoneMobs=false; end
		LootCount_DropCount_Character.ShowZone=nil;	-- Obsolete
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
		if (not LootCount_DropCount_DB.Forge) then LootCount_DropCount_DB.Forge={}; end
		if (not LootCount_DropCount_DB.Trainer) then LootCount_DropCount_DB.Trainer={ [CONST.MYFACTION]={}, }; end
		DropCount:ConvertBookFormat();
		Astrolabe:Register_OnEdgeChanged_Callback(DropCountXML.AstrolabeEdge,1);
		LootCount_DropCount_DB.RAID=nil;
		if (IsInGuild()) then LootCount_DropCount_DB.GUILD=true; else LootCount_DropCount_DB.GUILD=nil; end
		DropCount:RemoveFromDatabase();
		LootCount_DropCount_RemoveData=nil;

-- MoP
--		QueryQuestsCompleted();
--		LootCount_DropCount_DB.QuestQuery=GetQuestsCompleted();
--		DropCount:GetQuestNames();

		DropCount.Loaded=0;
		LCDC_ResultListScroll:DMClear();		-- Prep search-list
		LCDC_VendorSearch_UseVendors:SetText("Vendors"); LCDC_VendorSearch_UseVendors:SetChecked(true);
		LCDC_VendorSearch_UseQuests:SetText("Quests"); LCDC_VendorSearch_UseQuests:SetChecked(true);
		LCDC_VendorSearch_UseBooks:SetText("Books"); LCDC_VendorSearch_UseBooks:SetChecked(true);
		LCDC_VendorSearch_UseItems:SetText("Items"); LCDC_VendorSearch_UseItems:SetChecked(true);
		LCDC_VendorSearch_UseMobs:SetText("Creatures"); LCDC_VendorSearch_UseMobs:SetChecked(true);
		LCDC_VendorSearch_UseTrainers:SetText("Trainers"); LCDC_VendorSearch_UseTrainers:SetChecked(true);
		-- Fire initial MT tasks
		MT:Run("ConvertAndMerge",DropCount.MT.ConvertAndMerge);	-- DropCount.OnUpdate:RunConvertAndMerge(elapsed);
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
			DropCount:SetLootlist(entry.DB.Entry,entry.DB.sguid,GameTooltip);
		end
	end
	if (event=="DMEVENT_LISTBOX_ITEM_LEAVE") then
		GameTooltip:Hide();
	end
	if (event=="DMEVENT_LISTBOX_ITEM_CLICKED") then
		local entry=frame.DMTheList[index];
		if (frame==LCDC_ListOfOptions_List) then
			if (entry.DB.Base) then
				_G["LootCount_DropCount_"..entry.DB.Base][entry.DB.Setting]=checked;
				if (LootCount_DropCount_DB.GUILD) then LootCount_DropCount_DB.RAID=nil; end
				if (LootCount_DropCount_DB.RAID) then LootCount_DropCount_DB.GUILD=nil; end
				MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
			end
		else
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
end

function DropCount.Hook.SetBagItem(self,bag,slot)
	local hasCooldown,repairCost=DropCount.Hook.TT_SetBagItem(self,bag,slot);

	local _,item=GameTooltip:GetItem();
	DropCount.Hook:AddLocationData(GameTooltip,item);
	return hasCooldown,repairCost;
end

function DropCount.Hook:AddLocationData(frame,item)
	if (LootCount_DropCount_Character.NoTooltip) then return; end
	local ThisItem=DropCount:GetID(item);
	if (ThisItem) then
		local iData=DropCount.DB.Item:Read(ThisItem);
		if (iData) then
			local text="|cFFF89090B|cFFF09098e|cFFE890A0s|cFFE090A8t |cFFD890B0k|cFFD090B8n|cFFC890C0o|cFFC090C8w|cFFB890D0n |cFFB090D8a|cFFA890E0r|cFFA090E8e|cFF9890F0a: |cFF9090F8";
			if (iData.Best) then
				frame:LCAddLine(text..iData.Best.Location.." at "..iData.Best.Score.."%",.6,.6,1,1);	-- 1=wrap text
			elseif (iData.BestW) then
				frame:LCAddLine(text..iData.BestW.Location.." at "..iData.BestW.Score.."%",.6,.6,1,1);	-- 1=wrap text
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
				if (count==0) then DropCount:Chat("Vendors without coordinates:"); end
				count=count+1;
				local text=vendor;
				if (Zone and Zone~=" ") then text=text.." in "..Zone; end
				if (Faction and Faction~=" ") then text=text.." ("..Faction..")"; end
				DropCount:Chat(text);
			end
		end
	end
	if (count==0) then
		DropCount:Chat("All vendors accounted for");
	else
		DropCount:Chat(count.." vendors found");
	end
end

function DropCount:ShowStats(length)
	if (not length or length<2) then length=3; end
	local top={ { kill=0, name="", zone="" } };
	local index=2;
	while(index<=length) do
		top[index]=DropCount:CopyTable(top[1]);
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

	DropCount:Chat(CONST.C_BASIC..LOOTCOUNT_DROPCOUNT_VERSIONTEXT.." stats:");
	if (top[1].kill>0) then
		index=1;
		while (top[index] and top[index].kill>0) do
			DropCount:Chat(CONST.C_BASIC.."Most kills "..index..": "..CONST.C_GREEN..top[index].kill.." "..CONST.C_YELLOW..top[index].name..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
			index=index+1;
		end
	else
		DropCount:Chat(CONST.C_RED.."No stats available");
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
			DropCount:Chat(CONST.C_BASIC.."Most prof. loot "..index..": "..CONST.C_GREEN..top[index].kill.." "..CONST.C_YELLOW..top[index].name..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
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
			DropCount:Chat(CONST.C_BASIC.."Highest drop-rate "..index..": "..CONST.C_GREEN..math.floor(top[index].kill*100).."\% "..CONST.C_WHITE..top[index].name..CONST.C_BASIC.." from "..CONST.C_YELLOW..top[index].mob..CONST.C_BASIC.." in "..CONST.C_HBLUE..top[index].zone);
			index=index+1;
		end
	end
end

function DropCount:Length(t)
	if (not t) then return 0; end
	local count=0;
	for _ in pairs(t) do count=count+1; end
	return count;
end

function DropCount:GetQuestNames()
	if (not LootCount_DropCount_DB.QuestQuery) then return; end
	LootCount_DropCount_DB.TesterTable=self:CopyTable(LootCount_DropCount_DB.QuestQuery);
--print("questquery:",self:Length(LootCount_DropCount_DB.QuestQuery));
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
--print("convertquests",DropCount.Tracker.ConvertQuests);

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
	for v,icon in pairs(DropCountXML.Icon.MM) do
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

function DropCount.Quest:SaveQuest(qName,qGiver,qLevel)
	local OnlyAddQuest=nil;
	if (not qName) then return; end
	if (not qLevel) then qLevel=0; end
	if (not CONST.MYFACTION) then return; end
	if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
	if (not LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then LootCount_DropCount_DB.Quest[CONST.MYFACTION]={}; end

	if (not qZone) then qZone="Unknown"; end
	local qX,qY,qZone;
	qX,qY=DropCount:GetPlayerPosition();
	qZone=DropCount:GetFullZone();
	if (not qGiver or qGiver=="") then
		qGiver="- item - ("..DropCount:GetFullZone().." "..math.floor(qX)..","..math.floor(qY)..")";
		if (QuestNPCModelNameText:IsVisible()) then
			local fsText=QuestNPCModelNameText:GetText();
			if (LootCount_DropCount_DB.Quest[CONST.MYFACTION][fsText]) then
				-- We have a remote quest with a known quest-giver
				qGiver=fsText;
				OnlyAddQuest=true;
				DropCount:Chat("DEBUG Q-DUDE: "..qGiver,1);
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
		if (DropCount.Debug) then DropCount:Chat(CONST.C_BASIC.."New Quest "..CONST.C_GREEN.."\""..qName.."\""..CONST.C_BASIC.." saved for "..CONST.C_GREEN..qGiver); end
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
	DropCount.SpoolQuests=DropCount:CopyTable(LootCount_DropCount_Character.Quests,DropCount.SpoolQuests);

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

function DropCount.MT.Icons:PlotWorldmap()
	if (not WorldMapDetailFrame) then return; end
	local mapID=GetCurrentMapAreaID();
	local floorNum=GetCurrentMapDungeonLevel();
	local ZoneName=LootCount_DropCount_Maps[GetLocale()]
	if (ZoneName) then ZoneName=ZoneName[mapID]; end
	local unit=DropCount.MT.Icons:BuildIconList(	ZoneName,nil,
									LootCount_DropCount_DB.BookWorldmap,
									LootCount_DropCount_DB.ForgeWorldmap,
									LootCount_DropCount_DB.QuestWorldmap,
									LootCount_DropCount_DB.VendorWorldmap,
									LootCount_DropCount_DB.RepairWorldmap,
									LootCount_DropCount_DB.TrainerWorldmap);
	local index=1;
	while (_G["LCDC_WorldmapIcon"..index]) do
		_G["LCDC_WorldmapIcon"..index]:Hide();
		index=index+1;
	end
	for index,eTable in pairs(unit) do
		MT:Yield();
		if (not _G["LCDC_WorldmapIcon"..index]) then
			DropCountXML.Icon.WM[index]=CreateFrame("Button","LCDC_WorldmapIcon"..index,WorldMapDetailFrame,"LCDC_VendorFlagTemplate");
			DropCountXML.Icon.WM[index].icon=DropCountXML.Icon.WM[index]:CreateTexture("ARTWORK");
		else
			DropCountXML.Icon.WM[index]=_G["LCDC_WorldmapIcon"..index];
		end
		DropCountXML.Icon.WM[index].icon:SetTexture(eTable.icon);
		if (eTable.r and eTable.g and eTable.b) then
			DropCountXML.Icon.WM[index].icon:SetVertexColor(eTable.r,eTable.g,eTable.b);
		else
			DropCountXML.Icon.WM[index].icon:SetVertexColor(1,1,1);
		end
		DropCountXML.Icon.WM[index].icon:SetAllPoints();
if (not eTable.X or not eTable.Y) then
	DropCount:Chat("Broken entry: "..eTable.Name.." - "..eTable.Type);
end
		DropCountXML.Icon.WM[index].Info={
			Name=eTable.Name,
			Type=eTable.Type,
			Service=eTable.Service,
			Map=mapID,
			Floor=floorNum,
			X=eTable.X/100,
			Y=eTable.Y/100,
		}
		Astrolabe:PlaceIconOnWorldMap(	WorldMapDetailFrame,
										DropCountXML.Icon.WM[index],
										DropCountXML.Icon.WM[index].Info.Map,
										DropCountXML.Icon.WM[index].Info.Floor,
										DropCountXML.Icon.WM[index].Info.X,
										DropCountXML.Icon.WM[index].Info.Y);
	end
end

function DropCountXML:OnEnterIcon(frame)
	LCDC_VendorFlag_Info=true;
	if (not frame.Info) then return; end
	if (frame.Info.Type=="Vendor") then DropCount.Tooltip:SetNPCContents(frame.Info.Name); return; end
	if (frame.Info.Type=="Book") then DropCount.Tooltip:Book(frame.Info.Name,parent); return; end
	if (frame.Info.Type=="Quest") then DropCount.Tooltip:QuestList(CONST.MYFACTION,frame.Info.Name,parent); return; end
	LootCount_DropCount_TT:ClearLines();
	LootCount_DropCount_TT:SetOwner(UIParent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText(frame.Info.Name);
	LootCount_DropCount_TT:LCAddLine(frame.Info.Type,1,1,1);
	if (frame.Info.Service) then
		LootCount_DropCount_TT:LCAddLine(frame.Info.Service,1,1,1);
	end
	LootCount_DropCount_TT:Show();
end

function DropCount:ListBook(bookin)
	if (not LootCount_DropCount_DB.Book) then return; end
	local book=string.lower(bookin);
	for title,bTable in pairs(LootCount_DropCount_DB.Book) do
		if (book==string.lower(title)) then
			DropCount:Chat(title);
			for loc,lTable in pairs(bTable) do
				DropCount:Chat(CONST.C_HBLUE..lTable.Zone..CONST.C_YELLOW.." ("..string.format("%.0f,%.0f",lTable.X,lTable.Y)..")");
			end
			return;
		end
	end

	DropCount:Chat(CONST.C_YELLOW.."Unknown book: "..bookin.."|r");
end

function DropCount:ListZoneBooks()
	if (not LootCount_DropCount_DB.Book) then return; end
	local found=nil;
	local here=GetRealZoneText();
	local clip=string.len(here)+3+1;
	DropCount:Chat(here);
	for title,bTable in pairs(LootCount_DropCount_DB.Book) do
		for index,iTable in pairs(bTable) do
			if (iTable.Zone) then
				if (string.find(iTable.Zone,here,1,true)==1) then
					local subzone=string.sub(iTable.Zone,clip);
					if (not subzone) then subzone=""; end
					DropCount:Chat(CONST.C_HBLUE..title.." |r- "..CONST.C_YELLOW..subzone.." ("..string.format("%.0f,%.0f",iTable.X,iTable.Y)..")");
					found=true;
				end
			end
		end
	end
	if (not found) then DropCount:Chat(CONST.C_YELLOW.."No known books in "..here.."|r"); end
end

function DropCount.MT.Icons:BuildIconList(zn,minimal,bBook,bForge,bQuest,bVendor,bRepair,bTrainer)
	local unit={};
	-- Book
	if (bBook) then
		for book,vTable in pairs(LootCount_DropCount_DB.Book) do
			for index,bTable in pairs(vTable) do
				MT:Yield();
				if (bTable.Zone and string.find(bTable.Zone,zn,1,true)==1) then
					table.insert(unit,{Name=book,Type="Book",X=bTable.X,Y=bTable.Y,icon="Interface\\Spellbook\\Spellbook-Icon"});
				end
			end
		end
	end
	-- Forge
	if (bForge) then
		local raw=DropCount.DB.Forge:Read(zn);
		if (raw) then
			for forge,fRaw in pairs(raw) do
				MT:Yield();
				local x,y=fRaw:match("(.+)_(.+)"); x=tonumber(x); y=tonumber(y);
				table.insert(unit,{Name="Forge",Type="Forge",X=x,Y=y,icon=CONST.PROFICON[5]});
			end
		end
	end
	-- Quest
	if (bQuest) then
		if (LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then
			for npc,nRaw in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
				MT:Yield();
				if (DropCount.DB:PreCheck(nRaw,zn)) then
					local nTable=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
					if (nTable.Quests) then
						if (nTable.Zone and string.find(nTable.Zone,zn,1,true)==1) then
							local r,g,b=1,1,1;
							local level=0;
							for _,qTable in pairs(nTable.Quests) do
								local state=DropCount:GetQuestStatus(qTable.ID,qTable.Quest);
								if (state==CONST.QUEST_NOTSTARTED and level<3) then r,g,b=0,1,0; level=3; end
								if (state==CONST.QUEST_STARTED and level<2) then r,g,b=1,1,1; level=2; end
								if (state==CONST.QUEST_DONE and level<1) then r,g,b=0,0,0; level=1; end
								if (state==CONST.QUEST_UNKNOWN) then r,g,b=1,0,0; level=100; end
							end
							if (level>1 or not minimal) then
								table.insert(unit,{Name=npc,Type="Quest",State=state,X=nTable.X,Y=nTable.Y,r=r,g=g,b=b,icon="Interface\\QuestFrame\\UI-Quest-BulletPoint"});
							end
						end
					end
				end
			end
		end
	end
	-- Vendor
	if (bVendor or bRepair) then
		for vendor,vRaw in pairs(LootCount_DropCount_DB.Vendor) do
			MT:Yield();
			if (DropCount.DB:PreCheck(vRaw,zn)) then
				local x,y,zone,faction,repair=DropCount.DB.Vendor:ReadBaseData(vendor);
				if (faction=="Neutral" or faction==CONST.MYFACTION) then
					if (bVendor or (bRepair and repair)) then
						if (zone and string.find(zone,zn,1,true)==1) then
							local texture="Interface\\GROUPFRAME\\UI-Group-MasterLooter";
							if (repair) then texture="Interface\\GossipFrame\\VendorGossipIcon"; end
							table.insert(unit,{Name=vendor,Type="Vendor",X=x,Y=y,icon=texture});
						end
					end
				end
			end
		end
	end
	-- Trainer
	if (bTrainer) then
		if (LootCount_DropCount_DB.Trainer[CONST.MYFACTION]) then
			for npc,nRaw in pairs(LootCount_DropCount_DB.Trainer[CONST.MYFACTION]) do
				MT:Yield();
				if (DropCount.DB:PreCheck(nRaw,zn)) then
					local nTable=DropCount.DB.Trainer:Read(npc);
					if (nTable.Zone and string.find(nTable.Zone,zn,1,true)==1) then
						local texture="Interface\\Icons\\INV_Misc_QuestionMark";
						for index,prof in pairs(CONST.PROFESSIONS) do
							if (prof==nTable.Service or prof:find(nTable.Service) or nTable.Service:find(prof)) then
								texture=CONST.PROFICON[index];
								break;
							end
						end
						table.insert(unit,{Name=npc,Service=nTable.Service,Type="Trainer",X=nTable.X,Y=nTable.Y,icon=texture});
					end
				end
			end
		end
	end

	return unit;
end

function DropCount.MT.Icons:PlotMinimap()
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();	-- Map helpers
	local unit=DropCount.MT.Icons:BuildIconList(	ZoneName,true,
									LootCount_DropCount_DB.BookMinimap,
									LootCount_DropCount_DB.ForgeMinimap,
									LootCount_DropCount_DB.QuestMinimap,
									LootCount_DropCount_DB.VendorMinimap,
									LootCount_DropCount_DB.RepairMinimap,
									LootCount_DropCount_DB.TrainerMinimap);
	local mapID,floorNum,ZoneName,SubZone=DropCount.Map:ForDatabase();	-- Map helpers
	local index;
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
		if (eTable.r and eTable.g and eTable.b) then
			DropCountXML.Icon.MM[index].icon:SetVertexColor(eTable.r,eTable.g,eTable.b);
		else
			DropCountXML.Icon.MM[index].icon:SetVertexColor(1,1,1);
		end
		DropCountXML.Icon.MM[index].icon:SetAllPoints();
if (not eTable.X or not eTable.Y) then
	DropCount:Chat("Broken entry: "..eTable.Name.." - "..eTable.Type);
end
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
	return Table:Read(DM_WHO,npc,base,"Quest");
end

function DropCount.DB.Quest:Write(npc,nData,faction)
	if (LootCount_DropCount_DB.DontFollowQuests) then return; end
	if (not faction) then faction=CONST.MYFACTION; end
	if (not LootCount_DropCount_DB.Quest[faction]) then LootCount_DropCount_DB.Quest[faction]={}; end
	Table:Write(DM_WHO,npc,nData,LootCount_DropCount_DB.Quest[faction],"Quest");
end

function DropCount.DB.Vendor:ReadBaseData(npc,base)
	if (not base) then base=LootCount_DropCount_DB.Vendor; end
	local vendor=DropCount.DB.Vendor:Read(npc,base);
	if (not vendor) then return nil; end
	return vendor.X,vendor.Y,vendor.Zone,vendor.Faction,vendor.Repair;
end

function DropCount.DB.Vendor:Read(npc,base)
	if (not base) then base=LootCount_DropCount_DB.Vendor; end
	return Table:Read(DM_WHO,npc,base,"Vendor");
end

function DropCount.DB.Vendor:Write(npc,nData)
	if (LootCount_DropCount_DB.DontFollowVendors) then return; end
	Table:Write(DM_WHO,npc,nData,LootCount_DropCount_DB.Vendor,"Vendor");
end

function DropCount.DB.Trainer:Read(name,base,faction)
	if (not base) then base=LootCount_DropCount_DB.Trainer; end
	if (not faction) then faction=CONST.MYFACTION; end
	if (not base[faction]) then return nil; end
	return Table:Read(DM_WHO,name,base[faction],"Trainer");
end

function DropCount.DB.Trainer:Write(npc,nData,faction)
	if (LootCount_DropCount_DB.DontFollowTrainers) then return; end
	if (not faction) then faction=CONST.MYFACTION; end
	if (not LootCount_DropCount_DB.Trainer[faction]) then LootCount_DropCount_DB.Trainer[faction]={}; end
	Table:Write(DM_WHO,npc,nData,LootCount_DropCount_DB.Trainer[faction],"Trainer");
end

function DropCount.DB.Forge:Read(area,base)
	if (not base) then base=LootCount_DropCount_DB.Forge; end
	return Table:Read(DM_WHO,area,base,"Forge");
end

function DropCount.DB.Forge:Write(area,nData)
	if (LootCount_DropCount_DB.DontFollowForges) then return; end
	Table:Write(DM_WHO,area,nData,LootCount_DropCount_DB.Forge,"Forge");
end

function DropCount.DB.Count:Write(mob,nData,base)
	if (LootCount_DropCount_DB.DontFollowMobsAndDrops) then return; end
	if (not base) then base=LootCount_DropCount_DB.Count; end
	Table:Write(DM_WHO,mob,nData,base,"Count");
end

function DropCount.DB.Count:Read(mob,base)
	if (not base) then base=LootCount_DropCount_DB.Count; end
	return Table:Read(DM_WHO,mob,base,"Count");
end

function DropCount.DB.Item:Write(item,iData,base)
	if (LootCount_DropCount_DB.DontFollowMobsAndDrops) then return; end
	if (not base) then base=LootCount_DropCount_DB.Item; end
	Table:Write(DM_WHO,item,iData,base,"Item");
end

function DropCount.DB.Item:ReadByName(name,dummy)
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
	return Table:Read(DM_WHO,item,base,"Item");
end

function DropCount:VendorsForItem()
	if (not DropCount.Search.Item) then return; end

	local itemName,itemLink=GetItemInfo(DropCount.Search.Item);
	if (itemLink) then
		local itemID=DropCount:GetID(itemLink);
		local list=DropCount.Tooltip:VendorList(itemID,true);

		-- Type list
		local line=1;
		while(list[line]) do
			if (line==1) then DropCount:Chat(itemLink); end
			DropCount:Chat(list[line].Ltext.." "..list[line].Rtext);
			line=line+1;
		end

		if (line==1) then
			DropCount:Chat(CONST.C_YELLOW.."No known vendors for "..itemName.."|r");
		end
	end
end

function DropCount:AreaForItem()
	if (not DropCount.Search.mobItem) then return; end
	if (not LootCount_DropCount_DB.Item) then return; end

	local itemName,itemLink=GetItemInfo(DropCount.Search.mobItem);
	if (not itemLink) then return; end
	local item=DropCount:GetID(itemLink);
	if (not LootCount_DropCount_DB.Item[item]) then
		DropCount:Chat(CONST.C_YELLOW.."Unknown drop: "..itemName.."|r");
		return;
	end
	item=DropCount.DB.Item:Read(item);
	if (not item.Best) then
		DropCount:Chat(CONST.C_YELLOW.."No known drop-area for "..itemName.."|r");
		return;
	end
	DropCount:Chat(itemLink);
	DropCount:Chat("Drops in "..item.Best.Location.." at "..item.Best.Score.."%");
	if (item.BestW) then
		DropCount:Chat("and in "..item.BestW.Location.." at "..item.BestW.Score.."%");
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
		DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN.."New vendor added to database|r");
	else
		vData=DropCount.DB.Vendor:Read(dude);
	end

	local posX,posY=DropCount:GetPlayerPosition();
	vData.Repair=_G.MerchantRepairAllButton:IsVisible();
	vData.Zone=DropCount:GetFullZone();
	vData.X=posX;
	vData.Y=posY;
	vData.Faction=DropCount.Target.LastFaction;
	vData.Map=DropCount:GetMapTable();

--	DropCount:SetVendorMMPosition(dude,posX,posY);

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
		link=DropCount:GetID(link);
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
--			DropCount:Chat("Unchached item(s) at this vendor. Look through the vendor-pages to load missing items from the server.",1);
			DropCount.VendorProblem=true;
		end
	else
		DropCount.DB.Vendor:Write(dude,vData);
		if (DropCount.VendorProblem) then
--			DropCount:Chat("Vendor saved",0,1,0);
			rebuildIcons=true;
		end
		if (rebuildIcons) then
			MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		end
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
		DropCount:AddKill(nil,guid,guid:sub(7,10),mob,nil,nil,true,item);
		if (DropCount.Debug) then
			DropCount:Chat(sender.." kill: \'"..mob.."\'",0,1,0);
		end
	elseif (header==COM.MOBLOOT) then
		if (not count or not item) then return; end
		if (source=="SKIN") then
			DropCount.Profession=source;
			if (not DropCount.Com:HaveReceivedSkin(guid)) then
				DropCount.Target.UnSkinned=guid:sub(7,10);
			end
		end
		DropCount:AddLoot(guid,guid:sub(7,10),mob,item,count,true);
		local itemname=GetItemInfo(item);
		if (not itemname) then _,itemname=DropCount:GetID(item); end
		if (DropCount.Debug) then
			DropCount:Chat(sender.." drop: \'"..mob.."\' -> \'"..itemname.."\'x"..count,0,1,0);
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

function DropCount:GetPlayerPosition()
	local posX,posY=GetPlayerMapPosition("player");
	posX=(floor(posX*100000))/1000;
	posY=(floor(posY*100000))/1000;
	if (posX==0 or posY==0) then
		DropCount:Chat("Invalid player position",1);
	end
	return posX,posY;
end

function DropCount:AddKill(oma,GUID,sguid,mob,reservedvariable,noadd,notransmit,otherzone)
	if (not mob and not sguid) then return; end
	-- Check if already counted
	local i=DropCount.Tracker.QueueSize;
	while (i>0) do
		if (DropCount.Tracker.TimedQueue[i].GUID==GUID) then return; end
		i=i-1;
	end

	local now=time();
	local mTable=DropCount.DB.Count:Read(sguid);
	if (not mTable) then mTable={ Kill=0 }; end
	if (not mTable.Name) then mTable.Name=mob; end
--	mob=mTable.Name;
	if (not otherzone) then otherzone=DropCount:GetFullZone(); end
	mTable.Zone=otherzone;		-- Set zone for last kill
	if (not noadd) then
		if (not mTable.Kill) then mTable.Kill=0; end
		mTable.Kill=mTable.Kill+1;
		if (not nagged) then
			if (mTable.Name and ((mTable.Kill<=50 and mod(mTable.Kill,25)==0) or mTable.Kill==(math.floor(mTable.Kill/100)*100))) then
				DropCount:Chat(CONST.C_BASIC.."DropCount: "..CONST.C_YELLOW..mTable.Name..CONST.C_BASIC.." has been killed "..CONST.C_YELLOW..mTable.Kill..CONST.C_BASIC.." times!");
				DropCount:Chat(CONST.C_BASIC.."Please consider sending your SavedVariables file to "..CONST.C_YELLOW.."dropcount@ybeweb.com"..CONST.C_BASIC.." to help develop the DropCount addon.");
				nagged=true;
			end
		end
		if (not notransmit) then DropCount.Com:Transmit(GUID,sguid); end
		DropCount.DB.Count:Write(sguid,mTable);
	else
		DropCount.DB.Count:Write(sguid,mTable);
		return;
	end
	if (not mob) then return; end

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

--DropCount:Chat("Queue: "..DropCount.Tracker.QueueSize,1);
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
--DropCount:Chat(iDB.Item,1);
				end
			end
		end
	end
end

function DropCount:AddLootMob(GUID,sguid,mob,item)
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
	if (not nameTable[sguid]) then		-- Mob not in drop-list
		nameTable[sguid]=0;				-- Not looted, but make entry (will be added later)
	end
	DropCount.DB.Item:Write(item,iTable);
	if (not LootCount_DropCount_DB.Count[sguid]) then		-- Mob not in kill-list
		DropCount:AddKill(nil,GUID,sguid,mob,nil,true,true,"");	-- Add it with zero kills
	end
end

--		DropCount:AddLoot(guid,sguid,nil,list[i].Item,list[i].Count);
function DropCount:AddLoot(GUID,sguid,mob,item,count,notransmit)
	if (not notransmit) then DropCount.Com:Transmit(GUID,mob,item,count,DropCount.Profession); end
	local now=time();
	local iTable=DropCount.DB.Item:Read(item);
	if (not iTable) then iTable={}; end
	local itemName,itemLink=GetItemInfo(item);
	iTable.Item=itemName;
	iTable.Time=now;				-- Last point in time for loot of this item
	DropCount.DB.Item:Write(item,iTable);
	DropCount:AddLootMob(GUID,sguid,mob,item);			-- Make register
	iTable=DropCount.DB.Item:Read(item,nil,true);
	local skinning=nil;
	local nameTable;
	if (DropCount.Profession) then
		nameTable=iTable.Skinning;
		skinning=true;
	else
		nameTable=iTable.Name;
	end
	nameTable[sguid]=nameTable[sguid]+count;
	DropCount.DB.Item:Write(item,iTable);

	if (skinning) then		-- Skinner-loot, so add it as a skinning-kill
		if (DropCount.Target.UnSkinned and DropCount.Target.UnSkinned==sguid) then
			local mTable=DropCount.DB.Count:Read(sguid);
			if (mTable) then
				if (not mTable.Skinning) then mTable.Skinning=0; end
				mTable.Skinning=mTable.Skinning+1;
--print("skinning +1 for",sguid);
				DropCount.Target.UnSkinned=nil;					-- Added, so next loot on this target is more than one items from same skinning
				DropCount.DB.Count:Write(sguid,mTable);
			end
		end
	end
	if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
end

function DropCount:GetRatio(item,sguid)
	if (CONST.QUESTID) then
		local _,_,_,_,_,itemtype=GetItemInfo(item);
		local _,itemID=DropCount:GetID(item);
		if (itemtype and itemtype==CONST.QUESTID and not LootCount_DropCount_NoQuest[itemID]) then return CONST.QUESTRATIO,CONST.QUESTRATIO; end
	end

	local nosafe=nil;
	local nKills,nRatio=0,0;
	local sKills,sRatio=0,0;
	if (not LootCount_DropCount_DB.Item[item]) then return 0,0,true; end
	local iTable=DropCount.DB.Item:Read(item);
	if (not iTable.Name and not iTable.Skinning) then return 0,0,true; end
	if (iTable.Name and not iTable.Name[sguid]) then nRatio=0; end
	if (iTable.Skinning and not iTable.Skinning[sguid]) then sRatio=0; end
	if (not LootCount_DropCount_DB.Count[sguid]) then return 0,0,true; end

	local mTable=DropCount.DB.Count:Read(sguid);
	if (iTable.Name) then
		nKills=mTable.Kill;
		if (not nKills or nKills<1) then nRatio=0;
		else
			if (iTable.Name[sguid]) then
				nRatio=iTable.Name[sguid]/nKills;
				if (iTable.Name[sguid]<2) then unsafe=true; end
			else
				nRatio=0;
			end
		end
	end

	if (iTable.Skinning) then
		sKills=mTable.Skinning;
		if (not sKills or sKills<1) then sRatio=0;
		else
			if (iTable.Skinning[sguid]) then
				sRatio=iTable.Skinning[sguid]/sKills;
				if (iTable.Skinning[sguid]<2) then unsafe=true; end
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

	if (DropCount.LootCount.Registered) then LootCountAPI.SetData(LOOTCOUNT_DROPCOUNT,button,DropCount:FormatPst(ratio),goalvalue); end
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
	elseif (clearit) then wipe(button.User);
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
		DropCount:Chat(CONST.C_RED.."The DropCount database is currently being converted to the new format. Your data will be available when this is done.|r");
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
	if (getlist) then return DropCount:CopyTable(list); end
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
		LootCount_DropCount_DB.DebugData[name]=DropCount:CopyTable(variable);
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
	local iTable=DropCount.DB.Item:Read(button.User.itemID);
	local skinningdrop=iTable.Skinning;
	local normaldrop=iTable.Name;
	local scrap=colour.."["..DropCount:Highlight(itemname,highlight,colour).."]|r:";
	if (LootCount_DropCount_Character.CompactView) then
		if (skinningdrop) then
			if (normaldrop) then scrap=scrap.." (L/|cFFFF00FFP|r)"; else scrap=scrap.." (|cFFFF00FFP|r)"; end
		end
	end
	GameTooltip:SetText(scrap);
	local currentzone=GetRealZoneText();
	if (not currentzone) then
		currentzone="";
	elseif (LootCount_DropCount_Character.ShowZoneMobs) then
		if (LootCount_DropCount_Character.CompactView) then scrap="("..currentzone..")";
		else scrap="Showing mobs from "..currentzone.." only"; end
		GameTooltip:LCAddLine(scrap,0,1,1);
	end
	if (not LootCount_DropCount_Character.CompactView) then
		if (skinningdrop) then
			if (normaldrop) then scrap="Loot and |cFFFF00FFprofession"; else scrap="Profession"; end
			GameTooltip:LCAddLine(scrap,1,0,1);
		end
	end
	if (iTable.Best) then
		if (not LootCount_DropCount_Character.CompactView) then
			GameTooltip:LCAddDoubleLine("Best drop-area:",DropCount:Highlight(iTable.Best.Location,highlight).." ("..iTable.Best.Score.."\%)",0,1,1,0,1,1);
			if (iTable.BestW) then
				GameTooltip:LCAddDoubleLine(" ",DropCount:Highlight(iTable.BestW.Location,highlight).." ("..iTable.BestW.Score.."\%)",0,1,1,0,1,1);
			end
		else
			GameTooltip:LCAddLine(DropCount:Highlight(iTable.Best.Location,highlight).." ("..iTable.Best.Score.."\%)",0,1,1);
			if (iTable.BestW) then
				GameTooltip:LCAddLine(DropCount:Highlight(iTable.BestW.Location,highlight).." ("..iTable.BestW.Score.."\%)",0,1,1);
			end
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
--DropCount:Chat(mob.." does not exist (drop)",1);
				DropCount:RemoveFromItems("Name",mob);
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
				if (not LootCount_DropCount_Character.CompactView and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end

				local mobName=DropCount.DB.Count:Read(mob).Name or mob;
				list[line].Ltext=colour..pretext..DropCount:Highlight(mobName,highlight,colour)..zone.."|r: ";
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
--DropCount:Chat(mob.." does not exist (skinning)",1);
				DropCount:RemoveFromItems("Skinning",mob);
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
				if (not LootCount_DropCount_Character.CompactView and mTable.Zone) then
					zone=" |cFF0060FF("..DropCount:Highlight(mTable.Zone,highlight,"|cFF0060FF")..")";
				end

				local mobName=DropCount.DB.Count:Read(mob).Name or mob;
				list[line].Ltext=colour..pretext..DropCount:Highlight(mobName,highlight,colour)..zone.."|r: ";
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
	list=DropCount:CopyTable(list);
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
			if (LootCount_DropCount_DB.Quest[CONST.MYFACTION][unit]) then
				DropCount.Tooltip:QuestList(CONST.MYFACTION,unit,parent,frame);
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

function DropCount:SetLootlist(unit,sguid,AltTT,compact)
-- MoP
	if (LootCount_DropCount_DB.Count[unit]) then DropCount.WoW5:ConvertMOB(unit,sguid); end

	if (not LootCount_DropCount_DB.Count[sguid]) then
		DropCount.Tooltip:SetNPCContents(unit);
		return;
	end

	if (type(AltTT)~="table") then
		compact=AltTT;
		AltTT=LootCount_DropCount_TT;
	end
	AltTT:ClearLines();
	AltTT:SetOwner(UIParent,"ANCHOR_CURSOR");
	local text="";
	local mTable=DropCount.DB.Count:Read(sguid);
	if (not mTable.Kill) then mTable.Kill=0; end
	LootCount_DropCount_Character.MouseOver=DropCount:CopyTable(mTable);
	if (not LootCount_DropCount_Character.CompactView) then
		AltTT:SetText(unit);
		if (mTable.Skinning and mTable.Skinning>0) then text="Profession-loot: "..mTable.Skinning.." times"; end
		AltTT:LCAddDoubleLine(mTable.Kill.." kills",text,.4,.4,1,1,0,1);
	else
		text=unit.." |cFF6666FFK:"..mTable.Kill;
		if (mTable.Skinning and mTable.Skinning>0) then text=text.." |cFFFF00FFP:"..mTable.Skinning; end
		AltTT:SetText(text);
	end

	local list={};
	local line=1;
	local missingitems=0;
	local itemsinlist=nil;
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (iData:find(sguid,1,true)) then		-- Plain search
			local iTable=DropCount.DB.Item:Read(item);
			if (iTable.Name and iTable.Name[sguid]) then
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
				elseif (LootCount_DropCount_Character.ShowSingle or questitem or iTable.Name[sguid]~=1) then
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local thisratio,_,thissafe=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
					if (iTable.Quest) then list[line].Quests=DropCount:CopyTable(iTable.Quest); end
					line=line+1;
					itemsinlist=true;
				end
			end
			if (iTable.Skinning and iTable.Skinning[sguid]) then
				local itemname,_,rarity=GetItemInfo(item);
				if (not itemname or not rarity) then
					DropCount.Cache:AddItem(item);
					missingitems=missingitems+1;
				else
					local _,_,_,colour=GetItemQualityColor(rarity); colour="|c"..colour;
					local _,thisratio,thissafe=DropCount:GetRatio(item,sguid);
					list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
					list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext;	-- AARRGGBB
					if (iData.Quest) then list[line].Quests=DropCount:CopyTable(iData.Quest); end
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
		if (((compact and IsShiftKeyDown()) or not compact) and list[line].Quests) then
			for quest,amount in pairs(list[line].Quests) do
				if (LootCount_DropCount_DB.Quest and LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then
					for npc,rawData in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
						if (rawData:find(quest,1,true)) then
							local qData=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
							if (qData.Quests) then
								for _,qListData in ipairs(qData.Quests) do
									if (qListData.Quest==quest) then
										if (not qListData.Header) then
											AltTT:LCAddSmallLine("   "..amount.." for "..quest,.5,.3,.2);
										else
											AltTT:LCAddSmallLine("   "..amount.." for "..quest.." ("..qListData.Header..")",.5,.3,.2);
										end
										AltTT:LCAddSmallLine("   |cFFFFFF00   ! |r"..npc.." ("..qData.Zone.." - "..math.floor(qData.X)..","..math.floor(qData.Y)..")",.5,.3,.2);
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
--DropCount:Chat("NORM: "..widget.LCSize);
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
			if (xml) then
				xml.Tooltip=entry.Tooltip;
				wipe(xml.DB); xml.DB=nil;
				xml.DB=entry.DB;
			end
		end
	end
end

DropCount.Search={ _section="", _result={}, };

function DropCount.Search:Found(section,entry,tooltip,db,icon)
	if (not self._result[section]) then self._result[section]={}; end
	table.insert(self._result[section],{ Entry=entry, Tooltip=tooltip, DB=db, Icon=icon });
end

function DropCount.Search:Do(find,uVen,uQue,uBoo,uIte,uMob,uTra)
	find=strtrim(find); if (find=="") then return; end
	if (not find) then return; end
	find=find:lower();
	wipe(self._result);

	-- Search vendors
	local entry;
	local started=nil;
	if (uVen) then
		for vendor,vData in pairs(LootCount_DropCount_DB.Vendor) do
			local testdata=vData; testdata=testdata:lower();
			if (testdata:find(find,1,true)) then
				local X,Y,Zone,Faction,Repair=DropCount.DB.Vendor:ReadBaseData(vendor);
				if (Faction==CONST.MYFACTION or Faction=="Neutral") then
					local tt={Faction.." vendor: "..vendor,Zone..string.format(" (%.0f,%.0f)",X,Y)};
					if (Repair) then table.insert(tt,"Can repair your stuff"); end
					self:Found(	"Vendor",
								Zone..": "..vendor,
								tt,
								{Section="Vendor",Entry=vendor,Data=vData});
				end
			end
		end
	end

	-- Search quests
	if (uQue) then
		started=nil;
		for npc,nData in pairs(LootCount_DropCount_DB.Quest[CONST.MYFACTION]) do
			local testdata=nData; testdata=testdata:lower();
			if (testdata:find(find,1,true)) then
				local npcData=DropCount.DB.Quest:Read(CONST.MYFACTION,npc);
				self:Found(	"Quest",
							npcData.Zone..": "..npc,
							{"Quest-giver: "..npc,npcData.Zone..string.format(" (%.0f,%.0f)",npcData.X,npcData.Y)},
							{Section="Quest",Entry=npc,Data=nData});
			end
		end
	end

	-- Search books
	if (uBoo) then
		started=nil;
		for book,bData in pairs(LootCount_DropCount_DB.Book) do
			local include=nil;
			local testdata=book; testdata=testdata:lower();
			if (testdata:find(find,1,true)) then include=true;
			else
				for _,iData in ipairs(bData) do
					local testdata=iData.Zone; testdata=testdata:lower();
					if (testdata:find(find,1,true)) then include=true; break; end
				end
			end
			if (include) then
				local tt={"Book: "..book};
				for index,iData in ipairs(bData) do
					table.insert(tt,iData.Zone..string.format(" (%.0f,%.0f)",iData.X,iData.Y));
				end
				self:Found(	"Book",
							book,
							tt,
							{Section="Book",Entry=npc});
			end
		end
	end

	-- Search items
	if (uIte) then
		started=nil;
		for item,iData in pairs(LootCount_DropCount_DB.Item) do
			local testdata=iData; testdata=testdata:lower();
			if (testdata:find(find,1,true)) then
				DropCount.Cache:AddItem(item);
				local itemData=DropCount.DB.Item:Read(item);
				self:Found(	"Item",
							itemData.Item,
							nil,
							{Section="Item",Entry=item,Data=itemData},
							GetItemIcon(item));
			end
		end
	end

	-- Search mobs
	if (uMob) then
		started=nil;
		for mob,data in pairs(LootCount_DropCount_DB.Count) do
			local testmob=mob; testmob=testmob:lower();
			local testdata=data; testdata=testdata:lower();
			if (testmob:find(find,1,true) or testdata:find(find,1,true)) then
				local t=DropCount.DB.Count:Read(mob);
				if (t.Name) then testmob=t.Name; else testmob=mob; end	-- if converted, use name entry
				self:Found(	"Creature",
							testmob,
							nil,
							{Section="Creature",Entry=mob});
			end
		end
	end

	-- Search trainers
	if (uTra) then
		started=nil;
		for npc,nData in pairs(LootCount_DropCount_DB.Trainer[CONST.MYFACTION]) do
			local testdata=nData; testdata=testdata:lower();
			if (testdata:find(find,1,true)) then
				local npcData=DropCount.DB.Trainer:Read(npc);
				self:Found(	"Trainer",
							npcData.Zone..": "..npc,
							{"Trainer "..npc..": "..npcData.Service,npcData.Zone..string.format(" (%.0f,%.0f)",npcData.X,npcData.Y)},
							{Section="Trainer",Entry=npc,Data=nData});
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
			local _,thisid=DropCount:GetID(DropCount.ThisBuffer.User.itemID);
			if (not LootCount_DropCount_NoQuest[thisid]) then info.checked=true; end
			info.text="Only drops when on a quest"; info.value=thisid; info.func=DropCount.Menu.ToggleQuestItem; UIDropDownMenu_AddButton(info,1);

			info.isTitle=1; info.checked=nil; info.func=nil; info.text=" "; UIDropDownMenu_AddButton(info,1);
		end
	end

	info.isTitle=1; info.checked=nil; info.func=nil; info.text="Global settings for "..LOOTCOUNT_DROPCOUNT_VERSIONTEXT..":"; UIDropDownMenu_AddButton(info,1); info.isTitle=nil; info.disabled=nil;

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
	if (not DropCount.LootCount.Registered) then return; end
	local user=LootCountAPI.User(DropCount.ThisBuffer);
	LootCount_SetGoalPopup(DropCount.ThisBuffer);
end

function DropCount:CleanDB()
	local text=CONST.C_BASIC.."DropCount:|r ";

	if (DropCount.Debug) then
--		collectgarbage("collect");
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
		DropCount:Chat(CONST.C_BASIC.."DropCount: "..CONST.C_GREEN..nowitems..CONST.C_BASIC.." known books ("..CONST.C_GREEN..volumes..CONST.C_BASIC.." total volumes)");
	end
	if (LootCount_DropCount_DB.Vendor) then
		nowmobs=0;
		for vendor,vTable in pairs(LootCount_DropCount_DB.Vendor) do nowmobs=nowmobs+1; end
		DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN..nowmobs.."|r known vendors");
	end
	if (LootCount_DropCount_DB.Quest) then
		nowmobs=0;
		for _,fTable in pairs(LootCount_DropCount_DB.Quest) do
			for _,nTable in pairs(fTable) do
				nowmobs=nowmobs+1;
			end
		end
		DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN..nowmobs.."|r known quest-givers");
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
	DropCount:Chat(text);

	if (nowitems-LootCount_DropCount_StartItems>0 or nowmobs-LootCount_DropCount_StartMobs>0) then
		DropCount:Chat(CONST.C_BASIC.."DropCount:|r New this session: "..CONST.C_GREEN..nowitems-LootCount_DropCount_StartItems.."|r items, "..CONST.C_GREEN..nowmobs-LootCount_DropCount_StartMobs.."|r mobs");
	end
	DropCount:Chat(CONST.C_BASIC.."Type "..CONST.C_GREEN..SLASH_DROPCOUNT2..CONST.C_BASIC.." to view options");
	DropCount:Chat(CONST.C_BASIC.."Please consider sending your SavedVariables file to "..CONST.C_YELLOW.."dropcount@ybeweb.com"..CONST.C_BASIC.." to help develop the DropCount addon.");
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
		bX,bY=DropCount:GetPlayerPosition();
		bZone=DropCount:GetFullZone();
		Map=DropCount:GetMapTable()
		silent=nil;
	end
	if (not bZone) then bZone="Unknown"; end
	local i=1;
	local newBook,updatedBook=0,0;
	if (not LootCount_DropCount_DB.Book[BookName]) then
		if (not silent) then DropCount:Chat(CONST.C_BASIC.."Location of new book "..CONST.C_GREEN.."\""..BookName.."\""..CONST.C_BASIC.." saved"); end
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
		MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
		DropCount:Chat(CONST.C_BASIC..BookName..CONST.C_GREEN.." saved. "..CONST.C_BASIC..i.." volumes known.");
	end
	return newBook,updatedBook;
end

function DropCount:SaveTrainer(name,service,zone,x,y,faction)
	if (not faction) then faction=CONST.MYFACTION; end
--print(name,service,zone,x,y,faction);
	if (not LootCount_DropCount_DB.Trainer) then LootCount_DropCount_DB.Trainer={}; end
	if (not LootCount_DropCount_DB.Trainer[faction]) then LootCount_DropCount_DB.Trainer[faction]={}; end
	local base=LootCount_DropCount_DB.Trainer[faction];
	DropCount.DB.Trainer:Write(name,{Service=service,Zone=zone,X=x,Y=y},faction);
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
end

function DropCountXML:OnUpdate(frame,elapsednow)
	if (not DropCount.Loaded) then return; end
	MT.FastMT=elapsednow*0.99;				-- aim at slighly higher fps for fast switching
	if (MT.FastMT>MT.Speed) then MT.FastMT=MT.Speed; end	-- limit to slowest MT
	MT:Next();		-- Run multi-threading
	DropCount.Loaded=DropCount.Loaded+elapsednow;
	DropCount.Tracker.Elapsed=DropCount.Tracker.Elapsed+elapsednow;
	if (not DropCount.Tracker.Exited) then return; end	-- block for real MT
	DropCount.Tracker.Exited=nil;
	local elapsed=DropCount.Tracker.Elapsed;
	DropCount.Tracker.Elapsed=0;

	if (DropCount.Loaded>10) then					-- block for held processes
		if (DropCount_Local_Code_Enabled) then		-- block only for me
			DropCount.Update=DropCount.Update+elapsed;
			if (DropCount.Update>=20) then
				DropCount.Update=0;
				if (DropCountXML.ARL and DropCountXML.ARL.Importing==false) then
--					DropCountXML.ARL:Import()
				end
			end
		end
	end

	-- add quest-ID
	if (not CONST.QUESTID and (not DropCount.Tracker.UnknownItems or not DropCount.Tracker.UnknownItems["item:31812"])) then
		_,_,_,_,_,CONST.QUESTID=GetItemInfo("item:31812");
		if (not CONST.QUESTID) then
			DropCount.Cache:AddItem("item:31812")
--		else
--			DropCount.Convert:One();
		end
	end

	-- delayed merchant read
	if (DropCount.Timer.VendorDelay>=0) then
		DropCount.Timer.VendorDelay=DropCount.Timer.VendorDelay-elapsed;
		if (DropCount.Timer.VendorDelay<0) then
			if (not DropCount:ReadMerchant(DropCount.Target.OpenMerchant)) then
				DropCount.Timer.VendorDelay=.5;
			end
		end
	end

	DropCount.OnUpdate:RunMouseoverInWorld();
	DropCount.OnUpdate:MonitorReadableTexts();
	if (DropCount.Tracker.UnknownItems) then DropCount.OnUpdate:RunUnknownItems(elapsed); end
	if (DropCount.Tracker.QueueSize>0) then DropCount.OnUpdate:RunTimedQueue(); end
	if (GameTooltip and GameTooltip:IsVisible()) then DropCount.OnUpdate:MonitorGameTooltip(); end
	if (DropCount.Tracker.MobList.button) then DropCount.OnUpdate:RunMobList(); end
	if (DropCount.Timer.StartupDelay) then DropCount.OnUpdate:RunStartup(elapsed); end
	if (LCDC_RescanQuests) then DropCount.OnUpdate:RunQuestScan(elapsed); end
	if (LootCount_DropCount_DB.QuestQuery) then DropCount.OnUpdate:WalkOldQuests(elapsed); end

	if (DropCount.SpoolQuests) then DropCount:WalkQuests(); end

	if (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
		if (not self.CTF) then
			self.CTF=true;
			local isEnabled = GetTrainerServiceTypeFilter("used")
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",1); end
			local trainerService=GetTrainerServiceSkillLine(1);
--print("Trainer: "..trainerService);
			if (not isEnabled) then SetTrainerServiceTypeFilter("used",0); end
			if (IsTradeskillTrainer()) then		-- this filters out riding trainers
				DropCount:SaveTrainer(DropCount.Target.CurrentAliveFriendClose,trainerService,DropCount:GetFullZone(),DropCount:GetPlayerPosition());
			end
		end
	else
		self.CTF=nil;
	end

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

			LootCount_DropCount_DB.RAID=nil;
			if (IsInGuild()) then LootCount_DropCount_DB.GUILD=true; else LootCount_DropCount_DB.GUILD=nil; end
			LootCountAPI.Register(info);
			DropCount.LootCount.Registered=true;
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN.."LootCount detected. DropCount is available from the LootCount menu.");
		end
	end
	if (not DropCount.Crawler.Registered) then
		if (CrawlerXML and CrawlerXML.SetPlugin) then
			CrawlerXML:SetPlugin("DropCount",DropCount.Crawler);
			DropCount.Crawler.Registered=true;
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_GREEN.."Crawler detected. DropCount is available as a Crawler plug-in.");
		end
	end
	DropCount.Tracker.Exited=true;
end

function DropCount.OnUpdate:RunMobList()
	DropCount.Tooltip:MobList(	DropCount.Tracker.MobList.button,
								DropCount.Tracker.MobList.plugin,
								DropCount.Tracker.MobList.limit,
								DropCount.Tracker.MobList.down);
end

-- Keep un-MT'd
function DropCount.OnUpdate:RunUnknownItems(elapsed)
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
					DropCount:Chat("Converting DropCount database: "..i.." items left...",0,1,1);
				end
			end
		end
	end
	if (DropCount.Cache.Retries>=CONST.CACHEMAXRETRIES) then
		if (DropCount.Search.Item==DropCount.Tracker.RequestedItem) then
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Could not retrieve information for this item from the server.");
			DropCount.Search.Item=nil;
		elseif (DropCount.Search.mobItem==DropCount.Tracker.RequestedItem) then
			DropCount:Chat(CONST.C_BASIC.."DropCount:|r "..CONST.C_RED.."Could not retrieve information for this item from the server.");
			DropCount.Search.mobItem=nil;
		end
		DropCount:Chat("Not retrievable: "..DropCount.Tracker.RequestedItem,1);
		if (LootCount_DropCount_DB.Item and
				LootCount_DropCount_DB.Item[DropCount.Tracker.RequestedItem]) then
			local iTable=DropCount.DB.Item:Read(DropCount.Tracker.RequestedItem);
			if (iTable.Item) then
				DropCount:Chat("\""..DropCount.Tracker.RequestedItem.."\" seem to be \""..iTable.Item.."\"",1);
			end
		end
		DropCount:Chat("This can happen if it has not been seen on the server since last server restart.",1);
		DropCount.Tracker.UnknownItems=nil;			-- Too many tries, so abort
		DropCount.Tracker.RequestedItem=nil;
	end
end

function DropCount.OnUpdate:RunMouseoverInWorld()
	if (UnitExists("mouseover")) then
		local modifier=IsAltKeyDown();
		local unit=UnitName("mouseover");
		local sguid=UnitGUID("mouseover"):sub(7,10);	-- MoP
		if (LootCount_DropCount_DB.Count[unit] and LootCount_DropCount_Character.InvertMobTooltip) then
			modifier=(not modifier);
		end
		if (modifier) then
			if (not LootCount_DropCount_TT:IsVisible()) then DropCount:SetLootlist(unit,sguid,LootCount_DropCount_Character.CompactView);
			elseif (LootCount_DropCount_TT.Loading) then
				LootCount_DropCount_TT:Hide();
				DropCount:SetLootlist(unit,sguid,LootCount_DropCount_Character.CompactView);
			end
			return;
		end
	end
	if (not LCDC_VendorFlag_Info) then
		if (LootCount_DropCount_TT:IsVisible()) then LootCount_DropCount_TT:Hide(); end
	end
end

function DropCount.OnUpdate:RunTimedQueue()
	local now=time();
	if (now-DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize].Time>CONST.QUEUETIME) then
		DropCount.Tracker.TimedQueue[DropCount.Tracker.QueueSize]=nil;
		DropCount.Tracker.QueueSize=DropCount.Tracker.QueueSize-1;
		if (DropCount.LootCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
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

function DropCount.OnUpdate:MonitorGameTooltip()
	if (not GameTooltip or not GameTooltip:IsVisible()) then return; end
	if (not IsControlKeyDown() and not IsAltKeyDown()) then return; end
	local _,ThisItem=GameTooltip:GetItem();
	if (not ThisItem) then return; end
	ThisItem=DropCount:GetID(ThisItem);
	if (ThisItem) then
		if (IsControlKeyDown()) then DropCount.Tooltip:VendorList(ThisItem);
		elseif (IsAltKeyDown()) then DropCount.Tooltip:MobList(ThisItem);
		end
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
	if (DropCount.Timer.PrevQuests<0 and LootCount_DropCount_DB.QuestQuery) then
		local count=nil;
		for qIndex,_ in pairs(LootCount_DropCount_DB.QuestQuery) do
			count=true;
			local qName=DropCount:GetQuestName("quest:"..qIndex);
--print("qName",qName);
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

function DropCount.MT.DB:CleanImport()
	local sects=0;
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		sects=sects+1;
	end
	if (DropCount.Debug) then
		DropCount:Chat("Cleaning import data: "..sects.." sections.",.8,.8,1);
	end
	for s,md in ipairs(LootCount_DropCount_MergeData) do
		if (DropCount.Debug) then DropCount:Chat("Cleaning section "..s,.8,.8,1); end
		if (not md.Count) then
			DropCount.Tracker.CleanImport.Cleaned=true;
			return;
		end

		DropCount.MT.DB.Maintenance:_0x(md,true);		-- Check for WoW 4.2 combatmessage f-up
		DropCount.MT.DB.Maintenance:_KillHotwiredLoot(md,true);	-- Check for Pandaria hotwired addons
		DropCount.MT.DB.Maintenance:_Skinning(md,true);
		DropCount.MT.DB.Maintenance:_Kill(md,true);

		DropCount.Tracker.CleanImport.Okay=DropCount.Tracker.CleanImport.Okay+1;

		if (not checkMob) then
			if (DropCount.Debug) then
				DropCount:Chat("Cleaning import data done",.8,.8,1);
				DropCount:Chat("Deleted: "..DropCount.Tracker.CleanImport.Deleted,.8,.8,1);
				DropCount:Chat("Okay: "..DropCount.Tracker.CleanImport.Okay,.8,.8,1);
			end
			DropCount.Tracker.CleanImport.Cleaned=true;
--			collectgarbage("collect");
		end
	end
end

-- Check for WoW 4.2 combatmessage f-up
function DropCount.MT.DB.Maintenance:_0x(t,y)
--print("_0x start");
	if (not t or not t.Count) then return; end
	for m in pairs(t.Count) do
		if (m:find("0x",1,true)==1) then
			DropCount:RemoveFromItems("Name",m,t) MT:Yield(y);
			DropCount:RemoveFromItems("Skinning",m,t)
			t.Count[m]=nil;
			DropCount.Tracker.CleanImport.Deleted=DropCount.Tracker.CleanImport.Deleted+1;
			if (DropCount.Debug) then DropCount:Chat("("..DropCount.Tracker.CleanImport.Deleted.."/"..DropCount.Tracker.CleanImport.Deleted+DropCount.Tracker.CleanImport.Okay..") "..m.." has been deleted.",.8,.8,1); end
		end
		MT:Yield();			-- "slow"
	end
	Table:PurgeCache(DM_WHO);
--print("_0x end");
end

-- Check that mobs have registered drops for their loot type
function DropCount.MT.DB.Maintenance:_Skinning(t,y) return self:_Drop(t,"Skinning",y); end
function DropCount.MT.DB.Maintenance:_Kill(t,y) return self:_Drop(t,"Kill",y); end
-- Check drop sections for validity
function DropCount.MT.DB.Maintenance:_Drop(t,s,y)
--print("_Drop start");
	local si=s;
	if (si=="Kill") then si="Name"; end	-- items do "Name"
	if (s=="Name") then s="Kill"; end	-- mobs do "Kill"
	for m,md in pairs(t.Count) do
		if (md:find(s,1,true)) then	-- possibly had this drop type
			local mt=DropCount.DB.Count:Read(m,t.Count);
			if (mt and mt[s] and mt[s]>2) then	-- got it
				local foundone=nil;
				for i,id in pairs(t.Item) do		-- cycle items
					if (id:find(m,1,true)) then		-- possible mob precense
						local it=DropCount.DB.Item:Read(i,t.Item);
						if (it and it[si] and it[si][m] and it[si][m]>0) then	-- dropped by said mob and not quest item
							foundone=true; break;	-- drop exists
						end
					end
					MT:Yield();		-- must be slow to ever finish
				end
				if (not foundone) then		-- no skinning drop for skinned mob
					DropCount:RemoveFromItems("Name",m,t,true); MT:Yield(y);
					DropCount:RemoveFromItems("Skinning",m,t,true);
					LootCount_DropCount_DB.Count[m]=nil;
					if (DropCount.Debug) then DropCount:Chat(s.."-drop missing: "..(mt.Name or m).." deleted.",.8,.8,1); end
					Table:PurgeCache(DM_WHO);
				else
					MT:Yield(y);
				end
			end
		else
			MT:Yield(y);
		end
	end
	Table:PurgeCache(DM_WHO);
--print("_Drop end");
end

-- Check for Pandaria hotwired addons
function DropCount.MT.DB.Maintenance:_KillHotwiredLoot(t,y)
--print("_KillHotwiredLoot start");
	local first=time({year=2012,month=8,day=28});
	for i in pairs(t.Item) do
		local buf=DropCount.DB.Item:Read(i,t.Item);
		if (buf and buf.Time and buf.Time>first and buf.Time<time()) then
			if (LootCount_DropCount_DB.LocalImporter) then
				print("==>> Importer found:",buf.Item or i,date("%c",buf.Time));
			end
			if (t~=LootCount_DropCount_DB or not LootCount_DropCount_DB.LocalImporter) then
				if (buf.Name) then
					for m in pairs(buf.Name) do
						DropCount:RemoveFromItems("Name",m,t,true); MT:Yield(true);
						LootCount_DropCount_DB.Count[m]=nil;
						MT:Yield(y);
						Table:PurgeCache(DM_WHO);
					end
				end
				if (buf.Skinning) then
					for m in pairs(buf.Skinning) do
						DropCount:RemoveFromItems("Skinning",m,t,true); MT:Yield(true);
						LootCount_DropCount_DB.Count[m]=nil;
						MT:Yield(y);
						Table:PurgeCache(DM_WHO);
					end
				end
				LootCount_DropCount_DB.Item[i]=nil;
			else
				MT:Yield();		-- "slow"
			end
		else
			MT:Yield(y);
		end
	end
--print("_KillHotwiredLoot end");
end

-- This can run for too long
-- Hopefully fixed now by removing garbagecollect
function DropCount.MT.DB:CleanDatabase()
	if (DropCount.Debug) then DropCount:Chat("Running low-impact background database cleaner..."); end
--print("starting");

	-- Remove QG without quests or location 0,0
	for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
		for qg,qgd in pairs(fTable) do									-- All factions
			local x,y=qg:match("^%- item %- %(.+ %- .+ (%d+)%,(%d+)%)$");
			if (x and y and (x=="0" or y=="0")) then
				fTable[qg]=nil;
				Table:PurgeCache(DM_WHO);
				if (DropCount.Debug) then
					DropCount:Chat("Misplaced QG: "..faction..": "..qg.." deleted",.8,.8,1);
				end
--			elseif (not DropCount.DB.Quest:Read(faction,qg).Quests) then
			elseif (not qgd:find("Quests",1,true) and not DropCount.DB.Quest:Read(faction,qg).Quests) then
				fTable[qg]=nil;
				Table:PurgeCache(DM_WHO);
				if (DropCount.Debug) then
					DropCount:Chat("Empty QG: "..faction..": "..qg.." deleted",.8,.8,1);
				end
			end
			MT:Yield(true);		-- maintain low profile ("too long" has happened here)
		end
		Table:PurgeCache(DM_WHO);
	end
--print("Empty and misplaced QG done");
	DropCount.WeHaveCleanDatabaseQG=true;

	DropCount.MT.DB.Maintenance:_0x(LootCount_DropCount_DB,true);		-- Check for WoW 4.2 combatmessage f-up
	DropCount.MT.DB.Maintenance:_Skinning(LootCount_DropCount_DB,true);
	DropCount.MT.DB.Maintenance:_Kill(LootCount_DropCount_DB,true);

	if (DropCount.Debug) then
		DropCount:Chat("Cleaning database done.",.8,.8,1);
	end
end

function DropCount.MT.DB:CleanDatabaseQG()
--DropCount.Debug=true;
	repeat MT:Yield(true); until (DropCount.WeHaveCleanDatabaseQG);		-- wait until QG DB cleaning is done
	if (DropCount.Debug) then DropCount:Chat("Running QG cleaner..."); end

--"- item - (Uldum 39,67)"
--"- item - (Uldum - Obelisk of the Sun 42,57)"
--"- item - (Stormwind City - Wizard's Sanctum 48,87)"

	local scanA="^%- item %- %((.+) %- .+ %d+%,%d+%)$";				-- Set filter A
	local scanB="^%- item %- %((.+) %d+%,%d+%)$";					-- Set filter B
	local scanI="^%- item %- %(.+ %d+%,%d+%)$";						-- Set filter item
	local buf={};

	-- Remove duplicate same-zone item quest givers
	for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
		for qg,qgr in pairs(fTable) do									-- All factions
			-- find zone for this npc or item
			local zone=qg:match(scanA);									-- Get zone if any
			if (not zone) then zone=qg:match(scanB); end
			if (not zone) then											-- no zone, so npc
				zone=DropCount.DB.Quest:Read(faction,qg).Zone;			-- get npc's zone
				if (zone:find(" - ",1,true)) then
					zone=zone:match("^(.+) %- .+$");					-- main zone only
				end
			end
			-- spool all item qg for that zone
			wipe(buf);
			for _qg,_qgr in pairs(fTable) do							-- spool zone
				if (_qg:find(zone,1,true)) then							-- zone in item QG name
					table.insert(buf,_qg);
				end
				MT:Yield();		-- low fps for a fraction of a second as opposed to 10 minutes or lag
			end
--			if (DropCount.Debug) then DropCount:Chat("QGC: "..faction..", "..zone..", "..#buf.." items"); end
			local qgd=DropCount.DB.Quest:Read(faction,qg);				-- get first item
			-- cycle all same-zone item qg
			for _bi,_qg in pairs(buf) do								-- spool zone
				local _zone=_qg:match(scanA);							-- get zone if any
				if (not _zone) then _zone=_qg:match(scanB); end
				if (_zone and _zone==zone and qg~=_qg) then				-- same zone, different item
					-- compare quests to find duplicates and remove them
					for i,q in ipairs(qgd.Quests) do					-- cycle first quests
						if (fTable[_qg]:find(tostring(q.ID)) and fTable[_qg]:find(q.Quest) and fTable[_qg]:find(q.Header)) then	-- All strings present
							local _qgd=DropCount.DB.Quest:Read(faction,_qg);	-- Get tester item
							for _i,_q in ipairs(_qgd.Quests) do			-- cycle tester quests
								-- Has same quest?
								if (_q.ID==q.ID and _q.Quest==q.Quest and _q.Header==q.Header) then
									table.remove(_qgd.Quests,_i);
									if (DropCount.Debug) then
										DropCount:Chat("Duplicate "..faction.." QI: ".._qg,.8,.8,1);
										DropCount:Chat("Deleted: "..q.Quest.." in "..q.Header,.8,.8,1);
									end
									-- only save if there are more quests as empty will be deleted
									if (next(_qgd.Quests)) then			-- check for more quest
										DropCount.DB.Quest:Write(_qg,_qgd,faction);
									end
									break;
								end
							end
							if (not next(_qgd.Quests)) then				-- check for empty quest list
								fTable[_qg]=nil;
								Table:PurgeCache(DM_WHO,true);
								break;
							end
						end
						MT:Yield(true);		-- maintain low profile
					end
				end
			end
		end
	end
	Table:PurgeCache(DM_WHO);
--print("Double item-QG done");

	if (DropCount.Debug) then DropCount:Chat("Cleaning QG database done.",.8,.8,1); end
end

function DropCount.MT:ConvertAndMerge()
	-- Check for really old stuff
	while (DropCount.Loaded<=10) do MT:Yield(true); end
	if (not LootCount_DropCount_DB.Converted or LootCount_DropCount_DB.MergedData<5) then
		LootCount_DropCount_DB.MergedData=5;
		LootCount_DropCount_DB.Converted=7;
		LootCount_DropCount_DB.Vendor={};
		LootCount_DropCount_DB.Book={};
		LootCount_DropCount_DB.Item={};
		LootCount_DropCount_DB.Quest={};
		LootCount_DropCount_DB.Count={};
--		collectgarbage("collect");
	end
	if (not LootCount_DropCount_MergeData) then return; end

	-- Strip data
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		if (LootCount_DropCount_DB.DontFollowMobsAndDrops) then
			wipe(LootCount_DropCount_DB.Count); wipe(md.Count);
			wipe(LootCount_DropCount_DB.Item); wipe(md.Items);
		end
		if (LootCount_DropCount_DB.DontFollowVendors) then
			wipe(LootCount_DropCount_DB.Vendor); wipe(md.Vendor);
		end
		if (LootCount_DropCount_DB.DontFollowQuests) then
			wipe(LootCount_DropCount_DB.Quest); wipe(md.Quest);
		end
		if (LootCount_DropCount_DB.DontFollowTrainers) then
			wipe(LootCount_DropCount_DB.Trainer); wipe(md.Trainer);
		end
		if (LootCount_DropCount_DB.DontFollowForges) then
			wipe(LootCount_DropCount_DB.Forge); wipe(md.Forge);
		end
	end
--DropCount.Debug=true;

	-- convert known GUID/name
	if (LootCount_DropCount_MergeData.Version~=LootCount_DropCount_DB.MergedData) then
		DropCount:Chat("New version of DropCount has been installed.",.6,1,.6);
		DropCount:Chat("Due to WoW loot bugs (and some users' unskilled DropCount hacks), an extended database check has been implemented. This is a must for it to work at all with Pandaria.",.6,.6,1);
		DropCount:Chat("During this time, your fps will drop to about 30. I am very sorry for this inconvenience. This will only happen once after installing a new version, so it is recommended to let it finish.",.6,.6,1);
		DropCount:Chat("You can log out during this period if you so wish, and the operation will restart when you log back in. You will be presented with a summary when all operations have finished.",.6,.6,1);
	end

	-- Check for hotwired addons for aoe loot changes
	if (not LootCount_DropCount_DB.FixedHotWired or DropCount.Debug) then
		DropCount:Chat("Running post-Pandaria database clean-up...");
		DropCount.MT.DB.Maintenance:_KillHotwiredLoot(LootCount_DropCount_DB,true);	-- Check for Pandaria hotwired addons
		LootCount_DropCount_DB.FixedHotWired=time();
	end

	-- convert known GUID/name
	if (LootCount_DropCount_MergeData.Version~=LootCount_DropCount_DB.MergedData) then
		DropCount:Chat("Running database integrity check...");
--print("Setting GUID in mergedata from local...");
		for _,md in ipairs(LootCount_DropCount_MergeData) do
			if (md.Count) then
				for name,rawn in pairs(md.Count) do
					local datan=DropCount.DB.Count:Read(name,md.Count);
					if (not datan.Name) then	-- need conversion
						for sguid,rawg in pairs(LootCount_DropCount_DB.Count) do
							if (rawg:find(name,1,true) and strlen(sguid)==4 and tonumber(sguid,16)) then
								local datag=DropCount.DB.Count:Read(sguid);
								if (datag.Name==name) then
									DropCount.WoW5:ConvertMOB(name,sguid,md);
									Table:PurgeCache(DM_WHO);
								end
								MT:Yield();
							end
						end
					end
					MT:Yield();
				end
				Table:PurgeCache(DM_WHO);
--print("Setting GUID in local from mergedata...");
				for name,rawn in pairs(LootCount_DropCount_DB.Count) do
					local datan=DropCount.DB.Count:Read(name);
					if (not datan.Name) then	-- need conversion
						for sguid,rawg in pairs(md.Count) do
							if (rawg:find(name,1,true) and strlen(sguid)==4 and tonumber(sguid,16)) then
								local datag=DropCount.DB.Count:Read(sguid,md.Count);
								if (datag.Name==name) then
									DropCount.WoW5:ConvertMOB(name,sguid);
									Table:PurgeCache(DM_WHO);
								end
								MT:Yield();
							end
						end
					end
					MT:Yield();
				end
				Table:PurgeCache(DM_WHO);
			end
		end
--print("GUIDs inserted");
	end

	if (DropCount_Local_Code_Enabled) then DropCount.MT.DB:CleanImport(); end
	DropCount.Tracker.CleanImport.Cleaned=true;

	-- Merge and make tidiefy a bit
	DropCount.MT:MergeDatabase();
	wipe(LootCount_DropCount_MergeData); LootCount_DropCount_MergeData=nil;

	if (LootCount_DropCount_DB.MergedData~=LootCount_DropCount_DB.CleanedData) then
		DropCount.MT.DB:CleanDatabase();	-- no need all the time
		LootCount_DropCount_DB.CleanedData=LootCount_DropCount_DB.MergedData;
	end
	if (LootCount_DropCount_DB.MergedData~=LootCount_DropCount_DB.CleanedDataQG) then
		DropCount.MT.DB:CleanDatabaseQG();	-- no need all the time
		LootCount_DropCount_DB.CleanedDataQG=LootCount_DropCount_DB.MergedData;
	end
--	collectgarbage("collect");
end

function DropCount:RemoveFromDatabase()
	-- Delete quests from database
	if (LootCount_DropCount_RemoveData.Quest and LootCount_DropCount_DB.Quest) then
		for faction,fTable in pairs(LootCount_DropCount_RemoveData.Quest) do
			for npc,_ in pairs(fTable) do
--				local nTable=DropCount.DB.Quest:Read(faction,npc,LootCount_DropCount_RemoveData.Quest);
				local nTable=LootCount_DropCount_RemoveData.Quest[faction][npc];
				if (not nTable.Quests) then			-- Remove entire NPC
					if (LootCount_DropCount_DB.Quest[faction]) then
						LootCount_DropCount_DB.Quest[faction][npc]=nil;
					end
				else								-- Remove specific quest
					if (LootCount_DropCount_DB.Quest[faction] and LootCount_DropCount_DB.Quest[faction][npc]) then
						local tempTable=DropCount.DB.Quest:Read(faction,npc);	-- Get said NPC
						for _,qTable in pairs(nTable.Quests) do					-- Walk quests to remove
							local index=1;
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
									tempTable.Quests[index]=DropCount:CopyTable(tempTable.Quests[index+1]);
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
	-- delete drops from creatures
	if (LootCount_DropCount_RemoveData.Count and LootCount_DropCount_DB.Count) then
		for npc,nData in pairs(LootCount_DropCount_RemoveData.Count) do
			if (LootCount_DropCount_DB.Count[npc]) then
				for section,item in pairs(nData) do
					local iSect=section;
					if (iSect=="Kill") then iSect="Name"; end
					if (type(item)=="table") then				-- remove named items
						for _,item in pairs(item) do
							DropCount:RemoveMobFromItem(item,npc,iSect);	-- remove from item loot list
						end
					elseif (type(item)=="boolean") then			-- remove entire section
						local mTable=DropCount.DB.Count:Read(npc);
						if (mTable[section]) then
							mTable[section]=nil;					-- Kill it
							DropCount.DB.Count:Write(npc,mTable);	-- save it
							DropCount:RemoveFromItems(iSect,npc);	-- remove from all loot lists
						end
					end
				end
			end
		end
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

	-- remove items from game
	if (LootCount_DropCount_RemoveData.Item and LootCount_DropCount_DB.Item) then
		for item,iRaw in pairs(LootCount_DropCount_RemoveData.Item) do
			if (iRaw==false) then
				LootCount_DropCount_DB.Item[item]=nil;
			end
		end
	end
end

function DropCount:IsEmpty(check)
	if (not check) then return true; end
	if (next(check)) then return nil; end
	return true;
end

function DropCount:RemoveFromItems(section,npc,base,y)
	if (not base) then base=LootCount_DropCount_DB; end
	if (not base.Item) then return; end
	for item,iData in pairs(base.Item) do
		if (string.find(iData,npc,1,true)) then
			local iTable=DropCount.DB.Item:Read(item,base.Item);
			if (iTable[section]) then
				iTable[section][npc]=nil;					-- Kill it
				DropCount.DB.Item:Write(item,iTable,base.Item);
				if (y) then MT:Yield(); end
			end
		end
	end
end

function DropCount.MT:MergeStatus()
	DropCount.Tracker.Merge.Total=DropCount.Tracker.Merge.Total+1;
	local pc=math.floor((DropCount.Tracker.Merge.Total/DropCount.Tracker.Merge.Goal)*100);
	if (pc>DropCount.Tracker.Merge.Printed and pc==math.floor(pc/10)*10) then
		DropCount.Tracker.Merge.Printed=pc;
		if (DropCount.Debug) then
			local tex="Merged: "..pc.."%";
			DropCount:Chat(tex,1,.6,.6);
		end
	else
		MT:Yield(nil,pc);
	end
end

function DropCount.MT:MergeDatabase()
	if (not LootCount_DropCount_MergeData) then return false; end
	if (not LootCount_DropCount_DB.MergedData) then LootCount_DropCount_DB.MergedData=0; end
	if (LootCount_DropCount_MergeData.Version==LootCount_DropCount_DB.MergedData) then return false; end

	DropCount.Tracker.Merge.Total=0;
	DropCount.Tracker.Merge.Goal=0;
	DropCount.Tracker.Merge.Printed=-1;
	local sects=0;
	for _,md in ipairs(LootCount_DropCount_MergeData) do
		sects=sects+1;
		for _,_ in pairs(md.Vendor) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _,_ in pairs(md.Count) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _,_ in pairs(md.Item) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		for _,bT in pairs(md.Book) do
			for _,_ in pairs(bT) do
				DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1;
				MT:Yield();
			end
		end
		for _,qT in pairs(md.Quest) do
			for _,_ in pairs(qT) do
				DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1;
				MT:Yield();
			end
		end
		if (not md.Forge) then md.Forge={}; end
		for _,_ in pairs(md.Forge) do DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1; MT:Yield(); end
		if (not md.Trainer) then md.Trainer={ [CONST.MYFACTION]={}, }; end
		for _,tT in pairs(md.Trainer) do
			for _,_ in pairs(tT) do
				DropCount.Tracker.Merge.Goal=DropCount.Tracker.Merge.Goal+1;
				MT:Yield();
			end
		end
	end
	DropCount:Chat(LOOTCOUNT_DROPCOUNT_VERSIONTEXT,1,.3,.3);
	DropCount:Chat("There are "..DropCount.Tracker.Merge.Goal.." entries to merge with your database.",1,.6,.6);
	DropCount:Chat("A summary will be presented when the process is done.",1,.6,.6);
	DropCount:Chat("This will take a few minutes, depending on the speed of your computer.",1,.6,.6);
	DropCount:Chat("You can play WoW while this is running is the background, even thought you may experience some lag or lower FPS.",1,.6,.6);
	if (DropCount.Debug) then
		DropCount:Chat("===> "..sects.." sections.",1,.6,.6);
	end

	for s,md in ipairs(LootCount_DropCount_MergeData) do
		-- Forges
		for area in pairs(md.Forge) do
			local merge=DropCount.DB.Forge:Read(area,md.Forge);
			local localF=DropCount.DB.Forge:Read(area);
			if (localF) then
				for mi,mData in pairs(merge) do
					for index,lData in pairs(localF) do
						MT:Yield();
						local mX,mY=mData:match("(.+)_(.+)"); mX=tonumber(mX); mY=tonumber(mY);
						local lX,lY=lData:match("(.+)_(.+)"); lX=tonumber(lX); lY=tonumber(lY);
						if (mX>=lX-1 and mX<=lX+1 and mY>=lY-1 and mY<=lY+1) then
							localF[index]=mX.."_"..mY;			-- set new position
							DropCount.Tracker.Merge.Forge.Updated=DropCount.Tracker.Merge.Forge.Updated+1;
							merge[mi]=nil;
						end
					end
				end
				for _,mData in pairs(merge) do
					MT:Yield();
					table.insert(localF,mData);		-- add new forge
					DropCount.Tracker.Merge.Forge.New=DropCount.Tracker.Merge.Forge.New+1;
				end
				DropCount.DB.Forge:Write(area,localF);			-- save modified area data
			else
				DropCount.DB.Forge:Write(area,merge);			-- save new area
			end
			DropCount.MT:MergeStatus();	-- Will handle yield
		end

		-- Trainers
		for faction,fData in pairs(md.Trainer) do
			if (not DropCount.Tracker.Merge.Trainer.New[faction]) then DropCount.Tracker.Merge.Trainer.New[faction]=0; end
			if (not DropCount.Tracker.Merge.Trainer.Updated[faction]) then DropCount.Tracker.Merge.Trainer.Updated[faction]=0; end
			if (not LootCount_DropCount_DB.Trainer[faction]) then LootCount_DropCount_DB.Trainer[faction]={}; end
			for trainer,tData in pairs(fData) do
				if (not LootCount_DropCount_DB.Trainer[faction][trainer]) then
					DropCount.Tracker.Merge.Trainer.New[faction]=DropCount.Tracker.Merge.Trainer.New[faction]+1;
				else
					DropCount.Tracker.Merge.Trainer.Updated[faction]=DropCount.Tracker.Merge.Trainer.Updated[faction]+1;
				end
				LootCount_DropCount_DB.Trainer[faction][trainer]=tData;
				DropCount.MT:MergeStatus();	-- Will handle yield
			end
		end

		-- Vendors
		if (md.Vendor and not DropCount:IsEmpty(md.Vendor)) then
			if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end
			for vend,_ in pairs(md.Vendor) do
				local vTable=DropCount.DB.Vendor:Read(vend,md.Vendor);
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
					if ((vTable.X and vTable.Y and vTable.Zone and (vTable.X>0 or vTable.Y>0)) and
						((tv.X and tv.Y and tv.Zone and (tv.X>0 or tv.Y>0)))) then
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
							tv.Items=DropCount:CopyTable(vTable.Items);
							updated=true;
						else
							for item,iTable in pairs(vTable.Items) do
								if (not tv.Items[item]) then
									tv.Items[item]=DropCount:CopyTable(iTable);
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
				md.Vendor[vend]=nil;	-- Done this vendor
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Vendor -> MS in "..vend);
				DropCount.MT:MergeStatus();	-- Will handle yield
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Vendor -> MS out "..vend);
			end
		end

	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Books");
		-- Books
		if (md.Book and not DropCount:IsEmpty(md.Book)) then
			if (not LootCount_DropCount_DB.Book) then LootCount_DropCount_DB.Book={}; end
			for title,bTable in pairs(md.Book) do
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
				md.Book[title]=nil;	-- Done this volume
				DropCount.MT:MergeStatus();	-- Will handle yield
			end
		end

	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Quest");
		-- Quests
		if (md.Quest and not DropCount:IsEmpty(md.Quest)) then
			if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
			-- Traverse hardcoded
			for faction,fTable in pairs(md.Quest) do
				if (not LootCount_DropCount_DB.Quest[faction]) then
					-- Don't have this faction, so take all.
					LootCount_DropCount_DB.Quest[faction]=DropCount:CopyTable(fTable);
				else
					DropCount.Tracker.Merge.Quest.New[faction]=0;
					DropCount.Tracker.Merge.Quest.Updated[faction]=0;
					-- Traverse hardcoded npcs in this faction
					for npc,nEntry in pairs(fTable) do
						local nTable=DropCount.DB.Quest:Read(faction,npc,md.Quest);
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
	--						local fromIndex=1;
	--							fromIndex=fromIndex+1;
	--						end
							if (updated) then
								DropCount.DB.Quest:Write(npc,tn,faction);
								DropCount.Tracker.Merge.Quest.Updated[faction]=DropCount.Tracker.Merge.Quest.Updated[faction]+1;
							end
						end
						md.Quest[faction][npc]=nil;
						DropCount.MT:MergeStatus();
					end
				end
			end
		end
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Seven");
--		DropCount.Convert:Seven();

	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Drops");
		-- Merge drops
		if (md.Count and md.Item) then
			if (not DropCount:IsEmpty(md.Count)) then
				local strict=nil; if (LootCount_DropCount_DB.MergedData==4) then strict=true; end
				if (not LootCount_DropCount_DB.Count) then LootCount_DropCount_DB.Count={}; end
				if (not LootCount_DropCount_DB.Item) then LootCount_DropCount_DB.Item={}; end
				for mob,mTable in pairs(md.Count) do
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> "..mob.." in");
					local newMob,updatedMob=DropCount.MT:MergeMOB(mob,s,strict);
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> "..mob.." out");
					if (newMob>=0) then
						DropCount.Tracker.Merge.Mob.New=DropCount.Tracker.Merge.Mob.New+newMob;
						DropCount.Tracker.Merge.Mob.Updated=DropCount.Tracker.Merge.Mob.Updated+updatedMob;
						md.Count[mob]=nil;
					end
					DropCount.MT:MergeStatus();
				end
			end
		end

	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Area");
		-- Merge best areas
		if (md.Item and LootCount_DropCount_DB.Item) then
			if (not DropCount:IsEmpty(md.Item)) then
				for item,iData in pairs(md.Item) do
					if (LootCount_DropCount_DB.Item[item]) then
						local miData=DropCount.DB.Item:Read(item,md.Item);
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
					md.Item[item]=nil;
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Area -> MergeStatus in");
					DropCount.MT:MergeStatus();
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Area -> MergeStatus out");
				end
			end
		end

	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Maps");
		-- Maps
		if (LootCount_DropCount_Maps) then		-- I have maps
			for Lang,LTable in pairs(LootCount_DropCount_Maps) do		-- Check all locales I have
				if (md[Lang]) then		-- Hardcoded has same locale
					-- Blend tables
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Maps -> Copy in");
					LootCount_DropCount_Maps[Lang]=DropCount:CopyTable(md[Lang],LootCount_DropCount_Maps[Lang])
	--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Maps -> Copy out");
					MT:Yield();
				end
			end
		end
	end

--DropCount:Chat("-> DropCount.MT:MergeDatabase() -> Output");
	-- Output result
	LootCount_DropCount_DB.MergedData=LootCount_DropCount_MergeData.Version;
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

	DropCount:Chat("Your DropCount database has been updated.",1,.6,.6);
	if (string.len(text)>0) then
		text=LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."\nData merge summary:\n"..text;
		StaticPopupDialogs["LCDC_D_NOTIFICATION"].text=text;
		StaticPopup_Show("LCDC_D_NOTIFICATION");
	end
	Table:PurgeCache(DM_WHO)

	return true;
end

function DropCount.DB:PreCheck(raw,contents)
	if (type(raw)=="string") then
		if (not raw:find(contents,1,true)) then return nil; end
	end
	return true;
end

-- The call next(t, k), where k is a key of the table t, returns a next
-- key in the table, in an arbitrary order. (It returns also the value
-- associated with that key, as a second return value.)
-- The call next(t, nil) returns a first pair. When there are no more
-- pairs, next returns nil.
--function DropCount:ClearMobDropMT(amount,mob,section)
function DropCount.MT:ClearMobDrop(_,mob,section)
	for item,iRaw in pairs(LootCount_DropCount_DB.Item) do
		if (item) then
			DropCount:RemoveMobFromItem(item,mob,section,iRaw);
			MT:Yield();
		end
	end
end

function DropCount:RemoveMobFromItem(item,mob,section,iRaw)
	if (not iRaw or DropCount.DB:PreCheck(iRaw,mob)) then
		local iTable=DropCount.DB.Item:Read(item);
		if (iTable and iTable[section] and iTable[section][mob]) then
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

--[[
"Redstone Basilisk" {
	Map {
		Floor 0
		ID 19
	}
	X 51.847
	Kill 9
	Zone Blasted Lands
	Skinning 9
	Quests {
		1 {
			ID 25771
			Quest One Draenei's Junk...
			Header Blasted Lands
		}
	}
	Y 30.511
}
]]


-- Check mobs and insert anything that is missing
-- IMPORTANT: Do not merge counts! Only insert missing!
--
-- o Check if new data has more kills/skinnings than me
--   If I don't have it at all, mine is set up as zero.
function DropCount.MT:MergeMOB(mob,mdSection,strict)
	local newMob,updatedMob=0,0;
	local kill,skinning=nil,nil;
	local tester;

	local mData;
	local cData;

--DropCount:Chat("-> DropCount.MT:MergeMOB -> ");

	mData=DropCount.DB.Count:Read(mob,LootCount_DropCount_MergeData[mdSection].Count);
	cData=DropCount.DB.Count:Read(mob,LootCount_DropCount_DB.Count);
	-- Create the mob if it doesn't exist
	if (not cData and (mData.Kill or mData.Skinning)) then
		cData=DropCount:CopyTable(mData);
		cData.Kill=nil;
		cData.Skinning=nil;
		newMob=1;
	end
--DropCount:Chat("-> DropCount.MT:MergeMOB -> Kills v");
	-- Merge kills
	if (mData.Kill) then
		if (not cData.Kill) then
			cData.Kill=0;
		end
		tester=cData.Kill; if (strict) then tester=tester-1; end
		if (mData.Kill>tester) then
--DropCount:Chat("-> MergeMOB() -> "..mob.." -> ClearMobDrop in");
			DropCount.MT:ClearMobDrop(nil,mob,"Name");	-- New (and higher) count, so remove old drops
--DropCount:Chat("-> MergeMOB() -> "..mob.." -> ClearMobDrop out");
			kill=mData.Kill;
			cData.Kill=kill;
			if (newMob==0) then updatedMob=1; end
		end
	end
--DropCount:Chat("-> DropCount.MT:MergeMOB -> Profs v");
	-- Merge skinning (all professions)
	if (mData.Skinning) then
		if (not cData.Skinning) then
			cData.Skinning=0;
		end
		tester=cData.Skinning; if (strict) then tester=tester-1; end
		if (mData.Skinning>tester) then
			DropCount.MT:ClearMobDrop(_,mob,"Skinning");
			skinning=mData.Skinning;
			cData.Skinning=skinning;
			if (newMob==0) then updatedMob=1; end
		end
	end

--DropCount:Chat("-> DropCount.MT:MergeMOB -> Kills");
	-- Traverse hardcoded items
	-- Do normal kill/loot
	if (kill) then
		for item,iRaw in pairs(LootCount_DropCount_MergeData[mdSection].Item) do
			if (DropCount.DB:PreCheck(iRaw,mob)) then
				local iTable=DropCount.DB.Item:Read(item,LootCount_DropCount_MergeData[mdSection].Item);
				if (iTable.Name and iTable.Name[mob]) then	-- Exists in source
					local miTable;
					if (not LootCount_DropCount_DB.Item[item]) then		-- Unknown item in target
						miTable=DropCount:CopyTable(iTable);	-- Copy item to target
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
						miTable.Quest=DropCount:CopyTable(iTable.Quest,miTable.Quest);
					end
					DropCount.DB.Item:Write(item,miTable);				-- Copy item to target
				end
			end
		end
	end
--DropCount:Chat("-> DropCount.MT:MergeMOB -> Profs");
	-- Do profession-loot
	if (skinning) then
		for item,iRaw in pairs(LootCount_DropCount_MergeData[mdSection].Item) do
			if (DropCount.DB:PreCheck(iRaw,mob)) then
				local iTable=DropCount.DB.Item:Read(item,LootCount_DropCount_MergeData[mdSection].Item);
				if (iTable.Skinning and iTable.Skinning[mob]) then	-- Exists in source
					local miTable;
					if (not LootCount_DropCount_DB.Item[item]) then		-- Unknown item in target
						miTable=DropCount:CopyTable(iTable);	-- Copy item to target
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
						miTable.Quest=DropCount:CopyTable(iTable.Quest,miTable.Quest);
					end
					DropCount.DB.Item:Write(item,miTable);				-- Copy item to target
				end
			end
		end
	end

	if (cData) then
		if (not cData.Kill and not cData.Skinning) then cData=nil; end
		DropCount.DB.Count:Write(mob,cData);
	end

	return newMob,updatedMob;
end

function DropCount.Menu:AddHeader(text,icon)
	local info=UIDropDownMenu_CreateInfo();
	info.text=CONST.C_LBLUE..text;
	info.icon=icon;
	UIDropDownMenu_AddButton(info,1);
end
function DropCount.Menu:AddChecker(text,switch,func,icon)
	local info=UIDropDownMenu_CreateInfo();
	info.text=CONST.C_BASIC..text;
	info.value=switch;
	if (LootCount_DropCount_DB[switch]) then info.text=info.text..CONST.C_GREEN.."ON"; else info.text=info.text..CONST.C_RED.."OFF"; end
	info.func=DropCount.Menu.ToggleSwitch;
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
	DropCount.Menu:AddButton("Search...",DropCount.Menu.OpenSearchWindow,"");
	DropCount.Menu:AddButton("Options...",DropCount.Menu.OpenOptionsWindow,"");

	DropCount.Menu:AddHeader(" ");
	DropCount.Menu:AddHeader("Minimap");
	DropCount.Menu:AddChecker("Vendors: ","VendorMinimap","Interface\\GROUPFRAME\\UI-Group-MasterLooter");
	DropCount.Menu:AddChecker("Repair: ","RepairMinimap","Interface\\GossipFrame\\VendorGossipIcon");
	DropCount.Menu:AddChecker("Books: ","BookMinimap","Interface\\Spellbook\\Spellbook-Icon");
	DropCount.Menu:AddChecker("Quests: ","QuestMinimap","Interface\\QuestFrame\\UI-Quest-BulletPoint");
	DropCount.Menu:AddChecker("Trainers: ","TrainerMinimap","Interface\\Icons\\INV_Misc_QuestionMark");
	DropCount.Menu:AddChecker("Forges: ","ForgeMinimap",CONST.PROFICON[5]);

	DropCount.Menu:AddHeader(" ");
	DropCount.Menu:AddHeader("Worldmap");
	DropCount.Menu:AddChecker("Vendors: ","VendorWorldmap","Interface\\GROUPFRAME\\UI-Group-MasterLooter");
	DropCount.Menu:AddChecker("Repair: ","RepairWorldmap","Interface\\GossipFrame\\VendorGossipIcon");
	DropCount.Menu:AddChecker("Books: ","BookWorldmap","Interface\\Spellbook\\Spellbook-Icon");
	DropCount.Menu:AddChecker("Quests: ","QuestWorldmap","Interface\\QuestFrame\\UI-Quest-BulletPoint");
	DropCount.Menu:AddChecker("Trainers: ","TrainerWorldmap","Interface\\Icons\\INV_Misc_QuestionMark");
	DropCount.Menu:AddChecker("Forges: ","ForgeWorldmap",CONST.PROFICON[5]);
end

function DropCount.Menu.ToggleSwitch(switch)
	if (LootCount_DropCount_DB[switch.value]) then LootCount_DropCount_DB[switch.value]=nil;
	else LootCount_DropCount_DB[switch.value]=true; end
	MT:Run("MM Plot",DropCount.MT.Icons.PlotMinimap);
end

function DropCount.Menu.OpenSearchWindow()
	LCDC_VendorSearch:Show();
end
function DropCount.Menu.OpenOptionsWindow()
	LCDC_ListOfOptions:Show();
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
	if (DropCount.LootCount.Registered) then
		GameTooltip:LCAddLine(CONST.C_BASIC.."LootCount: "..CONST.C_GREEN.."Present");
	end
	if (DropCount.Crawler.Registered) then
		GameTooltip:LCAddLine(CONST.C_BASIC.."Crawler: "..CONST.C_GREEN.."Present");
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

--
-- DuckLib extracts
--
function DropCount:Chat(msg,r,g,b)
	if (DEFAULT_CHAT_FRAME) then
		if (not r and not g and not b) then r=1; g=1; b=1; end;
		if (not r) then r=0; end;
		if (not g) then g=0; end;
		if (not b) then b=0; end;
		DEFAULT_CHAT_FRAME:AddMessage(msg,r,g,b);
	end
end

-- Return the common DuckMod ID
function DropCount:GetID(link)
	if (type(link)~="string") then
		if (type(link)~="number") then return nil,nil; end
		_,link=GetItemInfo(link);
	end
	local itemID,i1,i2,i3,i4,i5,i6=link:match("|Hitem:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
	if (not i6) then
		itemID,i1,i2,i3,i4,i5,i6=link:match("item:(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+):(%p?%d+)");
	end
	if (not i6) then return; end
	return "item:"..itemID..":"..i1..":"..i2..":"..i3..":"..i4..":"..i5..":"..i6,tonumber(itemID);
end

-- Multi-threading utility
function MT:Run(name,func,...)
debugtimerthing=debugprofilestop();
	for _,tTable in pairs(self.Threads) do
		if (tTable.orig==func and tTable.name==name) then
			if (DropCount.Debug) then print(name.."> Already running in another thread. Aborted."); end
			return;
		end
	end

	self.RunningCo=true;
	self.Count=self.Count+1;
	self.Threads[self.Count]={};
	self.Threads[self.Count].name=name;
	self.Threads[self.Count].orig=func;
	self.Threads[self.Count].cr=coroutine.create(func);
	self.LastTime=debugprofilestop();
	self.LastStack="Running "..name;
--	self.Speed=(1/30)*1000;
	-- For running without timer
--	self.PassCounter=0;
--	if (not self.Multiplier) then self.Multiplier=500; end

	local succeeded,result=coroutine.resume(self.Threads[self.Count].cr,...);
	if (not succeeded and Swatter) then
		if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
		else DropCount:Chat(result); DropCount:Chat(self.LastStack); end
	end
	self.RunningCo=nil;
end

-- Timer version
function MT:Yield(fast,dbdata)
	local now=debugprofilestop();
	self.LastStack=debugstack(2);
	local speed=self.Speed;
	if (fast) then speed=self.FastMT; end
	if (now-self.LastTime<=speed) then return; end
--print(speed," ",now-self.LastTime);
	self.LastTime=now;
--if (ChatFrame3) then local tm=(debugprofilestop()-debugtimerthing)/1000; if (tm>debugtimerthingbig) then debugtimerthingbig=tm; end ChatFrame3:AddMessage(string.format("---===>>> %.05f (%.05f)",tm,debugtimerthingbig)); end
	coroutine.yield();
debugtimerthing=debugprofilestop();
	self.LastStack=debugstack(2);
end

--[[ Update version
function MT:Yield(immediate,dbdata)
	self.LastStack=debugstack(2);
	self.PassCounter=self.PassCounter+1;
	if (not immediate) then
		if (self.PassCounter<self.Multiplier) then return; end
	end
	self.PassCounter=0;		-- Inaccurate to account for other snags
	coroutine.yield();
	self.LastStack=debugstack(2);
end]]

function MT:Next()
	if (self.Count<1) then return; end
	if (self.RunningCo) then return; end	-- Don't if we are already doing it. In case of real MT.
	-- Set timing for MT yield
--	if (elapsed<self.Speed) then self.Multiplier=self.Multiplier+5;
--	else self.Multiplier=self.Multiplier-6; end
--	if (self.Multiplier<1) then self.Multiplier=1; end
--DM:DropCount:Chat(self.Multiplier);

	if (not self.Threads[self.Current+1]) then self.Current=0; end	-- Wrap
	self.Current=self.Current+1;
	if (not self.Threads[self.Current]) then return; end	-- Nothing to do
	if (coroutine.status(self.Threads[self.Current].cr)=="dead") then
		local removeIt=self.Current;
--DropCount:Chat("Ending "..self.Threads[removeIt].name);
		while (self.Threads[removeIt]) do
			self.Threads[removeIt]=self.Threads[removeIt+1];
			removeIt=removeIt+1;
		end
		self.Current=self.Current-1;
		self.Count=self.Count-1;
	else
		self.RunningCo=true;
		local succeeded,result=coroutine.resume(self.Threads[self.Current].cr);
		if (not succeeded) then
			if (Swatter) then Swatter.OnError(result,nil,self.LastStack);
			else DropCount:Chat(result); DropCount:Chat(self.LastStack); end
		end
 		self.RunningCo=nil;
	end
end

function MT:Processes()
	return self.Count;
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

function Table:CompressV2(tData,level)
	local text="";
	if (type(tData)~="table") then return tostring(tData); end
	for entry,eData in pairs(tData) do
		text=text..self:GetType(entry,nil,2)..entry..self:GetType(eData,level,2)..self:CompressV2(eData,level+1);
		if (type(eData)=="table") then
			text=text..self[2].eTable..string.char(level);
		end
	end
	return text;
end

function Table:Write(who,entry,tData,base,section)
	local cache=self.Default[who].UseCache;
	if (not who) then who="Default"; end
	if (not base) then
		base=self.Default[who].Base;
	elseif (section and base~=self.Default[who].Base[section]) then		-- Only cache for base data
		cache=false
	end
	base[entry]=self[self.CV].Version..self[self.CV].ThisVersion..self:GetType(tData,100,self.CV)..self:CompressV2(tData,101);
	base[entry]=base[entry]..self[self.CV].eTable..string.char(100);

	if (cache) then
		if (base==self.Default[who].Base) then
			if (section) then
				if (not self.Default[who].Cache[section]) then self.Default[who].Cache[section]={}; end
				cache=self.Default[who].Cache[section];
			else
				cache=self.Default[who].Cache;
			end
			cache[entry]=tData;
		end
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
			end
		end
		if (not base) then return dData;
		else
			if (anon) then base=dData;
			else base[eData]=dData; end
		end
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
			end
		end
		if (not base) then return dData;
		else
			if (anon) then base=dData;
			else base[eData]=dData; end
		end
	end
	return base;
end

function Table:Read(who,entry,base,section)
	local cache=self.Default[who].UseCache;
	if (not who) then who="Default"; end								-- Using default settings
	if (not base) then
		base=self.Default[who].Base;
	elseif (section and base~=self.Default[who].Base[section]) then		-- Only cache for base data
		cache=false
	end
	if (not base[entry]) then return nil; end							-- Entry does not exist
	if (type(base[entry])~="string") then			-- Not a proper entry
		DropCount:Chat("Got "..type(base[entry]).." as entry");
		return nil;
	end
	local CV=tonumber(base[entry]:sub(2,2));
	local fnDecompress=self["DecompressV"..CV];		-- Look for decompressor
	if (not fnDecompress) then return nil; end		-- We don't have a decompressor for this data
	-- Not using cache, so decompress to scrap-book and return it
	if (not cache) then
		wipe(self.Scrap);
		return DropCount:CopyTable(fnDecompress(self,self.Scrap,base[entry]:sub(3),true));		-- Strip version
	end
	if (section) then
		if (not self.Default[who].Cache[section]) then self.Default[who].Cache[section]={}; end
		cache=self.Default[who].Cache[section];
	else
		cache=self.Default[who].Cache;
	end
	-- Not decompressed yet, so decompress to cache and return it
	if (not cache[entry]) then
		cache[entry]={};
		fnDecompress(self,cache[entry],base[entry]:sub(3),true);
	end
	return cache[entry];
end

function Table:PurgeCache(who,nocollect)
	wipe(self.Default[who].Cache);
--	if (not nocollect) then collectgarbage("collect"); end
end

-- Safe table-copy with optional merge (equal entries will be overwritten, arg1 has pri)
function DropCount:CopyTable(t,new)
	if (not t and not new) then return nil; end
	if (not t) then t={}; end
	if (not new) then new={}; end
	local i,v;
	for i,v in pairs(t) do
		if (type(v)=="table") then new[i]=self:CopyTable(v,new[i]); else new[i]=v; end
	end
	return new;
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
