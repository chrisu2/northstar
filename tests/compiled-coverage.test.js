'use strict';
// Every class, race, faction, and profession that this checkout compiles.
// Counts come from the compiled guide Lua, not from a fixture list of names.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { runAddon } = require('./helpers/lua');

const ADDON = path.join(__dirname, '..', 'addon');
const CLASSES = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID'];
const RACES = ['Human', 'NightElf', 'Dwarf', 'Gnome', 'Orc', 'Scourge', 'Tauren', 'Troll', 'Skyborne'];
const PROFESSIONS = ['alchemy', 'blacksmithing', 'cooking', 'enchanting', 'engineering', 'first-aid', 'fishing', 'herbalism', 'leatherworking', 'mining', 'skinning', 'tailoring'];

function compiled() {
	let text = '';
	for (const name of fs.readdirSync(ADDON)) {
		if (!name.startsWith('Northstar_Guides')) continue;
		const file = path.join(ADDON, name, 'Guides.lua');
		if (fs.existsSync(file)) text += fs.readFileSync(file, 'utf8');
		const legs = path.join(ADDON, name, 'Legs.lua');
		if (fs.existsSync(legs)) text += fs.readFileSync(legs, 'utf8');
	}
	return text;
}

test('compiled guides cover every class, both factions, every race part, and all twelve professions', () => {
	const text = compiled();
	const ids = [...text.matchAll(/id = "([^"]+)"/g)].map((m) => m[1]);
	for (const cls of CLASSES) {
		assert.ok(text.includes(`"${cls}"`), cls);
	}
	assert.ok(ids.some((id) => id.startsWith('forever/alliance/')));
	assert.ok(ids.some((id) => id.startsWith('forever/horde/')));
	for (const race of RACES) {
		const toc = path.join(ADDON, `Northstar_Guides_${race}`, `Northstar_Guides_${race}.toc`);
		assert.ok(fs.existsSync(toc), race);
		assert.match(text, new RegExp(race === 'Scourge' ? 'forever/horde/undead/' : race.toLowerCase()));
	}
	for (const prof of PROFESSIONS) {
		assert.ok(ids.includes(`forever/professions/${prof}`), prof);
	}
	for (const id of ['forever/reputation/warsong-gulch', 'forever/reputation/arathi-basin', 'forever/reputation/alterac-valley', 'forever/class/druid/cat-form', 'forever/miscellaneous/cozy-sleeping-bag', 'forever/horde/tauren/01-mulgore']) {
		assert.ok(ids.includes(id) || text.includes(`["${id}"]`), id);
	}
	for (const prof of PROFESSIONS) {
		const at = text.indexOf(`id = "forever/professions/${prof}"`);
		const slice = text.slice(at, at + 12000);
		assert.match(slice, /t = "(train|skill|collect|buy|turnin|accept)"/, prof);
	}
});

function classHeaders(text) {
	const out = [];
	for (const block of text.split('Northstar.RegisterGuide({').slice(1)) {
		const head = block.slice(0, 900);
		const id = (head.match(/id = "([^"]+)"/) || [])[1];
		if (!id || !id.startsWith('forever/class/')) continue;
		const classes = [...((head.match(/classes = \{([^}]*)\}/) || [])[1] || '').matchAll(/"([^"]+)"/g)].map((m) => m[1]);
		const races = (head.match(/\n\t\t\traces = \{([^}]*)\}/) || [])[1];
		const faction = (head.match(/faction = "([^"]+)"/) || [])[1];
		out.push({
			id,
			classes,
			races: races ? [...races.matchAll(/"([^"]+)"/g)].map((m) => m[1]) : [],
			faction: faction || null,
		});
	}
	return out;
}

function luaHeader(h) {
	const races = h.races.length ? `, races = { ${h.races.map((r) => JSON.stringify(r)).join(', ')} }` : '';
	const faction = h.faction ? `, faction = ${JSON.stringify(h.faction)}` : '';
	return `{ id = ${JSON.stringify(h.id)}, category = "Class", classes = { ${h.classes.map((c) => JSON.stringify(c)).join(', ')} }${races}${faction} }`;
}

test('the sheet offers each class only the compiled guides that race and faction can take', () => {
	const headers = classHeaders(compiled());
	const characters = [
		{ class: 'DRUID', race: 'Tauren', faction: 'Horde' },
		{ class: 'DRUID', race: 'NightElf', faction: 'Alliance' },
		{ class: 'HUNTER', race: 'Orc', faction: 'Horde' },
		{ class: 'HUNTER', race: 'Dwarf', faction: 'Alliance' },
		{ class: 'MAGE', race: 'Scourge', faction: 'Horde' },
		{ class: 'MAGE', race: 'Human', faction: 'Alliance' },
		{ class: 'PALADIN', race: 'Human', faction: 'Alliance' },
		{ class: 'PRIEST', race: 'Troll', faction: 'Horde' },
		{ class: 'PRIEST', race: 'Dwarf', faction: 'Alliance' },
		{ class: 'ROGUE', race: 'Orc', faction: 'Horde' },
		{ class: 'ROGUE', race: 'Gnome', faction: 'Alliance' },
		{ class: 'SHAMAN', race: 'Tauren', faction: 'Horde' },
		{ class: 'SHAMAN', race: 'Dwarf', faction: 'Alliance' },
		{ class: 'WARLOCK', race: 'Orc', faction: 'Horde' },
		{ class: 'WARLOCK', race: 'Gnome', faction: 'Alliance' },
		{ class: 'WARRIOR', race: 'Tauren', faction: 'Horde' },
		{ class: 'WARRIOR', race: 'Human', faction: 'Alliance' },
	];
	const script = characters.map((p) => `emit(Northstar.UI.Sheet.ClassView(headers, { class = ${JSON.stringify(p.class)}, race = ${JSON.stringify(p.race)}, faction = ${JSON.stringify(p.faction)} }))`).join('\n');
	const views = runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		script: `uistub.install()\nstub.login()\nlocal headers = {\n${headers.map(luaHeader).join(',\n')}\n}\n${script}`,
	}).emitted;
	assert.equal(views.length, characters.length);
	characters.forEach((p, i) => {
		const view = views[i];
		assert.equal(view.kind, 'class', `${p.race} ${p.class}`);
		assert.ok(view.rows.length > 0, `${p.race} ${p.class}`);
		for (const row of view.rows) {
			const header = headers.find((h) => h.id === row.id);
			assert.ok(header.classes.some((c) => c.toLowerCase() === p.class.toLowerCase()), row.id);
			if (header.faction) assert.equal(header.faction, p.faction, row.id);
			if (header.races.length) assert.ok(header.races.some((r) => r.toLowerCase() === p.race.toLowerCase() || (p.race === 'Scourge' && r.toLowerCase() === 'undead')), row.id);
		}
	});
	const hordeHunter = views[2].rows.map((r) => r.id);
	assert.equal(hordeHunter.includes('forever/class/hunter/taming-the-beast-alliance'), false);
	assert.ok(hordeHunter.includes('forever/class/hunter/taming-the-beast-horde'));
});
