#!/usr/bin/env python3
"""Draw the Northstar open-book textures and a preview. Original art.

Run: python3 tools/media/tome/draw.py
Writes addon/Northstar/Media/UI/tome-*.tga and /opt/cursor/artifacts/northstar-tome.png
"""
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[3] / "addon" / "Northstar" / "Media" / "UI"
ART = Path("/opt/cursor/artifacts")
FONTS = Path(__file__).resolve().parents[3] / "addon" / "Northstar" / "Media" / "Fonts"

CRIMSON = (0x7A, 0x14, 0x20, 255)
CRIMSON_DEEP = (0x4E, 0x0C, 0x14, 255)
GOLD = (0xE2, 0xC0, 0x56, 255)
GOLD_DIM = (0xA8, 0x84, 0x2C, 255)
PAGE = (0xF1, 0xE4, 0xC4, 255)
PAGE_LIT = (0xF8, 0xF0, 0xD4, 255)
PAGE_SHADE = (0xA4, 0x7C, 0x4C, 255)
PLUM = (0x2A, 0x1A, 0x22, 255)
INK = (0x3A, 0x18, 0x1C, 255)
GREEN = (0x3E, 0x7A, 0x45, 255)
MUTED = (120, 84, 64, 255)
CLEAR = (0, 0, 0, 0)


def noise(x, y, n):
	v = (x * 374761393 + y * 668265263 + n * 144067) & 0xFFFFFFFF
	v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
	return (v ^ (v >> 16)) & 255


def mix(a, b, t):
	return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def blank(w, h, c):
	px = bytearray(w * h * 4)
	for i in range(w * h):
		px[i * 4:i * 4 + 4] = bytes(c)
	return px


def put(px, w, h, x, y, c):
	if 0 <= x < w and 0 <= y < h:
		i = (y * w + x) * 4
		px[i:i + 4] = bytes(c[:4])


def get(px, w, x, y):
	i = (y * w + x) * 4
	return tuple(px[i:i + 4])


def write_tga(path, w, h, px):
	header = bytearray(18)
	header[2] = 2
	header[12:14] = struct.pack("<H", w)
	header[14:16] = struct.pack("<H", h)
	header[16] = 32
	header[17] = 8 | 0x20
	bgra = bytearray(len(px))
	for i in range(0, len(px), 4):
		r, g, b, a = px[i:i + 4]
		bgra[i:i + 4] = bytes((b, g, r, a))
	path.write_bytes(bytes(header) + bgra)


def inside_round(x, y, w, h, r):
	if r <= 0:
		return True
	cx = min(max(x, r), w - 1 - r)
	cy = min(max(y, r), h - 1 - r)
	dx, dy = x - cx, y - cy
	return dx * dx + dy * dy <= r * r


