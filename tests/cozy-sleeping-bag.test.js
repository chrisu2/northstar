'use strict';
// Cozy Sleeping Bag chain membership. Reads the guide, the compiled register
// call, and forever-db. Does not treat an outside article's buff claims as facts.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const GUIDE = fs.readFileSync(path.join(ROOT, 'guides/forever/miscellaneous/cozy-sleeping-bag.guide'), 'utf8');
const COMPILED = fs.readFileSync(path.join(ROOT, 'addon/Northstar_Guides/Guides.lua'), 'utf8');

const HORDE = [79007, 79007, 79192, 79192, 79980, 79980, 79974, 79974, 79975, 79975, 79976, 79976];
const ALLIANCE = [79008, 79008, 79192, 79192, 79980, 79980, 79974, 79974, 79975, 79975, 79976, 79976];
const TITLES = {
	79007: '... and that note you found',
	79008: '... and that note you found',
	79192: 'Stepping Stones',
	79980: 'Scramble',
	79974: 'Wet Job',
	79975: "Eagle's Fist",
	79976: 'This Must Be The Place',
};

function questRows() {
	const out = new Map();
	for (const line of fs.readFileSync(path.join(ROOT, 'forever-db/data/quest.jsonl'), 'utf8').split('\n')) {
		if (!line) continue;
		const row = JSON.parse(line);
		if (TITLES[row.id]) out.set(row.id, row);
	}
	return out;
}

function steps(text) {
	return text.split('\nstep ').slice(1).map((block) => {
		const faction = /\n  only Horde\b/.test(block) ? 'Horde' : (/\n  only Alliance\b/.test(block) ? 'Alliance' : null);
		const ids = [];
		for (const match of block.matchAll(/\b(?:accept|turnin) (\d+)/g)) ids.push(Number(match[1]));
		return { faction, ids };
	});
}

function chain(faction) {
	const ids = [];
	for (const step of steps(GUIDE)) {
		if (step.faction && step.faction !== faction) continue;
		ids.push(...step.ids);
	}
	return ids;
}

test('the guide file holds the Horde and Alliance orders, and no experience-buff claim', () => {
	assert.deepEqual(chain('Horde'), HORDE);
	assert.deepEqual(chain('Alliance'), ALLIANCE);
	assert.match(GUIDE, /only Horde/);
	assert.doesNotMatch(GUIDE, /3%|one percent|per minute/i);
	assert.match(GUIDE, /Not play-tested on Forever yet/);
});

test('forever-db names the same quests, with Horde on the same side as the Tauren cat quest', () => {
	const rows = questRows();
	for (const [id, title] of Object.entries(TITLES)) {
		const row = rows.get(Number(id));
		assert.ok(row, `missing quest ${id}`);
		assert.equal(row.title, title);
		assert.equal(row.min_level, 14);
		assert.equal(row.classes, 0, `${id} is not class-locked in forever-db`);
	}
	assert.equal(rows.get(79007).side, 2);
	assert.equal(rows.get(79008).side, 1);
	const cat = JSON.parse(fs.readFileSync(path.join(ROOT, 'forever-db/data/quest.jsonl'), 'utf8').split('\n').find((line) => line.includes('"id":98340,')));
	assert.equal(cat.side, rows.get(79007).side);
	assert.equal(cat.title, 'The Great Cat Spirit');
});

test('base quest_reward and quest_prereq rows do not carry this chain', () => {
	const reward = fs.readFileSync(path.join(ROOT, 'forever-db/data/quest_reward.jsonl'), 'utf8');
	const pre = fs.readFileSync(path.join(ROOT, 'forever-db/data/quest_prereq.jsonl'), 'utf8');
	for (const id of Object.keys(TITLES)) {
		assert.equal(reward.includes(`"quest":${id}`), false, id);
		assert.equal(pre.includes(`"quest":${id}`), false, id);
	}
	const items = fs.readFileSync(path.join(ROOT, 'forever-db/data/item.jsonl'), 'utf8');
	assert.match(items, /"id":211527,"name":"Cozy Sleeping Bag"/);
	assert.match(items, /"id":221498,"name":"Old Toolbox"/);
	assert.match(items, /"id":216619,"name":"Student Fodder"/);
});

test('the compiled guide includes the Horde start and the shared hand-in order', () => {
	const start = COMPILED.indexOf('id = "forever/miscellaneous/cozy-sleeping-bag"');
	assert.ok(start > 0);
	const slice = COMPILED.slice(start, start + 12000);
	assert.match(slice, /factions = \{ "Horde" \}/);
	assert.match(slice, /quest = 79007/);
	const shared = slice.slice(slice.indexOf('quest = 79192'));
	const order = [...shared.matchAll(/quest = (79192|79980|79974|79975|79976)/g)].map((m) => Number(m[1]));
	assert.deepEqual(order, [79192, 79192, 79192, 79980, 79980, 79974, 79974, 79975, 79975, 79976, 79976]);
	const corrections = fs.readFileSync(path.join(ROOT, 'forever-db/corrections/quests.json'), 'utf8');
	assert.match(corrections, /"79192"[\s\S]*?79007[\s\S]*?79008/);
	assert.match(corrections, /"79976"[\s\S]*?79975/);
});
