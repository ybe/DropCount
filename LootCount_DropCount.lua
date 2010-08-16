--[[****************************************************************
	LootCount DropCount v0.76

	Author: Evil Duck
	****************************************************************

	For the game World of Warcraft
	Stand-alone addon, and plug-in for the add-on LootCount.

	****************************************************************]]

--      separated instance and world drop areas, changed quest faction
--      to player faction, less memory-intentsive at DB.Write, time-sliced
--      removal of mobs from item drop-list, tuned cpu-load at merge a
--      bit more, fixed bug in quest-convert (seven) that could lose
--      area-names
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


-- CHECK:
-- Kayneth Stillwind <-> Item Ashenvale 85,44
-- Orb of Grishnath (it's not a drop at all)


LOOTCOUNT_DROPCOUNT_VERSIONTEXT = "DropCount v0.76";
LOOTCOUNT_DROPCOUNT = "DropCount";
SLASH_DROPCOUNT1 = "/dropcount";
SLASH_DROPCOUNT2 = "/lcdc";
local DuckLib=DuckMod[2.02];


--local DropCount={
DropCount={
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
	Event={},
	Edit={},
	OnUpdate={},
	Hook={},
	Icons={
		MakeMM={},
		MakeWM={},
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
	},
	Cache={
		Timer=6,
		Retries=0,
		CachedConvertItems=0,	-- Items requested from server when converting DB
	},
	Search={
		Item=nil,
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
	BURSTSIZE=0.5,
};
local COM={
	PREFIX="LcDc",
	SEPARATOR=",",
	MOBKILL="MOB_KILL",
	MOBLOOT="MOB_LOOT",
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
};
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

local Obsolete={
	SkinningList={
		[2934]=true,		-- Ruined Leather Scraps
		[2318]=true,		-- Light Leather
		[2319]=true,		-- Medium Leather
		[4234]=true,		-- Heavy Leather
		[4304]=true,		-- Thick Leather
		[8170]=true,		-- Rugged Leather
		[25649]=true,		-- Knothide Leather Scraps
		[21887]=true,		-- Knothide Leather
		[5082]=true,		-- Thin Kodo Leather
		[15423]=true,		-- Chimera Leather
		[15417]=true,		-- Devilsaur Leather
		[15422]=true,		-- Frostsaber Leather
		[15419]=true,		-- Warbear Leather
		[25703]=true,		-- Zhevra Leather
		[19767]=true,		-- Primal Bat Leather
		[19768]=true,		-- Primal Tiger Leather
		[17012]=true,		-- Core Leather
		[25699]=true,		-- Crystal Infused Leather
		[25708]=true,		-- Thick Clefthoof Leather
		[25700]=true,		-- Fel Scales
		[29539]=true,		-- Cobra Scales
		[29548]=true,		-- Nether Dragonscales
		[783]=true,			-- Light Hide
		[4232]=true,		-- Medium Hide
		[4235]=true,		-- Heavy Hide
		[8169]=true,		-- Thick Hide
		[8171]=true,		-- Rugged Hide
		[25707]=true,		-- Fel Hide
		[7428]=true,		-- Shadowcat Hide
		[8368]=true,		-- Thick Wolfhide
		[12731]=true,		-- Pristine Hide of the Beast
		[20500]=true,		-- Light Silithid Carapace
		[20501]=true,		-- Heavy Silithid Carapace
		[8167]=true,		-- Turtle Scale
		[8154]=true,		-- Scorpid Scale
		[15408]=true,		-- Heavy Scorpid Scale
		[20498]=true,		-- Silithid Chitin
		[29547]=true,		-- Wind Scales
		[7072]=true,		-- Naga Scale
		[7286]=true,		-- Black Whelp Scale
		[7287]=true,		-- Red Whelp Scale
		[7392]=true,		-- Green Whelp Scale
		[12607]=true,		-- Brilliant Chromatic Scale
		[8165]=true,		-- Worn Dragonscale
		[15412]=true,		-- Green Dragonscale
		[15415]=true,		-- Blue Dragonscale
		[15416]=true,		-- Black Dragonscale
		[15414]=true,		-- Red Dragonscale
		[15410]=true,		-- Scale of Onyxia
		[20381]=true,		-- Dreamscale
		[6470]=true,		-- Deviate Scale (drop and skinning)
		[6471]=true,		-- Perfect Deviate Scale (drop and skinning)
		[33567]=true,		-- Borean Leather Scraps
		[33568]=true,		-- Borean Leather
	--	[12607]=true,		-- Brilliant Chromatic Scale
		[44128]=true,		-- Arctic Fur
	},
};

-- reference to the Astrolabe mapping library
local Astrolabe = DongleStub("Astrolabe-0.4");



-- Set up for handling
function DropCountXML:OnLoad()
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	this:RegisterEvent("PLAYER_FOCUS_CHANGED");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("CHAT_MSG_ADDON");
	this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("LOOT_OPENED");
	this:RegisterEvent("LOOT_SLOT_CLEARED");
	this:RegisterEvent("MERCHANT_SHOW");
	this:RegisterEvent("MERCHANT_CLOSED");
	this:RegisterEvent("WORLD_MAP_UPDATE");
	this:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	this:RegisterEvent("QUEST_DETAIL");
	this:RegisterEvent("QUEST_COMPLETE");
	this:RegisterEvent("QUEST_FINISHED");
	this:RegisterEvent("UNIT_SPELLCAST_START");
	this:RegisterEvent("QUEST_QUERY_COMPLETE");

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
				DropCount.Search.Item=DropCount:ItemByName(DropCount.Search.Item);
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
	elseif (string.find(msg,"book",1,true)==1) then
		msg=string.sub(msg,5);
		msg=strtrim(msg);
		if (msg=="zone") then
			DropCount:ListZoneBooks();
		else
			DropCount:ListBook(msg);
		end
		return;
	elseif (msg=="show") then
		LCDC_VendorSearch:Show();
		return;
	elseif (msg=="stats") then
		DropCount:ShowStats();
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
								DropCount.DB.Quest:Write(faction,npc,npcData);
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

function DropCount.Event.COMBAT_LOG_EVENT_UNFILTERED()
	if (arg2=="PARTY_KILL" and (bit.band(arg3,COMBATLOG_OBJECT_TYPE_PET) or bit.band(arg3,COMBATLOG_OBJECT_TYPE_PLAYER))) then
		if (GetNumPartyMembers()<1) then
			DropCount:AddKill(true,arg6,arg7,LootCount_DropCount_Character.Skinning);
		end
		if (DropCount.Registered) then LootCountAPI.Force(LOOTCOUNT_DROPCOUNT); end
	end
end

function DropCount.Event.PLAYER_FOCUS_CHANGED() DropCount.Event.PLAYER_TARGET_CHANGED(); end
function DropCount.Event.PLAYER_TARGET_CHANGED()
	local targettype=DropCount:GetTargetType();
	if (not targettype) then
		DropCount.Target.MyKill=nil;
		DropCount.Target.Skin=nil;
		DropCount.Target.UnSkinned=nil;
		DropCount.Target.CurrentAliveFriendClose=nil;
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

function DropCount.Event.CHAT_MSG_ADDON()
	if (arg1~=COM.PREFIX) then return; end
	if (LootCount_DropCount_DB.RAID) then
		if (arg3~="RAID" and arg3~="PARTY") then return; end
	elseif (LootCount_DropCount_DB.GUILD) then
		if (arg3~="GUILD") then return; end
	else return; end

	if (arg4==UnitName("player")) then return; end
	DropCount.Com:ParseMessage(arg2,arg4);
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
		target=CheckInteractDistance(DropCount:GetTargetType(),2);	-- Trade-distance
	end
	if (not target) then		-- No target, or too far away
		DropCount.Target.CurrentAliveFriendClose=nil;
	end
	if (qName) then DropCount:SaveQuest(qName,DropCount.Target.CurrentAliveFriendClose); end
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

function DropCount.Event.QUEST_FINISHED()		-- Also when frame is closed (apparently)
	LCDC_RescanQuests=CONST.RESCANQUESTS;
end

function DropCount.Event.UNIT_SPELLCAST_START()
	if (arg1~="player") then return; end		-- Someone else in party
	if (arg2==CONST.PROFESSIONS[1] or arg2==CONST.PROFESSIONS[2] or
		arg2==CONST.PROFESSIONS[3] or arg2==CONST.PROFESSIONS[4]) then
		if (DropCount.Target.Skin) then			-- Casting on a skinning-target
			DropCount.Profession=arg2;			-- Set loot-by-profession type
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
function DropCountXML:OnEvent(event)
	if (DropCount.Event[event]) then DropCount.Event[event](); return; end

	if (event=="ADDON_LOADED" and arg1=="LootCount_DropCount") then
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
	end
end

function DropCount.Hook.SetBagItem(self,bag,slot)
	local hasCooldown,repairCost=DropCount.Hook.TT_SetBagItem(self,bag,slot);

	if (not LootCount_DropCount_Character.NoTooltip) then
		local _,ThisItem=GameTooltip:GetItem();
		if (ThisItem) then
			ThisItem=DuckLib:GetID(ThisItem);
			local iData=DropCount.DB.Item:Read(ThisItem);
			if (iData) then
				local text="|cFFF89090B|cFFF09098e|cFFE890A0s|cFFE090A8t |cFFD890B0k|cFFD090B8n|cFFC890C0o|cFFC090C8w|cFFB890D0n |cFFB090D8a|cFFA890E0r|cFFA090E8e|cFF9890F0a: |cFF9090F8";
				if (iData.BestW) then
					GameTooltip:AddLine(text..iData.BestW.Location.." at "..iData.BestW.Score.."%",.6,.6,1,1);	-- 1=wrap text
				elseif (iData.Best) then
					GameTooltip:AddLine(text..iData.Best.Location.." at "..iData.Best.Score.."%",.6,.6,1,1);	-- 1=wrap text
				end
			end
			GameTooltip:Show();
		end
	end

	return hasCooldown,repairCost;
end


function DropCount:ToggleSingleDrop()
	if (LootCount_DropCount_Character.ShowSingle) then
		LootCount_DropCount_Character.ShowSingle=nil;
	else
		LootCount_DropCount_Character.ShowSingle=true;
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

	local text=getglobal("LootCount_DropCount_CFTextLeft1"):GetText();
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

function DropCount:SaveQuest(qName,qGiver,qLevel)
	if (not qName) then return; end
	if (not qLevel) then qLevel=0; end
	if (not CONST.MYFACTION) then return; end
	if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
	if (not LootCount_DropCount_DB.Quest[CONST.MYFACTION]) then LootCount_DropCount_DB.Quest[CONST.MYFACTION]={}; end

	local qX,qY=DropCount:GetPLayerPosition();
	local qZone=DropCount:GetFullZone();
	if (not qZone) then qZone="Unknown"; end
	if (not qGiver or qGiver=="") then
		qGiver="- item - ("..DropCount:GetFullZone().." "..math.floor(qX)..","..math.floor(qY)..")";
	end
	local qTable={
		[qGiver]=DropCount.DB.Quest:Read(CONST.MYFACTION,qGiver);
	};

	if (not qTable[qGiver]) then qTable[qGiver]={}; end
	qTable[qGiver].Zone=qZone;
	if (not qTable[qGiver].X or not qTable[qGiver].Y or (qTable[qGiver].X and qX~=0 and qTable[qGiver].Y and qY~=0)) then
		qTable[qGiver].X=qX;
		qTable[qGiver].Y=qY;
	end
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

	if (newquest) then
		DropCount.DB.Quest:Write(CONST.MYFACTION,qGiver,qTable[qGiver]);
		DuckLib:Chat(CONST.C_BASIC.."New Quest "..CONST.C_GREEN.."\""..qName.."\""..CONST.C_BASIC.." saved for "..CONST.C_GREEN..qGiver);
	end
end

function DropCount:ScanQuests()
	if (not LootCount_DropCount_Character.Quests) then LootCount_DropCount_Character.Quests={}; end
	wipe(LootCount_DropCount_Character.Quests);

	-- Get all current quests
	ExpandQuestHeader(0);			-- Expand all quest-headers
	local i=1;
	local lastheader=nil;
	while (GetQuestLogTitle(i)~=nil) do
		local questTitle,level,questTag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily=GetQuestLogTitle(i);
		if (not isHeader) then
			local link=GetQuestLink(i);
			local questID,i1,i2=link:match("|Hquest:(%p?%d+):(%p?%d+)|h%[(.-)%]|h");
			LootCount_DropCount_Character.Quests[questTitle]={
				ID=tonumber(questID),
				Header=lastheader,
			}
		else
			lastheader=questTitle;
		end
		i=i+1;
	end
	if (not DropCount.SpoolQuests) then DropCount.SpoolQuests={}; end
	DropCount.SpoolQuests=DuckLib:CopyTable(LootCount_DropCount_Character.Quests,DropCount.SpoolQuests);
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
						local changed=nil;
						for index,qData in pairs(nTable.Quests) do
							if (type(qData)~="table") then
								nTable.Quests[index]={ Quest=qData, };
								converted=true;
								changed=true;
							end
							if (nTable.Quests[index].Quest==quest) then
--if (npc=="Xink") then
--	DuckLib:Chat(faction.."-"..quest.."-"..qTable.Header.."-"..nTable.Quests[index].Header);
--end
								if (not nTable.Quests[index].Header or
									(qTable.Header and nTable.Quests[index].Header~=qTable.Header)) then
									nTable.Quests[index].Header=qTable.Header;
									changed=true;
								end
							end
						end
						if (changed) then
							DropCount.DB.Quest:Write(faction,npc,nTable);
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
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	local Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
	for npc,nTable in pairs(DropCountXML.Icon.QuestMM) do
		Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.QuestMM[npc]);
	end
	if (not LootCount_DropCount_DB.Quest) then return; end
	if (not LootCount_DropCount_DB.QuestMinimap) then return; end
	local count=1;
	for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
		if (faction=="Neutral" or faction==CONST.MYFACTION) then
			for npc,nRaw in pairs(fTable) do
				if (DropCount.DB:PreCheck(nRaw,CONST.ZONES[Cont][Zone])) then
					local nTable=DropCount.DB.Quest:Read(faction,npc);
					if (nTable.Zone and string.find(nTable.Zone,CONST.ZONES[Cont][Zone],1,true)==1) then
						local r,g,b=1,1,1;
						local level=0;
						for _,qTable in pairs(nTable.Quests) do
							local state=DropCount:GetQuestStatus(qTable.Quest);
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
								Continent=Cont,
								Zone=Zone,
								Faction=faction,
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

function DropCount.Icons.MakeWM:Quest(Cont,Zone)
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	if (not Cont or not Zone) then
		Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	end
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
	for npc,nTable in pairs(DropCountXML.Icon.Quest) do
		nTable.NPC.Unused=true;
	end
	if (not LootCount_DropCount_DB.Quest) then return; end
	if (not LootCount_DropCount_DB.QuestWorldmap) then return; end
	local count=1;
	for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
		if (faction==CONST.MYFACTION or faction=="Neutral") then
			for npc,nRaw in pairs(fTable) do
				if (DropCount.DB:PreCheck(nRaw,CONST.ZONES[Cont][Zone])) then
					local nTable=DropCount.DB.Quest:Read(faction,npc);
					if (nTable.Zone and string.find(nTable.Zone,CONST.ZONES[Cont][Zone],1,true)==1) then
						local r,g,b=1,1,1;
						local level=0;
						for _,qTable in pairs(nTable.Quests) do
							local state=DropCount:GetQuestStatus(qTable.Quest);
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
							Continent=Cont,
							Zone=Zone,
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

function DropCount.Icons:Plot()
	if (not WorldMapDetailFrame) then return; end
	local c=GetCurrentMapContinent();
	if (c<1) then return; end		-- Cosmos or battleground or DK starting-area
	local z=GetCurrentMapZone();

	DropCount.Icons.MakeWM:Vendor(c,z);
	for entry,eIcon in pairs(DropCountXML.Icon.Vendor) do
		if (not eIcon.Vendor.Unused and (LootCount_DropCount_DB.VendorWorldmap or LootCount_DropCount_DB.RepairWorldmap) and eIcon.Vendor.Continent==c and eIcon.Vendor.Zone==z) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,c,z,eIcon.Vendor.X,eIcon.Vendor.Y);
		else
			eIcon:Hide();
		end
	end

	DropCount.Icons.MakeWM:Book(c,z);
	for entry,eIcon in pairs(DropCountXML.Icon.Book) do
		if (not eIcon.Book.Unused and LootCount_DropCount_DB.BookWorldmap and eIcon.Book.Continent==c and eIcon.Book.Zone==z) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,c,z,eIcon.Book.X,eIcon.Book.Y);
		else
			eIcon:Hide();
		end
	end

	DropCount.Icons.MakeWM:Quest(c,z);
	for entry,eIcon in pairs(DropCountXML.Icon.Quest) do
		if (not eIcon.NPC.Unused and LootCount_DropCount_DB.QuestWorldmap and eIcon.NPC.Continent==c and eIcon.NPC.Zone==z) then
			Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame,eIcon,c,z,eIcon.NPC.X,eIcon.NPC.Y);
		else
			eIcon:Hide();
		end
	end
