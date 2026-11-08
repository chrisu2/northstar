'use strict';
// The offline harness command. The scenarios themselves run real addon Lua.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { evaluate, run } = require('../tools/commands/harness');

test('harness exits 0 and names every scenario', () => {
	const lines = [];
	const write = console.log;
	console.log = (...args) => lines.push(args.join(' '));
	let status;
	try {
		status = run();
	} finally {
		console.log = write;
	}
	const stdout = lines.join('\n');
	assert.equal(status, 0, stdout);
	for (const name of ['quest', 'class-druid', 'class-open-keeps-route', 'class-unknown', 'class-warrior', 'trade-skill', 'fish-tally', 'pvp', 'missing-codex']) {
		assert.match(stdout, new RegExp(`PASS ${name}:`));
	}
	assert.match(stdout, /Not Forever 1\.60\.1\.70862/);
	assert.match(stdout, /simulated: CreateFrame/);
	assert.match(stdout, /0 failed, 9 passed/);
});

test('a report that drops the leveling route fails the harness check', () => {
	const checks = evaluate({
		quest: { next: 'Accept Synthetic Herb', areas: ['· Quest', '  PvP'] },
		classDruid: { head: 'Tauren DRUID. Class quests, separate from the leveling route.', rows: ['Synthetic Cat Form'] },
		classUnknown: { head: 'Class is not reported. Class quests stay closed.' },
		classWarrior: { head: 'No WARRIOR class guide is loaded.' },
		trade: { rows: ['Alchemy  12 / 75', 'Fishing  not reported'] },
		tally: { more: 'Manual tally: 1. You tapped this. Kept on this character. Not a detected bite. Not sent.' },
		pvp: { next: 'World PvP has no guide in this checkout.', more: 'No companion command is sent.', rows: ['Synthetic Warsong'] },
		opened: 'synthetic/class/druid/form',
		levelId: 'synthetic/class/druid/form',
		missing: ['Northstar_Codex'],
	});
	assert.equal(checks.find((c) => c.name === 'class-open-keeps-route').ok, false);
});