def cover(w, h):
	r = 28
	px = blank(w, h, CLEAR)
	for y in range(h):
		for x in range(w):
			if not inside_round(x, y, w, h, r):
				continue
			n = noise(x, y, 9)
			c = CRIMSON
			if n > 240:
				c = (0x8C, 0x1C, 0x28, 255)
			elif n < 14:
				c = CRIMSON_DEEP
			# double gold rules, inset, following the rounded edge
			for inset, col in ((10, GOLD), (16, GOLD_DIM)):
				if inside_round(x, y, w, h, r) and not inside_round(x, y, w, h, max(4, r - 2)):
					pass
				outer = inside_round(x, y, w, h, r) and not (
					inset < x < w - 1 - inset and inset < y < h - 1 - inset and inside_round(x - 0, y, w, h, r)
				)
			# simpler inset rings
			on_ring = False
			for inset, thick, col in ((12, 2, GOLD), (18, 1, GOLD_DIM)):
				if inset <= x < w - inset and inset <= y < h - inset:
					edge = x < inset + thick or y < inset + thick or x >= w - inset - thick or y >= h - inset - thick
					if edge and inside_round(x, y, w, h, r):
						c = col
						on_ring = True
			put(px, w, h, x, y, c)
	# corner ornaments: small diamond plus a short double bracket
	def ornament(ox, oy, sx, sy):
		for i in range(14):
			put(px, w, h, ox + sx * i, oy, GOLD)
			put(px, w, h, ox + sx * i, oy + sy * 3, GOLD_DIM)
			put(px, w, h, ox, oy + sy * i, GOLD)
			put(px, w, h, ox + sx * 3, oy + sy * i, GOLD_DIM)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if abs(dx) + abs(dy) <= 3:
					put(px, w, h, ox + sx * 10 + dx, oy + sy * 10 + dy, GOLD if abs(dx) + abs(dy) != 3 else GOLD_DIM)
	ornament(22, 22, 1, 1)
	ornament(w - 23, 22, -1, 1)
	ornament(22, h - 23, 1, -1)
	ornament(w - 23, h - 23, -1, -1)
	# small stamped cartouche on the top edge
	cx, cy, cw, ch = w // 2 - 48, 4, 96, 18
	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if 0 <= x < w and 0 <= y < h and get(px, w, x, y)[3]:
				edge = x in (cx, cx + cw - 1) or y in (cy, cy + ch - 1)
				put(px, w, h, x, y, GOLD_DIM if edge else (0x6A, 0x10, 0x1A, 255))
	return px


def leaf(w, h, side):
	"""One page. side 'left' darkens toward the right (the spine)."""
	px = blank(w, h, PAGE)
	for y in range(h):
		for x in range(w):
			t = x / (w - 1)
			toward_spine = t if side == "left" else 1 - t
			outer = 1 - toward_spine
			base = mix(PAGE_LIT, PAGE_SHADE, toward_spine * 0.85)
			# a little lift on the outer curl
			if outer > 0.92:
				base = mix(base, PAGE_LIT, 0.65)
			n = noise(x, y, 4)
			if n > 248:
				base = mix(base, (0xE4, 0xD2, 0xA8, 255), 0.8)
			put(px, w, h, x, y, base)
	# stacked sheet edges on the outer side and along the bottom
	outer_x = 0 if side == "left" else w - 1
	step = 1 if side == "left" else -1
	for i in range(6):
		x = outer_x + step * (i * 2)
		col = (0xD8, 0xC4, 0x98, 255) if i % 2 == 0 else (0xA8, 0x84, 0x58, 255)
		for y in range(8, h - 8):
			put(px, w, h, x, y, col)
			if 0 <= x + step < w:
				put(px, w, h, x + step, y, (0xF7, 0xEE, 0xD2, 255))
	for i in range(4):
		y = h - 1 - i * 2
		col = (0xD8, 0xC4, 0x98, 255) if i % 2 == 0 else (0xA8, 0x84, 0x58, 255)
		x0 = 10 if side == "left" else 0
		x1 = w if side == "left" else w - 10
		for x in range(x0, x1):
			put(px, w, h, x, y, col)
	return px


def spine(w, h):
	px = blank(w, h, CLEAR)
	mid = (w - 1) / 2
	for y in range(h):
		for x in range(w):
			d = abs(x - mid) / (mid + 0.001)
			a = int(150 * (1 - d) ** 1.4)
			put(px, w, h, x, y, (0x3A, 0x18, 0x1C, a))
	return px


def ribbon(w, h, fill):
	px = blank(w, h, CLEAR)
	for y in range(h):
		for x in range(w):
			# swallowtail notch in the bottom eighth
			notch = y > h - h // 6 and abs(x - w / 2) < (y - (h - h // 6)) * (w / 2) / (h // 6)
			if notch:
				continue
			edge = x < 2 or x >= w - 2
			fold = abs(x - w / 2) < 2
			c = GOLD if edge else (GOLD_DIM if fold else fill)
			# cloth shade
			if not edge and not fold and noise(x, y, 6) > 242:
				c = mix(c, (0, 0, 0, 255), 0.25)
			put(px, w, h, x, y, c)
	return px