end

function DropCountXML:OnEnterIcon()
	LCDC_VendorFlag_Info=true;
	if (this.Vendor) then DropCount.Tooltip:SetNPCContents(this.Vendor.Name); end
	if (this.Book) then DropCount.Tooltip:Book(this.Book.Name,parent); end
	if (this.NPC) then DropCount.Tooltip:QuestList(this.NPC.Faction,this.NPC.Name,parent); end
end

function DropCount:SetQuestMMPosition(npc,xPos,yPos)
	if (not DropCountXML.Icon.QuestMM[npc]) then return; end
	local icon=DropCountXML.Icon.QuestMM[npc];
	icon.NPC.X=xPos/100;
	icon.NPC.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(icon,icon.NPC.Continent,icon.NPC.Zone,icon.NPC.X,icon.NPC.Y);
end
function DropCount:SetVendorMMPosition(dude,xPos,yPos)
	if (not DropCountXML.Icon.VendorMM[dude]) then return; end
	DropCountXML.Icon.VendorMM[dude].Vendor.X=xPos/100;
	DropCountXML.Icon.VendorMM[dude].Vendor.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(DropCountXML.Icon.VendorMM[dude],DropCountXML.Icon.VendorMM[dude].Vendor.Continent,DropCountXML.Icon.VendorMM[dude].Vendor.Zone,DropCountXML.Icon.VendorMM[dude].Vendor.X,DropCountXML.Icon.VendorMM[dude].Vendor.Y);
