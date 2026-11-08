'use strict';
// Local page over the real route-sheet Lua. Each click replays the action
// list through tests/helpers/lua.js. Not the Forever client.

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { runAddon } = require('../../tests/helpers/lua');

const SCRIPT = fs.readFileSync(path.join(__dirname, 'play.lua'), 'utf8');

function luaString(s) {
	return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
}

function luaValue(v) {
	if (v == null) return 'nil';
	if (typeof v === 'boolean') return v ? 'true' : 'false';
	if (typeof v === 'number' && Number.isFinite(v)) return String(v);
	if (typeof v === 'string') return luaString(v);
	if (Array.isArray(v)) return '{' + v.map(luaValue).join(',') + '}';
	return '{' + Object.entries(v).map(([k, val]) => `[${luaString(k)}]=${luaValue(val)}`).join(',') + '}';
}

const AREAS = new Set(['quest', 'class', 'trade', 'pvp']);

function sanitize(a) {
	if (!a || typeof a !== 'object') throw new Error('bad action');
	if (a.t === 'area' && AREAS.has(a.id)) return { t: 'area', id: a.id };
	if (a.t === 'class' && typeof a.class === 'string' && a.class.length <= 16) {
		return { t: 'class', class: a.class, race: typeof a.race === 'string' ? a.race.slice(0, 16) : '' };
	}
	if (a.t === 'step' && a.n >= 1 && a.n <= 3) return { t: 'step', n: a.n };
	if (a.t === 'row' && a.n >= 1 && a.n <= 12) return { t: 'row', n: a.n };
	if (a.t === 'fish' || a.t === 'release' || a.t === 'reset' || a.t === 'boom') return { t: a.t };
	if (a.t === 'codex') return { t: 'codex', present: a.present === true };
	if (a.t === 'profession') {
		if (!a.name) return { t: 'profession', name: '' };
		const rank = Number(a.rank);
		const max = Number(a.max);
		if (!Number.isFinite(rank) || !Number.isFinite(max)) throw new Error('rank must be a number');
		return { t: 'profession', name: String(a.name).slice(0, 40), rank, max };
	}
	throw new Error('unsupported action');
}

function play(actions) {
	const clean = (actions || []).map(sanitize);
	const script = `HARNESS = { actions = ${luaValue(clean)} }\n${SCRIPT}`;
	const { emitted } = runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Northstar', files: ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'] }],
		script: `uistub.install()\nstub.login()\n${script}`,
	});
	const view = emitted[0];
	if (!Array.isArray(view.missing)) view.missing = [];
	if (!Array.isArray(view.rows)) view.rows = [];
	if (!Array.isArray(view.limits)) view.limits = [];
	return view;
}

