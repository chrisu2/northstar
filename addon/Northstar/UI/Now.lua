-- The route sheet is an open book. Crimson cover, two facing pages, a
-- gutter. The left page lists zones. The right page holds the steps, and
-- the live tracker sits in a note at the bottom of that page. Quest is the
-- leveling route. Class, Trade and PvP open guides already in this install.
--
-- Forever only: Interface 16001. Nothing here is checked in the 1.60.1.70862
-- client. A skill number is shown only when the client names that profession.
-- No cast, loot, recast, honor read, or companion command.

local ADDON, ns = ...
local UI = ns.UI
local Now, Fish, Sheet = {}, {}, {}
UI.Now, UI.Fish, UI.Sheet = Now, Fish, Sheet

Fish.GUIDE = "forever/professions/fishing"
Sheet.AREAS = { "quest", "class", "trade", "pvp" }

local f
local area = "quest"
local stepsOpen = true
local COMPACT_H = 420
local BAR_W = 640
local ROW_H = 18

local function nowClock()
	if GetTime then return GetTime() end
	return nil
end

function Fish.Lines(rank, maxRank, elapsed, caught)
	local lines = {
		"Open the fishing guide for the route.",
		"The client is not asked to detect a bite.",
		"Lures and pole enchants are not read.",
		"Northstar does not cast or loot.",
	}
	if type(rank) == "number" then
		local cap = type(maxRank) == "number" and (" / " .. maxRank) or ""
		lines[#lines + 1] = "Skill the client reported: " .. rank .. cap .. "."
	else
		lines[#lines + 1] = "Fishing skill: not reported."
	end
	if type(elapsed) == "number" then
		lines[#lines + 1] = "Session timer: " .. math.floor(elapsed / 60) .. " min."
	else
		lines[#lines + 1] = "Session timer off."
	end
	local n = type(caught) == "number" and caught or 0
	lines[#lines + 1] = "Manual tally: " .. n .. ". You tapped this. Kept on this character. Not a detected bite. Not sent."
	return lines
end

local function fishNote()
	if not ns.CharState then return nil end
	local s = ns.CharState()
	if type(s) ~= "table" then return nil end
	if type(s.fish) ~= "table" then s.fish = {} end
	return s.fish
end

-- A wall clock can be kept across a reload. GetTime cannot: it restarts
-- with the UI, so a timer based on it stays on this login only.
local function wallClock()
	if type(time) ~= "function" then return nil end
	local ok, t = pcall(time)
	if ok and type(t) == "number" and t > 0 then return t end
	return nil
end

local function sessionClock()
	return wallClock() or nowClock()
end

-- Name match only. The classic skill-line id is not treated as a Forever fact,
-- and this does not read lures, enchants, or a cast.
function Sheet.NamedRank(name)
	local want = type(name) == "string" and name:lower() or ""
	if want == "" then return nil, nil end
	if GetProfessions and GetProfessionInfo then
		local profs = { GetProfessions() }
		for i = 1, 5 do
			local index = profs[i]
			if index then
				local pname, _, rank, maxRank = GetProfessionInfo(index)
				if pname and pname:lower() == want and type(rank) == "number" then
					return rank, maxRank
				end
			end
		end
	end
	local S = C_SkillInfo
	if S and S.GetNumSkillLines and S.GetSkillLineInfo then
		for i = 1, S.GetNumSkillLines() or 0 do
			local info = S.GetSkillLineInfo(i)
			if info and not info.isHeader and info.name and info.name:lower() == want then
				local rank = tonumber(info.rank)
				local maxRank = tonumber(info.maxRank)
				if rank and not (rank == 0 and (maxRank or 0) == 0) then
					return rank, maxRank
				end
			end
		end
	end
	return nil, nil
end

function Fish.Rank()
	return Sheet.NamedRank("fishing")
end

function Fish.Load()
	local note = fishNote()
	Fish.caught = (note and tonumber(note.caught)) or 0
	local started = note and tonumber(note.started)
	if started and wallClock() then
		Fish.started = started
	else
		Fish.started = nil
		if note then note.started = nil end
	end
end

function Fish.Elapsed()
	if not Fish.started then return nil end
	local t = sessionClock()
	if not t then return nil end
	local elapsed = t - Fish.started
	if elapsed < 0 then return nil end
	return elapsed
end

function Fish.AddCatch()
	local note = fishNote()
	local count = ((note and tonumber(note.caught)) or Fish.caught or 0) + 1
	Fish.caught = count
	if note then note.caught = count end
	if Now.Refresh then Now.Refresh() end
end

function Fish.ToggleSession()
	if not sessionClock() then return end
	if Fish.started then Fish.started = nil else Fish.started = sessionClock() end
	local note = fishNote()
	if note then note.started = wallClock() and Fish.started or nil end
	if Now.Refresh then Now.Refresh() end
end

function Fish.OpenGuide()
	local E = ns.Engine
	if E and E.OpenTab then E.OpenTab(Fish.GUIDE, true) end
end

-- The next open goal of a step view, plus up to three quieter lines.
-- `view` is an Engine step view, or nil when no guide is open.
function Now.Compose(view)
	if type(view) ~= "table" or type(view.goals) ~= "table" then
		return { step = "", title = "No guide open", next = "Open a guide when you are ready.", more = {} }
	end
	local function open(g)
		return g and not g.folded and g.status ~= "done" and g.status ~= "skipped" and g.status ~= "na"
	end
	local nextGoal
	if view.current and open(view.goals[view.current]) then nextGoal = view.goals[view.current] end
	if not nextGoal then
		for i = 1, #view.goals do
			if open(view.goals[i]) then nextGoal = view.goals[i] break end
		end
	end
	local more = {}
	for i = 1, #view.goals do
		local g = view.goals[i]
		if open(g) and g ~= nextGoal then
			more[#more + 1] = UI.PlainGoalText(g)
			if #more == 3 then break end
		end
	end
	local step = view.index and ("Step " .. view.index) or ""
	local title = view.title or ""
	local nextText = nextGoal and UI.PlainGoalText(nextGoal) or "Nothing left on this step."
	-- The arrow's waypoint can be an along goal (a kill while the step is a
	-- turn-in). The sheet says that same line, with the log's count.
	local wp = ns.Engine and ns.Engine.GetWaypoint and ns.Engine.GetWaypoint()
	if wp and type(wp.label) == "string" and wp.label ~= "" then
		nextText = wp.label
		if wp.stepIndex and ns.Engine.GetStepView then
			local sv = ns.Engine.GetStepView(wp.stepIndex)
			if sv then
				step = "Step " .. wp.stepIndex
				if sv.title and sv.title ~= "" then title = sv.title end
				local g = sv.goals and wp.goalIndex and sv.goals[wp.goalIndex]
				local p = g and g.progress
				if p and type(p.cur) == "number" and type(p.max) == "number" then
					nextText = nextText .. " (" .. p.cur .. "/" .. p.max .. ")"
				end
			end
		end
	end
	local checks = {}
	for i = 1, #view.goals do
		local g = view.goals[i]
		checks[#checks + 1] = { text = UI.PlainGoalText(g), done = g.status == "done" or g.status == "skipped" }
	end
	return { step = step, title = title, next = nextText, more = more, checks = checks }
end

-- Facing-relative words. 0 is straight ahead. This is not the floating dart.
function Now.BearingWord(angle)
	if type(angle) ~= "number" then return "" end
	local pi = math.pi
	local a = angle % (2 * pi)
	if a > pi then a = a - 2 * pi end
	local abs = math.abs(a)
	if abs < pi / 8 then return "ahead" end
	if abs > pi - pi / 8 then return "behind" end
	if a > 0 then
		if a < 3 * pi / 8 then return "ahead right" end
		if a < 5 * pi / 8 then return "right" end
		return "behind right"
	end
	a = -a
	if a < 3 * pi / 8 then return "ahead left" end
	if a < 5 * pi / 8 then return "left" end
	return "behind left"
end

-- Arrival stays on this line. It does not replace the action and it is not a green ring.
function Now.DistanceLine(mode, yards)
	if mode == "arrived" or mode == "search" then return "at the point" end
	if mode == "far" then return "other continent" end
	if mode == "nopos" then return "no position" end
	if mode == "none" or mode == nil then return "" end
	if type(yards) == "number" and ns.FormatDistance then return ns.FormatDistance(yards) end
	if type(yards) == "number" then return math.floor(yards + 0.5) .. " yd" end
	return ""
end

function Now.ReadCourse()
	local Nav = ns.Nav
	if not Nav or not Nav.Sample then return "", "", nil end
	local mode, dist, angle = Nav.Sample()
	return Now.BearingWord(angle), Now.DistanceLine(mode, dist), angle
end

-- One plain line: "Ahead, 375 yd" or "At the point".
function Now.CourseLine()
	local bear, dist = Now.ReadCourse()
	if dist == "at the point" then return "At the point" end
	if type(bear) ~= "string" or bear == "" then return dist or "" end
	local nice = bear:gsub("^%l", string.upper)
	if type(dist) == "string" and dist ~= "" then return nice .. ", " .. dist end
	return nice
end

Sheet.SLEEP_ID = "forever/miscellaneous/cozy-sleeping-bag"

function Sheet.Headers()
	if type(Sheet.headers) == "table" then return Sheet.headers end
	local G = ns.Guides
	if G and G.List then return G.List() end
	return {}
end

function Sheet.Player()
	if type(Sheet.player) == "table" then return Sheet.player end
	local C = ns.Compat
	if C and C.GetPlayerInfo then return C.GetPlayerInfo() end
	return {}
end

function Sheet.TradeName(header)
	local title = header and header.title
	if type(title) == "string" and title ~= "" and not title:find("{", 1, true) then
		return (title:gsub(" %d+%-%d+$", ""))
	end
	local id = header and header.id or ""
	local name = id:match("/([^/]+)$") or id
	return (name:gsub("^%l", string.upper))
end

function Sheet.MatchesClass(header, classToken)
	if type(classToken) ~= "string" or classToken == "" then return false end
	if not header or header.category ~= "Class" or type(header.classes) ~= "table" then return false end
	local want = classToken:lower()
	for i = 1, #header.classes do
		local c = header.classes[i]
		if type(c) == "string" and c:lower() == want then return true end
	end
	return false
end

-- Race and faction use the same rule as the guide menu. A class with no
-- race or faction on the player still lists that class's guides.
function Sheet.FitsCharacter(header, player)
	if not Sheet.MatchesClass(header, player and player.class) then return false end
	if not player or (not player.race and not player.faction) then return true end
	local G = ns.Guides
	if G and G.GuideMatches then return G.GuideMatches(header, player) end
	return true
end

local function byTitle(a, b) return (a.title or "") < (b.title or "") end

function Sheet.ClassView(headers, player)
	if not player or type(player.class) ~= "string" or player.class == "" then
		return { kind = "unknown", rows = {}, text = "Class is not reported. Class quests stay closed." }
	end
	local rows = {}
	for _, h in ipairs(headers or {}) do
		if Sheet.FitsCharacter(h, player) then
			rows[#rows + 1] = { id = h.id, title = h.title or h.id }
		end
	end
	table.sort(rows, byTitle)
	if #rows == 0 then
		return { kind = "missing", class = player.class, rows = {}, text = "No " .. player.class .. " class guide is loaded." }
	end
	local who = player.class
	if type(player.race) == "string" and player.race ~= "" then who = player.race .. " " .. who end
	return { kind = "class", class = player.class, race = player.race, rows = rows, text = who .. ". Class quests, separate from the leveling route." }
end

function Sheet.TradeView(headers, rankOf)
	local rows = {}
	for _, h in ipairs(headers or {}) do
		if h.category == "Professions" and type(h.id) == "string" then
			local title = Sheet.TradeName(h)
			local rank, maxRank = nil, nil
			if rankOf then rank, maxRank = rankOf(title) end
			local skill = "not reported"
			if type(rank) == "number" then
				skill = type(maxRank) == "number" and (rank .. " / " .. maxRank) or tostring(rank)
			end
			rows[#rows + 1] = { id = h.id, title = title, skill = skill, fishing = title:lower() == "fishing" }
		end
	end
	table.sort(rows, byTitle)
	local text = #rows == 0 and "No profession guide is loaded." or "Profession guides in this install. A number is the client's own name match. Routes inside a guide are not repeated here."
	return { kind = "trade", rows = rows, text = text }
end

function Sheet.PvpView(headers)
	local bg, mounts = {}, {}
	for _, h in ipairs(headers or {}) do
		if h.folder == "Reputation · Battlegrounds" then
			bg[#bg + 1] = { id = h.id, title = h.title or h.id }
		elseif h.folder == "Mounts · PvP" then
			mounts[#mounts + 1] = { id = h.id, title = h.title or h.id }
		end
	end
	table.sort(bg, byTitle)
	table.sort(mounts, byTitle)
	return {
		kind = "pvp",
		battlegrounds = bg,
		mounts = mounts,
		rows = bg,
		world = "World PvP has no guide in this checkout.",
		companion = "No companion command is sent.",
		text = #bg == 0 and "Battleground guides are not loaded." or "Battleground guides in this install.",
	}
end

function Sheet.NoteLevel(levelId, header)
	if header and type(header.id) == "string" and (header.category == nil or header.category == "Leveling") then
		return header.id
	end
	return levelId
end

function Sheet.Open(headers, id)
	for _, h in ipairs(headers or {}) do
		if h.id == id then return { ok = true, id = id, category = h.category, title = h.title or id } end
	end
	return { ok = false, id = id, reason = "not loaded" }
end

function Sheet.ReleaseLabel(on)
	if on then return "Release in a battleground: on. You turned this on." end
	return "Release in a battleground: off."
end

-- Leveling guides this character can follow, from the loaded packs.
-- The Horde and Alliance guides live in Northstar_Guides_<faction>, loaded at login.
function Sheet.LevelingRows(headers, player)
	local G = ns.Guides
	local rows = {}
	for _, h in ipairs(headers or {}) do
		if h and (h.category == nil or h.category == "Leveling") then
			local ok = true
			if player and G and G.GuideMatches then
				ok = G.GuideMatches(h, player) or (G.OtherStart and G.OtherStart(h, player))
			end
			if ok then
				local title = h.zoneName
				if type(title) ~= "string" or title == "" then title = h.title or h.id end
				rows[#rows + 1] = { id = h.id, title = title, minLevel = h.minLevel or 1, maxLevel = h.maxLevel or h.minLevel or 1 }
			end
		end
	end
	local level = player and player.level or 1
	local function band(row)
		if level >= row.minLevel and level <= row.maxLevel then return 0 end
		if row.minLevel > level then return 1 end
		return 2
	end
	table.sort(rows, function(a, b)
		local ba, bb = band(a), band(b)
		if ba ~= bb then return ba < bb end
		if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
		return (a.title or "") < (b.title or "")
	end)
	return rows
end

function Sheet.RangeInk(minLevel, maxLevel, level)
	local Q = (ns.Theme and ns.Theme.QUEST) or {}
	level = level or 1
	minLevel, maxLevel = minLevel or 1, maxLevel or minLevel or 1
	if level >= minLevel and level <= maxLevel then return Q.easy end
	if minLevel <= level + 4 then return Q.gold end
	if minLevel <= level + 8 then return Q.hard end
	return Q.crimson
end

-- Class guides for this character, from the loaded packs.
function Now.ClassRows()
	local view = Sheet.ClassView(Sheet.Headers(), Sheet.Player())
	return view.rows
end

local function questColors()
	local T = ns.Theme
	return (T and T.QUEST) or {
		crimson = { 0.48, 0.08, 0.13, 1 }, gold = { 0.89, 0.75, 0.34, 1 },
		parchment = { 0.95, 0.89, 0.77, 1 }, ink = { 0.23, 0.09, 0.11, 1 },
		muted = { 0.47, 0.33, 0.25, 1 }, plum = { 0.16, 0.10, 0.13, 1 },
		easy = { 0.24, 0.48, 0.27, 1 }, hard = { 0.77, 0.47, 0.19, 1 },
		title = { 0.48, 0.08, 0.13, 1 }, body = { 0.23, 0.09, 0.11, 1 },
		page = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-page-left",
		pageLeft = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-page-left",
		pageRight = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-page-right",
		note = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-note",
		cover = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-cover",
		corner = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-corner",
		ribbon = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-ribbon",
		ribbonOn = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-ribbon-on",
		check = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-check",
		mark = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-mark",
		rule = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-rule",
		spine = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-spine",
		plumTex = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-plum",
		goldTex = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-gold",
		crimsonTex = "Interface\\AddOns\\Northstar\\Media\\UI\\tome-crimson",
		fontTitle = "Interface\\AddOns\\Northstar\\Media\\Fonts\\Cinzel-Regular.ttf",
		fontBody = "Interface\\AddOns\\Northstar\\Media\\Fonts\\Alegreya-Regular.ttf",
		fontFallback = "Fonts\\FRIZQT__.TTF",
	}
end

local function ink(fs, key)
	local c = questColors()[key] or questColors().body
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function label(parent, font, key)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	ink(fs, key or "body")
	return fs
end

local function face(fs, path, size)
	local Q = questColors()
	if not fs:SetFont(path or Q.fontBody, size or 12, "") then
		fs:SetFont(Q.fontFallback or "Fonts\\FRIZQT__.TTF", size or 12, "")
	end
end

local function openListed(id)
	local found = Sheet.Open(Sheet.Headers(), id)
	if not found.ok then return found end
	local E = ns.Engine
	if E and E.OpenTab then E.OpenTab(id, true) end
	return found
end

local AREAS = {
	{ id = "quest", label = "Leveling" },
	{ id = "class", label = "Class" },
	{ id = "trade", label = "Professions" },
	{ id = "pvp", label = "PvP" },
}

local function areaLabel(id)
	for _, spec in ipairs(AREAS) do if spec.id == id then return spec.label end end
	return "Leveling"
end

local function button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 18)
	b:SetText(text)
	b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.Label:SetAllPoints()
	b.Label:SetJustifyH("LEFT")
	b.Label:SetText(text)
	face(b.Label, questColors().fontBody, 11)
	ink(b.Label, "gold")
	b:SetScript("OnClick", onClick)
	return b
end

local function plate(parent, path, layer)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(path)
	return t
end

local function build()
	if f then return f end
	local Q = questColors()
	f = CreateFrame("Frame", "NorthstarNow", UIParent)
	f:SetSize(BAR_W, COMPACT_H)
	f:SetPoint("TOP", UIParent, "TOP", 0, -80)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.DragLocked() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetClampedToScreen(true)
	f:Hide()

	local cover = plate(f, Q.cover)
	cover:SetAllPoints()

	f.Title = label(f, "GameFontNormal", "gold")
	face(f.Title, Q.fontTitle, 13)
	f.Title:SetPoint("TOP", 0, -7)
	f.Title:SetJustifyH("CENTER")
	f.Title:SetText("Northstar")

	local close = CreateFrame("Button", nil, f)
	close:SetSize(16, 16)
	close:SetPoint("TOPRIGHT", -16, -6)
	close.Label = label(close, "GameFontNormal", "gold")
	face(close.Label, Q.fontTitle, 13)
	close.Label:SetAllPoints()
	close.Label:SetJustifyH("CENTER")
	close.Label:SetText("x")
	close:SetScript("OnClick", function() f:Hide() end)

	local left = CreateFrame("Frame", nil, f)
	left:SetPoint("TOPLEFT", 14, -32)
	left:SetSize(297, 374)
	local leftPage = plate(left, Q.pageLeft or Q.page)
	leftPage:SetAllPoints()
	local right = CreateFrame("Frame", nil, f)
	right:SetPoint("TOPLEFT", 329, -32)
	right:SetSize(297, 374)
	local rightPage = plate(right, Q.pageRight or Q.page)
	rightPage:SetAllPoints()
	f.Center = right
	local gutter = plate(f, Q.spine, "ARTWORK")
	gutter:SetPoint("TOPLEFT", 311, -32)
	gutter:SetSize(18, 374)

	f.Menu = CreateFrame("Button", "NorthstarNowMenu", f)
	f.Menu:SetSize(1, 1)
	f.Menu:Hide()

	f.Areas = {}
	local ribbonW, ribbonGap = 76, 8
	local ribbonX = (BAR_W - (4 * ribbonW + 3 * ribbonGap)) / 2
	for i, spec in ipairs(AREAS) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(ribbonW, spec.id == "quest" and 52 or 34)
		b:SetPoint("TOPLEFT", ribbonX + (i - 1) * (ribbonW + ribbonGap), -20)
		b.Plate = plate(b, spec.id == "quest" and Q.ribbonOn or Q.ribbon)
		b.Plate:SetAllPoints()
		b.Label = label(b, "GameFontHighlightSmall", spec.id == "quest" and "ink" or "parchment")
		face(b.Label, Q.fontBody, 11)
		b.Label:SetPoint("TOP", 0, -6)
		b.Label:SetJustifyH("CENTER")
		b.Label:SetText(spec.label)
		b.areaId = spec.id
		b:SetScript("OnClick", function()
			area = spec.id
			Now.Refresh()
		end)
		f.Areas[spec.id] = b
	end

	f.ZoneHead = label(left, "GameFontHighlightSmall", "title")
	face(f.ZoneHead, Q.fontBody, 13)
	f.ZoneHead:SetPoint("TOPLEFT", 18, -48)
	f.ZoneHead:SetText("Zones")

	f.Rows = {}
	for i = 1, 12 do
		local b = CreateFrame("Button", nil, left)
		b:SetSize(262, ROW_H)
		b:SetPoint("TOPLEFT", 16, -68 - (i - 1) * ROW_H)
		b.Plate = plate(b, Q.goldTex)
		b.Plate:SetAllPoints()
		b.Plate:Hide()
		b.Label = label(b, "GameFontHighlightSmall", "ink")
		face(b.Label, Q.fontBody, 12)
		b.Label:SetPoint("LEFT", 4, 0)
		b.Label:SetText("")
		b.Range = label(b, "GameFontHighlightSmall", "gold")
		face(b.Range, Q.fontBody, 11)
		b.Range:SetPoint("RIGHT", -4, 0)
		b.Range:SetJustifyH("RIGHT")
		b.Range:SetText("")
		b:SetScript("OnClick", function(self)
			if self.rowId then openListed(self.rowId) end
		end)
		b:Hide()
		f.Rows[i] = b
	end

	f.PageNoL = label(left, "GameFontHighlightSmall", "muted")
	face(f.PageNoL, Q.fontBody, 11)
	f.PageNoL:SetPoint("BOTTOM", 0, 6)
	f.PageNoL:SetJustifyH("CENTER")
	f.PageNoL:SetText("~ 1 ~")
	f.PageNoR = label(right, "GameFontHighlightSmall", "muted")
	face(f.PageNoR, Q.fontBody, 11)
	f.PageNoR:SetPoint("BOTTOM", 0, 6)
	f.PageNoR:SetJustifyH("CENTER")
	f.PageNoR:SetText("~ 2 ~")

	f.DropPlate = plate(right, Q.crimsonTex, "ARTWORK")
	f.DropPlate:SetSize(28, 32)
	f.DropPlate:SetPoint("TOPLEFT", 16, -46)
	f.DropPlate:Hide()
	f.Drop = label(right, "GameFontNormal", "gold")
	face(f.Drop, Q.fontTitle, 22)
	f.Drop:SetPoint("TOPLEFT", 20, -48)
	f.Drop:SetText("")
	f.Drop:Hide()

	f.Area = label(right, "GameFontNormal", "title")
	face(f.Area, Q.fontTitle, 18)
	f.Area:SetPoint("TOPLEFT", 16, -52)
	f.Area:SetText("Leveling")

	f.Rule = plate(right, Q.rule, "ARTWORK")
	f.Rule:SetSize(260, 8)
	f.Rule:SetPoint("TOPLEFT", 16, -84)

	f.Step = label(right, "GameFontHighlightSmall", "muted")
	face(f.Step, Q.fontBody, 11)
	f.Step:SetPoint("TOPLEFT", 16, -96)

	f.Band = plate(right, Q.goldTex, "BORDER")
	f.Band:SetPoint("TOPLEFT", 14, -114)
	f.Band:SetSize(268, 18)
	f.Band:Hide()
	f.Mark = plate(right, Q.mark, "OVERLAY")
	f.Mark:SetSize(12, 14)
	f.Mark:SetPoint("TOPLEFT", 18, -116)
	f.Mark:Hide()
	f.Next = label(right, "GameFontHighlight", "ink")
	face(f.Next, Q.fontBody, 12)
	f.Next:SetPoint("TOPLEFT", 34, -116)
	f.Next:SetWidth(240)

	f.Strip = CreateFrame("Frame", nil, right)
	f.Strip:SetPoint("TOPLEFT", 14, -138)
	f.Strip:SetSize(268, 108)
	f.StripRows = {}
	for i = 1, 8 do
		local row = CreateFrame("Frame", nil, f.Strip)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
		row:SetPoint("RIGHT", 0, 0)
		row.Wash = plate(row, Q.goldTex)
		row.Wash:SetAllPoints()
		row.Wash:Hide()
		row.Mark = plate(row, Q.check, "ARTWORK")
		row.Mark:SetSize(12, 12)
		row.Mark:SetPoint("LEFT", 2, 0)
		row.Mark:Hide()
		row.Text = label(row, "GameFontHighlightSmall", "ink")
		face(row.Text, Q.fontBody, 11)
		row.Text:SetPoint("LEFT", 16, 0)
		row.Text:SetPoint("RIGHT", -4, 0)
		row:Hide()
		f.StripRows[i] = row
	end

	f.Note = CreateFrame("Frame", nil, right)
	f.Note:SetPoint("BOTTOMLEFT", 12, 22)
	f.Note:SetSize(272, 112)
	local noteBg = plate(f.Note, Q.note or Q.page)
	noteBg:SetAllPoints()

	f.Head = label(f.Note, "GameFontNormal", "title")
	face(f.Head, Q.fontTitle, 13)
	f.Head:SetPoint("TOPLEFT", 8, -6)
	f.Head:SetWidth(256)
	if f.Head.SetWordWrap then f.Head:SetWordWrap(true) end

	f.Checks = {}
	f.GoalLines = {}
	for i = 1, 6 do
		local mark = plate(f.Note, Q.check, "ARTWORK")
		mark:SetSize(12, 12)
		mark:SetPoint("TOPLEFT", 8, -26 - (i - 1) * 12)
		mark:Hide()
		local line = label(f.Note, "GameFontHighlightSmall", "ink")
		face(line, Q.fontBody, 11)
		line:SetPoint("LEFT", mark, "RIGHT", 4, 0)
		line:SetWidth(200)
		line:Hide()
		f.Checks[i] = mark
		f.GoalLines[i] = line
	end

	f.Dir = label(f.Note, "GameFontHighlightSmall", "muted")
	face(f.Dir, Q.fontBody, 11)
	f.Dir:SetPoint("BOTTOMLEFT", 8, 6)
	f.Dir:SetText("Direction")
	f.Arrow = plate(f.Note, Q.mark, "ARTWORK")
	f.Arrow:SetSize(10, 12)
	f.Arrow:SetPoint("LEFT", f.Dir, "RIGHT", 4, 0)
	f.Course = label(f.Note, "GameFontHighlightSmall", "ink")
	face(f.Course, Q.fontBody, 12)
	f.Course:SetPoint("LEFT", f.Arrow, "RIGHT", 2, 0)
	f.Course:SetWidth(150)
	f.Bear = label(f.Note, "GameFontHighlightSmall", "muted")
	f.Bear:SetPoint("TOPLEFT", 8, -6)
	f.Bear:Hide()
	f.Dist = label(f.Note, "GameFontHighlightSmall", "muted")
	f.Dist:SetPoint("TOPLEFT", 8, -6)
	f.Dist:Hide()
	f.Tick = plate(f.Note, Q.mark, "OVERLAY")
	f.Tick:SetSize(1, 1)
	f.Tick:Hide()

	f.More = label(right, "GameFontHighlightSmall", "muted")
	face(f.More, Q.fontBody, 11)
	f.More:SetPoint("BOTTOMLEFT", 16, 136)
	f.More:SetWidth(260)
	f.More:Hide()

	f.Wide = button(right, "Steps", 64, function()
		stepsOpen = not stepsOpen
		Now.Refresh()
	end)
	f.Wide:SetPoint("TOPRIGHT", -12, -94)

	f.Tools = button(f, "Tools", 44, function()
		if f.ToolsBox:IsShown() then f.ToolsBox:Hide() else f.ToolsBox:Show() end
	end)
	f.Tools:SetPoint("BOTTOMLEFT", 16, 1)
	f.ToolsBox = CreateFrame("Frame", nil, f)
	f.ToolsBox:SetSize(160, 72)
	f.ToolsBox:SetPoint("BOTTOMLEFT", f.Tools, "TOPLEFT", 0, 4)
	local boxBg = plate(f.ToolsBox, Q.pageLeft or Q.page)
	boxBg:SetAllPoints()
	f.ToolsBox:Hide()

	f.Sleep = button(f.ToolsBox, "Sleeping bag", 140, function() openListed(Sheet.SLEEP_ID) end)
	f.Sleep:SetPoint("TOPLEFT", 4, -4)
	f.Sleep:Hide()
	f.FishTime = button(f.ToolsBox, "Fish time", 72, function() Fish.ToggleSession() end)
	f.FishTime:SetPoint("TOPLEFT", 4, -24)
	f.FishTime:Hide()
	f.FishTally = button(f.ToolsBox, "Fish tally", 72, function() Fish.AddCatch() end)
	f.FishTally:SetPoint("LEFT", f.FishTime, "RIGHT", 4, 0)
	f.FishTally:Hide()
	f.Release = button(f.ToolsBox, "Release", 148, function()
		local on = ns.Get and ns.Get("qol.autoReleasePvP")
		if ns.Set then ns.Set("qol.autoReleasePvP", not on) end
		Now.Refresh()
	end)
	f.Release:SetPoint("TOPLEFT", 4, -44)
	f.Release:Hide()

	Now.frame = f
	return f
end

local function showRows(frame, rows)
	local open = ns.Engine and ns.Engine.GetGuide and ns.Engine.GetGuide()
	local openId = open and open.id
	local level = Sheet.Player().level or 1
	for i = 1, #frame.Rows do
		local b = frame.Rows[i]
		local row = rows[i]
		if row then
			b.rowId = row.id
			b.Label:SetText(row.label or row.title or row.id)
			if b.Range then
				if row.minLevel then
					b.Range:SetText(row.minLevel .. "-" .. row.maxLevel)
					local c = Sheet.RangeInk(row.minLevel, row.maxLevel, level)
					if c then b.Range:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
				else
					b.Range:SetText("")
				end
			end
			if b.Plate then b.Plate:SetShown(row.id ~= nil and row.id == openId) end
			b:Show()
		else
			b.rowId = nil
			if b.Range then b.Range:SetText("") end
			if b.Plate then b.Plate:Hide() end
			b:Hide()
		end
	end
end

local function paintChecks(frame, checks, nextText)
	local Q = questColors()
	for i = 1, #frame.Checks do
		local row = checks and checks[i]
		local mark, line = frame.Checks[i], frame.GoalLines[i]
		if row then
			line:SetText(row.text or "")
			local c = row.done and Q.easy or Q.gold
			line:SetTextColor(c[1], c[2], c[3], c[4] or 1)
			line:Show()
			if row.done then mark:Show() else mark:Hide() end
		else
			line:Hide()
			mark:Hide()
		end
	end
	frame.Next:SetText(nextText or "")
end

local function paintRibbons(frame)
	local Q = questColors()
	for _, spec in ipairs(AREAS) do
		local b = frame.Areas[spec.id]
		local on = area == spec.id
		if b.Plate then b.Plate:SetTexture(on and Q.ribbonOn or Q.ribbon) end
		if b.SetHeight then b:SetHeight(on and 52 or 34) end
		if b.Label then
			local c = on and Q.ink or Q.parchment
			b.Label:SetTextColor(c[1], c[2], c[3], 1)
		end
	end
end

local function zoneTitle()
	local E = ns.Engine
	local g = E and E.GetGuide and E.GetGuide()
	if type(g) ~= "table" then return nil end
	if type(g.zoneName) == "string" and g.zoneName ~= "" then return g.zoneName end
	for _, h in ipairs(Sheet.Headers()) do
		if h.id == g.id then
			if type(h.zoneName) == "string" and h.zoneName ~= "" then return h.zoneName end
			if type(h.title) == "string" and h.title ~= "" then return h.title end
		end
	end
	if type(g.title) == "string" and g.title ~= "" then return g.title end
end

local function paintDrop(frame, zone)
	if zone and zone ~= "" then
		frame.Drop:SetText(zone:sub(1, 1))
		frame.Drop:Show()
		frame.DropPlate:Show()
		frame.Area:ClearAllPoints()
		frame.Area:SetPoint("LEFT", frame.Drop, "RIGHT", 6, -4)
		frame.Area:SetText(zone:sub(2))
	else
		frame.Drop:Hide()
		frame.DropPlate:Hide()
		frame.Area:ClearAllPoints()
		frame.Area:SetPoint("TOPLEFT", frame.Center, "TOPLEFT", 12, -16)
		frame.Area:SetText(areaLabel(area))
	end
end

local function paintStrip(frame)
	local show = stepsOpen and area == "quest"
	frame.Strip:SetShown(show)
	frame.Wide:SetText(stepsOpen and "Hide steps" or "Steps")
	if frame.Wide.Label then frame.Wide.Label:SetText(stepsOpen and "Hide steps" or "Steps") end
	local Q = questColors()
	local E = ns.Engine
	local here = E and E.GetStepIndex and E.GetStepIndex() or 1
	for i = 1, #frame.StripRows do
		local row = frame.StripRows[i]
		local index = here - 1 + i
		local view = E and E.GetStepView and index >= 1 and E.GetStepView(index) or nil
		if show and view and view.title then
			local current = index == here
			row.Text:SetText((current and "! " or "") .. view.title)
			local c = current and Q.ink or (index < here and Q.easy or Q.muted)
			row.Text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
			row.Wash:SetShown(current)
			row.Mark:SetTexture(index < here and Q.check or Q.mark)
			row.Mark:SetShown(index <= here)
			row:Show()
		else
			row:Hide()
		end
	end
end

function Now.Apply(composed)
	local frame = build()
	paintRibbons(frame)
	if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame.Menu, areaLabel(area)) end
	frame.Sleep:Hide()
	frame.FishTime:Hide()
	frame.FishTally:Hide()
	frame.Release:Hide()
	frame.ToolsBox:Hide()
	frame.Band:Hide()
	frame.Mark:Hide()
	showRows(frame, {})
	for i = 1, #frame.Checks do frame.Checks[i]:Hide(); frame.GoalLines[i]:Hide() end
	frame.Tick:Hide()
	frame.Bear:Hide()
	frame.Dist:Hide()
	frame:SetHeight(COMPACT_H)
	local headers = Sheet.Headers()
	if area == "class" then
		paintDrop(frame, nil)
		if frame.ZoneHead then frame.ZoneHead:SetText("Guides") end
		local view = Sheet.ClassView(headers, Sheet.Player())
		frame.Step:SetText("Not the leveling route")
		frame.Head:SetText(view.text)
		frame.Next:SetText("")
		frame.Course:SetText("")
		frame.More:SetText("")
		showRows(frame, view.rows)
	elseif area == "trade" then
		paintDrop(frame, nil)
		if frame.ZoneHead then frame.ZoneHead:SetText("Guides") end
		local view = Sheet.TradeView(headers, Sheet.NamedRank)
		frame.Step:SetText("Loaded profession guides")
		frame.Head:SetText(view.text)
		local fish = Fish.Lines(nil, nil, Fish.Elapsed(), Fish.caught or 0)
		frame.Next:SetText("")
		frame.Course:SetText("")
		frame.More:SetText(fish[#fish])
		frame.More:Show()
		local rows = {}
		for i, row in ipairs(view.rows) do
			rows[i] = { id = row.id, label = row.title .. "  " .. row.skill }
		end
		showRows(frame, rows)
		frame.FishTime:Show()
		frame.FishTally:Show()
	elseif area == "pvp" then
		paintDrop(frame, nil)
		if frame.ZoneHead then frame.ZoneHead:SetText("Guides") end
		local view = Sheet.PvpView(headers)
		frame.Step:SetText("Battlegrounds")
		frame.Head:SetText(view.text)
		frame.Next:SetText(view.world)
		frame.Course:SetText("")
		frame.More:SetText(view.companion)
		frame.More:Show()
		showRows(frame, view.battlegrounds)
		frame.Release:Show()
		if frame.Release.Label then frame.Release.Label:SetText(Sheet.ReleaseLabel(ns.Get and ns.Get("qol.autoReleasePvP"))) end
		frame.Release:SetText(Sheet.ReleaseLabel(ns.Get and ns.Get("qol.autoReleasePvP")))
	else
		paintDrop(frame, zoneTitle())
		if frame.ZoneHead then frame.ZoneHead:SetText("Zones") end
		showRows(frame, Sheet.LevelingRows(headers, Sheet.Player()))
		frame.Step:SetText(composed.step or "")
		frame.Head:SetText(composed.title or "")
		paintChecks(frame, composed.checks, composed.next)
		local bear, dist = Now.ReadCourse()
		frame.Bear:SetText(bear)
		frame.Dist:SetText(dist)
		frame.Course:SetText(Now.CourseLine())
		frame.Course:Show()
		local on = (composed.next or "") ~= ""
		frame.Band:SetShown(on)
		frame.Mark:SetShown(on)
		local sleep = Sheet.Open(headers, Sheet.SLEEP_ID)
		if sleep.ok then frame.Sleep:Show() end
		frame.More:SetText("")
	end
	paintStrip(frame)
end

function Now.Refresh()
	if not f or not f:IsShown() then return end
	local E = ns.Engine
	if E and E.GetGuide then
		Now.levelId = Sheet.NoteLevel(Now.levelId, E.GetGuide())
	end
	local view
	if E and E.GetStepIndex and E.GetStepView then
		local i = E.GetStepIndex()
		if i then view = E.GetStepView(i) end
	end
	Now.Apply(Now.Compose(view))
end

function Now.Show()
	build()
	f:Show()
	Now.Refresh()
end

function Now.Hide()
	if f then f:Hide() end
end

function Now.Toggle()
	if f and f:IsShown() then Now.Hide() else Now.Show() end
end

local function shown()
	return ns.Get("ui.journal") and ns.Get("ui.shown") ~= false
end

local function sync()
	if shown() then Now.Show() else Now.Hide() end
end

ns.On("TOGGLE_JOURNAL", function()
	if f and f:IsShown() then
		ns.Set("ui.journal", false)
	else
		ns.Set("ui.journal", true)
		ns.Set("ui.shown", true)
	end
	sync()
end)
ns.On("SETTING_CHANGED", function(path)
	if path == "ui.journal" or path == "ui.shown" then sync() end
end)
ns.On("GUIDE_CHANGED", function() Now.Refresh() end)
-- The arrow already follows these. The sheet was only painted on guide
-- changes, so an accepted quest left "Accept ..." on screen.
ns.On("STEP_CHANGED", function() Now.Refresh() end)
ns.On("STEP_UPDATED", function() Now.Refresh() end)
ns.On("WAYPOINT_CHANGED", function() Now.Refresh() end)

if ns.RegisterCommand then
	ns.RegisterCommand("journal", function() ns.Fire("TOGGLE_JOURNAL") end, "Show or hide the step list")
	ns.RegisterCommand("fish", function()
		ns.Set("ui.journal", true)
		ns.Set("ui.shown", true)
		area = "trade"
		sync()
		Fish.OpenGuide()
	end, "Open the fishing guide from the trade list")
end

ns.OnLogin(function()
	-- An older saved window that opened the wide guide does not bring that
	-- window back. ui.wideGuide is the only switch for it.
	if not ns.Get("ui.wideGuide") then ns.Set("ui.journal", true) end
	-- SavedVariables schema 1 stored the floating dart on, because that was
	-- the default. Schema 2 drops that stored value back to the new default
	-- (off) once. A later /northstar arrow stores true and is left alone.
	local db = ns.DB()
	if (db.schema or 1) < 2 then
		-- Only a stored "on" is cleared. The default itself is already off,
		-- and writing false over an absent key shows up as a changed setting.
		local nav = db.settings and db.settings.nav
		if type(nav) == "table" and nav.arrow == true then ns.Set("nav.arrow", false) end
		db.schema = 2
		local arrow = ns.Nav and ns.Nav.arrow
		if arrow and arrow.Refresh then arrow:Refresh() end
	end
	Fish.Load()
	sync()
end)
if ns.IsLoggedIn and ns.IsLoggedIn() then
	Fish.Load()
	sync()
end