end
function DropCount:SetBookMMPosition(book,xPos,yPos)
	if (not DropCountXML.Icon.BookMM[book]) then return; end
	DropCountXML.Icon.BookMM[book].Book.X=xPos/100;
	DropCountXML.Icon.BookMM[book].Book.Y=yPos/100;
	Astrolabe:PlaceIconOnMinimap(DropCountXML.Icon.BookMM[book],DropCountXML.Icon.BookMM[book].Book.Continent,DropCountXML.Icon.BookMM[book].Book.Zone,DropCountXML.Icon.BookMM[book].Book.X,DropCountXML.Icon.BookMM[book].Book.Y);
end

function DropCount:EnumZones()
	if (CONST.ZONES) then DuckLib:ClearTable(CONST.ZONES); CONST.ZONES=nil; end
	local cNames = { GetMapContinents() };
	CONST.ZONES={ };
	local c=1;
	while(cNames[c]) do
		CONST.ZONES[c]={ GetMapZones(c) } ;
		c=c+1;
	end
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
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	local Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
	for book,bTable in pairs(DropCountXML.Icon.BookMM) do
		Astrolabe:RemoveIconFromMinimap(DropCountXML.Icon.BookMM[book]);
	end
	if (not LootCount_DropCount_DB.Book) then return; end
	if (not LootCount_DropCount_DB.BookMinimap) then return; end
	local index;
	local count=1;
	for book,vTable in pairs(LootCount_DropCount_DB.Book) do
		for index,bTable in pairs(vTable) do
			if (bTable.Zone and string.find(bTable.Zone,CONST.ZONES[Cont][Zone],1,true)==1) then
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
					Continent=Cont,
					Zone=Zone,
				}
				DropCount:SetBookMMPosition(book..index,bTable.X,bTable.Y);
				count=count+1;
			end
		end
	end
end

function DropCount.Icons.MakeWM:Book(Cont,Zone)
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	if (not Cont or not Zone) then
		Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	end
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
	for book,bTable in pairs(DropCountXML.Icon.Book) do
		bTable.Book.Unused=true;
	end
	if (not LootCount_DropCount_DB.Book) then return; end
	local index;
	local count=1;
	for book,vTable in pairs(LootCount_DropCount_DB.Book) do
		for index,bTable in pairs(vTable) do
			if (bTable.Zone and string.find(bTable.Zone,CONST.ZONES[Cont][Zone],1,true)==1) then
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
					Continent=Cont,
					Zone=Zone,
				}
				count=count+1;
			end
		end
	end
end

function DropCount.Icons.MakeMM:Vendor()
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	local Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
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
				if (zone and string.find(zone,CONST.ZONES[Cont][Zone],1,true)==1) then
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
						Continent=Cont,
						Zone=Zone,
						Faction=faction,
					}
					DropCount:SetVendorMMPosition(vendor,x,y);
					count=count+1;
				end
			end
		end
	end
end

function DropCount.Icons.MakeWM:Vendor(Cont,Zone)
	if (not CONST.ZONES) then DropCount:EnumZones(); if (not CONST.ZONES) then return; end end
	if (not Cont or not Zone) then
		Cont,Zone,_,_=Astrolabe:GetCurrentPlayerPosition();
	end
	if (not Cont or not Zone) then return; end
	if (not CONST.ZONES[Cont] or not CONST.ZONES[Cont][Zone]) then return; end
	for vendor,vTable in pairs(DropCountXML.Icon.Vendor) do
		vTable.Vendor.Unused=true;
	end
	if (not LootCount_DropCount_DB.Vendor) then return; end
	if (not LootCount_DropCount_DB.VendorWorldmap and not LootCount_DropCount_DB.RepairWorldmap) then return; end
	local count=1;
	for vendor,_ in pairs(LootCount_DropCount_DB.Vendor) do
		local x,y,zone,faction,repair=DropCount.DB.Vendor:ReadBaseData(vendor);
		if (faction=="Neutral" or faction==CONST.MYFACTION) then
			if (LootCount_DropCount_DB.VendorWorldmap or
			  (LootCount_DropCount_DB.RepairWorldmap and repair)) then
				if (zone and string.find(zone,CONST.ZONES[Cont][Zone],1,true)==1) then
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
						Continent=Cont,
						Zone=Zone,
						Faction=faction,
						Unused=nil,
					}
					count=count+1;
				end
			end
		end
	end
