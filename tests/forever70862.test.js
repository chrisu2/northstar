'use strict';
// The wowf 1.60.1.70862 probe decisions. Fixtures only: no client, no Windows.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const policy = require('../tools/forever70862/policy');
const { validateManifest } = require('../tools/lib/pack/manifest');

const READING = 'reading wowf 1.60.1.70862 client tables from H:\\battle_net\\World of Warcraft';

function meta(extra) {
	return JSON.stringify({
		warnings: [],
		counts: { questieQuests: 4432 },
		liveFrameMaps: [1412],
		...extra,
	});
}

test('missing log or meta is a provenance failure', () => {
	for (const input of [
		{ logText: null, metaText: meta() },
		{ logText: READING, metaText: null },
		{ logText: '   ', metaText: meta() },
		{ logText: READING, metaText: '   ' },
		{ logText: READING, metaText: '{', },
		{ logText: READING, metaText: '{"counts":{"questieQuests":1}}' },
	]) {
		const d = policy.judgeProvenance(input);
		assert.equal(d.exit, 1, d.message);
		assert.equal(d.provenanceOk, false);
	}
});

test('an Era fallback fails even when the log also names wowf', () => {
	const log = `${READING}\nzones and frames from Classic Era`;
	const d = policy.judgeMaps({ forgeExit: 0, logText: log, metaText: meta() });
	assert.equal(d.exit, 1);
	assert.match(d.message, /Classic Era/);
	const warned = policy.judgeMaps({
		forgeExit: 0,
		logText: READING,
		metaText: meta({ warnings: ['Forever map tables unavailable (missing UiMap); zones and frames from Classic Era'] }),
	});
	assert.equal(warned.exit, 1);
	assert.match(warned.message, /Era substitution/);
});

test('a stale meta is not provenance', () => {
	const d = policy.judgeProvenance({ logText: READING, metaText: meta(), metaOlderThanLog: true });
	assert.equal(d.exit, 1);
	assert.match(d.message, /Stale meta/);
});

test('a wrong product in the log is refused', () => {
	const d = policy.judgeProvenance({
		logText: 'reading wow_classic_beta 1.15.8.70425 client tables from somewhere',
		metaText: meta(),
	});
	assert.equal(d.exit, 1);
	assert.match(d.message, /other than wowf/);
});

test('maps: a nonzero forge exit still reaches the incomplete-quest result', () => {
	const d = policy.judgeMaps({ forgeExit: 2, logText: READING, metaText: meta({ counts: { quests: 100 } }) });
	assert.equal(d.exit, 3);
	assert.equal(d.code, 'quests-incomplete');
	assert.match(d.message, /Forge exit 2/);
	assert.match(d.message, /not a release/);
});

test('maps: questieQuests of 0 is incomplete, and a positive count with a forge error is exit 1', () => {
	const zero = policy.judgeMaps({ forgeExit: 0, logText: READING, metaText: meta({ counts: { questieQuests: 0 } }) });
	assert.equal(zero.exit, 3);
	const crashed = policy.judgeMaps({ forgeExit: 1, logText: READING, metaText: meta() });
	assert.equal(crashed.exit, 1);
	assert.equal(crashed.code, 'forge');
	assert.match(crashed.message, /not a release/);
});

test('maps: provenance and a real quest count is exit 0 and still not a release', () => {
	const d = policy.judgeMaps({ forgeExit: 0, logText: READING, metaText: meta() });
	assert.equal(d.exit, 0);
	assert.match(d.message, /not a release/);
});

test('grid and data keep incomplete output off the success exit', () => {
	const maps = { mapsLogText: READING, mapsMetaText: meta({ counts: {} }), indexProduct: 'wowf', indexBuild: '1.60.1.70862', gridLogText: READING, gridStdoutText: '', forgeExit: 0 };
	assert.equal(policy.judgeGrid(maps).exit, 3);
	const named = policy.judgeGrid({ ...maps, mapsMetaText: meta(), gridLogText: 'no build here', gridStdoutText: '' });
	assert.equal(named.exit, 1);
	const old = policy.judgeGrid({ ...maps, mapsMetaText: meta(), indexProduct: 'wow_classic_beta', indexBuild: '1.15.8.70425' });
	assert.equal(old.exit, 1);
	const data = policy.judgeData({ forgeExit: 0, logText: READING, metaText: meta({ counts: {} }), questieToc: true });
	assert.equal(data.exit, 3);
	const noToc = policy.judgeData({ forgeExit: 0, logText: READING, metaText: meta(), questieToc: false });
	assert.equal(noToc.exit, 1);
	assert.match(noToc.message, /--no-questie/);
});

