
local ThisVersion=5;

LootCount_DropCount_MergeData = {
	Version=ThisVersion,
	["Vendor"] = {
	},
	["Book"] = {
	},
	["Quest"] = {
	},
	["Item"] = {
	},
	["Count"] = {
	},
}

LootCount_DropCount_RemoveData = {
}

if (GetLocale()~="enGB" and GetLocale()~="enUS") then

LootCount_DropCount_MergeData = {
	Version=ThisVersion, Vendor={}, Book={}, Item={}, Count={}, Quest={},
}
LootCount_DropCount_RemoveData = { Generic={}, }

end