end

function DropCount:ItemByName(name)
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
	local store=nil;
	local storeMD=nil;
	if (not base) then
		if (not self.Fast[faction]) then self.Fast[faction]={}; end
		if (self.Fast[faction][npc]) then return self.Fast[faction][npc]; end
		base=LootCount_DropCount_DB.Quest;
		store=true;
	elseif (LootCount_DropCount_MergeData and LootCount_DropCount_MergeData.Quest and base==LootCount_DropCount_MergeData.Quest) then
		if (self.Fast.MD[npc]) then return self.Fast.MD[npc]; end
		storeMD=true;
	end
	if (not base) then return nil; end
	if (not base[faction]) then return nil; end
	if (not base[faction][npc]) then return nil; end

	if (type(base[faction][npc])=="table") then
		return base[faction][npc];
	end

	if (not self.Fast[faction]) then self.Fast[faction]={}; end
	local nData;
	if (store) then
		if (self.Fast[faction][npc]) then wipe(self.Fast[faction][npc]); else self.Fast[faction][npc]={}; end
		nData=self.Fast[faction][npc];
	elseif (storeMD) then
		if (self.Fast.MD[npc]) then wipe(self.Fast.MD[npc]); else self.Fast.MD[npc]={}; end
		nData=self.Fast.MD[npc];
	else nData={}; end
	local quests;
	nData.X,nData.Y,nData.Zone,quests=strsplit(CONST.SEP1,base[faction][npc]);
	nData.X=tonumber(nData.X);
	nData.Y=tonumber(nData.Y);
	quests={ strsplit(CONST.SEP2,quests) };
	nData.Quests={};
	for index,iData in pairs(quests) do
		nData.Quests[index]={};
		nData.Quests[index].Quest,nData.Quests[index].Header=strsplit(CONST.SEP3,iData);
	end
	return nData;
end

function DropCount.DB.Quest:Write(faction,npc,nData)
	if (not self.Fast[faction]) then self.Fast[faction]={}; end
	self.Fast[faction][npc]=DuckLib:CopyTable(nData,self.Fast[faction][npc]);
	local compact=nData.X..CONST.SEP1..nData.Y..CONST.SEP1..nData.Zone..CONST.SEP1;
	local index=1;
	while(nData.Quests[index]) do
		if (index>1) then compact=compact..CONST.SEP2; end
		compact=compact..nData.Quests[index].Quest..CONST.SEP3;
		if (nData.Quests[index].Header) then
			compact=compact..nData.Quests[index].Header;
		else
			compact=compact.." ";
		end
		index=index+1;
	end
	if (not LootCount_DropCount_DB.Quest) then LootCount_DropCount_DB.Quest={}; end
	if (not LootCount_DropCount_DB.Quest[faction]) then LootCount_DropCount_DB.Quest[faction]={}; end
	LootCount_DropCount_DB.Quest[faction][npc]=compact;
end

function DropCount.DB.Vendor:ReadBaseData(npc,base)
	if (not base) then base=LootCount_DropCount_DB.Vendor; end
	if (not base) then return nil; end
	if (not base[npc]) then return nil; end

	if (type(base[npc])=="table") then
		return base[npc].X,base[npc].Y,base[npc].Zone,base[npc].Faction;
	end

	local X,Y,Zone,Faction,Repair,items=strsplit(CONST.SEP1,base[npc]);
	if (Repair=="Y") then Repair=true; else Repair=nil; end
	X=tonumber(X);
	Y=tonumber(Y);
	return X,Y,Zone,Faction,Repair;
end

function DropCount.DB.Vendor:Read(npc,base)
	local store=nil;
	if (not base) then
		if (self.Fast[npc]) then return self.Fast[npc]; end
		base=LootCount_DropCount_DB.Vendor;
		store=true;
	end
	if (not base) then return nil; end
	if (not base[npc]) then return nil; end

	if (type(base[npc])=="table") then
		return base[npc];
	end

	local nData;
	if (store) then
		if (self.Fast[npc]) then wipe(self.Fast[npc]); else self.Fast[npc]={}; end
		nData=self.Fast[npc];
	else nData={}; end
	local items;
	nData.X,nData.Y,nData.Zone,nData.Faction,nData.Repair,items=strsplit(CONST.SEP1,base[npc]);
	nData.X=tonumber(nData.X);
	nData.Y=tonumber(nData.Y);
	if (nData.Repair=="Y") then nData.Repair=true; else nData.Repair=nil; end
	items={ strsplit(CONST.SEP2,items) };
	nData.Items={};
	for _,iData in pairs(items) do
		local item,count,name=strsplit(CONST.SEP3,iData);
		nData.Items[item]={ Count=tonumber(count), Name=name };
	end
	return nData;
end

function DropCount.DB.Vendor:Write(npc,nData)
	self.Fast[npc]=DuckLib:CopyTable(nData,self.Fast[npc]);
	if (not nData.Faction) then nData.Faction=" "; end
	local compact=nData.X..CONST.SEP1..nData.Y..CONST.SEP1..nData.Zone..CONST.SEP1..nData.Faction..CONST.SEP1;
	if (nData.Repair) then compact=compact.."Y"; else compact=compact.."N"; end
	compact=compact..CONST.SEP1;
	local first=true;
	if (nData.Items) then
		for item,iData in pairs(nData.Items) do
			if (not first) then compact=compact..CONST.SEP2; end
			if (not iData.Name) then iData.Name=" "; end
			if (not iData.Count) then iData.Count=0; end
			compact=compact..item..CONST.SEP3..iData.Count..CONST.SEP3..iData.Name;
			first=nil;
		end
	end
	if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end
	LootCount_DropCount_DB.Vendor[npc]=compact;
end

function DropCount.DB.Count:Write(mob,nData)
	if (not nData) then
		self.Fast[mob]=nil;
		LootCount_DropCount_DB.Count[mob]=nil;
		return;
	end
	self.Fast[mob]=DuckLib:CopyTable(nData,self.Fast[mob]);
	if (not nData.Kill) then nData.Kill=0; end
	if (not nData.Skinning) then nData.Skinning=0; end
	if (not nData.Zone) then nData.Zone=" "; end
	local compact=nData.Zone..CONST.SEP1..nData.Kill..CONST.SEP1..nData.Skinning;
	if (not LootCount_DropCount_DB.Count) then LootCount_DropCount_DB.Count={}; end
	LootCount_DropCount_DB.Count[mob]=compact;
end

function DropCount.DB.Count:Read(mob,base)
	local store=nil;
	local storeMD=nil;
	if (not base) then
		if (self.Fast[mob]) then return self.Fast[mob]; end
		base=LootCount_DropCount_DB.Count;
		store=true;
	elseif (LootCount_DropCount_MergeData and LootCount_DropCount_MergeData.Count and base==LootCount_DropCount_MergeData.Count) then
		if (self.Fast.MD[mob]) then return self.Fast.MD[mob]; end
		storeMD=true;
	end
	if (not base) then return nil; end
	if (not base[mob]) then return nil; end

	if (type(base[mob])=="table") then
		return base[mob];
	end

	local mTable;
	if (store) then
		if (self.Fast[mob]) then wipe(self.Fast[mob]); else self.Fast[mob]={}; end
		mTable=self.Fast[mob];
	elseif (storeMD) then
		if (self.Fast.MD[mob]) then wipe(self.Fast.MD[mob]); else self.Fast.MD[mob]={}; end
		mTable=self.Fast.MD[mob];
	else mTable={}; end
	mTable.Zone,mTable.Kill,mTable.Skinning=strsplit(CONST.SEP1,base[mob]);
	mTable.Kill=tonumber(mTable.Kill);
	mTable.Skinning=tonumber(mTable.Skinning);
	if (mTable.Kill==0) then mTable.Kill=nil; end
	if (mTable.Skinning==0) then mTable.Skinning=nil; end
	return mTable;
