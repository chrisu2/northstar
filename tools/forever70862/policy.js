'use strict';
// Decisions for the wowf 1.60.1.70862 extraction probe. A missing log or meta
// is a failure. An incomplete quest set is exit 3 and is not a release.
// This file does not read the game.

const fs = require('node:fs');

const PRODUCT = 'wowf';
const BUILD = '1.60.1.70862';
const FORBIDDEN = ['--no-questie', '--allow-build-mismatch', '--allow-incomplete', '--no-forever'];
const ERA_LOG = ['zones and frames from Classic Era', 'Forever map tables unavailable'];
const READING = `reading ${PRODUCT} ${BUILD} client tables`;

function fail(message, code) {
	return { ok: false, exit: 1, code: code || 'provenance', message, provenanceOk: false, questsIncomplete: false };
}

function questCount(meta) {
	const n = meta && meta.counts && meta.counts.questieQuests;
	return typeof n === 'number' && Number.isFinite(n) ? n : null;
}

function judgeProvenance({ logText, metaText, metaOlderThanLog }) {
	if (logText == null) return fail('missing log');
	if (metaText == null) return fail('missing meta');
	if (String(logText).trim() === '') return fail('empty log');
	if (String(metaText).trim() === '') return fail('empty meta');
	if (metaOlderThanLog) return fail('meta.json is older than this run\'s log. Stale meta is not provenance.');
	const log = String(logText);
	for (const bad of ERA_LOG) {
		if (log.includes(bad)) return fail(`log contains '${bad}'`);
	}
	if (/reading wow_classic(?:_era|_beta)? /.test(log)) return fail('log read a product other than wowf');
	if (!log.includes(READING)) return fail(`log never recorded '${READING}'`);
	let meta;
	try {
		meta = JSON.parse(metaText);
	} catch {
		return fail('meta.json is not JSON');
	}
	if (!meta || typeof meta !== 'object' || !Array.isArray(meta.warnings)) return fail('meta.json has no warnings array');
	for (const w of meta.warnings) {
		const s = String(w);
		if (s.includes('Classic Era') || s.includes('Forever map tables unavailable')) {
			return fail(`meta.warnings flags an Era substitution: ${s}`);
		}
	}
	const n = questCount(meta);
	return {
		ok: true,
		exit: 0,
		code: 'provenance',
		message: 'provenance passed',
		provenanceOk: true,
		questsIncomplete: !(n > 0),
		questieQuests: n,
	};
}

function judgeMaps(input) {
	const p = judgeProvenance(input);
	if (!p.ok) return p;
	const forgeExit = Number(input.forgeExit);
	if (p.questsIncomplete) {
		return {
			ok: false,
			exit: 3,
			code: 'quests-incomplete',
			provenanceOk: true,
			questsIncomplete: true,
			message: `Quest set is incomplete (questieQuests ${p.questieQuests == null ? 'absent' : p.questieQuests}). Forge exit ${forgeExit}. This directory is not a release. Do not compile guides from it.`,
		};
	}
	if (forgeExit !== 0) {
		return {
			ok: false,
			exit: 1,
			code: 'forge',
			provenanceOk: true,
			questsIncomplete: false,
			message: `data build exit ${forgeExit}. Provenance passed and questieQuests is ${p.questieQuests}. The output is not a release.`,
		};
	}
	return {
		ok: true,
		exit: 0,
		code: 'maps',
		provenanceOk: true,
		questsIncomplete: false,
		message: `Maps written for ${PRODUCT} ${BUILD} (questieQuests ${p.questieQuests}). This is not a release.`,
	};
}

function judgeGrid(input) {
	const maps = judgeProvenance({
		logText: input.mapsLogText,
		metaText: input.mapsMetaText,
		metaOlderThanLog: input.mapsMetaOlderThanLog,
	});
	if (!maps.ok) return { ...maps, message: `map provenance failed: ${maps.message}` };
	if (input.indexMissing) return fail('missing grid index.json');
	if (input.indexProduct !== PRODUCT || input.indexBuild !== BUILD) {
		return fail(`grid index is ${input.indexProduct} ${input.indexBuild}, expected ${PRODUCT} ${BUILD}`);
	}
	const named = `${input.gridLogText || ''}\n${input.gridStdoutText || ''}`;
	if (!named.includes(`${PRODUCT} ${BUILD}`)) return fail(`grid log does not name ${PRODUCT} ${BUILD}`);
	const forgeExit = Number(input.forgeExit);
	if (forgeExit !== 0) {
		return { ok: false, exit: 1, code: 'forge', provenanceOk: true, questsIncomplete: maps.questsIncomplete, message: `nav grid exit ${forgeExit}. Do not pass --allow-incomplete. Not a release.` };
	}
	if (maps.questsIncomplete) {
		return {
			ok: false,
			exit: 3,
			code: 'quests-incomplete',
			provenanceOk: true,
			questsIncomplete: true,
			message: `Grid index is ${PRODUCT} ${BUILD}. The map stage's quest set is incomplete, so this grid is not a release.`,
		};
	}
	return { ok: true, exit: 0, code: 'grid', provenanceOk: true, questsIncomplete: false, message: `Grid ok: ${PRODUCT} ${BUILD}. Not a release.` };
}

