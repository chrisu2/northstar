'use strict';
// Northstar's own identity and the compact step list. The fishing lines are
// checked as text only: this does not claim the Forever 1.60.1.70862 client
// answered a skill, cast, or loot event.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { runAddon } = require('./helpers/lua');

const ROOT = path.join(__dirname, '..');
const TOC = path.join(ROOT, 'addon', 'Northstar', 'Northstar.toc');

test('the addon folder, saved variables, and interface are Northstar on Forever', () => {
	assert.equal(fs.existsSync(path.join(ROOT, 'addon', 'Polestar')), false);
	const toc = fs.readFileSync(TOC, 'utf8');
	assert.match(toc, /^## Interface: 16001$/m);
	assert.match(toc, /^## Title: Northstar$/m);
	assert.match(toc, /^## SavedVariables: NorthstarDB$/m);
	assert.match(toc, /^## SavedVariablesPerCharacter: NorthstarCharDB$/m);
	assert.match(toc, /X-Northstar-Origin: https:\/\/github.com\/fitzforge\/polestar/);
	assert.doesNotMatch(toc, /SavedVariables: PolestarDB/);
	assert.match(fs.readFileSync(path.join(ROOT, 'addon', 'Northstar_Guides', 'Northstar_Guides.toc'), 'utf8'), /Dependencies: Northstar$/m);
});

function load(script) {
	return runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		script: `uistub.install()\nstub.login()\n${script}`,
	}).emitted;
}

test('slash commands and the global do not reuse Polestar', () => {
	const [out] = load(`
		emit({
			northstar = Northstar ~= nil,
			polestar = _G.Polestar ~= nil,
			slash = SLASH_NORTHSTAR1,
			short = SLASH_NORTHSTAR2,
			origin = Northstar.OriginName,
		})
	`);
	assert.equal(out.northstar, true);
	assert.equal(out.polestar, false);
	assert.equal(out.slash, '/northstar');
	assert.equal(out.short, '/ns');
	assert.equal(out.origin, 'Polestar');
});

test('the step list names the next open goal and keeps the wide window hidden', () => {
	const [text, shown] = load(`
		local view = {
			index = 4,
			title = 'Camp Narache',
			current = 1,
			goals = {
				{ status = 'current', text = 'Accept The Hunt Begins', t = 'accept' },
				{ status = 'current', text = 'Collect Plainstrider Meat', t = 'collect' },
				{ status = 'done', text = 'Already done', t = 'turnin' },
			},
		}
		local c = Northstar.UI.Now.Compose(view)
		emit(c.next .. '|' .. c.title .. '|' .. table.concat(c.more, ','))
		local guide = NorthstarGuideFrame and NorthstarGuideFrame:IsShown() and true or false
		emit({ journal = Northstar.UI.Now.frame:IsShown(), guide = guide })
	`);
	assert.equal(text, 'Accept The Hunt Begins|Camp Narache|Collect Plainstrider Meat');
	assert.equal(shown.journal, true);
	assert.equal(shown.guide, false);
});

test('fishing notes do not invent catches, lures, or casts', () => {
	const [idle, ranked] = load(`
		emit(table.concat(Northstar.UI.Fish.Lines(nil, nil, nil, 0), ' | '))
		emit(table.concat(Northstar.UI.Fish.Lines(12, 75, 120, 3), ' | '))
	`);
	for (const text of [idle, ranked]) {
		assert.match(text, /does not cast or loot/);
		assert.match(text, /Not a detected bite/);
		assert.match(text, /Lures and pole enchants are not read/);
		assert.match(text, /Kept on this character/);
		assert.match(text, /Not sent/);
		assert.doesNotMatch(text, /Not saved/);
		assert.doesNotMatch(text, /1,300|Classic|pool|Booty Bay|Nat Pagle|Shiny Bauble/i);
	}
	assert.match(idle, /Fishing skill: not reported/);
	assert.match(idle, /Manual tally: 0/);
	assert.match(ranked, /Skill the client reported: 12 \/ 75/);
	assert.match(ranked, /Session timer: 2 min/);
	assert.match(ranked, /Manual tally: 3/);
});

test('a fishing tally is a local note, and skill is a named profession only', () => {
	const now = fs.readFileSync(path.join(ROOT, 'addon', 'Northstar', 'UI', 'Now.lua'), 'utf8');
	assert.doesNotMatch(now, /\b356\b|\b7620\b|CastSpell|UseAction|GetWeaponEnchant/);
	const [loaded, count, named, other] = load(`
		NorthstarCharDB = { fish = { caught = 4, started = time() - 90 } }
		Northstar.UI.Fish.Load()
		emit({ caught = Northstar.UI.Fish.caught, elapsed = Northstar.UI.Fish.Elapsed() })
		Northstar.UI.Fish.AddCatch()
		emit(NorthstarCharDB.fish.caught)
		GetProfessions = function() return 1 end
		GetProfessionInfo = function() return "Fishing", nil, 12, 75 end
		local rank, maxRank = Northstar.UI.Fish.Rank()
		emit(rank .. "/" .. maxRank)
		GetProfessionInfo = function() return "Alchemy", nil, 40, 75 end
		local again = Northstar.UI.Fish.Rank()
		emit(again == nil)
	`);
	assert.equal(loaded.caught, 4);
	assert.ok(loaded.elapsed >= 90 && loaded.elapsed < 95);
	assert.equal(count, 5);
	assert.equal(named, '12/75');
	assert.equal(other, true);
});
