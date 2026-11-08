'use strict';
// The client's share flag (addon/Northstar_Recorder/Recorder.lua, docs/RECORDING.md
// "Ack file"): Polestar Client writes NorthstarRecorderShare into Ack.lua while
// sharing (on by default there). true turns recording on at login (once, with
// a message) unless the player typed /nsrec off; false turns it off; nil (no
// client) leaves the player's choice, so a Recorder on its own stays off.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

function run(share, saved) {
	const [out] = runAddon({
		stubs: ['stub_recorder.lua'],
		before: share === undefined ? '' : `NorthstarRecorderShare = ${share}`,
		addons: ['Northstar_Recorder'],
		saved: saved ? { Northstar_Recorder: saved } : undefined,
		login: true,
		script: 'emit({ on = NorthstarRecorderDB.enabled == true, optout = NorthstarRecorderDB.optout == true, said = table.concat(stub.messages, "\\n") })',
	}).emitted;
	return out;
}

const OFF = 'NorthstarRecorderDB = { schema = 2, enabled = false }';
const ON = 'NorthstarRecorderDB = { schema = 2, enabled = true }';
// A first login: no SavedVariables at all.
const NONE = 'NorthstarRecorderDB = nil';

test('the client sharing turns recording on, once, and says so', () => {
	const out = run('true', OFF);
	assert.equal(out.on, true);
	assert.match(out.said, /on, because sharing is on in Polestar Client\. \/nsrec off to stop\./);
	// Already on: nothing to say.
	assert.doesNotMatch(run('true', ON).said, /because sharing is on/);
	assert.equal(run('true', NONE).on, true);
});

test('the client not sharing turns recording off without an opt-out', () => {
	const out = run('false', ON);
	assert.equal(out.on, false);
	assert.equal(out.optout, false);
});

test('/nsrec off beats the client; /nsrec on clears it', () => {
	const out = run('true', 'NorthstarRecorderDB = { schema = 2, enabled = false, optout = true }');
	assert.equal(out.on, false);
	assert.equal(out.optout, true);
	const [after] = runAddon({
		stubs: ['stub_recorder.lua'],
		before: 'NorthstarRecorderShare = true',
		addons: ['Northstar_Recorder'],
		saved: { Northstar_Recorder: ON },
		login: true,
		script: `
		local cmd = SlashCmdList.NORTHSTARREC
		cmd("off")
		local off = { on = NorthstarRecorderDB.enabled, optout = NorthstarRecorderDB.optout }
		cmd("on")
		emit({ off = off, on = NorthstarRecorderDB.enabled, optout = NorthstarRecorderDB.optout or false })`,
	}).emitted;
	assert.deepEqual(after, { off: { on: false, optout: true }, on: true, optout: false });
});

test('without the client (no flag) the old behaviour holds: off unless /nsrec on', () => {
	assert.equal(run(undefined, OFF).on, false);
	assert.equal(run(undefined, ON).on, true);
	assert.equal(run(undefined, NONE).on, false);
});
