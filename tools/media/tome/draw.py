#!/usr/bin/env python3
"""Draw the Northstar tome textures and a preview. Original art, no Blizzard files.

Run: python3 tools/media/tome/draw.py
Writes addon/Northstar/Media/UI/tome-*.tga and /opt/cursor/artifacts/northstar-tome.png
"""
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[3] / "addon" / "Northstar" / "Media" / "UI"
ART = Path("/opt/cursor/artifacts")

CRIMSON = (0x7A, 0x14, 0x20, 255)
GOLD = (0xE2, 0xC0, 0x56, 255)
GOLD_DIM = (0xA8, 0x84, 0x2C, 255)
PAGE = (0xF1, 0xE4, 0xC4, 255)
PLUM = (0x2A, 0x1A, 0x22, 255)
INK = (0x3A, 0x18, 0x1C, 255)
GREEN = (0x3E, 0x7A, 0x45, 255)
MUTED = (120, 84, 64, 255)


def noise(x, y, n):
	v = (x * 374761393 + y * 668265263 + n * 144067) & 0xFFFFFFFF
	v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
	return (v ^ (v >> 16)) & 255


def blank(w, h, c):
	px = bytearray(w * h * 4)
	for i in range(w * h):
		px[i * 4:i * 4 + 4] = bytes(c)
	return px


def put(px, w, x, y, c):
	if 0 <= x < w and y >= 0:
		i = (y * w + x) * 4
		if i + 3 < len(px):
			px[i:i + 4] = bytes(c)


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
	path.write_bytes(header + bgra)


def page(w, h):
	px = blank(w, h, PAGE)
	for y in range(h):
		for x in range(w):
			n = noise(x, y, 3) 
			if n > 248:
				put(px, w, x, y, (0xE4, 0xD2, 0xA8, 255))
			elif n < 6:
				put(px, w, x, y, (0xE8, 0xD8, 0xB4, 255))
	return px


def leather(w, h):
	px = blank(w, h, CRIMSON)
	for y in range(h):
		for x in range(w):
			n = noise(x, y, 9)
			if n > 230:
				put(px, w, x, y, (0x8C, 0x1C, 0x28, 255))
			elif n < 18:
				put(px, w, x, y, (0x5C, 0x0C, 0x16, 255))
			# gold tooled inner line
			if x in (2, 3, w - 3, w - 4) or y in (2, 3, h - 3, h - 4):
				put(px, w, x, y, GOLD)
	return px


