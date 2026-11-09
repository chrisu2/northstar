'use strict';
// The Recorder window (addon/Northstar_Recorder/Panel.lua) against
// tests/lua/stub_recorder.lua: the label comes from the next spot of the
// player's faction's tour, Start/Stop records a trail, and the stop ticks the
// spot in NorthstarRecorderDB.spots and moves the label to the next spot.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

test('the window\'s Start/Stop records a trail with the next spot\'s label and ticks that spot', () => {
	const { emitted: [out] } = runAddon({
		stubs: ['stub_recorder.lua'],
		addons: ['Northstar_Recorder'],
		login: true,
		script: `
		local cmd = NorthstarRecorder_Command
		stub.world.level = 30
		cmd("on")
		cmd("ui")
		local F = NorthstarRecorderPanel
		local label = F.Label:GetText()
		local rows = {}
		for i, r in ipairs(F.Rows) do if r.spot then rows[i] = r.spot.id end end
		stub.moveTo(40, 40)
		F.Start:Click()
		local running = F.Start.text or (F.Start.Label and F.Start.Label:GetText())
		stub.moveTo(40.2, 40)
		stub.advance(0.6)
		F.Start:Click()
		stub.fire("PLAYER_LOGOUT") -- writes the open chunk
		local evs = {}
		for _, text in pairs(NorthstarRecorderDB.chunks) do
			for _, r in ipairs(stub.records(text)) do
				if r[1] == "mark" then evs[#evs + 1] = r[6] end
			end
		end
		emit({
			label = label, rows = rows, running = running, evs = evs,
			ticked = NorthstarRecorderDB.spots and NorthstarRecorderDB.spots[11], next = F.Label:GetText(),
			trail = F.Trails[1]:GetText(), head = F.SpotsHead:GetText(),
			check = F.Rows[1].Check:IsShown(),
		})`,
	});
	// stub_recorder's player is Alliance: the Alliance tour starts at #11.
	assert.match(out.label, /^#11 /);
	assert.deepEqual(out.rows.slice(0, 2), [11, 20], "the Alliance tour order");
	assert.equal(out.running, 'Stop trail');
	assert.equal(out.evs.length, 2, JSON.stringify(out.evs));
	assert.equal(out.evs[0], `trail on: ${out.label}`);
	const stop = out.evs[1].match(/^trail off: (.*) \((\d+) points, (\d+) yd, off\)$/);
	assert.ok(stop && stop[1] === out.label && Number(stop[2]) >= 2 && Number(stop[3]) > 5, out.evs[1]);
	assert.equal(typeof out.ticked, 'number', 'spot 11 ticked');
	assert.match(out.next, /^#20 /, 'the label moves on to the next spot');
	assert.ok(out.trail.startsWith(`${out.label}: `), out.trail);
	assert.match(out.head, /1\/\d+$/);
	assert.equal(out.check, true);
});

test('with Northstar loaded the window is drawn in Northstar\'s theme and works the same', () => {
	const { emitted: [out] } = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Northstar', 'Northstar_Recorder'],
		login: true,
		script: `
		NorthstarRecorder_Command("on")
		NorthstarRecorder_Command("ui")
		local F = NorthstarRecorderPanel
		F.Start:Click()
		stub.advance(1)
		local running = F.Start.Label:GetText()
		NorthstarRecorder_Command("trail toggle") -- the key binding
		emit({ shown = F:IsShown(), polestarButton = F.Start.Label ~= nil, running = running, after = F.Start.Label:GetText(), trails = #F.Trails, first = F.Trails[1]:GetText() })`,
	});
	assert.deepEqual({ ...out, first: undefined }, { shown: true, polestarButton: true, running: 'Stop trail', after: 'Start trail', trails: 4, first: undefined });
	assert.match(out.first, /: \d+ points, 0:01, \d+ yd$/);
});
