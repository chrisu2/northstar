'use strict';
// The clickable offline page. Actions go through the real addon Lua.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { play, createServer } = require('../tools/harness/play');

function post(port, path, body) {
	return new Promise((resolve, reject) => {
		const req = http.request({ hostname: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json' } }, (res) => {
			const chunks = [];
			res.on('data', (c) => chunks.push(c));
			res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') }));
		});
		req.on('error', reject);
		if (body) req.write(body);
		req.end();
	});
}

test('quest steps advance and a class tab keeps the leveling route', () => {
	const first = play([{ t: 'step', n: 1 }]);
	assert.equal(first.next, 'Accept Synthetic Herb');
	assert.equal(first.levelId, 'synthetic/leveling/camp');
	const later = play([{ t: 'step', n: 3 }]);
	assert.equal(later.next, 'Talk to Synthetic Guide');
	assert.equal(later.levelId, 'synthetic/leveling/camp');
	const opened = play([
		{ t: 'class', class: 'DRUID', race: 'Tauren' },
		{ t: 'area', id: 'class' },
		{ t: 'row', n: 1 },
	]);
	assert.match(opened.head, /Tauren DRUID/);
	assert.equal(opened.opened, 'synthetic/class/druid/bear');
	assert.equal(opened.levelId, 'synthetic/leveling/camp');
	const warrior = play([{ t: 'class', class: 'WARRIOR', race: 'Orc' }, { t: 'area', id: 'class' }]);
	assert.match(warrior.head, /No WARRIOR class guide is loaded/);
	const unknown = play([{ t: 'class', class: '', race: '' }, { t: 'area', id: 'class' }]);
	assert.match(unknown.head, /not reported/);
	const mage = play([{ t: 'class', class: 'MAGE', race: 'Human' }, { t: 'area', id: 'class' }]);
	assert.deepEqual(mage.rows, ['Synthetic Mage Robe']);
});

test('profession skill, fishing tally, release, and a missing codex', () => {
	const named = play([{ t: 'profession', name: 'Alchemy', rank: 12, max: 75 }, { t: 'area', id: 'trade' }]);
	assert.ok(named.rows.includes('Alchemy  12 / 75'));
	assert.ok(named.rows.includes('Fishing  not reported'));
	const blank = play([{ t: 'profession', name: '' }, { t: 'area', id: 'trade' }]);
	assert.ok(blank.rows.every((r) => r.endsWith('not reported')));
	const caught = play([{ t: 'area', id: 'trade' }, { t: 'fish' }, { t: 'fish' }]);
	assert.equal(caught.fish, 2);
	assert.match(caught.more, /Manual tally: 2/);
	const released = play([{ t: 'release' }]);
	assert.equal(released.release, true);
	const reset = play([{ t: 'fish' }, { t: 'release' }, { t: 'reset' }]);
	assert.equal(reset.fish, 0);
	assert.equal(reset.release, false);
	const missing = play([]);
	assert.ok(missing.missing.includes('Northstar_Codex'));
	assert.ok(!missing.missing.includes('Northstar_QuestDB'));
	const present = play([{ t: 'codex', present: true }]);
	assert.ok(!present.missing.includes('Northstar_Codex'));
	const pvp = play([{ t: 'area', id: 'pvp' }]);
	assert.match(pvp.next, /no guide/);
	assert.equal(pvp.rows[0], 'Synthetic Warsong');
	assert.match(pvp.more, /No companion command/);
	const boom = play([{ t: 'boom' }]);
	assert.match(boom.error, /synthetic Lua error/);
});

test('the local page serves the sheet and accepts a click', async () => {
	const server = createServer([]);
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	const port = server.address().port;
	try {
		const page = await new Promise((resolve, reject) => {
			http.get({ hostname: '127.0.0.1', port, path: '/' }, (res) => {
				const chunks = [];
				res.on('data', (c) => chunks.push(c));
				res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
			}).on('error', reject);
		});
		assert.match(page, /Not Forever 1\.60\.1\.70862/);
		assert.match(page, /Now\.lua/);
		const acted = await post(port, '/act', JSON.stringify({ t: 'area', id: 'pvp' }));
		assert.equal(acted.status, 200);
		const view = JSON.parse(acted.body);
		assert.equal(view.area, 'PVP');
		const bad = await post(port, '/act', JSON.stringify({ t: 'eval', code: 'os.exit(1)' }));
		assert.equal(bad.status, 400);
	} finally {
		server.close();
	}
});
