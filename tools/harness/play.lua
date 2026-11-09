-- One replay of the offline sheet. HARNESS.actions is applied in order to the
-- real Now.lua frames. Values are synthetic. This is not the Forever client.
--
-- Simulated: CreateFrame, clicks, font strings, GetProfessionInfo, C_AddOns,
-- ns.Set, and NorthstarCharDB. Not simulated: quest completion, casts, loot,
-- map movement, a PvP queue, honor, and the 1.60.1.70862 client.

local H = HARNESS or {}
local actions = H.actions or {}
local S = Northstar.UI.Sheet
local N = Northstar.UI.Now

local STEPS = {
	{ index = 1, title = "Synthetic camp", text = "Accept Synthetic Herb" },
	{ index = 2, title = "Synthetic camp", text = "Turn in Synthetic Herb" },
	{ index = 3, title = "Synthetic camp", text = "Talk to Synthetic Guide" },
}

S.headers = {
	{ id = "synthetic/leveling/camp", title = "Synthetic camp", category = "Leveling" },
	{ id = "synthetic/class/druid/bear", title = "Synthetic Bear Form", category = "Class", classes = { "DRUID" } },
	{ id = "synthetic/class/druid/cat", title = "Synthetic Cat Form", category = "Class", classes = { "DRUID" } },
	{ id = "synthetic/class/mage/robe", title = "Synthetic Mage Robe", category = "Class", classes = { "MAGE" } },
	{ id = "synthetic/class/hunter/tame", title = "Synthetic Tame", category = "Class", classes = { "HUNTER" } },
	{ id = "synthetic/class/priest/flash", title = "Synthetic Flash", category = "Class", classes = { "PRIEST" } },
	{ id = "synthetic/professions/alchemy", title = "Alchemy 1-300", category = "Professions" },
	{ id = "synthetic/professions/fishing", title = "Fishing 1-300", category = "Professions" },
	{ id = "synthetic/professions/herbalism", title = "Herbalism 1-300", category = "Professions" },
	{ id = "synthetic/pvp/warsong", title = "Synthetic Warsong", folder = "Reputation · Battlegrounds" },
	{ id = "synthetic/pvp/mount", title = "Synthetic War Mount", folder = "Mounts · PvP" },
}

local step = 1
local className = "DRUID"
local raceName = "Tauren"
local prof = nil
local codex = false
local opened = nil
local lastError = nil

local function guideNow()
	return { id = "synthetic/leveling/camp", category = "Leveling" }
end

Northstar.Engine.GetStepIndex = function() return STEPS[step].index end
Northstar.Engine.GetStepView = function()
	local s = STEPS[step]
	return { index = s.index, title = s.title, current = 1, goals = { { status = "current", text = s.text, t = "accept" } } }
end
Northstar.Engine.GetGuide = function() return guideNow() end
Northstar.Engine.OpenTab = function(id)
	opened = id
	local header
	for _, h in ipairs(S.Headers()) do
		if h.id == id then header = h end
	end
	if header and header.category ~= "Leveling" then
		Northstar.Engine.GetGuide = function() return header end
	else
		Northstar.Engine.GetGuide = function() return guideNow() end
	end
	N.Refresh()
	return 1
end

GetProfessions = function()
	if prof then return 1 end
end
GetProfessionInfo = function()
	if prof then return prof.name, nil, prof.rank, prof.max end
end

S.player = { class = className, race = raceName }

local function apply(a)
	local t = a.t
	if t == "class" then
		className = a.class or ""
		raceName = a.race or ""
		S.player = { class = className ~= "" and className or nil, race = raceName ~= "" and raceName or nil }
		N.Refresh()
	elseif t == "step" then
		step = a.n
		N.Refresh()
	elseif t == "area" then
		local b = N.frame.Areas[a.id]
		if not b then error("no area " .. tostring(a.id)) end
		b:Click()
	elseif t == "row" then
		local b = N.frame.Rows[a.n]
		if not b or not b:IsShown() then error("row " .. tostring(a.n) .. " is not shown") end
		b:Click()
	elseif t == "fish" then
		N.frame.FishTally:Click()
	elseif t == "release" then
		N.frame.Release:Click()
	elseif t == "reset" then
		Northstar.Set("qol.autoReleasePvP", false)
		local s = Northstar.CharState()
		s.fish = {}
		Northstar.UI.Fish.Load()
		N.Refresh()
	elseif t == "codex" then
		codex = a.present and true or false
	elseif t == "profession" then
		if type(a.name) ~= "string" or a.name == "" then prof = nil else prof = { name = a.name, rank = a.rank, max = a.max } end
		N.Refresh()
	elseif t == "boom" then
		error("synthetic Lua error raised inside the replay")
	else
		error("unknown action " .. tostring(t))
	end
end

N.Show()
for i = 1, #actions do
	local ok, err = pcall(apply, actions[i])
	if not ok then lastError = tostring(err) end
end

local function checkInstall()
	stub.addons = {
		{ name = "Northstar_Guides", title = "Northstar Guides" },
		{ name = "Northstar_Guides_Horde", title = "Northstar Guides Horde" },
	}
	if codex then stub.addons[#stub.addons + 1] = { name = "Northstar_Codex", title = "Northstar Codex" } end
	stub.addonMeta = stub.addonMeta or {}
	stub.addonMeta.Northstar_Guides = { Version = Northstar.version }
	stub.addonMeta.Northstar_Guides_Horde = { Version = Northstar.version }
	if codex then stub.addonMeta.Northstar_Codex = { Version = Northstar.version } end
	UnitFactionGroup = function() return "Horde", "Horde" end
	return Northstar.Data.CheckInstall()
end

local f = N.frame
local rows = {}
for i = 1, #f.Rows do
	local b = f.Rows[i]
	if b:IsShown() then rows[#rows + 1] = b.Label:GetText() end
end
local areas = {}
for _, id in ipairs(S.AREAS) do
	areas[#areas + 1] = { id = id, label = f.Areas[id].Label:GetText() }
end
local fish = Northstar.CharState().fish or {}

emit({
	area = f.Area:GetText(),
	stepLine = f.Step:GetText(),
	head = f.Head:GetText(),
	next = f.Next:GetText(),
	more = f.More:GetText(),
	rows = rows,
	areas = areas,
	releaseShown = f.Release:IsShown() and true or false,
	releaseText = f.Release:IsShown() and f.Release.Label:GetText() or nil,
	levelId = N.levelId,
	opened = opened,
	release = Northstar.Get("qol.autoReleasePvP") and true or false,
	fish = tonumber(fish.caught) or 0,
	missing = checkInstall(),
	error = lastError,
	class = className,
	race = raceName,
	step = step,
	limits = {
		"CreateFrame, clicks, font strings, GetProfessionInfo, C_AddOns, ns.Set, and NorthstarCharDB are simulated.",
		"Quest completion, casts, loot, map movement, a PvP queue, honor, and the 1.60.1.70862 client are not simulated.",
		"Synthetic Herb and the synthetic guide ids are fixtures, not live quests.",
		"This page is not a statement about ban-safety.",
	},
})