test('forbidden flags and the wrong product are refused before a forge run', () => {
	for (const flag of policy.FORBIDDEN) {
		const d = policy.judgeArgs(['data', 'build', flag], 'maps');
		assert.equal(d.exit, 1, flag);
	}
	assert.equal(policy.judgeArgs(['data', 'build', '--forever-tables', 'wago', '--product', 'wowf'], 'maps').exit, 1);
	assert.equal(policy.judgeArgs(['data', 'build', '--forever-tables', 'client', '--product', 'wow_classic_era', '--forever-build', policy.BUILD], 'maps').exit, 1);
	const ok = policy.judgeArgs(['data', 'build', '--forever-tables', 'client', '--product', 'wowf', '--forever-build', policy.BUILD], 'maps');
	assert.equal(ok.exit, 0);
});

test('the checker CLI fails closed on a stale meta file', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ns-probe-'));
	const log = path.join(dir, 'maps.log');
	const metaPath = path.join(dir, 'meta.json');
	fs.writeFileSync(metaPath, meta());
	const past = new Date(Date.now() - 60_000);
	fs.utimesSync(metaPath, past, past);
	fs.writeFileSync(log, READING);
	const out = path.join(dir, 'decision.json');
	const run = spawnSync(process.execPath, [
		path.join(__dirname, '..', 'tools', 'forever70862', 'policy.js'),
		'maps', '--forge-exit', '0', '--log', log, '--meta', metaPath, '--out', out,
	], { encoding: 'utf8' });
	assert.equal(run.status, 0, run.stderr);
	const d = JSON.parse(fs.readFileSync(out, 'utf8'));
	assert.equal(d.exit, 1);
	assert.match(d.message, /Stale meta/);
	const toc = spawnSync(process.execPath, [
		path.join(__dirname, '..', 'tools', 'forever70862', 'policy.js'),
		'data', '--forge-exit', '0', '--log', log, '--meta', metaPath, '--questie-toc', 'True', '--out', out,
	], { encoding: 'utf8' });
	assert.equal(toc.status, 0, toc.stderr);
	const withToc = JSON.parse(fs.readFileSync(out, 'utf8'));
	assert.doesNotMatch(withToc.message, /not installed/);
});

test('the probe script judges maps before treating a forge exit as success', () => {
	const ps1 = fs.readFileSync(path.join(__dirname, '..', 'tools', 'forever70862', 'windows-forever-70862.ps1'), 'utf8');
	const maps = ps1.slice(ps1.indexOf("'Maps' {"), ps1.indexOf("'Grid' {"));
	assert.match(maps, /Invoke-Decision 'maps'/);
	assert.doesNotMatch(maps, /if \(\$code -ne 0\) \{ Fail/);
	assert.match(ps1, /missing policy\.js/);
	for (const flag of ['--no-questie', '--allow-build-mismatch', '--allow-incomplete', '--no-forever']) {
		assert.equal(ps1.includes(`'${flag}'`), false, flag);
	}
});

test('a community pack cannot take a Northstar or Polestar folder', () => {
	const base = { id: 'joe-routes', title: "Joe's Routes", author: 'Joe', version: '1.0.0', license: 'CC-BY-4.0' };
	for (const folder of ['Northstar_Guides', 'Polestar_Guides', 'Northstar', 'polestar_extra']) {
		const diags = validateManifest({ ...base, folder }, 'pack.json');
		assert.ok(diags.some((d) => d.severity === 'error' && /own addons/.test(d.message)), folder);
	}
	const official = validateManifest({ ...base, id: 'guides', folder: 'Northstar_Guides' }, 'pack.json', { official: true });
	assert.equal(official.some((d) => d.severity === 'error'), false);
});
