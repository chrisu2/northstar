-- The compact step list. One next action, the rest of the step in quiet lines,
-- and the wide guide window, search, and collections kept behind text buttons.
-- Fishing is a mode of this same list, not a second dashboard.
--
-- Forever only: Interface 16001. Nothing here is checked in the 1.60.1.70862
-- client. Skill numbers are shown only when the client answers. Catch counts,
-- lure timers, pool maps, and casting are omitted.

local ADDON, ns = ...
local UI = ns.UI
local Now, Fish = {}, {}
UI.Now, UI.Fish = Now, Fish

Fish.GUIDE = "forever/professions/fishing"

local f
local mode = "step" -- "step" | "fish"

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
function Fish.Rank()
	local want = "fishing"
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
	return {
		step = view.index and ("Step " .. view.index) or "",
		title = view.title or "",
		next = nextGoal and UI.PlainGoalText(nextGoal) or "Nothing left on this step.",
		more = more,
	}
end

-- Class guides for this character, from the loaded packs. Empty when the
-- client has not named a class or no class guide is loaded.
function Now.ClassRows()
	local rows = {}
	local G, C = ns.Guides, ns.Compat
	local info = C and C.GetPlayerInfo and C.GetPlayerInfo()
	local class = info and info.class
	if not (G and G.List and class) then return rows end
	for _, h in ipairs(G.List()) do
		if h.category == "Class" and type(h.classes) == "table" then
			for i = 1, #h.classes do
				if h.classes[i] == class then
					rows[#rows + 1] = { id = h.id, title = h.title or h.id }
					break
				end
			end
		end
		if #rows == 3 then break end
	end
	return rows
end

local function plate(parent, name)
	local frame = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.06, 0.06, 0.05, 0.94)
		frame:SetBackdropBorderColor(0.45, 0.40, 0.32, 1)
	end
	return frame
end

local function label(parent, font, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetTextColor(r, g, b)
	return fs
end

local function button(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(68, 16)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetAllPoints()
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(0.78, 0.74, 0.66)
	b.Label = fs
	b:SetScript("OnClick", onClick)
	return b
end

local function build()
	if f then return f end
	f = plate(UIParent, "NorthstarNow")
	f:SetSize(300, 228)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -160)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.DragLocked() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetClampedToScreen(true)

	f.Title = label(f, "GameFontHighlightSmall", 0.55, 0.52, 0.46)
	f.Title:SetPoint("TOPLEFT", 12, -10)
	f.Title:SetText("Northstar")
	f.Step = label(f, "GameFontHighlightSmall", 0.70, 0.66, 0.58)
	f.Step:SetPoint("TOPLEFT", 12, -26)
	f.Step:SetPoint("TOPRIGHT", -12, -26)
	f.Head = label(f, "GameFontHighlight", 0.90, 0.86, 0.76)
	f.Head:SetPoint("TOPLEFT", 12, -42)
	f.Head:SetPoint("TOPRIGHT", -12, -42)
	f.Next = label(f, "GameFontHighlight", 0.93, 0.84, 0.62)
	f.Next:SetPoint("TOPLEFT", 12, -62)
	f.Next:SetPoint("TOPRIGHT", -12, -62)
	f.More = label(f, "GameFontHighlightSmall", 0.62, 0.60, 0.54)
	f.More:SetPoint("TOPLEFT", 12, -84)
	f.More:SetPoint("RIGHT", -12, 0)
	f.More:SetHeight(78)

	f.ClassBtn = button(f, "Class", function()
		if UI.ShowPicker then UI.ShowPicker() end
		local P = UI.Picker
		if P and P.ShowSection then P.ShowSection("Guides") end
		if P and P.SetCategory then P.SetCategory("Class") end
	end)
	f.ClassBtn:SetPoint("BOTTOMLEFT", 12, 10)
	f.FishBtn = button(f, "Fish", function()
		mode = mode == "fish" and "step" or "fish"
		Now.Refresh()
	end)
	f.FishBtn:SetPoint("LEFT", f.ClassBtn, "RIGHT", 8, 0)
	f.MoreBtn = button(f, "More", function()
		if UI.ShowPicker then UI.ShowPicker() end
	end)
	f.MoreBtn:SetPoint("LEFT", f.FishBtn, "RIGHT", 8, 0)
	f.FullBtn = button(f, "Full guide", function()
		ns.Set("ui.journal", false)
		ns.Set("ui.shown", true)
	end)
	f.FullBtn:SetPoint("LEFT", f.MoreBtn, "RIGHT", 8, 0)
	f.TimerBtn = button(f, "Timer", function() Fish.ToggleSession() end)
	f.TimerBtn:Hide()
	f.CatchBtn = button(f, "Caught", function() Fish.AddCatch() end)
	f.CatchBtn:Hide()

	Now.frame = f
	return f
end

function Now.Apply(composed, fishLines)
	local frame = build()
	if fishLines then
		frame.Step:SetText("Fishing")
		frame.Head:SetText(fishLines[1] or "")
		frame.Next:SetText(fishLines[2] or "")
		local rest = {}
		for i = 3, #fishLines do rest[#rest + 1] = fishLines[i] end
		frame.More:SetText(table.concat(rest, "\n"))
		frame.TimerBtn:Show()
		frame.TimerBtn:ClearAllPoints()
		frame.TimerBtn:SetPoint("BOTTOMLEFT", 12, 28)
		frame.CatchBtn:Show()
		frame.CatchBtn:ClearAllPoints()
		frame.CatchBtn:SetPoint("LEFT", frame.TimerBtn, "RIGHT", 8, 0)
		frame.FishBtn.Label:SetText("Steps")
	else
		frame.Step:SetText(composed.step or "")
		frame.Head:SetText(composed.title or "")
		frame.Next:SetText(composed.next or "")
		frame.More:SetText(table.concat(composed.more or {}, "\n"))
		frame.TimerBtn:Hide()
		frame.CatchBtn:Hide()
		frame.FishBtn.Label:SetText("Fish")
	end
end

function Now.Refresh()
	if not f or not f:IsShown() then return end
	if mode == "fish" then
		local rank, maxRank = Fish.Rank()
		Now.Apply(nil, Fish.Lines(rank, maxRank, Fish.Elapsed(), Fish.caught or 0))
		return
	end
	local E = ns.Engine
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

if ns.RegisterCommand then
	ns.RegisterCommand("journal", function() ns.Fire("TOGGLE_JOURNAL") end, "Show or hide the step list")
	ns.RegisterCommand("fish", function()
		ns.Set("ui.journal", true)
		ns.Set("ui.shown", true)
		mode = "fish"
		sync()
		Fish.OpenGuide()
	end, "Fishing notes, and open the fishing guide")
end

ns.OnLogin(function()
	Fish.Load()
	sync()
end)
if ns.IsLoggedIn and ns.IsLoggedIn() then
	Fish.Load()
	sync()
end