const PAGE = `<!doctype html>
<meta charset="utf-8">
<title>Northstar offline play</title>
<style>
  body { font: 15px/1.4 sans-serif; margin: 16px; background: #f4f1ea; color: #222; }
  h1 { font-size: 18px; margin: 0 0 8px; }
  .banner, .limits, .err { padding: 8px 10px; margin: 0 0 12px; }
  .banner { background: #fff6d8; }
  .limits { background: #fff; }
  .err { background: #f8d7da; white-space: pre-wrap; }
  main { display: flex; gap: 16px; align-items: flex-start; }
  section { background: #fff; padding: 12px; }
  .sheet { width: 360px; border-left: 5px solid #6b4228; }
  button { margin: 2px; }
  .row { display: block; text-align: left; width: 100%; }
  .muted { color: #555; }
</style>
<h1>Northstar offline play</h1>
<div class="banner">Mock client only. Not Forever 1.60.1.70862. Not a statement about ban-safety. The words below are the font strings Now.lua set. Buttons call those frames' OnClick through the Lua runtime.</div>
<div id="err" class="err" hidden></div>
<main>
  <section class="sheet">
    <div id="area"></div>
    <div id="step" class="muted"></div>
    <div id="head"></div>
    <div id="next"></div>
    <div id="more" class="muted"></div>
    <div id="rows"></div>
    <div id="areas"></div>
    <div id="route" class="muted"></div>
  </section>
  <section>
    <p>Scenario controls. Each one is an action replayed in Lua.</p>
    <div>
      <button data-act='{"t":"step","n":1}'>Step 1</button>
      <button data-act='{"t":"step","n":2}'>Step 2</button>
      <button data-act='{"t":"step","n":3}'>Step 3</button>
    </div>
    <div>
      <button data-act='{"t":"class","class":"DRUID","race":"Tauren"}'>Tauren Druid</button>
      <button data-act='{"t":"class","class":"MAGE","race":"Human"}'>Human Mage</button>
      <button data-act='{"t":"class","class":"HUNTER","race":"Orc"}'>Orc Hunter</button>
      <button data-act='{"t":"class","class":"PRIEST","race":"Undead"}'>Undead Priest</button>
      <button data-act='{"t":"class","class":"WARRIOR","race":"Orc"}'>Orc Warrior</button>
      <button data-act='{"t":"class","class":"","race":""}'>Class unknown</button>
    </div>
    <div>
      <button id="alchemy">Report Alchemy 12/75</button>
      <button data-act='{"t":"profession","name":""}'>Profession not reported</button>
    </div>
    <div>
      <button data-act='{"t":"fish"}'>Fish tally</button>
      <button data-act='{"t":"release"}'>Toggle battleground release</button>
      <button data-act='{"t":"reset"}'>Reset tally and release</button>
    </div>
    <div>
      <button data-act='{"t":"codex","present":false}'>Codex missing</button>
      <button data-act='{"t":"codex","present":true}'>Codex present</button>
      <button data-act='{"t":"boom"}'>Raise a Lua error</button>
      <button id="clear">Clear actions</button>
    </div>
    <p id="state" class="muted"></p>
    <div id="limits" class="limits"></div>
  </section>
</main>
<script>
async function render(view) {
  const err = document.querySelector('#err');
  if (!view || view.fatal) {
    err.hidden = false;
    err.textContent = view && view.fatal ? view.fatal : 'no view';
    return;
  }
  err.hidden = !view.error;
  err.textContent = view.error || '';
  document.querySelector('#area').textContent = view.area || '';
  document.querySelector('#step').textContent = view.stepLine || '';
  document.querySelector('#head').textContent = view.head || '';
  document.querySelector('#next').textContent = view.next || '';
  document.querySelector('#more').textContent = view.more || '';
  document.querySelector('#route').textContent = 'Leveling route ' + (view.levelId || '') + ' · opened tab ' + (view.opened || '(none)');
  const rows = document.querySelector('#rows');
  rows.replaceChildren();
  (view.rows || []).forEach((label, i) => {
    const b = document.createElement('button');
    b.className = 'row';
    b.textContent = label;
    b.onclick = () => act({ t: 'row', n: i + 1 });
    rows.appendChild(b);
  });
  const areas = document.querySelector('#areas');
  areas.replaceChildren();
  (view.areas || []).forEach((a) => {
    const b = document.createElement('button');
    b.textContent = a.label;
    b.onclick = () => act({ t: 'area', id: a.id });
    areas.appendChild(b);
  });
  document.querySelector('#state').textContent = 'Class ' + (view.class || '(none)') + ' ' + (view.race || '') + ' · step ' + view.step + ' · fish ' + view.fish + ' · release ' + view.release + (view.releaseText ? ' · ' + view.releaseText : '') + ' · missing ' + ((view.missing || []).join(', ') || '(none)');
  document.querySelector('#limits').textContent = (view.limits || []).join(' ');
}
async function act(a) {
  const res = await fetch('/act', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(a) });
  render(await res.json());
}
document.body.addEventListener('click', (ev) => {
  const raw = ev.target.getAttribute && ev.target.getAttribute('data-act');
  if (raw) act(JSON.parse(raw));
});
document.querySelector('#alchemy').onclick = () => act({ t: 'profession', name: 'Alchemy', rank: 12, max: 75 });
document.querySelector('#clear').onclick = async () => {
  render(await (await fetch('/reset', { method: 'POST' })).json());
};
fetch('/state').then((r) => r.json()).then(render);
</script>
`;

function createServer(actions) {
	const log = actions || [];
	return http.createServer((req, res) => {
		const send = (code, body, type) => {
			res.writeHead(code, { 'Content-Type': type || 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
			res.end(body);
		};
		if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
			send(200, PAGE, 'text/html; charset=utf-8');
			return;
		}
		if (req.method === 'GET' && req.url === '/state') {
			try {
				send(200, JSON.stringify(play(log)));
			} catch (err) {
				send(500, JSON.stringify({ fatal: err.message }));
			}
			return;
		}
		if (req.method === 'POST' && req.url === '/reset') {
			log.length = 0;
			try {
				send(200, JSON.stringify(play(log)));
			} catch (err) {
				send(500, JSON.stringify({ fatal: err.message }));
			}
			return;
		}
		if (req.method === 'POST' && req.url === '/act') {
			const chunks = [];
			req.on('data', (c) => chunks.push(c));
			req.on('end', () => {
				try {
					log.push(sanitize(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')));
					send(200, JSON.stringify(play(log)));
				} catch (err) {
					send(400, JSON.stringify({ fatal: err.message }));
				}
			});
			return;
		}
		send(404, JSON.stringify({ fatal: 'not found' }));
	});
}

function serve(port) {
	const server = createServer([]);
	return new Promise((resolve, reject) => {
		server.on('error', reject);
		server.listen(port, '127.0.0.1', () => {
			const addr = server.address();
			console.log(`offline play: http://127.0.0.1:${addr.port}`);
			console.log('Mock client only. Not Forever 1.60.1.70862. Not a statement about ban-safety.');
			console.log('Stop with Ctrl-C. No game, account, or network client.');
		});
	});
}

module.exports = { play, createServer, serve, sanitize };
