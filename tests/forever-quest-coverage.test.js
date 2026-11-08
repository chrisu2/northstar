'use strict';
// Quest coverage of the published forever-db, and the Alliance mage robe guide
// against a Questie-sourced race mask. Not a live 1.60.1.70862 census.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { loadData } = require('../tools/lib/dsl/data');
const { compileSources } = require('../tools/lib/dsl/project');

const ROOT = path.join(__dirname, '..');
const CLASSES = [[1n, 'Warrior'], [2n, 'Paladin'], [4n, 'Hunter'], [8n, 'Rogue'], [16n, 'Priest'], [64n, 'Shaman'], [128n, 'Mage'], [256n, 'Warlock'], [1024n, 'Druid']];
const RACES = [[1n, 'Human'], [2n, 'Orc'], [4n, 'Dwarf'], [8n, 'NightElf'], [16n, 'Undead'], [32n, 'Tauren'], [64n, 'Gnome'], [128n, 'Troll'], [1n << 32n, 'HighOrderSkyborne'], [1n << 33n, 'WindshaperSkyborne']];

function rows(name) {
	return fs.readFileSync(path.join(ROOT, 'forever-db/data', name), 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
}

test('published forever-db covers both factions and every class and race, without claiming 70862', () => {
	const index = JSON.parse(fs.readFileSync(path.join(ROOT, 'forever-db/index.json'), 'utf8'));
	const quests = rows('quest.jsonl');
	const byId = new Map(quests.map((q) => [q.id, q]));
	assert.equal(quests.length, index.counts.quest);
	assert.equal(index.clientBuild, '1.60.1.70532');
	assert.notEqual(index.clientBuild, '1.60.1.70862');
	const side = { 0: 0, 1: 0, 2: 0 };
	const classBits = Object.fromEntries(CLASSES.map(([, name]) => [name, 0]));
	const raceBits = Object.fromEntries(RACES.map(([, name]) => [name, 0]));
	for (const q of quests) {
		side[q.side] += 1;
		const classes = BigInt(q.classes || 0);
		const races = BigInt(q.races || 0);
		for (const [bit, name] of CLASSES) if ((classes & bit) !== 0n) classBits[name] += 1;
		for (const [bit, name] of RACES) if ((races & bit) !== 0n) raceBits[name] += 1;
	}
	assert.ok(side[0] > 0 && side[1] > 0 && side[2] > 0);
	for (const [, name] of CLASSES) assert.ok(classBits[name] > 0, name);
	for (const [, name] of RACES) assert.ok(raceBits[name] > 0, name);
	const ids = new Set(byId.keys());
	const dangling = rows('quest_prereq.jsonl').filter((row) => !ids.has(row.quest) || !ids.has(row.pre));
	assert.equal(dangling.length, 0);
	for (const id of [98340, 98362, 79007, 79008, 79192, 79980, 79974, 79975, 79976]) {
		assert.ok(byId.has(id), String(id));
		assert.ok(byId.get(id).title);
	}
	assert.equal(byId.get(98340).classes, 1024);
	assert.equal(byId.get(98340).side, 2);
	assert.equal(byId.get(79007).side, 2);
	assert.equal(byId.get(79008).side, 1);
	const corrections = fs.readFileSync(path.join(ROOT, 'forever-db/corrections/quests.json'), 'utf8');
	assert.match(corrections, /"98362"[\s\S]*?98739/);
	assert.ok(byId.has(98738) && byId.has(98739));
	assert.equal(fs.existsSync(path.join(ROOT, 'data/forever/quests.json')), false);
});

test('the Alliance mage robe guide matches the Human and Gnome mask', () => {
	const text = fs.readFileSync(path.join(ROOT, 'guides/forever/class/mage/astral-knot-garment.guide'), 'utf8');
	assert.match(text, /^race Human,Gnome$/m);
	assert.doesNotMatch(text, /only Skyborne/);
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ns-robe-'));
	const quests = {};
	for (const id of [1938, 1939, 1940, 1942]) {
		quests[id] = { id, title: 'Robe', races: 65, classes: 128, source: ['questie-forever'], pre: [], excl: [], objectives: [] };
	}
	fs.writeFileSync(path.join(dir, 'quests.json'), JSON.stringify(quests));
	for (const name of ['npcs', 'objects', 'items', 'zones', 'map-frames', 'meta']) fs.writeFileSync(path.join(dir, `${name}.json`), '{}');
	fs.writeFileSync(path.join(dir, 'items.json'), JSON.stringify({ 7511: { id: 7511, name: 'Robe' }, 9516: { id: 9516, name: 'Blouse' }, 7266: { id: 7266, name: 'Treatise' }, 7267: { id: 7267, name: 'Silk' } }));
	const out = compileSources([{ file: 'astral-knot-garment.guide', text }], loadData(dir));
	const race = out.diag.list.filter((d) => d.severity === 'error' && /not available to any race/.test(d.message));
	assert.deepEqual(race, []);
});