end

function DropCount.DB.Item:Write(item,iData)
	self.Fast[item]=DuckLib:CopyTable(iData,self.Fast[item]);
	if (not iData.Time) then iData.Time=time(); end
	if (not iData.Item) then iData.Item="<Unknown Item>"; end
	local compact=iData.Item..CONST.SEP1..iData.Time..CONST.SEP1;
	if (iData.Name) then
		local first=true;
		for mob,count in pairs(iData.Name) do
			if (not first) then compact=compact..CONST.SEP2; end
			compact=compact..mob..CONST.SEP3..count;
			first=nil;
		end
	end
	compact=compact..CONST.SEP1;
	if (iData.Skinning) then
		local first=true;
		for mob,count in pairs(iData.Skinning) do
			if (not first) then compact=compact..CONST.SEP2; end
			compact=compact..mob..CONST.SEP3..count;
			first=nil;
		end
	end
	compact=compact..CONST.SEP1;
	if (iData.Best) then
		compact=compact..iData.Best.Location..CONST.SEP2..iData.Best.Score
		if (iData.BestW) then
			compact=compact..CONST.SEP2..iData.BestW.Location..CONST.SEP2..iData.BestW.Score
		end
	end
	if (not LootCount_DropCount_DB.Item) then LootCount_DropCount_DB.Item={}; end
	LootCount_DropCount_DB.Item[item]=compact;
end

function DropCount.DB.Item:Read(item,base,KeepZero)
	local store=nil;
	local storeMD=nil;
	if (not base) then
		if (self.Fast[item]) then return self.Fast[item]; end
		base=LootCount_DropCount_DB.Item;
		store=true;
	elseif (LootCount_DropCount_MergeData and LootCount_DropCount_MergeData.Item and base==LootCount_DropCount_MergeData.Item) then
		if (self.Fast.MD[item]) then return self.Fast.MD[item]; end
		storeMD=true;
	end
	if (not base) then return nil; end
	if (not base[item]) then return nil; end

	if (type(base[item])=="table") then
		return base[item];
	end

	local nData;
	if (store) then
		if (self.Fast[item]) then wipe(self.Fast[item]); else self.Fast[item]={}; end
		nData=self.Fast[item];
	elseif (storeMD) then
		if (self.Fast.MD[item]) then wipe(self.Fast.MD[item]); else self.Fast.MD[item]={}; end
		nData=self.Fast.MD[item];
	else nData={}; end
	local drop,skin;
	nData.Item,nData.Time,drop,skin,best=strsplit(CONST.SEP1,base[item]);
	nData.Time=tonumber(nData.Time);
	if (drop and drop~="") then
		nData.Name={};
		drop={strsplit(CONST.SEP2,drop)};
		for _,data in ipairs(drop) do
			local mob,count=strsplit(CONST.SEP3,data);
			nData.Name[mob]=tonumber(count);
			-- Zero drops. The old compress-bug has destroyed the mob
			if (not KeepZero and nData.Name[mob]==0 and store) then
				local rData=DropCount.DB.Count:Read(mob);
				if (rData) then
					if (rData.Skinning) then					-- There's skinning-drops
						rData.Kill=nil;							-- No drops only
						DropCount.DB.Count:Write(mob,rData);
					else										-- No skinning, so kill it
						LootCount_DropCount_DB.Count[mob]=nil;	-- Kill mob
						DropCount.DB.Count.Fast[mob]=nil;		-- Kill mob
					end
				end
				DropCount:ClearMobDrop(mob,"Name");				-- Kill all normal drops from mob
				return DropCount.DB.Item:Read(item,base,KeepZero);	-- Normal read after mod
			end
		end
	end
	if (skin and skin~="") then
		nData.Skinning={};
		skin={strsplit(CONST.SEP2,skin)};
		for _,data in ipairs(skin) do
			local mob,count=strsplit(CONST.SEP3,data);
			nData.Skinning[mob]=tonumber(count);
		end
	end
	if (best and best~="") then
		nData.Best={};
		nData.BestW={};
		nData.Best.Location,nData.Best.Score,nData.BestW.Location,nData.BestW.Score=strsplit(CONST.SEP2,best);
		nData.Best.Score=tonumber(nData.Best.Score);
		if (nData.BestW.Score) then
			nData.BestW.Score=tonumber(nData.BestW.Score);
		else
			nData.BestW=nil;
		end
	end

	return nData;
end

-- This is called from elsewhere as well. Not only the convert-routine.
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

function DropCount.Convert:Six()
	if (LootCount_DropCount_DB.Converted>=6) then return; end
	local amount=0;
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (type(iData)=="table") then
			DropCount.DB.Item:Write(item,iData);
			return;
		end
		amount=amount+1;
	end
	LootCount_DropCount_DB.Converted=6;
	collectgarbage("collect");
end

function DropCount.Convert:Five()
	if (LootCount_DropCount_DB.Converted>=5) then return; end
	local amount=0;
	for mob,mData in pairs(LootCount_DropCount_DB.Count) do
		if (type(mData)=="table") then
			DropCount.DB.Count:Write(mob,mData);
			return;
		end
		amount=amount+1;
	end
	LootCount_DropCount_DB.Converted=5;
	collectgarbage("collect");
end

function DropCount.Convert:Four()
	if (LootCount_DropCount_DB.Converted>=4) then return; end
	local amount=0;
	for vendor,vData in pairs(LootCount_DropCount_DB.Vendor) do
		if (type(vData)=="table") then
			DropCount.DB.Vendor:Write(vendor,vData);
			return;
		end
		amount=amount+1;
	end
	LootCount_DropCount_DB.Converted=4;
	collectgarbage("collect");
end

function DropCount.Convert:Three()
	if (LootCount_DropCount_DB.Converted>=3) then return; end
	local amount=0;
	for faction,fData in pairs(LootCount_DropCount_DB.Quest) do
		for npc,nData in pairs(fData) do
			if (type(nData)=="table") then
				DropCount.DB.Quest:Write(faction,npc,nData);
				return;
			end
			amount=amount+1;
		end
	end
	LootCount_DropCount_DB.Converted=3;
	collectgarbage("collect");
end

function DropCount.Convert:Two()
	if (LootCount_DropCount_DB.Converted~=true and LootCount_DropCount_DB.Converted>=2) then
		return;
	end
	for id,idValue in pairs(Obsolete.SkinningList) do
		local dbItem="item:"..id..":0:0:0:0:0:0";
		if (LootCount_DropCount_DB.Item[dbItem] and LootCount_DropCount_DB.Item[dbItem].Name) then
			LootCount_DropCount_DB.Item[dbItem].Skinning=DuckLib:CopyTable(LootCount_DropCount_DB.Item[dbItem].Name);
			LootCount_DropCount_DB.Item[dbItem].Name=nil;
		end
	end
	LootCount_DropCount_DB.Converted=2;
end

