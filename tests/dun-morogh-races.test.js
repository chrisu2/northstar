'use strict';
// Published forever-db race masks. A generated guide whose `race` header does not
// include one of those bits must not offer the quest. Skyborne-only guides are
// not judged here: an Era mask does not decide them.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const RACE_BIT = { Human: 1, Orc: 2, Dwarf: 4, NightElf: 8, Scourge: 16, Undead: 16, Tauren: 32, Gnome: 64, Troll: 128 };

function questRaces() {
	const out = new Map();
	for (const line of fs.readFileSync(path.join(ROOT, 'forever-db/data/quest.jsonl'), 'utf8').split('\n')) {
		if (!line) continue;
		const q = JSON.parse(line);
		out.set(q.id, Number(q.races || 0));
	}
	return out;
}

function offered(text) {
	const ids = new Set();
	for (const line of text.split('\n')) {
		const m = line.match(/^\s+(?:accept|turnin|complete)\s+(\d+)\b/) || line.match(/\bquest\s+(\d+)(?:\.\d+)?\b/);
		if (m) ids.add(Number(m[1]));
	}
	return ids;
}

test('Dun Morogh does not offer a class quest the published race mask excludes', () => {
	const races = questRaces();
	assert.equal(races.get(1599), 65);
	assert.equal(races.get(1715), 65);
	assert.equal(races.get(1688), 65);
	assert.equal(races.get(1689), 65);
	assert.equal(races.get(94373), 4);
	assert.equal(races.get(94374), 4);
	assert.equal(races.get(94375), 4);
	assert.equal(races.get(94466), 4);
	const dwarf = fs.readFileSync(path.join(ROOT, 'guides/forever/alliance/dwarf/01-dun-morogh.guide'), 'utf8');
	const gnome = fs.readFileSync(path.join(ROOT, 'guides/forever/alliance/gnome/01-dun-morogh.guide'), 'utf8');
	const dwarfIds = offered(dwarf);
	const gnomeIds = offered(gnome);
	for (const id of [1599, 1715, 1688, 1689]) assert.equal(dwarfIds.has(id), false, `dwarf ${id}`);
	for (const id of [94373, 94374, 94375, 94466]) assert.equal(gnomeIds.has(id), false, `gnome ${id}`);
	assert.equal(dwarfIds.has(94373), true);
	assert.equal(gnomeIds.has(1599), true);
	for (const [file, ids] of [['dwarf', dwarfIds], ['gnome', gnomeIds]]) {
		const bit = RACE_BIT[file === 'dwarf' ? 'Dwarf' : 'Gnome'];
		for (const id of ids) {
			const mask = races.get(id);
			if (mask) assert.ok((mask & bit) !== 0, `${file} ${id} mask ${mask}`);
		}
	}
});
