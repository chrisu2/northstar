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
