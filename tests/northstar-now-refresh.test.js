'use strict';
// The route sheet and the arrow share one waypoint. Accepting a quest and
// moving on to its kill must change the sheet. This is the mock client, not
// an in-game check.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

function load(script) {
	return runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		script: `uistub.install()\nstub.login()\n${script}`,
	}).emitted;
}

test('accept then kill refreshes the sheet to the same line as the arrow', () => {
	const [before, after, step] = load(`
		local N = Northstar.UI.Now
		local step = 1
		local wp = { label = "Accept The Hunt Begins", stepIndex = 1, goalIndex = 1 }
		Northstar.Engine.GetStepIndex = function() return step end
		Northstar.Engine.GetGuide = function() return { id = "forever/horde/tauren/01-mulgore", category = "Leveling" } end
		Northstar.Engine.GetStepView = function(i)
			if i == 2 then
				return {
					index = 2, title = "On the way", current = 1,
					goals = { { status = "active", text = "Kill Plainstrider for Plainstrider Meat", progress = { cur = 1, max = 7 } } },
				}
			end
			return {
				index = 1, title = "Camp Narache", current = 1,
				goals = { { status = "current", text = "Accept The Hunt Begins", t = "accept" } },
			}
		end
		Northstar.Engine.GetWaypoint = function() return wp end
		N.Show()
		emit(N.frame.Next:GetText())
		step = 2
		wp = { label = "Kill Plainstrider for Plainstrider Meat", stepIndex = 2, goalIndex = 1 }
		Northstar.Fire("STEP_CHANGED", 2)
		Northstar.Fire("WAYPOINT_CHANGED", wp)
		emit(N.frame.Next:GetText())
		emit(N.frame.Step:GetText())
	`);
	assert.equal(before, 'Accept The Hunt Begins');
	assert.match(after, /Kill Plainstrider for Plainstrider Meat \(1\/7\)/);
	assert.equal(step, 'Step 2');
});

test('the default sheet is a short bar and does not open the wide guide', () => {
	const [height, journal, wide, grown, opened, arrow, schema] = load(`
		local N = Northstar.UI.Now
		Northstar.Engine.GetStepIndex = function() return 1 end
		Northstar.Engine.GetGuide = function() return { id = "synthetic/leveling/camp", category = "Leveling" } end
		Northstar.Engine.GetStepView = function()
			return { index = 1, title = "Camp", current = 1, goals = {
				{ status = "current", text = "Accept The Hunt Begins" },
				{ status = "active", text = "Accept A Humble Task" },
			}}
		end
		Northstar.Engine.GetWaypoint = function() return { label = "Accept The Hunt Begins", stepIndex = 1, goalIndex = 1 } end
		N.Show()
		emit(N.frame:GetHeight())
		emit(Northstar.Get("ui.journal"))
		emit(Northstar.Get("ui.wideGuide"))
		local strip = N.frame.Strip:IsShown()
		N.frame.Wide:Click()
		emit(N.frame:GetHeight())
		emit(N.frame.Strip:IsShown() ~= strip)
		emit(Northstar.Get("nav.arrow"))
		emit(NorthstarDB.schema)
	`);
	assert.ok(height >= 470 && height <= 540, `book is ${height}`);
	assert.equal(grown, height, `the step strip does not stretch the log (${grown})`);
	assert.equal(journal, true);
	assert.equal(wide, false);
	assert.equal(arrow, false);
	assert.equal(schema, 2);
	assert.equal(opened, true);
});

test('direction and distance sit on the action bar, and arrival keeps the action', () => {
	const [word, right, left, line, action, dist, bear, still, here] = load(`
		emit(Northstar.UI.Now.BearingWord(0))
		emit(Northstar.UI.Now.BearingWord(math.pi / 2))
		emit(Northstar.UI.Now.BearingWord(-math.pi / 2))
		emit(Northstar.UI.Now.DistanceLine("arrived", 2))
		Northstar.Nav = { Sample = function() return "travel", 375, 0 end }
		Northstar.Engine.GetStepIndex = function() return 2 end
		Northstar.Engine.GetGuide = function() return { id = "synthetic/leveling/camp", category = "Leveling" } end
		Northstar.Engine.GetStepView = function()
			return { index = 2, title = "On the way", current = 1, goals = {
				{ status = "active", text = "Kill Plainstrider for Plainstrider Meat", progress = { cur = 1, max = 7 } },
			}}
		end
		Northstar.Engine.GetWaypoint = function() return { label = "Kill Plainstrider for Plainstrider Meat", stepIndex = 2, goalIndex = 1 } end
		Northstar.UI.Now.Show()
		emit(Northstar.UI.Now.frame.Next:GetText())
		emit(Northstar.UI.Now.frame.Dist:GetText())
		emit(Northstar.UI.Now.frame.Bear:GetText())
		Northstar.Nav.Sample = function() return "arrived", 2, 0 end
		Northstar.UI.Now.Refresh()
		emit(Northstar.UI.Now.frame.Next:GetText())
		emit(Northstar.UI.Now.frame.Dist:GetText())
	`);
	assert.equal(word, 'ahead');
	assert.equal(right, 'right');
	assert.equal(left, 'left');
	assert.equal(line, 'at the point');
	assert.match(action, /Kill Plainstrider for Plainstrider Meat \(1\/7\)/);
	assert.match(dist, /375/);
	assert.equal(bear, 'ahead');
	assert.match(still, /Kill Plainstrider for Plainstrider Meat \(1\/7\)/);
	assert.equal(here, 'at the point');
});

