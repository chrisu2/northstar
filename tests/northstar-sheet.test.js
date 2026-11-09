'use strict';
// The route sheet's four areas. Guide ids below are the ones this checkout
// compiles. A missing guide stays missing.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { runAddon } = require('./helpers/lua');

const ROOT = path.join(__dirname, '..');

function load(script) {
	return runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		script: `uistub.install()\nstub.login()\n${script}`,
	}).emitted;
}

function professionGuides() {
	const dir = path.join(ROOT, 'guides/forever/professions');
	return fs.readdirSync(dir).filter((name) => name.endsWith('.guide')).map((name) => {
		const text = fs.readFileSync(path.join(dir, name), 'utf8');
		const id = text.match(/^guide (\S+)/m)[1];
		const title = text.match(/^title (.+)$/m)[1];
		return { id, title, category: 'Professions' };
	});
}

test('trade lists every profession guide in this checkout and does not invent another', () => {
	const files = professionGuides();
	assert.equal(files.length, 12);
	const [view] = load(`
		local headers = {
			${files.map((g) => `{ id = ${JSON.stringify(g.id)}, title = ${JSON.stringify(g.title)}, category = "Professions" }`).join(',\n')}
		}
		emit(Northstar.UI.Sheet.TradeView(headers))
	`);
	assert.equal(view.rows.length, 12);
	assert.deepEqual(view.rows.map((r) => r.id).sort(), files.map((g) => g.id).sort());
	assert.ok(view.rows.every((r) => r.skill === 'not reported'));
	assert.equal(view.rows.filter((r) => r.fishing).length, 1);
	assert.doesNotMatch(view.rows.map((r) => r.title).join(' '), /Jewelcrafting|Inscription/);
});

test('class quests follow the character, and a missing class or guide stays closed', () => {
	const headers = [
		{ id: 'forever/class/druid/cat-form', title: 'Cat Form', category: 'Class', classes: ['DRUID'] },
		{ id: 'forever/class/druid/bear-form', title: 'Bear Form and Moonglade', category: 'Class', classes: ['DRUID'] },
		{ id: 'forever/class/mage/atiesh', title: 'Atiesh', category: 'Class', classes: ['MAGE'] },
	];
	const [druid, unknown, warrior, missing] = load(`
		local headers = {
			{ id = "forever/class/druid/cat-form", title = "Cat Form", category = "Class", classes = { "DRUID" } },
			{ id = "forever/class/druid/bear-form", title = "Bear Form and Moonglade", category = "Class", classes = { "DRUID" } },
			{ id = "forever/class/mage/atiesh", title = "Atiesh", category = "Class", classes = { "MAGE" } },
		}
		emit(Northstar.UI.Sheet.ClassView(headers, { class = "DRUID", race = "Tauren" }))
		emit(Northstar.UI.Sheet.ClassView(headers, {}))
		emit(Northstar.UI.Sheet.ClassView(headers, { class = "WARRIOR" }))
		emit(Northstar.UI.Sheet.Open(headers, "forever/class/druid/not-a-real-guide"))
	`);
	assert.equal(druid.kind, 'class');
	assert.match(druid.text, /Tauren DRUID/);
	assert.deepEqual(druid.rows.map((r) => r.id), ['forever/class/druid/bear-form', 'forever/class/druid/cat-form']);
	assert.equal(unknown.kind, 'unknown');
	assert.equal(warrior.kind, 'missing');
	assert.equal(missing.ok, false);
	assert.equal(missing.reason, 'not loaded');
	assert.ok(headers);
});

test('opening a class guide does not replace the remembered leveling route', () => {
	const [kept, opened] = load(`
		local level = { id = "forever/horde/01-mulgore", category = "Leveling" }
		local classed = { id = "forever/class/druid/cat-form", category = "Class" }
		local id = Northstar.UI.Sheet.NoteLevel(nil, level)
		id = Northstar.UI.Sheet.NoteLevel(id, classed)
		emit(id)
		emit(Northstar.UI.Sheet.Open({ level, classed }, classed.id).ok)
	`);
	assert.equal(kept, 'forever/horde/01-mulgore');
	assert.equal(opened, true);
});

test('the Tauren cat, bear, and aquatic guides are the compiled class guides', () => {
	const compiled = fs.readFileSync(path.join(ROOT, 'addon/Northstar_Guides/Guides.lua'), 'utf8');
	for (const id of ['forever/class/druid/cat-form', 'forever/class/druid/bear-form', 'forever/class/druid/aquatic-form']) {
		const at = compiled.indexOf(`id = "${id}"`);
		assert.ok(at > 0, id);
		const slice = compiled.slice(at, at + 400);
		assert.match(slice, /classes = \{ "DRUID" \}/);
		assert.match(slice, /category = "Class"/);
	}
	const cat = fs.readFileSync(path.join(ROOT, 'guides/forever/class/druid/cat-form.guide'), 'utf8');
	assert.match(cat, /accept 98340/);
	assert.match(cat, /only Tauren/);
});

test('pvp lists battleground guides and does not invent world pvp or a companion command', () => {
	const [view] = load(`
		emit(Northstar.UI.Sheet.PvpView({
			{ id = "forever/reputation/warsong-gulch", title = "Warsong Gulch Reputation", folder = "Reputation · Battlegrounds" },
			{ id = "forever/reputation/cenarion-circle", title = "Cenarion Circle", folder = "Reputation" },
			{ id = "forever/collectibles/mounts/horde/black-war-mounts", title = "Black War Mounts", folder = "Mounts · PvP" },
		}))
	`);
	assert.deepEqual(view.battlegrounds.map((r) => r.id), ['forever/reputation/warsong-gulch']);
	assert.equal(view.mounts.length, 1);
	assert.match(view.world, /no guide/);
	assert.match(view.companion, /No companion command/);
	assert.equal(view.rows.some((r) => /cenarion/.test(r.id)), false);
});

test('the quest sheet can open the sleeping-bag guide without dropping the route', () => {
	const [opened, level] = load(`
		local headers = {
			{ id = "forever/horde/01-mulgore", title = "Mulgore", category = "Leveling" },
			{ id = "forever/miscellaneous/cozy-sleeping-bag", title = "Cozy Sleeping Bag", category = "Miscellaneous" },
		}
		local found = Northstar.UI.Sheet.Open(headers, Northstar.UI.Sheet.SLEEP_ID)
		emit(found.ok)
		emit(Northstar.UI.Sheet.NoteLevel("forever/horde/01-mulgore", found))
	`);
	assert.equal(opened, true);
	assert.equal(level, 'forever/horde/01-mulgore');
	const now = fs.readFileSync(path.join(ROOT, 'addon/Northstar/UI/Now.lua'), 'utf8');
	assert.doesNotMatch(now, /\/ov |356|Jewelcrafting/);
});
