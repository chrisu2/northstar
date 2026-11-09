'use strict';
// Side-by-side checks: old Polestar commands are not registered, companion
// folders depend on Northstar, and the shipped recorder does not turn sharing on.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { runAddon } = require('./helpers/lua');

const ROOT = path.join(__dirname, '..');
const ADDON = path.join(ROOT, 'addon');

test('no shipped TOC depends on Polestar or saves PolestarDB', () => {
	const tocs = fs.readdirSync(ADDON).filter((name) => fs.existsSync(path.join(ADDON, name, `${name}.toc`)));
	assert.ok(tocs.includes('Northstar'));
	assert.ok(!tocs.includes('Polestar'));
	for (const name of tocs) {
		const text = fs.readFileSync(path.join(ADDON, name, `${name}.toc`), 'utf8');
		assert.doesNotMatch(text, /^## Dependencies:.*\bPolestar\b/m, name);
		assert.doesNotMatch(text, /SavedVariables: PolestarDB/, name);
		assert.doesNotMatch(text, /SavedVariablesPerCharacter: PolestarCharDB/, name);
		const dep = text.match(/^## Dependencies: (.+)$/m);
		if (dep) {
			for (const part of dep[1].split(',')) {
				const token = part.trim();
				assert.ok(!token.startsWith('Polestar'), `${name} depends on ${token}`);
			}
		}
	}
	const guides = fs.readFileSync(path.join(ADDON, 'Northstar_Guides', 'Northstar_Guides.toc'), 'utf8');
	assert.match(guides, /^## Dependencies: Northstar$/m);
	const nav = fs.readFileSync(path.join(ADDON, 'Northstar_Nav', 'Northstar_Nav.toc'), 'utf8');
	assert.match(nav, /^## Dependencies: Northstar$/m);
	const ek = fs.readFileSync(path.join(ADDON, 'Northstar_Nav_EK', 'Northstar_Nav_EK.toc'), 'utf8');
	assert.match(ek, /^## Dependencies: Northstar_Nav$/m);
});

test('old slash commands are not registered', () => {
	const [found] = runAddon({
		stubs: ['stub_ui.lua', 'stub_recorder.lua'],
		addons: ['Northstar', 'Northstar_Recorder'],
		login: true,
		script: `
			local bad = {}
			for key, value in pairs(_G) do
				if type(key) == "string" and key:find("^SLASH_") and type(value) == "string" then
					if value == "/polestar" or value == "/pole" or value == "/psrec" or value == "/polestarrec" then
						bad[#bad + 1] = key .. "=" .. value
					end
				end
			end
			emit(table.concat(bad, ","))
		`,
	}).emitted;
	assert.equal(found, '');
});

test('old slash commands are not assigned in addon source', () => {
	function walk(dir, out) {
		for (const name of fs.readdirSync(dir)) {
			const full = path.join(dir, name);
			if (fs.statSync(full).isDirectory()) walk(full, out);
			else if (name.endsWith('.lua')) out.push(full);
		}
		return out;
	}
	const bad = [];
	for (const file of walk(ADDON, [])) {
		const code = fs.readFileSync(file, 'utf8').split('\n').filter((line) => !line.trim().startsWith('--')).join('\n');
		if (/=\s*"\/(?:polestar|pole|psrec|polestarrec)"/.test(code)) bad.push(path.relative(ROOT, file));
		if (/NorthstarRecorderShare\s*=\s*true/.test(code)) bad.push(path.relative(ROOT, file) + ' share');
	}
	assert.deepEqual(bad, []);
	const recorder = fs.readFileSync(path.join(ADDON, 'Northstar_Recorder', 'Recorder.lua'), 'utf8');
	assert.match(recorder, /local enabled = false/);
});

test('the shipped recorder ack does not enable sharing or recording', () => {
	const ack = fs.readFileSync(path.join(ADDON, 'Northstar_Recorder', 'Ack.lua'), 'utf8');
	const code = ack.split('\n').filter((line) => !line.trim().startsWith('--')).join('\n');
	assert.match(code, /NorthstarRecorderAck = nil/);
	assert.doesNotMatch(code, /NorthstarRecorderShare\s*=\s*true/);
	const [out] = runAddon({
		stubs: ['stub_recorder.lua'],
		addons: ['Northstar_Recorder'],
		saved: { Northstar_Recorder: 'NorthstarRecorderDB = nil; NorthstarRecorderShare = nil' },
		login: true,
		script: 'emit({ on = NorthstarRecorderDB.enabled == true, share = NorthstarRecorderShare == true })',
	}).emitted;
	assert.equal(out.on, false);
	assert.equal(out.share, false);
});
