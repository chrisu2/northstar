'use strict';
// The textures of the Halo and Blizzard skins (Northstar.Theme, "Skins"), as
// the design handoff lists them (DIRECTION_B_HALO.md §7, DIRECTION_A_BLIZZARD.md
// §7): white masks the addon tints at runtime, except the Blizzard dart, whose
// gold gradient is baked in. Drawn here from signed distance shapes, so they
// stay editable and owned by the project.

const path = require('node:path');
const { Canvas, sdf } = require('../lib/tga');

const WHITE = [1, 1, 1, 1];

// The veil under every Halo window: a 64 px square whose 24 px edge goes from
// full to clear, nine-sliced at 24 px (Theme.lua, veilFor).
function veilSoft() {
	const c = new Canvas(64, 64);
	const E = 24;
	for (let y = 0; y < 64; y++) {
		for (let x = 0; x < 64; x++) {
			const d = Math.min(x + 0.5, 64 - x - 0.5, y + 0.5, 64 - y - 0.5);
			const t = Math.max(0, Math.min(1, d / E));
			const i = (y * 64 + x) * 4;
			c.px[i] = c.px[i + 1] = c.px[i + 2] = 1;
			// Smoothstep: no visible step where the edge meets the middle.
			c.px[i + 3] = t * t * (3 - 2 * t);
		}
	}
	return c;
}

// The arrival ring and the transport alert's ring: radius 24 and stroke 3 on
// the handoff's 60-unit grid, drawn at 128 px.
const K = 128 / 60;
function ring() {
	return new Canvas(128, 128).fill(sdf.ring(64, 64, 24 * K, 3 * K), WHITE);
}

// The arrival check: the polyline 19,31 27,39 42,22, stroke 5 on the 60 grid.
function arriveCheck() {
	const p = [[19, 31], [27, 39], [42, 22]].map(([x, y]) => [x * K, y * K]);
	const w = (5 * K) / 2;
	return new Canvas(128, 128).fill(sdf.union(sdf.segment(p[0][0], p[0][1], p[1][0], p[1][1], w), sdf.segment(p[1][0], p[1][1], p[2][0], p[2][1], w)), WHITE);
}

// The dart of both skins: the polygon 30,4 52,54 30,42 8,54 on the 60 grid,
// pointing up (SetRotation turns it), drawn at 128 px.
const DART = [[30, 4], [52, 54], [30, 42], [8, 54]].map(([x, y]) => [x * K, y * K]);
const dartShape = sdf.polygon(DART);

// Its fill, a white mask (Halo: tinted accent, then arrive up close).
function dart() {
	return new Canvas(128, 128).fill(dartShape, WHITE);
}

// Its 2-unit stroke (on the 60 grid), a white mask tinted dark.
function dartEdge() {
	const half = K; // 2 units wide, centred on the outline
	return new Canvas(128, 128).fill((x, y) => Math.abs(dartShape(x, y)) - half, WHITE);
}

// The Blizzard dart: the gradient #FFE266 at the tip to #B07C00 at the base,
// baked (the rotation turns it with the dart).
function dartGold() {
	const c = new Canvas(128, 128);
	const top = [1, 0.886, 0.4], bottom = [0.69, 0.486, 0];
	const y0 = 4 * K, y1 = 54 * K;
	for (let y = 0; y < 128; y++) {
		const t = Math.max(0, Math.min(1, (y + 0.5 - y0) / (y1 - y0)));
		const col = [0, 1, 2].map((i) => top[i] + (bottom[i] - top[i]) * t);
		for (let x = 0; x < 128; x++) {
			const d = dartShape(x + 0.5, y + 0.5);
			let cov = 0.5 - d;
			if (cov <= 0) continue;
			if (cov > 1) cov = 1;
			const i = (y * 128 + x) * 4;
			c.px[i] = col[0];
			c.px[i + 1] = col[1];
			c.px[i + 2] = col[2];
			c.px[i + 3] = cov;
		}
	}
	return c;
}

// Report a problem, in the skins: a flag on its pole (24-unit grid, stroke
// 2.25, drawn at 32 px like the house glyphs).
function flag() {
	const s = 32 / 24;
	const g = (v) => v * s;
	const pole = sdf.segment(g(6), g(3.5), g(6), g(21), g(2.25) / 2);
	const cloth = sdf.polygon([[6, 4.5], [19, 4.5], [16, 9], [19, 13.5], [6, 13.5]].map(([x, y]) => [g(x), g(y)]));
	return new Canvas(32, 32).fill(sdf.union(pole, cloth), WHITE);
}

// Nearby services, in the skins: a house (the handoff's 14-unit outline,
// 1.5,7 7,2 12.5,7 12.5,12.5 1.5,12.5, stroke 1.6, and its door 3 x 4).
function house() {
	const s = 32 / 14;
	const g = (v) => v * s;
	const pts = [[1.5, 7], [7, 2], [12.5, 7], [12.5, 12.5], [1.5, 12.5]].map(([x, y]) => [g(x), g(y)]);
	const half = g(1.6) / 2;
	const edges = pts.map((p, i) => sdf.segment(p[0], p[1], pts[(i + 1) % pts.length][0], pts[(i + 1) % pts.length][1], half));
	const door = sdf.box(g(7), g(10.5), g(1.5), g(2));
	return new Canvas(32, 32).fill(sdf.union(...edges, door), WHITE);
}

function generate(addonRoot) {
	const dir = path.join(addonRoot, 'Media', 'UI');
	const out = [];
	out.push(veilSoft().write(path.join(dir, 'veil-soft.tga')));
	out.push(ring().write(path.join(dir, 'skin-ring.tga')));
	out.push(arriveCheck().write(path.join(dir, 'skin-check.tga')));
	out.push(dart().write(path.join(dir, 'dart.tga')));
	out.push(dartEdge().write(path.join(dir, 'dart-edge.tga')));
	out.push(dartGold().write(path.join(dir, 'dart-gold.tga')));
	out.push(flag().write(path.join(dir, 'flag.tga')));
	out.push(house().write(path.join(dir, 'house.tga')));
	return out;
}

module.exports = { name: 'skins', generate };