function DropCount.Convert:One()
	if (not LootCount_DropCount_DB.Item) then LootCount_DropCount_DB.Item={}; end
	if (not LootCount_DropCount_DB.Vendor) then LootCount_DropCount_DB.Vendor={}; end
	if (LootCount_DropCount_DB.Converted) then DropCount.Convert:Two(); return; end

	local item,iTable;
	DropCount.Cache.CachedConvertItems=0;
	if (LootCount_DropCount_DB.Item) then
		for item,iTable in pairs(LootCount_DropCount_DB.Item) do
			if (not iTable.Item) then					-- Conversion needed
				local itemName,itemLink=GetItemInfo(item);
				if (not itemName) then
					DropCount.Cache:AddItem(item);
					DropCount.Cache.CachedConvertItems=DropCount.Cache.CachedConvertItems+1;
				else
					iTable.Item=itemName;
				end
			end
		end
	end

	if (LootCount_DropCount_DB.Vendor) then
		local vendor,vTable;
		for vendor,vTable in pairs(LootCount_DropCount_DB.Vendor) do
			for item,iTable in pairs(LootCount_DropCount_DB.Vendor[vendor].Items) do
				if (type(iTable)=="number") then		-- Conversion needed
					local itemName,itemLink=GetItemInfo(item);
					if (not itemName) then
						DropCount.Cache:AddItem(item);
						DropCount.Cache.CachedConvertItems=DropCount.Cache.CachedConvertItems+1;
					else
						local count=LootCount_DropCount_DB.Vendor[vendor].Items[item];
						LootCount_DropCount_DB.Vendor[vendor].Items[item]={};
						LootCount_DropCount_DB.Vendor[vendor].Items[item].Name=itemName;
						LootCount_DropCount_DB.Vendor[vendor].Items[item].Count=count;
					end
				end
			end
		end
	end

	if (DropCount.Cache.CachedConvertItems==0) then
		LootCount_DropCount_DB.Converted=true;
		DropCount.Convert:Two();
		collectgarbage("collect");
	end
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
	DropCount:SetVendorMMPosition(dude,posX,posY);

	-- Remove all permanent items
	for item,avail in pairs(vData.Items) do
		if (not avail or not avail.Count or avail.Count==0 or avail.Count==CONST.PERMANENTITEM) then
			vData.Items[item]=nil;
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
			DuckLib:Chat("Unchached item(s) at this vendor. Look through the vendor-pages to load missing items from the server.",1);
			DropCount.VendorProblem=true;
		end
	else
		DropCount.DB.Vendor:Write(dude,vData);
		if (DropCount.VendorProblem) then
			DuckLib:Chat("Vendor saved",0,1,0);
			rebuildIcons=true;
		end
		if (rebuildIcons) then
			DropCount.Icons.MakeMM:Vendor();
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
		mTable.Kill=mTable.Kill+1;
		if (mTable.Kill==50 or mTable.Kill==(math.floor(mTable.Kill/100)*100)) then
			DuckLib:Chat(CONST.C_BASIC.."DropCount: "..CONST.C_YELLOW..mob..CONST.C_BASIC.." has been killed "..CONST.C_YELLOW..mTable.Kill..CONST.C_BASIC.." times!");
		end
		if (not notransmit) then DropCount.Com:Transmit(GUID,mob); end
		DropCount.DB.Count:Write(mob,mTable);
	else
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
	local texture=getglobal(button:GetName().."IconTexture");
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
	local _,_,_,colour=GetItemQualityColor(rarity);
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
			GameTooltip:AddDoubleLine("Showing vendors from "..currentzone.." only","",0,1,1,0,1,1);
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
		GameTooltip:AddLine("No known vendors",1,1,1);
	else
		-- Type list
		line=1;
		while(list[line]) do
			GameTooltip:AddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
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