def note_card(w, h):
	px = blank(w, h, (0xF6, 0xED, 0xD2, 255))
	for y in range(h):
		for x in range(w):
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				put(px, w, h, x, y, GOLD)
			elif x < 4 or y < 4 or x >= w - 4 or y >= h - 4:
				put(px, w, h, x, y, GOLD_DIM)
	return px


def rule(w, h):
	px = blank(w, h, CLEAR)
	mid = h // 2
	for x in range(w):
		put(px, w, h, x, mid, GOLD)
		if x % 18 == 9:
			put(px, w, h, x, mid - 2, GOLD)
			put(px, w, h, x, mid + 2, GOLD)
	return px


def check(w, h):
	px = blank(w, h, CLEAR)
	for i in range(3, w // 2):
		put(px, w, h, i, h // 2 + i // 3, GREEN)
		put(px, w, h, i, h // 2 + i // 3 + 1, GREEN)
	for i in range(w // 2, w - 2):
		put(px, w, h, i, h - 4 - (i - w // 2) // 2, GREEN)
		put(px, w, h, i, h - 5 - (i - w // 2) // 2, GREEN)
	return px


def mark(w, h):
	px = blank(w, h, CLEAR)
	for y in range(2, h - 6):
		for x in range(w // 2 - 1, w // 2 + 2):
			put(px, w, h, x, y, GOLD)
	for y in range(h - 5, h - 2):
		for x in range(w // 2 - 1, w // 2 + 2):
			put(px, w, h, x, y, GOLD)
	return px


def flat(w, h, c):
	return blank(w, h, c)


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	files = {
		"tome-cover": (512, 256, cover(512, 256)),
		"tome-page-left": (256, 512, leaf(256, 512, "left")),
		"tome-page-right": (256, 512, leaf(256, 512, "right")),
		"tome-page": (64, 64, flat(64, 64, PAGE)),
		"tome-spine": (32, 256, spine(32, 256)),
		"tome-ribbon": (64, 128, ribbon(64, 128, PLUM)),
		"tome-ribbon-on": (64, 128, ribbon(64, 128, GOLD)),
		"tome-note": (128, 64, note_card(128, 64)),
		"tome-rule": (128, 8, rule(128, 8)),
		"tome-check": (16, 16, check(16, 16)),
		"tome-mark": (16, 16, mark(16, 16)),
		"tome-corner": (32, 32, flat(32, 32, GOLD)),
		"tome-gold": (16, 16, flat(16, 16, GOLD)),
		"tome-crimson": (16, 16, flat(16, 16, CRIMSON)),
		"tome-plum": (16, 16, flat(16, 16, PLUM)),
	}
	for name, (w, h, px) in files.items():
		write_tga(OUT / f"{name}.tga", w, h, px)
	preview()
	print("wrote", len(files), "textures")


def preview():
	from PIL import Image, ImageDraw, ImageFont
	cinzel = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 22)
	cinzel_sm = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 16)
	drop_font = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 34)
	body = ImageFont.truetype(str(FONTS / "Alegreya-Regular.ttf"), 18)
	body_sm = ImageFont.truetype(str(FONTS / "Alegreya-Regular.ttf"), 15)
	W, H = 1400, 860
	im = Image.new("RGB", (W, H), (18, 10, 14))
	d = ImageDraw.Draw(im)
	# cover
	x0, y0, x1, y1 = 70, 36, 1330, 800
	d.rounded_rectangle((x0, y0, x1, y1), radius=28, fill=CRIMSON[:3])
	d.rounded_rectangle((x0 + 10, y0 + 10, x1 - 10, y1 - 10), radius=20, outline=GOLD[:3], width=3)
	d.rounded_rectangle((x0 + 18, y0 + 18, x1 - 18, y1 - 18), radius=14, outline=GOLD_DIM[:3], width=1)
	for ox, oy, sx, sy in ((x0 + 26, y0 + 26, 1, 1), (x1 - 26, y0 + 26, -1, 1), (x0 + 26, y1 - 26, 1, -1), (x1 - 26, y1 - 26, -1, -1)):
		d.line((ox, oy, ox + sx * 22, oy), fill=GOLD[:3], width=2)
		d.line((ox, oy, ox, oy + sy * 22), fill=GOLD[:3], width=2)
		d.polygon([
			(ox + sx * 16, oy + sy * 10),
			(ox + sx * 22, oy + sy * 16),
			(ox + sx * 16, oy + sy * 22),
			(ox + sx * 10, oy + sy * 16),
		], fill=GOLD[:3])
	# stamped title on the cover's top edge
	label = "Northstar"
	tw = d.textlength(label, font=cinzel)
	lx = (x0 + x1 - tw) / 2 - 14
	d.rounded_rectangle((lx, y0 + 4, lx + tw + 28, y0 + 32), radius=3, fill=(90, 14, 22), outline=GOLD_DIM[:3])
	d.text((lx + 14, y0 + 6), label, font=cinzel, fill=GOLD[:3])
	d.text((x1 - 36, y0 + 8), "x", font=cinzel_sm, fill=GOLD[:3])
	# two facing pages
	pl, pt, pr, pb = 112, 108, 1288, 748
	mid = (pl + pr) // 2
	gap = 16
	def sheet_edges():
		shades = ((232, 214, 170), (168, 132, 88), (214, 190, 140), (150, 112, 70), (236, 220, 180), (160, 120, 76))
		for i, shade in enumerate(shades):
			d.rectangle((pl - 14 + i * 2, pt + 14, pl - 12 + i * 2, pb - 8), fill=shade)
			d.rectangle((pr + 12 - i * 2, pt + 14, pr + 14 - i * 2, pb - 8), fill=shade)
			d.rectangle((pl + 18, pb + 2 + i * 2, pr - 18, pb + 3 + i * 2), fill=shade)
	def page_image(w, h, side):
		paper = Image.new("RGB", (w, h), PAGE[:3])
		shadow = Image.new("RGB", (w, h), PAGE_SHADE[:3])
		mask = Image.linear_gradient("L").resize((w, h))
		if side == "right":
			mask = mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
		# mask is dark (0) at left. For the left page the spine is on the right, so flip.
		if side == "left":
			mask = mask.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
		# soften so the gutter is a shade, not a brown slab
		mask = mask.point(lambda p: int(p * 0.8))
		return Image.composite(shadow, paper, mask)
	lw, rw = mid - gap // 2 - pl, pr - (mid + gap // 2)
	ph = pb - pt
	im.paste(page_image(lw, ph, "left"), (pl, pt))
	im.paste(page_image(rw, ph, "right"), (mid + gap // 2, pt))
	sheet_edges()
	# gutter
	for i in range(gap):
		d.line((mid - gap // 2 + i, pt, mid - gap // 2 + i, pb), fill=(40 + i * 4, 16, 18))
	# ribbons hanging from the top edge, over the binding
	names = [("Leveling", True), ("Class", False), ("Professions", False), ("PvP", False)]
	rwib, gapw = 86, 8
	total = 4 * rwib + 3 * gapw
	rx = (W - total) // 2
	for text, on in names:
		rh = 64 if on else 42
		fill = GOLD[:3] if on else PLUM[:3]
		fg = INK[:3] if on else PAGE[:3]
		top = pt - 6
		d.polygon([
			(rx, top), (rx + rwib, top), (rx + rwib, top + rh - 10),
			(rx + rwib / 2, top + rh), (rx, top + rh - 10),
		], fill=fill)
		tw = d.textlength(text, font=body_sm)
		d.text((rx + (rwib - tw) / 2, top + 8), text, font=body_sm, fill=fg)
		rx += rwib + gapw
	# left page: zones
	d.text((pl + 28, pt + 70), "Zones", font=body, fill=CRIMSON[:3])
	d.line((pl + 28, pt + 96, mid - 36, pt + 96), fill=GOLD[:3], width=1)
	zones = [
		("Mulgore", "1-12", True, GREEN[:3]),
		("Durotar", "1-12", False, GREEN[:3]),
		("Tirisfal Glades", "1-12", False, GREEN[:3]),
		("Silverpine Forest", "12-20", False, GOLD[:3]),
		("The Barrens", "15-21", False, (196, 120, 48)),
	]
	zy = pt + 112
	for name, lv, on, col in zones:
		if on:
			d.rectangle((pl + 24, zy - 2, mid - 28, zy + 24), fill=GOLD[:3])
		d.text((pl + 32, zy), name, font=body, fill=INK[:3])
		lwv = d.textlength(lv, font=body_sm)
		d.text((mid - 36 - lwv, zy + 2), lv, font=body_sm, fill=INK[:3] if on else col)
		zy += 32
	d.text((pl + lw / 2 - 20, pb - 28), "~ 1 ~", font=body_sm, fill=MUTED[:3])
	# right page: drop cap, steps, note
	rx0 = mid + gap // 2
	d.rectangle((rx0 + 28, pt + 72, rx0 + 74, pt + 126), fill=CRIMSON[:3], outline=GOLD[:3])
	d.text((rx0 + 36, pt + 78), "M", font=drop_font, fill=GOLD[:3])
	d.text((rx0 + 86, pt + 86), "ulgore", font=cinzel, fill=CRIMSON[:3])
	d.line((rx0 + 28, pt + 140, pr - 28, pt + 140), fill=GOLD[:3], width=2)
	for x in range(int(rx0 + 40), pr - 40, 42):
		d.polygon([(x, pt + 136), (x + 4, pt + 140), (x, pt + 144), (x - 4, pt + 140)], fill=GOLD[:3])
	d.text((rx0 + 28, pt + 150), "Step 2", font=body_sm, fill=MUTED[:3])
	d.rectangle((rx0 + 24, pt + 176, pr - 24, pt + 204), fill=GOLD[:3])
	d.text((rx0 + 32, pt + 178), "!   Kill Plainstriders (1/7)", font=body, fill=INK[:3])
	d.line([(rx0 + 40, pt + 230), (rx0 + 54, pt + 242)], fill=GREEN[:3], width=2)
	d.line([(rx0 + 54, pt + 242), (rx0 + 70, pt + 222)], fill=GREEN[:3], width=2)
	d.text((rx0 + 80, pt + 218), "Speak with Grull Hawkwind", font=body, fill=GREEN[:3])
	d.ellipse((rx0 + 44, pt + 258, rx0 + 58, pt + 272), outline=MUTED[:3])
	d.text((rx0 + 80, pt + 252), "Return to Grull Hawkwind", font=body, fill=MUTED[:3])
	# note card
	nx0, ny0, nx1, ny1 = rx0 + 24, pb - 168, pr - 24, pb - 36
	d.rounded_rectangle((nx0, ny0, nx1, ny1), radius=2, fill=(246, 237, 210), outline=GOLD[:3], width=2)
	d.text((nx0 + 12, ny0 + 8), "The Hunt Begins", font=cinzel_sm, fill=CRIMSON[:3])
	d.text((nx0 + 12, ny0 + 36), "Plainstrider Meat", font=body, fill=(150, 110, 36))
	d.text((nx1 - 48, ny0 + 36), "1/7", font=body, fill=(150, 110, 36))
	d.text((nx0 + 12, ny0 + 60), "Plainstrider Beak", font=body, fill=GREEN[:3])
	d.text((nx1 - 48, ny0 + 60), "7/7", font=body, fill=GREEN[:3])
	d.text((nx0 + 12, ny0 + 92), "Direction    Ahead, 120 yd", font=body_sm, fill=INK[:3])
	d.text((rx0 + rw / 2 - 20, pb - 28), "~ 2 ~", font=body_sm, fill=MUTED[:3])
	ART.mkdir(parents=True, exist_ok=True)
	im.save(ART / "northstar-tome.png")
	print("preview", ART / "northstar-tome.png")


if __name__ == "__main__":
	main()
