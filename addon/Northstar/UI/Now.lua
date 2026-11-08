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
	return { step = step, title = title, next = nextText, more = more }
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

local function byTitle(a, b) return (a.title or "") < (b.title or "") end

function Sheet.ClassView(headers, player)
	if not player or type(player.class) ~= "string" or player.class == "" then
		return { kind = "unknown", rows = {}, text = "Class is not reported. Class quests stay closed." }
	end
	local rows = {}
	for _, h in ipairs(headers or {}) do
		if Sheet.MatchesClass(h, player.class) then
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

local function plate(parent, name)
	local frame = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			tile = true, tileSize = 16, edgeSize = 0,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		frame:SetBackdropColor(0.10, 0.11, 0.12, 0.96)
		if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0, 0, 0, 0) end
	end
	local bar = frame:CreateTexture(nil, "ARTWORK")
	bar:SetColorTexture(0.42, 0.26, 0.16, 1)
	bar:SetPoint("TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMLEFT", 0, 0)
	bar:SetWidth(5)
	frame.Bar = bar
	return frame
end

local function label(parent, font, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetTextColor(r, g, b)
	return fs
end

local function button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 15)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetAllPoints()
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(0.72, 0.70, 0.64)
	b.Label = fs
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
	{ id = "quest", label = "Quest" },
	{ id = "class", label = "Class" },
	{ id = "trade", label = "Trade" },
	{ id = "pvp", label = "PvP" },
}

local function build()
	if f then return f end
	f = plate(UIParent, "NorthstarNow")
	f:SetSize(348, 430)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -120)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.DragLocked() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetClampedToScreen(true)

	f.Area = label(f, "GameFontHighlightSmall", 0.55, 0.42, 0.32)
	f.Area:SetPoint("TOPLEFT", 16, -12)
	f.Step = label(f, "GameFontHighlightSmall", 0.62, 0.60, 0.54)
	f.Step:SetPoint("TOPLEFT", 16, -30)
	f.Step:SetPoint("TOPRIGHT", -12, -30)
	f.Head = label(f, "GameFontHighlight", 0.93, 0.90, 0.84)
	f.Head:SetPoint("TOPLEFT", 16, -48)
	f.Head:SetPoint("TOPRIGHT", -12, -48)
	f.Next = label(f, "GameFontHighlight", 0.86, 0.78, 0.62)
	f.Next:SetPoint("TOPLEFT", 16, -70)
	f.Next:SetPoint("TOPRIGHT", -12, -70)
	f.More = label(f, "GameFontHighlightSmall", 0.62, 0.60, 0.54)
	f.More:SetPoint("TOPLEFT", 16, -96)
	f.More:SetPoint("RIGHT", -12, 0)
	f.More:SetHeight(36)

	f.Wide = button(f, "Wide", 40, function()
		ns.Set("ui.journal", false)
		ns.Set("ui.shown", true)
	end)
	f.Wide:SetPoint("TOPRIGHT", -10, -10)
	f.Areas = {}
	for i, spec in ipairs(AREAS) do
		local b = button(f, spec.label, 70, function()
			area = spec.id
			Now.Refresh()
		end)
		b.areaId = spec.id
		b:SetPoint("BOTTOMLEFT", 16, 12 + (4 - i) * 16)
		f.Areas[spec.id] = b
	end
	f.Rows = {}
	for i = 1, 12 do
		local b = button(f, "", 300, function(self)
			if self.rowId then openListed(self.rowId) end
		end)
		b:SetPoint("TOPLEFT", 16, -132 - (i - 1) * 16)
		b:Hide()
		f.Rows[i] = b
	end
	f.Sleep = button(f, "Sleeping bag", 140, function() openListed(Sheet.SLEEP_ID) end)
	f.Sleep:SetPoint("TOPLEFT", 16, -132)
	f.Sleep:Hide()
	f.FishTime = button(f, "Fish time", 70, function() Fish.ToggleSession() end)
	f.FishTime:SetPoint("BOTTOMLEFT", 100, 78)
	f.FishTime:Hide()
	f.FishTally = button(f, "Fish tally", 70, function() Fish.AddCatch() end)
	f.FishTally:SetPoint("LEFT", f.FishTime, "RIGHT", 8, 0)
	f.FishTally:Hide()
	f.Release = button(f, "Release", 220, function()
		local on = ns.Get and ns.Get("qol.autoReleasePvP")
		if ns.Set then ns.Set("qol.autoReleasePvP", not on) end
		Now.Refresh()
	end)
	f.Release:SetPoint("TOPLEFT", 16, -300)
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

local function markAreas(frame)
	for _, spec in ipairs(AREAS) do
		local b = frame.Areas[spec.id]
		local on = spec.id == area
		b.Label:SetText((on and "· " or "  ") .. spec.label)
		b.Label:SetTextColor(on and 0.93 or 0.55, on and 0.86 or 0.52, on and 0.72 or 0.46)
	end
end

function Now.Apply(composed)
	local frame = build()
	markAreas(frame)
	frame.Sleep:Hide()
	frame.FishTime:Hide()
	frame.FishTally:Hide()
	frame.Release:Hide()
	showRows(frame, {})
	local headers = Sheet.Headers()
	if area == "class" then
		local view = Sheet.ClassView(headers, Sheet.Player())
		frame.Area:SetText("CLASS")
		frame.Step:SetText("Not the leveling route")
		frame.Head:SetText(view.text)
		frame.Next:SetText("")
		frame.More:SetText("")
		showRows(frame, view.rows)
	elseif area == "trade" then
		local view = Sheet.TradeView(headers, Sheet.NamedRank)
		frame.Area:SetText("TRADE")
		frame.Step:SetText("All loaded profession guides")
		frame.Head:SetText(view.text)
		local fish = Fish.Lines(nil, nil, Fish.Elapsed(), Fish.caught or 0)
		frame.Next:SetText("")
		frame.More:SetText(fish[#fish])
		local rows = {}
		for i, row in ipairs(view.rows) do
			rows[i] = { id = row.id, label = row.title .. "  " .. row.skill }
		end
		showRows(frame, rows)
		frame.FishTime:Show()
		frame.FishTally:Show()
	elseif area == "pvp" then
		local view = Sheet.PvpView(headers)
		frame.Area:SetText("PVP")
		frame.Step:SetText("Battlegrounds, then what is not here")
		frame.Head:SetText(view.text)
		frame.Next:SetText(view.world)
		frame.More:SetText(view.companion)
		showRows(frame, view.battlegrounds)
		frame.Release:Show()
		frame.Release.Label:SetText(Sheet.ReleaseLabel(ns.Get and ns.Get("qol.autoReleasePvP")))
	else
		frame.Area:SetText("QUEST")
		frame.Step:SetText(composed.step or "")
		frame.Head:SetText(composed.title or "")
		frame.Next:SetText(composed.next or "")
		local more = table.concat(composed.more or {}, "\n")
		local sleep = Sheet.Open(headers, Sheet.SLEEP_ID)
		if sleep.ok then
			more = (more ~= "" and (more .. "\n") or "") .. "Cozy Sleeping Bag is a separate guide. It does not replace this route."
			frame.Sleep:Show()
		end
		frame.More:SetText(more)
	end
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
	Fish.Load()
	sync()
end)
if ns.IsLoggedIn and ns.IsLoggedIn() then
	Fish.Load()
	sync()
end