function DropCount.Tooltip:MobList(button,plugin,limit,down)
--	if (not limit) then limit=0; end
	if (type(button)=="string") then
		button={
			FreeFloat=true;
			User={
				itemID=button;
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
	local _,_,_,colour=GetItemQualityColor(rarity);
	if (button.FreeFloat) then GameTooltip:SetOwner(UIParent,"ANCHOR_CURSOR");
	else GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); end
	GameTooltip:SetText(colour.."["..itemname.."]|r:");
	local currentzone=GetRealZoneText();
	if (not currentzone) then
		currentzone="";
	elseif (LootCount_DropCount_Character.ShowZoneMobs) then
		GameTooltip:AddDoubleLine("Showing mobs from "..currentzone.." only","",0,1,1,0,1,1);
	end
	local iTable=DropCount.DB.Item:Read(button.User.itemID);
	local skinningdrop=iTable.Skinning;
	local normaldrop=iTable.Name;
	if (skinningdrop) then
		if (normaldrop) then GameTooltip:AddDoubleLine("Loot and |cFFFF00FFprofession","",1,1,1,1,1,1);
		else GameTooltip:AddDoubleLine("Profession","",1,0,1,1,0,1); end
	end
	if (iTable.Best) then
		if (iTable.BestW) then
			GameTooltip:AddDoubleLine("Best drop-area:",iTable.BestW.Location.." ("..iTable.BestW.Score..")",0,1,1,0,1,1);
			GameTooltip:AddDoubleLine("Including instances:",iTable.Best.Location.." ("..iTable.Best.Score..")",0,1,1,0,1,1);
		else
			GameTooltip:AddDoubleLine("Best drop-area:",iTable.Best.Location.." ("..iTable.Best.Score..")",0,1,1,0,1,1);
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
					zone=" |cFF0060FF("..mTable.Zone..")";
				end

				list[line].Ltext=colour..pretext..mob..zone.."|r: ";
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
					zone=" |cFF0060FF("..mTable.Zone..")";
				end

				list[line].Ltext=colour..pretext..mob..zone.."|r";
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
			GameTooltip:AddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
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
		GameTooltip:AddDoubleLine(supressed.." more entries","",1,.5,1,1,1,1);
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

function DropCount:GetQuestStatus(checkquest)
	local White="|cFFFFFFFF";
	local Yellow="|cFFFFFF00";
	local Red="|cFFFF0000";
	local Green="|cFF00FF00";
	local bBlue="|cFFA0A0FF";		-- Bright blue
	local Dark="|cFF808080";

	if (not checkquest) then return CONST.QUEST_UNKNOWN,White; end
	if (not LootCount_DropCount_DB.Quest) then return CONST.QUEST_UNKNOWN,White; end

	-- Check running quests
	if (LootCount_DropCount_Character.Quests) then
		if (LootCount_DropCount_Character.Quests[checkquest]) then
			return CONST.QUEST_STARTED,Yellow;	-- I have it
		end
	end
	-- Maybe it's done
	if (LootCount_DropCount_Character.DoneQuest) then
		if (LootCount_DropCount_Character.DoneQuest[checkquest]) then
			return CONST.QUEST_DONE,Dark;		-- I've done it
		end
	end

	return CONST.QUEST_NOTSTARTED,Green;
end

function DropCount.Tooltip:QuestList(faction,npc,parent)
	local nTable=DropCount.DB.Quest:Read(faction,npc);
	if (not nTable) then return; end
	if (not nTable.Quests) then return; end

	LootCount_DropCount_TT:ClearLines();
	if (not parent) then parent=UIParent; end
	LootCount_DropCount_TT:SetOwner(parent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText(npc);
	for _,qData in pairs(nTable.Quests) do
		local quest,header;
		quest=qData.Quest; header=qData.Header;
		if (not header) then header=""; end
		local _,colour=DropCount:GetQuestStatus(quest);
		LootCount_DropCount_TT:AddDoubleLine("  "..colour..quest,colour..header,1,1,1,1,1,1);
	end
	LootCount_DropCount_TT:Show();
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
	LootCount_DropCount_TT:AddLine(book,1,1,1);
	LootCount_DropCount_TT:AddLine(bStatus,1,1,1);
	LootCount_DropCount_TT:Show();
end

function DropCount.Tooltip:SetNPCContents(unit,parent)
	local breakit=nil;
	if (LootCount_DropCount_DB.Quest) then
		for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
			for npc,nTable in pairs(fTable) do
				if (npc==unit) then
					breakit=true;
					DropCount.Tooltip:QuestList(CONST.MYFACTION,unit,parent);
				end
				if (breakit) then break; end
			end
			if (breakit) then break; end
		end
	end
	if (not LootCount_DropCount_DB.Vendor) then return; end
	if (not LootCount_DropCount_DB.Vendor[unit]) then return; end

	local vData=DropCount.DB.Vendor:Read(unit);
	if (not vData) then return; end

	LootCount_DropCount_TT:ClearLines();
	if (not parent) then parent=UIParent; end
	LootCount_DropCount_TT:SetOwner(parent,"ANCHOR_CURSOR");
	local line=unit;
	if (vData.Repair) then line=line..CONST.C_GREEN.." (Repair)"; end
	LootCount_DropCount_TT:SetText(line);

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
			local _,_,_,colour=GetItemQualityColor(rarity);
			list[line]={ Ltext=colour..itemname.."|r ", Rtext="" };
			if (iTable.Count>=0) then list[line].Ltext=CONST.C_RED.."* |r"..list[line].Ltext;
			elseif (iTable.Count==CONST.UNKNOWNCOUNT) then list[line].Ltext=CONST.C_YELLOW.."* |r"..list[line].Ltext;
			end
			line=line+1;
			itemsinlist=true;
		end
	end
	if (missingitems>0) then
		LootCount_DropCount_TT:AddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		LootCount_DropCount_TT:AddDoubleLine("Loading...","",1,0,0,0,0,0);
		LootCount_DropCount_TT:Show();
		LootCount_DropCount_TT.Loading=true;
		return;
	end
	LootCount_DropCount_TT.Loading=nil;
	if (not itemsinlist) then LootCount_DropCount_TT:Hide(); return; end

	list=DropCount:SortByNames(list);
	line=1;
	while(list[line]) do
		LootCount_DropCount_TT:AddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
		line=line+1;
	end
	LootCount_DropCount_TT:Show();
end

function DropCount:SetLootlist(unit)
	if (not LootCount_DropCount_DB.Count[unit]) then
		DropCount.Tooltip:SetNPCContents(unit);
		return;
	end

	LootCount_DropCount_TT:ClearLines();
	LootCount_DropCount_TT:SetOwner(UIParent,"ANCHOR_CURSOR");
	LootCount_DropCount_TT:SetText(unit);
	local text="";
	local mTable=DropCount.DB.Count:Read(unit);
	if (mTable.Skinning and mTable.Skinning>0) then text="Profession-loot: "..mTable.Skinning.." times"; end
	LootCount_DropCount_TT:AddDoubleLine(mTable.Kill.." kills",text,.4,.4,1,1,0,1);

	local list={};
	local line=1;
	local missingitems=0;
	local itemsinlist=nil;
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (string.find(iData,unit,1,true)) then		-- Plain search
			local iTable=DropCount.DB.Item:Read(item);
			if (iTable.Name) then
				for mob,mTable in pairs(iTable.Name) do
					if (mob==unit) then
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
						elseif (LootCount_DropCount_Character.ShowSingle or mTable~=1 or questitem) then
							local _,_,_,colour=GetItemQualityColor(rarity);
							local thisratio,_,thissafe=DropCount:GetRatio(item,mob);
							list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
							line=line+1;
							itemsinlist=true;
						end
					end
				end
			end
			if (iTable.Skinning) then
				for mob,mTable in pairs(iTable.Skinning) do
					if (mob==unit) then
						local itemname,_,rarity=GetItemInfo(item);
						if (not itemname or not rarity) then
							DropCount.Cache:AddItem(item);
							missingitems=missingitems+1;
						else
							local _,_,_,colour=GetItemQualityColor(rarity);
							local _,thisratio,thissafe=DropCount:GetRatio(item,mob);
							list[line]={ Ltext=colour.."["..itemname.."]|r: ", ratio=thisratio, NoSafe=thissafe };
							list[line].Ltext="|cFFFF00FF*|r "..list[line].Ltext;	-- AARRGGBB
							line=line+1;
							itemsinlist=true;
						end
					end
				end
			end
		end
	end
	if (missingitems>0) then
		LootCount_DropCount_TT:AddDoubleLine("Missing "..missingitems.." items.","",1,0,0,0,0,0);
		LootCount_DropCount_TT:AddDoubleLine("Loading...","",1,0,0,0,0,0);
		LootCount_DropCount_TT:Show();
		LootCount_DropCount_TT.Loading=true;
		return;
	end
	LootCount_DropCount_TT.Loading=nil;
	if (not itemsinlist) then LootCount_DropCount_TT:Hide(); return; end

	list=DropCount:SortByRatio(list);
	line=1;
	while(list[line]) do
		LootCount_DropCount_TT:AddDoubleLine(list[line].Ltext,list[line].Rtext,1,1,1,1,1,1);
		line=line+1;
	end
	LootCount_DropCount_TT:Show();
end

function DropCount.Cache:AddItem(item)
	DropCount.Cache.Retries=0;
	if (not DropCount.Tracker.UnknownItems) then DropCount.Tracker.UnknownItems={}; DropCount.Cache.Timer=.5; end
	DropCount.Tracker.UnknownItems[item]=true;
end

-- A blind update will queue a request at the server without any
-- book-keeping at this side.
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
	ToggleDropDownMenu(nil,nil,LootCount_DropCount_MenuOptions,button,0,0);
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

function DropCount.Menu.ToggleQuestItem()
	if (LootCount_DropCount_NoQuest[this.value]) then LootCount_DropCount_NoQuest[this.value]=nil; return; end
	LootCount_DropCount_NoQuest[this.value]=true;
end

function DropCount.Menu.ToggleChannel()
	if (LootCount_DropCount_DB[this.value]) then LootCount_DropCount_DB[this.value]=nil; else LootCount_DropCount_DB[this.value]=true; end
	if (this.value=="GUILD") then LootCount_DropCount_DB.RAID=nil; end
	if (this.value=="RAID") then LootCount_DropCount_DB.GUILD=nil; end
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

--	-- Force items to neutral
--	if (LootCount_DropCount_DB.Quest) then
--		if (not LootCount_DropCount_DB.Quest.Neutral) then LootCount_DropCount_DB.Quest.Neutral={}; end
--		for faction,fTable in pairs(LootCount_DropCount_DB.Quest) do
--			if (faction~="Neutral") then
--				for npc,nTable in pairs(fTable) do
--					if (string.find(npc,"- item ",1,true)==1 and type(nTable)=="string") then
--						LootCount_DropCount_DB.Quest.Neutral[npc]=nTable;
--						LootCount_DropCount_DB.Quest[faction][npc]=nil;
--					end
--				end
--			end
--		end
--	end

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

function DropCount:SaveBook(BookName,bZone,bX,bY)
	if (not LootCount_DropCount_DB.Book) then LootCount_DropCount_DB.Book={}; end

	local silent=true;
	if (not bX or not bY or not bZone) then
		bX,bY=DropCount:GetPLayerPosition();
		bZone=DropCount:GetFullZone();
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
		Zone=bZone,
		X=bX,
		Y=bY,
	};
	if (not silent) then
		DropCount.Icons.MakeMM:Book();
		DuckLib:Chat(CONST.C_BASIC..BookName..CONST.C_GREEN.." saved. "..CONST.C_BASIC..i.." volumes known.");
	end
	return newBook,updatedBook;
end

function DropCountXML:OnUpdate(elapsed)
	if (not DropCount.Loaded) then return; end

	DropCount.Update=DropCount.Update+elapsed;
--	if (DropCount.Update<(1/20)) then return; end
	DropCount.Update=0;
	DropCount.Loaded=DropCount.Loaded+elapsed;

	if (not DuckLib) then return; end				-- Library is missing

	if (not CONST.QUESTID and (not DropCount.Tracker.UnknownItems or not DropCount.Tracker.UnknownItems["item:31812"])) then
		_,_,_,_,_,CONST.QUESTID=GetItemInfo("item:31812");
		if (not CONST.QUESTID) then
			DropCount.Cache:AddItem("item:31812")
		else
			DropCount.Convert:One();
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
		DropCount.Convert:One();
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
			DropCount:CleanDB();
			LCDC_RescanQuests=CONST.RESCANQUESTS;
		end
	end
end

function DropCount.OnUpdate:RunQuestScan(elapsed)
	if (LCDC_RescanQuests) then
		LCDC_RescanQuests=LCDC_RescanQuests-elapsed;
		if (LCDC_RescanQuests<0) then
			LCDC_RescanQuests=nil;
			DropCount:ScanQuests();
			DropCount.Icons.MakeMM:Quest();
		end
	end
end

function DropCount.OnUpdate:WalkOldQuests(elapsed)
	if (DropCount.Timer.PrevQuests>=0) then
		DropCount.Timer.PrevQuests=DropCount.Timer.PrevQuests-elapsed;
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
end

function DropCount.OnUpdate:RunConvertAndMerge(elapsed)
	if (LootCount_DropCount_DB.Converted and LootCount_DropCount_DB.Converted~=true) then
		if (DropCount.Loaded>10) then
			if (LootCount_DropCount_DB.Converted==2) then
				DropCount.Convert:Three(); return;
			elseif (LootCount_DropCount_DB.Converted==3) then
				DropCount.Convert:Four(); return;
			elseif (LootCount_DropCount_DB.Converted==4) then
				DropCount.Convert:Five(); return;
			elseif (LootCount_DropCount_DB.Converted==5) then
				DropCount.Convert:Six(); return;
			elseif (LootCount_DropCount_DB.Converted==6) then
				DropCount.Convert:Seven(); return;
			end
			if (LootCount_DropCount_MergeData and not DropCount.Tracker.ClearMobDrop.item) then
				DropCount.Tracker.Merge.FPS.Frames=DropCount.Tracker.Merge.FPS.Frames+1;
				DropCount.Tracker.Merge.FPS.Time=DropCount.Tracker.Merge.FPS.Time+elapsed;
				if (DropCount.Tracker.Merge.FPS.Time>=CONST.BURSTSIZE) then
					DropCount.Tracker.Merge.FPS.Time=DropCount.Tracker.Merge.FPS.Time-CONST.BURSTSIZE;
					if (DropCount.Tracker.Merge.FPS.Frames>(30*CONST.BURSTSIZE)) then
						DropCount.Tracker.Merge.Burst=DropCount.Tracker.Merge.Burst*1.05;
					elseif (DropCount.Tracker.Merge.FPS.Frames<(20*CONST.BURSTSIZE)) then
						DropCount.Tracker.Merge.Burst=DropCount.Tracker.Merge.Burst/2;
						if (DropCount.Tracker.Merge.Burst<CONST.BURSTSIZE/20) then DropCount.Tracker.Merge.Burst=CONST.BURSTSIZE/20; end
					end
					-- This looks a bit weird, but it will in effect leave a portion
					-- of the last frame to make better use of the average.
					DropCount.Tracker.Merge.FPS.Frames=DropCount.Tracker.Merge.FPS.Time-CONST.BURSTSIZE;
				end

				DropCount.Tracker.Merge.BurstFlow=DropCount.Tracker.Merge.BurstFlow+DropCount.Tracker.Merge.Burst;
				if (DropCount.Tracker.Merge.BurstFlow>=1) then
					if (DropCount:MergeDatabase()) then
						LootCount_DropCount_MergeData=nil;
						collectgarbage("collect");
					end
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
								DropCount.DB.Quest:Write(faction,npc,tempTable);
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
	for _,_ in pairs(check) do return nil; end
	return true;
end

function DropCount:RemoveFromItem(section,npc)
	if (not LootCount_DropCount_DB.Item) then return; end
	for item,iData in pairs(LootCount_DropCount_DB.Item) do
		if (string.find(iData,npc,1,true)) then
			local iTable=DropCount.DB.Item:Read(item);
			if (iTable[section]) then
				iTable[section][npc]=nil;					-- Kill it
				DropCount.DB.Item:Write(item,iTable);
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
			if (DropCount.Debug) then
				DuckLib:Chat(LOOTCOUNT_DROPCOUNT_VERSIONTEXT,1,.3,.3);
				DuckLib:Chat("There are "..DropCount.Tracker.Merge.Goal.." entries to merge with your database.",1,.6,.6);
				DuckLib:Chat("A summary will be presented when the process is done.",1,.6,.6);
				DuckLib:Chat("This will take a few minutes, depending on the speed of your computer.",1,.6,.6);
				DuckLib:Chat("You can play WoW while this is running is the background, even thought you may experience some lag.",1,.6,.6);
			end
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
				if (vTable.X>0 or vTable.Y>0) then
					if (math.floor(tv.X)~=math.floor(vTable.X) or
						math.floor(tv.Y)~=math.floor(vTable.Y) or
						tv.Zone~=vTable.Zone) then
						updated=true;
					end
					tv.X=vTable.X; tv.Y=vTable.Y; tv.Zone=vTable.Zone;
					if (vTable.Faction) then tv.Faction=vTable.Faction; end
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
				local newT,updT=DropCount:SaveBook(title,vTable.Zone,vTable.X,vTable.Y);
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
						DropCount.DB.Quest:Write(faction,npc,nTable);
						DropCount.Tracker.Merge.Quest.New[faction]=DropCount.Tracker.Merge.Quest.New[faction]+1;
					else
						local updated=nil;
						-- Have it, so update location and merge quests
						local tn=DropCount.DB.Quest:Read(faction,npc);
						if (nTable.X~=nTable.Y) then	-- To fix a nasty earlier bug
							tn.X=nTable.X; tn.Y=nTable.Y;
						end
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
							DropCount.DB.Quest:Write(faction,npc,tn);
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

	DuckLib:Chat("Your DropCount database has been updated.",1,.6,.6);

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

	if (string.len(text)>0) then
		text=LOOTCOUNT_DROPCOUNT_VERSIONTEXT.."\nData merge summary:\n"..text;
		StaticPopupDialogs["LCDC_D_NOTIFICATION"].text=text;
		StaticPopup_Show("LCDC_D_NOTIFICATION");
	end
	DropCount.Icons.MakeMM:Vendor();
	DropCount.Icons.MakeMM:Book();
	DropCount.Icons.MakeMM:Quest();
	return true;
end

function DropCount.DB:PreCheck(raw,contents)
	if (type(raw)=="string") then
		if (not string.find(raw,contents,1,true)) then return nil; end
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

function DropCountXML.Menu.MinimapInitialise()
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

--[[    Minimap icon stuff    ]]
function DropCountXML.MinimapOnEnter()
	GameTooltip:SetOwner(this,"ANCHOR_LEFT");
	GameTooltip:SetText("DropCount");
	GameTooltipTextLeft1:SetTextColor(0,1,0);
	GameTooltip:AddLine(LOOTCOUNT_DROPCOUNT_VERSIONTEXT);
	GameTooltip:AddLine(CONST.C_BASIC.."<Left-click>|r for menu");
	GameTooltip:AddLine(CONST.C_BASIC.."<Right-click>|r and drag to move");
	GameTooltip:AddLine(CONST.C_BASIC.."<Shift-right-click>|r and drag for free-move");
	if (DropCount.Registered) then
		GameTooltip:AddLine(CONST.C_BASIC.."LootCount: "..CONST.C_GREEN.."Present");
	end
	GameTooltip:Show();
end

function DropCountXML.MinimapOnClick()
	ToggleDropDownMenu(1,nil,DropCount.Menu.Minimap,this:GetParent(),0,0);
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