def corner(w, h):
	px = blank(w, h, (0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			on = x < 4 or y < 4 or (6 <= x <= 8 and y < 14) or (6 <= y <= 8 and x < 14)
			if on:
				put(px, w, x, y, GOLD if (x + y) % 5 else GOLD_DIM)
	return px


def ribbon(w, h, fill):
	px = blank(w, h, (0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			notch = y > h - 8 and (x < 4 or x >= w - 4 or abs(x - w // 2) < 2)
			if notch:
				continue
			edge = x < 2 or x >= w - 2
			put(px, w, x, y, GOLD if edge else fill)
	return px


def check(w, h):
	px = blank(w, h, (0, 0, 0, 0))
	for i in range(4, w - 2):
		put(px, w, i // 2, h // 2 + i // 3, GREEN)
		put(px, w, i // 2, h // 2 + i // 3 + 1, GREEN)
	for i in range(w // 2, w - 2):
		put(px, w, i, h - 3 - (i - w // 2) // 2, GREEN)
		put(px, w, i, h - 4 - (i - w // 2) // 2, GREEN)
	return px


def mark(w, h):
	px = blank(w, h, (0, 0, 0, 0))
	for y in range(2, h - 6):
		for x in range(w // 2 - 2, w // 2 + 2):
			put(px, w, x, y, GOLD)
	for y in range(h - 5, h - 2):
		for x in range(w // 2 - 2, w // 2 + 2):
			put(px, w, x, y, GOLD)
	return px


def rule(w, h):
	px = blank(w, h, (0, 0, 0, 0))
	mid = h // 2
	for x in range(w):
		put(px, w, x, mid, GOLD)
		if x % 16 == 8:
			put(px, w, x, mid - 2, GOLD)
			put(px, w, x, mid + 2, GOLD)
	return px


def spine(w, h):
	px = blank(w, h, (0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			a = 90 if x < 2 or x >= w - 2 else 40
			put(px, w, x, y, (0x3A, 0x18, 0x1C, a))
	return px


def plum(w, h):
	return blank(w, h, PLUM)


def gold_plate(w, h):
	px = blank(w, h, GOLD)
	for y in range(h):
		for x in range(w):
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				put(px, w, x, y, GOLD_DIM)
	return px


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	files = {
		"tome-page": page(64, 64),
		"tome-cover": leather(64, 64),
		"tome-corner": corner(32, 32),
		"tome-ribbon": ribbon(32, 64, PLUM),
		"tome-ribbon-on": ribbon(32, 64, GOLD),
		"tome-check": check(16, 16),
		"tome-mark": mark(16, 16),
		"tome-rule": rule(128, 8),
		"tome-spine": spine(16, 64),
		"tome-plum": plum(16, 16),
		"tome-gold": gold_plate(16, 16),
		"tome-crimson": blank(16, 16, CRIMSON),
	}
	for name, px in files.items():
		side = int(len(px) / 4) ** 0.5
		# widths differ; store with the generators' sizes via a parallel map
	sizes = {
		"tome-page": (64, 64), "tome-cover": (64, 64), "tome-corner": (32, 32),
		"tome-ribbon": (32, 64), "tome-ribbon-on": (32, 64), "tome-check": (16, 16),
		"tome-mark": (16, 16), "tome-rule": (128, 8), "tome-spine": (16, 64),
		"tome-plum": (16, 16), "tome-gold": (16, 16), "tome-crimson": (16, 16),
	}
	for name, (w, h) in sizes.items():
		write_tga(OUT / f"{name}.tga", w, h, files[name])
	preview()
	print("wrote", len(sizes), "textures")


def preview():
	try:
		from PIL import Image, ImageDraw, ImageFont
	except ImportError:
		print("no PIL, skipped preview")
		return
	font_dir = Path(__file__).resolve().parents[3] / "addon" / "Northstar" / "Media" / "Fonts"
	cinzel = ImageFont.truetype(str(font_dir / "Cinzel-Regular.ttf"), 28)
	cinzel_sm = ImageFont.truetype(str(font_dir / "Cinzel-Regular.ttf"), 18)
	cinzel_drop = ImageFont.truetype(str(font_dir / "Cinzel-Regular.ttf"), 36)
	body = ImageFont.truetype(str(font_dir / "Alegreya-Regular.ttf"), 18)
	body_sm = ImageFont.truetype(str(font_dir / "Alegreya-Regular.ttf"), 16)
	W, H = 1360, 920
	im = Image.new("RGB", (W, H), (22, 12, 16))
	px = im.load()
	for y in range(H):
		for x in range(W):
			n = noise(x // 3, y // 3, 1)
			if n > 250:
				px[x, y] = (32, 16, 22)
	d = ImageDraw.Draw(im)
	x0, y0, x1, y1 = 40, 30, 1320, 870
	d.rectangle((x0, y0, x1, y1), fill=CRIMSON[:3])
	for y in range(y0, y1):
		for x in range(x0, x1):
			n = noise(x, y, 9)
			if n > 246:
				px[x, y] = (140, 28, 40)
			elif n < 8:
				px[x, y] = (92, 12, 22)
	d.rectangle((x0 + 10, y0 + 10, x1 - 10, y1 - 10), outline=GOLD[:3], width=3)
	d.rectangle((x0 + 16, y0 + 16, x1 - 16, y1 - 16), outline=GOLD_DIM[:3], width=1)
	for ax, ay, bx, by in (
		(x0 + 10, y0 + 10, x0 + 32, y0 + 15), (x0 + 10, y0 + 10, x0 + 15, y0 + 32),
		(x1 - 32, y0 + 10, x1 - 10, y0 + 15), (x1 - 15, y0 + 10, x1 - 10, y0 + 32),
		(x0 + 10, y1 - 15, x0 + 32, y1 - 10), (x0 + 10, y1 - 32, x0 + 15, y1 - 10),
		(x1 - 32, y1 - 15, x1 - 10, y1 - 10), (x1 - 15, y1 - 32, x1 - 10, y1 - 10),
	):
		d.rectangle((ax, ay, bx, by), fill=GOLD[:3])
	title = "Northstar"
	tw = d.textlength(title, font=cinzel)
	d.text(((x0 + x1 - tw) / 2, y0 + 22), title, font=cinzel, fill=GOLD[:3])
	d.line((x0 + 280, y0 + 36, (x0 + x1 - tw) / 2 - 16, y0 + 36), fill=GOLD[:3], width=1)
	d.line(((x0 + x1 + tw) / 2 + 16, y0 + 36, x1 - 280, y0 + 36), fill=GOLD[:3], width=1)
	d.text((x1 - 36, y0 + 22), "x", font=cinzel_sm, fill=GOLD[:3])
	# facing pages
	d.rectangle((80, 100, 400, 820), fill=PAGE[:3])
	d.rectangle((416, 100, 900, 820), fill=PAGE[:3])
	d.rectangle((916, 100, 1288, 820), fill=PAGE[:3])
	for x in range(400, 416):
		shade = 70 + (x - 400) * 8
		d.line((x, 100, x, 820), fill=(shade, 40, 36))
	for x in range(900, 916):
		shade = 90 - (x - 900)
		d.line((x, 100, x, 820), fill=(shade, 48, 40))
	# bookmark ribbons on the cover edge
	ribbons = [("Leveling", True), ("Class", False), ("Professions", False), ("PvP", False)]
	ry = 112
	for text, on in ribbons:
		fill = GOLD[:3] if on else PLUM[:3]
		fg = INK[:3] if on else PAGE[:3]
		d.polygon([(56, ry), (188, ry), (188, ry + 36), (122, ry + 48), (56, ry + 36)], fill=fill)
		d.text((68, ry + 6), text, font=body, fill=fg)
		ry += 52
	d.text((96, 340), "Zones", font=body, fill=CRIMSON[:3])
	d.line((96, 366, 380, 366), fill=GOLD[:3], width=1)
	zones = [
		("Mulgore", "1-12", GREEN[:3], True),
		("Durotar", "1-12", GREEN[:3], False),
		("Tirisfal Glades", "1-12", GREEN[:3], False),
		("Silverpine Forest", "12-20", GOLD[:3], False),
		("The Barrens", "15-21", (196, 120, 48), False),
	]
	zy = 378
	for name, lv, col, on in zones:
		if on:
			d.rectangle((92, zy - 2, 388, zy + 24), fill=GOLD[:3])
			d.text((100, zy), name, font=body, fill=INK[:3])
		else:
			d.text((100, zy), name, font=body, fill=INK[:3])
		lw = d.textlength(lv, font=body_sm)
		d.text((380 - lw, zy + 1), lv, font=body_sm, fill=col if not on else INK[:3])
		zy += 30
	# illuminated drop cap
	d.rectangle((436, 118, 484, 174), fill=CRIMSON[:3])
	d.rectangle((436, 118, 484, 174), outline=GOLD[:3])
	d.text((444, 122), "M", font=cinzel_drop, fill=GOLD[:3])
	d.text((496, 132), "ulgore", font=cinzel, fill=CRIMSON[:3])
	d.line((436, 188, 880, 188), fill=GOLD[:3], width=2)
	for x in range(436, 880, 36):
		d.polygon([(x + 16, 184), (x + 20, 188), (x + 16, 192), (x + 12, 188)], fill=GOLD[:3])
	d.text((436, 198), "Step 2", font=body_sm, fill=MUTED[:3])
	d.rectangle((432, 226, 884, 254), fill=GOLD[:3])
	d.text((440, 228), "!   Kill Plainstriders (1/7)", font=body, fill=INK[:3])
	steps = [
		(True, "Speak with Grull Hawkwind"),
		(False, "Return to Grull Hawkwind"),
		(False, "Accept The Battleboars"),
	]
	sy = 266
	for done, text in steps:
		if done:
			d.line((444, sy + 14, 456, sy + 22), fill=GREEN[:3], width=2)
			d.line((456, sy + 22, 470, sy + 8), fill=GREEN[:3], width=2)
			d.text((480, sy), text, font=body, fill=GREEN[:3])
		else:
			d.ellipse((446, sy + 8, 458, sy + 20), outline=MUTED[:3])
			d.text((480, sy), text, font=body, fill=MUTED[:3])
		sy += 32
	d.text((936, 118), "The Hunt Begins", font=cinzel_sm, fill=CRIMSON[:3])
	d.text((936, 156), "Plainstrider Meat", font=body, fill=(168, 120, 32))
	d.text((1188, 156), "1/7", font=body, fill=(168, 120, 32))
	d.line((948, 196, 960, 208), fill=GREEN[:3], width=2)
	d.line((960, 208, 974, 190), fill=GREEN[:3], width=2)
	d.text((984, 188), "Plainstrider Beak", font=body, fill=GREEN[:3])
	d.text((1188, 188), "7/7", font=body, fill=GREEN[:3])
	d.text((936, 236), "Direction", font=body_sm, fill=MUTED[:3])
	d.polygon([(944, 276), (952, 260), (960, 276), (952, 270)], fill=GOLD[:3])
	d.text((972, 258), "Ahead, 120 yd", font=body, fill=INK[:3])
	d.text((48, 888), "Preview of the open tome. Example lines, not a live client.", font=body_sm, fill=(180, 150, 120))
	ART.mkdir(parents=True, exist_ok=True)
	im.save(ART / "northstar-tome.png")
	print("preview", ART / "northstar-tome.png")


if __name__ == "__main__":
	main()
