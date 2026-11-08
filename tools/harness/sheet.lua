-- Offline scenarios for the route sheet. Values are synthetic. This file is
-- loaded by `node tools/polestar.js harness` under tests/lua/wow_stub.lua.
-- It is not the Forever client and it does not cast, loot, or talk to a server.
--
-- Simulated here: CreateFrame, font strings, button clicks, GetProfessionInfo,
-- GetProfessions, UnitFactionGroup, C_AddOns.GetAddOnInfo, and the saved-variable
-- table NorthstarCharDB. Not simulated: the 1.60.1.70862 client, map geometry,
-- quest completion, combat, secure actions, and whether a profession name the
-- mock returns is what that client would return.

local S = Northstar.UI.Sheet
local N = Northstar.UI.Now

S.headers = {
	{ id = "synthetic/leveling/camp", title = "Synthetic camp", category = "Leveling" },
	{ id = "synthetic/class/druid/form", title = "Synthetic Cat Form", category = "Class", classes = { "DRUID" } },
	{ id = "synthetic/professions/alchemy", title = "Alchemy 1-300", category = "Professions" },
	{ id = "synthetic/professions/fishing", title = "Fishing 1-300", category = "Professions" },
	{ id = "synthetic/pvp/warsong", title = "Synthetic Warsong", folder = "Reputation · Battlegrounds" },
}
S.player = { class = "DRUID", race = "Tauren" }

Northstar.Engine.GetStepIndex = function() return 2 end
Northstar.Engine.GetStepView = function()
	return {
		index = 2,
		title = "Synthetic camp",
		current = 1,
		goals = { { status = "current", text = "Accept Synthetic Herb", t = "accept" } },
	}
end
Northstar.Engine.GetGuide = function()
	return { id = "synthetic/leveling/camp", category = "Leveling" }
end
Northstar.Engine.OpenTab = function(id)
	return id
end

local function snap()
	local f = N.frame
	local rows = {}
	for i = 1, #f.Rows do
		local b = f.Rows[i]
		if b:IsShown() then rows[#rows + 1] = b.Label:GetText() end
	end
	local areas = {}
	for _, id in ipairs(S.AREAS) do
		areas[#areas + 1] = f.Areas[id].Label:GetText()
	end
	return {
		area = f.Area:GetText(),
		step = f.Step:GetText(),
		head = f.Head:GetText(),
		next = f.Next:GetText(),
		more = f.More:GetText(),
		rows = rows,
		areas = areas,
		levelId = N.levelId,
	}
end

N.Show()
local quest = snap()

S.player = { class = "DRUID", race = "Tauren" }
N.frame.Areas.class:Click()
local classDruid = snap()
local opened
Northstar.Engine.OpenTab = function(id)
	opened = id
	return 1
end
N.frame.Rows[1]:Click()

S.player = {}
N.frame.Areas.class:Click()
local classUnknown = snap()

S.player = { class = "WARRIOR" }
N.frame.Areas.class:Click()
local classWarrior = snap()

GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Alchemy", nil, 12, 75 end
N.frame.Areas.trade:Click()
local trade = snap()
Northstar.UI.Fish.AddCatch()
local tally = snap()

N.frame.Areas.pvp:Click()
local pvp = snap()

local levelId = S.NoteLevel(nil, { id = "synthetic/leveling/camp", category = "Leveling" })
levelId = S.NoteLevel(levelId, { id = "synthetic/class/druid/form", category = "Class" })

stub.addons = {
	{ name = "Northstar_Guides", title = "Northstar Guides" },
	{ name = "Northstar_Guides_Horde", title = "Northstar Guides Horde" },
}
stub.addonMeta = stub.addonMeta or {}
stub.addonMeta.Northstar_Guides = { Version = Northstar.version }
stub.addonMeta.Northstar_Guides_Horde = { Version = Northstar.version }
UnitFactionGroup = function() return "Horde", "Horde" end
local missing = Northstar.Data.CheckInstall()

emit({
	quest = quest,
	classDruid = classDruid,
	classUnknown = classUnknown,
	classWarrior = classWarrior,
	trade = trade,
	tally = tally,
	pvp = pvp,
	opened = opened,
	levelId = levelId,
	missing = missing,
})