function judgeData(input) {
	if (!input.questieToc) return fail('QuestieDB_Forever.toc is not installed. Do not pass --no-questie. This stage does not download Questie.');
	const p = judgeProvenance(input);
	if (!p.ok) return p;
	const forgeExit = Number(input.forgeExit);
	if (p.questsIncomplete) {
		return {
			ok: false,
			exit: 3,
			code: 'quests-incomplete',
			provenanceOk: true,
			questsIncomplete: true,
			message: `Data stage quest set is incomplete (questieQuests ${p.questieQuests == null ? 'absent' : p.questieQuests}). Forge exit ${forgeExit}. Not a release.`,
		};
	}
	if (forgeExit !== 0) {
		return { ok: false, exit: 1, code: 'forge', provenanceOk: true, questsIncomplete: false, message: `forge build --until data exit ${forgeExit}. Not a release.` };
	}
	return { ok: true, exit: 0, code: 'data', provenanceOk: true, questsIncomplete: false, message: `Data written for ${PRODUCT} ${BUILD}. Not a release. Do not copy addon folders into the game.` };
}

function judgeArgs(args, stage) {
	const list = Array.isArray(args) ? args : [];
	for (const a of list) {
		if (FORBIDDEN.includes(a)) return fail(`refusing forbidden flag ${a}`, 'args');
	}
	const tables = list.indexOf('--forever-tables');
	if (tables >= 0 && list[tables + 1] === 'wago') return fail('refusing --forever-tables wago', 'args');
	if (stage === 'maps' || stage === 'grid') {
		const p = list.indexOf('--product');
		if (list[p + 1] !== PRODUCT) return fail(`refusing a product other than ${PRODUCT}`, 'args');
	}
	if (stage === 'maps' || stage === 'data') {
		if (list[tables + 1] !== 'client') return fail('refusing a Forever table source other than client', 'args');
	}
	if (stage === 'maps') {
		const b = list.indexOf('--forever-build');
		if (list[b + 1] !== BUILD) return fail(`refusing a forever build other than ${BUILD}`, 'args');
	}
	return { ok: true, exit: 0, code: 'args', message: 'arguments accepted', provenanceOk: false, questsIncomplete: false };
}

function fromPaths(kind, opts) {
	const read = (file) => (file && fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null);
	const older = (meta, log) => {
		if (!meta || !log || !fs.existsSync(meta) || !fs.existsSync(log)) return false;
		return fs.statSync(meta).mtimeMs + 2000 < fs.statSync(log).mtimeMs;
	};
	if (kind === 'args') return judgeArgs(opts.args || [], opts.stage);
	if (kind === 'maps') {
		return judgeMaps({ forgeExit: opts.forgeExit, logText: read(opts.log), metaText: read(opts.meta), metaOlderThanLog: older(opts.meta, opts.log) });
	}
	if (kind === 'data') {
		return judgeData({ forgeExit: opts.forgeExit, logText: read(opts.log), metaText: read(opts.meta), metaOlderThanLog: older(opts.meta, opts.log), questieToc: opts.questieToc === true });
	}
	if (kind === 'grid') {
		let index = null;
		if (opts.index && fs.existsSync(opts.index)) {
			try { index = JSON.parse(fs.readFileSync(opts.index, 'utf8')); } catch { index = {}; }
		}
		return judgeGrid({
			forgeExit: opts.forgeExit,
			mapsLogText: read(opts.mapsLog),
			mapsMetaText: read(opts.mapsMeta),
			mapsMetaOlderThanLog: older(opts.mapsMeta, opts.mapsLog),
			gridLogText: read(opts.log),
			gridStdoutText: read(opts.stdout),
			indexMissing: !index,
			indexProduct: index && index.product,
			indexBuild: index && index.build,
		});
	}
	return fail(`unknown decision ${kind}`, 'args');
}

function parseArgs(argv) {
	const out = { _: [] };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a.startsWith('--')) {
			const key = a.slice(2);
			const next = argv[i + 1];
			if (next === undefined || next.startsWith('--')) out[key] = true;
			else { out[key] = next; i++; }
		} else out._.push(a);
	}
	return out;
}

function main(argv) {
	const args = parseArgs(argv);
	const kind = args._[0];
	const opts = {
		forgeExit: args['forge-exit'],
		log: args.log,
		meta: args.meta,
		mapsLog: args['maps-log'],
		mapsMeta: args['maps-meta'],
		stdout: args.stdout,
		index: args.index,
		stage: args.stage,
		questieToc: String(args['questie-toc']).toLowerCase() === 'true',
		args: args['args-file'] ? fs.readFileSync(args['args-file'], 'utf8').split(/\r?\n/).filter(Boolean) : [],
	};
	const decision = fromPaths(kind, opts);
	const text = JSON.stringify(decision);
	if (args.out) fs.writeFileSync(args.out, text);
	process.stdout.write(`${text}\n`);
	return 0;
}

module.exports = {
	PRODUCT, BUILD, FORBIDDEN, READING, judgeProvenance, judgeMaps, judgeGrid, judgeData, judgeArgs, fromPaths, main,
};

if (require.main === module) process.exit(main(process.argv.slice(2)));