test('class, trade and pvp stay on the bar and hide the course tick', () => {
	const [klass, trade, pvp, tick, back] = load(`
		local N = Northstar.UI.Now
		Northstar.Nav = { Sample = function() return "travel", 40, 0 end }
		Northstar.Engine.GetStepIndex = function() return 1 end
		Northstar.Engine.GetGuide = function() return { id = "synthetic/leveling/camp", category = "Leveling" } end
		Northstar.Engine.GetStepView = function()
			return { index = 1, title = "Camp", current = 1, goals = {
				{ status = "current", text = "Accept The Hunt Begins" },
			}}
		end
		Northstar.Engine.GetWaypoint = function() return { label = "Accept The Hunt Begins", stepIndex = 1, goalIndex = 1 } end
		N.Show()
		N.frame.Areas.class:Click()
		emit(N.frame.Area:GetText())
		N.frame.Areas.trade:Click()
		emit(N.frame.Area:GetText())
		N.frame.Areas.pvp:Click()
		emit(N.frame.Area:GetText())
		emit(N.frame.Tick:IsShown())
		N.frame.Areas.quest:Click()
		emit(N.frame.Dist:GetText())
	`);
	assert.equal(klass, 'Class');
	assert.equal(trade, 'Professions');
	assert.equal(pvp, 'PvP');
	assert.equal(tick, false);
	assert.match(back, /40/);
});

test('an old saved floating arrow and wide window do not come back', () => {
	const [journal, arrow, schema, shown, width, dart] = runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'Nav/Nav.xml', 'UI/UI.xml'] }],
		saved: { Northstar: 'NorthstarDB = { schema = 1, settings = { nav = { arrow = true }, ui = { journal = false, shown = true } } }' },
		script: `uistub.install()\nstub.login()\nemit(Northstar.Get("ui.journal"))\nemit(Northstar.Get("nav.arrow"))\nemit(NorthstarDB.schema)\nemit(Northstar.UI.GuideFrame and Northstar.UI.GuideFrame.Frame and Northstar.UI.GuideFrame.Frame:IsShown())\nemit(Northstar.UI.Now.frame and Northstar.UI.Now.frame:GetWidth())\nemit(NorthstarNavArrow and NorthstarNavArrow:IsShown())`,
	}).emitted;
	assert.equal(journal, true);
	assert.equal(arrow, false);
	assert.equal(schema, 2);
	assert.notEqual(shown, true);
	assert.ok(width >= 780 && width <= 880, `width ${width}`);
	assert.notEqual(dart, true);
});

test('a later choice to use the floating arrow is kept', () => {
	const [arrow] = runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'Nav/Nav.xml', 'UI/UI.xml'] }],
		saved: { Northstar: 'NorthstarDB = { schema = 2, settings = { nav = { arrow = true } } }' },
		script: `uistub.install()\nstub.login()\nemit(Northstar.Get("nav.arrow"))`,
	}).emitted;
	assert.equal(arrow, true);
});

test('an old saved wide window stays closed unless wideGuide is set', () => {
	const [journal, shown] = runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		saved: { Northstar: 'NorthstarDB = { schema = 1, settings = { ui = { journal = false, shown = true } } }' },
		script: `uistub.install()\nstub.login()\nemit(Northstar.Get("ui.journal"))\nemit(Northstar.UI.GuideFrame and Northstar.UI.GuideFrame.Frame and Northstar.UI.GuideFrame.Frame:IsShown())`,
	}).emitted;
	assert.equal(journal, true);
	assert.notEqual(shown, true);
});
