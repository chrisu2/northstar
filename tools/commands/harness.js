'use strict';
// Offline route-sheet harness. Runs the real Now.lua / Data.lua under the
// repository's Lua 5.1 mock (tests/lua/wow_stub.lua). Not the Forever client.

const fs = require('node:fs');
const path = require('node:path');
const { runAddon } = require('../../tests/helpers/lua');

const usage = `usage: node tools/polestar.js harness
       node tools/polestar.js harness play [port]

With no arguments, runs the route sheet against a mock client and prints
PASS or FAIL. \`play\` serves http://127.0.0.1:8765 (or [port]) where clicks
go through the same Lua runtime. Needs Node and Lua 5.1 on PATH. No game,
account, or network.

This is not Forever 1.60.1.70862 and it says nothing about ban-safety.
CreateFrame, clicks, font strings, GetProfessionInfo, and C_AddOns are simulated.
Quest completion, map geometry, and what the live client would answer are not.
Fixture names such as "Synthetic Herb" are not quests.`;

function check(name, ok, detail) {
	return { name, ok, detail };
}

function evaluate(report) {
	const rows = (report.trade && report.trade.rows) || [];
	const alchemy = rows.find((r) => r.startsWith('Alchemy'));
	const fishing = rows.find((r) => r.startsWith('Fishing'));
	const missing = report.missing || [];
	return [
		check('quest', report.quest && report.quest.next === 'Accept Synthetic Herb' && report.quest.areas.some((a) => a.includes('Quest')) && report.quest.areas.some((a) => a.includes('PvP')), report.quest && report.quest.next),
		check('class-druid', report.classDruid && /Tauren DRUID/.test(report.classDruid.head) && report.classDruid.rows.length === 1 && report.classDruid.rows[0].includes('Synthetic Cat Form'), report.classDruid && report.classDruid.head),
		check('class-open-keeps-route', report.opened === 'synthetic/class/druid/form' && report.levelId === 'synthetic/leveling/camp', `${report.opened} / ${report.levelId}`),
		check('class-unknown', report.classUnknown && /not reported/.test(report.classUnknown.head), report.classUnknown && report.classUnknown.head),
		check('class-warrior', report.classWarrior && /No WARRIOR class guide is loaded/.test(report.classWarrior.head), report.classWarrior && report.classWarrior.head),
		check('trade-skill', alchemy === 'Alchemy  12 / 75' && fishing === 'Fishing  not reported', rows.join('; ')),
		check('fish-tally', report.tally && /Manual tally: 1/.test(report.tally.more) && /Not a detected bite/.test(report.tally.more), report.tally && report.tally.more),
		check('pvp', report.pvp && /no guide/.test(report.pvp.next) && /No companion command/.test(report.pvp.more) && report.pvp.rows[0] === 'Synthetic Warsong', report.pvp && `${report.pvp.next} | ${report.pvp.rows[0]}`),
		check('missing-codex', missing.includes('Northstar_Codex') && !missing.includes('Northstar_QuestDB'), missing.join(', ') || '(none)'),
	];
}

function run(argv = []) {
	if (argv[0] === 'play') {
		const port = argv[1] ? Number(argv[1]) : 8765;
		if (!Number.isInteger(port) || port < 1) {
			console.log('port must be an integer');
			return 1;
		}
		return require('../harness/play').serve(port);
	}
	const script = fs.readFileSync(path.join(__dirname, '..', 'harness', 'sheet.lua'), 'utf8');
	console.log('offline harness: mock client only. Not Forever 1.60.1.70862. Not a statement about ban-safety.');
	console.log('simulated: CreateFrame, clicks, font strings, GetProfessionInfo, GetProfessions, UnitFactionGroup, C_AddOns.GetAddOnInfo, NorthstarCharDB');
	console.log('unverified: 1.60.1.70862 skill lines, casts, loot, quest completion, map geometry, PvP queue, honor');
	console.log('fixtures: synthetic guide ids and the text "Synthetic Herb". Not live quests.');
	let report;
	try {
		const { emitted } = runAddon({
			stubs: ['stub_ui.lua'],
			addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
			script: `uistub.install()\nstub.login()\n${script}`,
		});
		report = emitted[0];
	} catch (err) {
		console.log(`FAIL load: ${err.message}`);
		return 1;
	}
	const checks = evaluate(report);
	let failed = 0;
	for (const c of checks) {
		console.log(`${c.ok ? 'PASS' : 'FAIL'} ${c.name}: ${c.detail}`);
		if (!c.ok) failed += 1;
	}
	console.log(`${failed} failed, ${checks.length - failed} passed`);
	return failed ? 1 : 0;
}

module.exports = {
	name: 'harness',
	summary: 'Run the route sheet under the mock client (no game)',
	usage,
	run,
	evaluate,
};
