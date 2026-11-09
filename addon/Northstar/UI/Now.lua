-- The route sheet. One column: the current action, then four areas down the
-- side. Quest is the leveling route. Class, Trade and PvP open guides that
-- are already in this install. Fishing is one trade row.
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
local stepsOpen = false
local COMPACT_H = 128
local BAR_W = 320
local ROW_H = 16

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

-- Class guides for this character, from the loaded packs.
function Now.ClassRows()
	local view = Sheet.ClassView(Sheet.Headers(), Sheet.Player())
	return view.rows
end

local function questColors()
	local T = ns.Theme
	return (T and T.QUEST) or {
		title = { 0.28, 0.14, 0.04, 1 }, body = { 0.32, 0.18, 0.06, 1 }, muted = { 0.45, 0.30, 0.16, 1 },
		wash = { 0.78, 0.66, 0.42, 0.45 }, check = "Interface\\Buttons\\UI-CheckBox-Check",
		bg = "Interface\\DialogFrame\\UI-DialogBox-Background", edge = "Interface\\DialogFrame\\UI-DialogBox-Border",
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

local function button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 120, 22)
	b:SetText(text)
	b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.Label:SetAllPoints()
	b.Label:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
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

local function build()
	if f then return f end
	local Q = questColors()
	f = CreateFrame("Frame", "NorthstarNow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(BAR_W, COMPACT_H)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -120)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.DragLocked() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetClampedToScreen(true)
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = Q.bg, edgeFile = Q.edge,
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		if f.SetBackdropColor then f:SetBackdropColor(1, 1, 1, 1) end
	end

	f.Menu = CreateFrame("Frame", "NorthstarNowMenu", f, "UIDropDownMenuTemplate")
	f.Menu:SetPoint("TOPLEFT", 4, -8)
	if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(f.Menu, 140) end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(f.Menu, function()
			for _, spec in ipairs(AREAS) do
				local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
				info.text = spec.label
				info.checked = area == spec.id
				info.func = function() area = spec.id; UIDropDownMenu_SetText(f.Menu, spec.label); Now.Refresh() end
				if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info) end
			end
		end)
	end
	if UIDropDownMenu_SetText then UIDropDownMenu_SetText(f.Menu, areaLabel(area)) end

	f.Tools = button(f, "Tools", 54, function()
		if f.ToolsBox:IsShown() then f.ToolsBox:Hide() else f.ToolsBox:Show() end
	end)
	f.Tools:SetPoint("TOPRIGHT", -16, -16)
	f.ToolsBox = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.ToolsBox:SetSize(150, 88)
	f.ToolsBox:SetPoint("TOPRIGHT", f.Tools, "BOTTOMRIGHT", 0, -2)
	f.ToolsBox:Hide()
	if f.ToolsBox.SetBackdrop then
		f.ToolsBox:SetBackdrop({ bgFile = Q.bg, edgeFile = Q.edge, tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	end

	f.Area = label(f, "GameFontNormal", "title")
	f.Area:SetPoint("TOPLEFT", 24, -22)
	f.Step = label(f, "GameFontNormalSmall", "muted")
	f.Step:SetPoint("TOPLEFT", 24, -42)
	f.Head = label(f, "GameFontNormal", "title")
	f.Head:SetPoint("TOPLEFT", 24, -56)
	f.Head:SetPoint("TOPRIGHT", -20, -56)
	f.Course = label(f, "GameFontHighlightSmall", "body")
	f.Course:SetPoint("TOPLEFT", 24, -74)
	f.Course:SetPoint("TOPRIGHT", -20, -74)
	-- Kept for the course numbers. The line the player reads is Course.
	f.Bear = label(f, "GameFontHighlightSmall", "body")
	f.Bear:SetPoint("TOPLEFT", 24, -74)
	f.Bear:Hide()
	f.Dist = label(f, "GameFontHighlightSmall", "body")
	f.Dist:SetPoint("TOPLEFT", 24, -74)
	f.Dist:Hide()
	f.Tick = f:CreateTexture(nil, "OVERLAY")
	f.Tick:SetSize(1, 1)
	f.Tick:Hide()
	f.Next = label(f, "GameFontHighlight", "body")
	f.Next:SetPoint("TOPLEFT", 44, -92)
	f.Next:SetPoint("TOPRIGHT", -16, -92)
	f.More = label(f, "GameFontHighlightSmall", "muted")
	f.More:SetPoint("TOPLEFT", 24, -110)
	f.More:SetPoint("RIGHT", -16, 0)
	f.More:SetHeight(20)
	f.More:Hide()

	f.Checks = {}
	f.GoalLines = {}
	for i = 1, 6 do
		local mark = f:CreateTexture(nil, "OVERLAY")
		mark:SetTexture(Q.check)
		mark:SetSize(16, 16)
		mark:SetPoint("TOPLEFT", 22, -90 - (i - 1) * ROW_H)
		mark:Hide()
		local line = label(f, "GameFontHighlightSmall", "body")
		line:SetPoint("LEFT", mark, "RIGHT", 4, 0)
		line:SetPoint("RIGHT", f, "RIGHT", -16, 0)
		line:Hide()
		f.Checks[i] = mark
		f.GoalLines[i] = line
	end

	f.Strip = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.Strip:SetWidth(132)
	f.Strip:SetPoint("TOPLEFT", f, "TOPRIGHT", -6, -12)
	f.Strip:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -6, 12)
	if f.Strip.SetBackdrop then
		f.Strip:SetBackdrop({ bgFile = Q.bg, edgeFile = Q.edge, tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	end
	f.StripRows = {}
	for i = 1, 8 do
		local row = CreateFrame("Frame", nil, f.Strip)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 8, -6 - (i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", -8, -6 - (i - 1) * ROW_H)
		row.Wash = row:CreateTexture(nil, "BACKGROUND")
		row.Wash:SetAllPoints()
		local w = Q.wash
		row.Wash:SetColorTexture(w[1], w[2], w[3], w[4] or 0.45)
		row.Wash:Hide()
		row.Mark = row:CreateTexture(nil, "OVERLAY")
		row.Mark:SetTexture(Q.check)
		row.Mark:SetSize(14, 14)
		row.Mark:SetPoint("LEFT", 0, 0)
		row.Mark:Hide()
		row.Text = label(row, "GameFontHighlightSmall", "body")
		row.Text:SetPoint("LEFT", 16, 0)
		row.Text:SetPoint("RIGHT", 0, 0)
		row:Hide()
		f.StripRows[i] = row
	end

	f.Wide = button(f, "Steps", 54, function()
		stepsOpen = not stepsOpen
		Now.Refresh()
	end)
	f.Wide:SetPoint("BOTTOMRIGHT", -16, 12)
	f.Areas = {}
	for _, spec in ipairs(AREAS) do
		local b = button(f, spec.label, 90, function()
			area = spec.id
			if UIDropDownMenu_SetText then UIDropDownMenu_SetText(f.Menu, spec.label) end
			Now.Refresh()
		end)
		b.areaId = spec.id
		b:Hide()
		f.Areas[spec.id] = b
	end
	f.Rows = {}
	for i = 1, 12 do
		local b = button(f, "", 260, function(self)
			if self.rowId then openListed(self.rowId) end
		end)
		b:SetPoint("TOPLEFT", 20, -88 - (i - 1) * ROW_H)
		b:Hide()
		f.Rows[i] = b
	end
	f.Sleep = button(f.ToolsBox, "Sleeping bag", 130, function() openListed(Sheet.SLEEP_ID) end)
	f.Sleep:SetPoint("TOPLEFT", 8, -8)
	f.Sleep:Hide()
	f.FishTime = button(f.ToolsBox, "Fish time", 64, function() Fish.ToggleSession() end)
	f.FishTime:SetPoint("TOPLEFT", 8, -32)
	f.FishTime:Hide()
	f.FishTally = button(f.ToolsBox, "Fish tally", 64, function() Fish.AddCatch() end)
	f.FishTally:SetPoint("LEFT", f.FishTime, "RIGHT", 4, 0)
	f.FishTally:Hide()
	f.Release = button(f.ToolsBox, "Release", 130, function()
		local on = ns.Get and ns.Get("qol.autoReleasePvP")
		if ns.Set then ns.Set("qol.autoReleasePvP", not on) end
		Now.Refresh()
	end)
	f.Release:SetPoint("TOPLEFT", 8, -56)
	f.Release:Hide()

	Now.frame = f
	return f
end

local function showRows(frame, rows)
	for i = 1, #frame.Rows do
		local b = frame.Rows[i]
		local row = rows[i]
		if row then
			b.rowId = row.id
			b.Label:SetText(row.label or row.title or row.id)
			b:Show()
		else
			b.rowId = nil
			b:Hide()
		end
	end
end

local function paintChecks(frame, checks, nextText)
	for i = 1, #frame.Checks do
		local row = checks and checks[i]
		local mark, line = frame.Checks[i], frame.GoalLines[i]
		if row then
			line:SetText(row.text or "")
			line:Show()
			if row.done then mark:Show() else mark:Hide() end
		else
			line:Hide()
			mark:Hide()
		end
	end
	frame.Next:SetText(nextText or "")
end

local function paintStrip(frame)
	frame.Strip:SetShown(stepsOpen)
	frame.Wide:SetText(stepsOpen and "Hide steps" or "Steps")
	if frame.Wide.Label then frame.Wide.Label:SetText(stepsOpen and "Hide steps" or "Steps") end
	local E = ns.Engine
	local here = E and E.GetStepIndex and E.GetStepIndex() or 1
	for i = 1, #frame.StripRows do
		local row = frame.StripRows[i]
		local index = here - 1 + i
		local view = E and E.GetStepView and index >= 1 and E.GetStepView(index) or nil
		if stepsOpen and view and view.title then
			row.Text:SetText(view.title)
			row.Wash:SetShown(index == here)
			row.Mark:SetShown(index < here)
			row:Show()
		else
			row:Hide()
		end
	end
end

function Now.Apply(composed)
	local frame = build()
	frame.Area:SetText(areaLabel(area))
	if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame.Menu, areaLabel(area)) end
	frame.Sleep:Hide()
	frame.FishTime:Hide()
	frame.FishTally:Hide()
	frame.Release:Hide()
	frame.ToolsBox:Hide()
	showRows(frame, {})
	for i = 1, #frame.Checks do frame.Checks[i]:Hide(); frame.GoalLines[i]:Hide() end
	frame.Tick:Hide()
	frame.Bear:Hide()
	frame.Dist:Hide()
	local headers = Sheet.Headers()
	if area == "class" then
		local view = Sheet.ClassView(headers, Sheet.Player())
		frame.Step:SetText("Not the leveling route")
		frame.Head:SetText(view.text)
		frame.Next:SetText("")
		frame.Course:SetText("")
		frame.More:SetText("")
		showRows(frame, view.rows)
		frame:SetHeight(COMPACT_H + #view.rows * ROW_H)
	elseif area == "trade" then
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
		frame:SetHeight(COMPACT_H + #rows * ROW_H)
		frame.FishTime:Show()
		frame.FishTally:Show()
	elseif area == "pvp" then
		local view = Sheet.PvpView(headers)
		frame.Step:SetText("Battlegrounds")
		frame.Head:SetText(view.text)
		frame.Next:SetText(view.world)
		frame.Course:SetText("")
		frame.More:SetText(view.companion)
		frame.More:Show()
		showRows(frame, view.battlegrounds)
		frame:SetHeight(COMPACT_H + (#view.battlegrounds + 1) * ROW_H)
		frame.Release:Show()
		if frame.Release.Label then frame.Release.Label:SetText(Sheet.ReleaseLabel(ns.Get and ns.Get("qol.autoReleasePvP"))) end
		frame.Release:SetText(Sheet.ReleaseLabel(ns.Get and ns.Get("qol.autoReleasePvP")))
	else
		frame.Step:SetText(composed.step or "")
		frame.Head:SetText(composed.title or "")
		paintChecks(frame, composed.checks, composed.next)
		local bear, dist = Now.ReadCourse()
		frame.Bear:SetText(bear)
		frame.Dist:SetText(dist)
		frame.Course:SetText(Now.CourseLine())
		frame.Course:Show()
		local sleep = Sheet.Open(headers, Sheet.SLEEP_ID)
		if sleep.ok then frame.Sleep:Show() end
		frame.More:SetText("")
		frame:SetHeight(COMPACT_H)
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
