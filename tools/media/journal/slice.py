#!/usr/bin/env python3
"""Slice MELLE's CC0 paintings into Northstar journal textures.

Sources (CC0, Melissa Krautheim, https://opengameart.org/users/melle):
  book.png
    https://opengameart.org/content/epic-collection-book
    file https://opengameart.org/sites/default/files/book_12.png
  parchment-set.png
    https://opengameart.org/content/fantasy-parchment-set
    file https://opengameart.org/sites/default/files/game_icons_parchment_set.png
Closed-cover variants on the book page (comments, same CC0 collection) are
not shipped; the spine strip is cut from the open book's own leather.

Run: python3 tools/media/journal/slice.py
Writes addon/Northstar/Media/UI/Journal/*.tga
and /opt/cursor/artifacts/northstar-tome.png
"""
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
SRC = Path(__file__).resolve().parent / "sources"
OUT = ROOT / "addon" / "Northstar" / "Media" / "UI" / "Journal"
ART = Path("/opt/cursor/artifacts")
FONTS = ROOT / "addon" / "Northstar" / "Media" / "Fonts"

# book.png is placed, unstretched, in a 2048x1024 texture. These match the paste.
BOOK_TEX = (2048, 1024)
BOOK_SCALE_H = 1024


def write_tga(path, image):
	im = image.convert("RGBA")
	w, h = im.size
	if w & (w - 1) or h & (h - 1):
		raise SystemExit(f"{path.name} is {w}x{h}, not power-of-two")
	raw = im.tobytes()
	header = bytearray(18)
	header[2] = 2
	header[12:14] = struct.pack("<H", w)
	header[14:16] = struct.pack("<H", h)
	header[16] = 32
	header[17] = 8 | 0x20  # 8 alpha bits, top-left origin
	bgra = bytearray(len(raw))
	for i in range(0, len(raw), 4):
		r, g, b, a = raw[i:i + 4]
		bgra[i:i + 4] = bytes((b, g, r, a))
	path.write_bytes(bytes(header) + bgra)


def write_icons():
	"""Original 32x32 step marks. Not Zygor, RestedXP, Polestar, or Blizzard art."""
	INK = (236, 224, 196, 255)
	GOLD = (226, 192, 86, 255)
	GREEN = (90, 190, 110, 255)

	def canvas():
		return Image.new("RGBA", (32, 32), (0, 0, 0, 0))

	def save(name, im):
		write_tga(OUT / f"journal-icon-{name}.tga", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.rectangle((14, 4, 18, 20), fill=GOLD)
	d.rectangle((14, 24, 18, 28), fill=GOLD)
	save("accept", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.arc((6, 2, 26, 20), 200, 60, fill=INK, width=3)
	d.rectangle((14, 22, 18, 26), fill=INK)
	save("turnin", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.polygon([(8, 26), (22, 6), (26, 8), (12, 28)], fill=INK)
	d.polygon([(6, 28), (12, 22), (16, 26), (10, 30)], fill=GOLD)
	save("kill", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.rounded_rectangle((6, 12, 26, 28), radius=3, outline=INK, width=2)
	d.arc((8, 6, 24, 18), 200, 340, fill=INK, width=2)
	save("collect", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.polygon([(6, 20), (16, 8), (20, 12), (12, 22)], fill=INK)
	d.ellipse((14, 16, 26, 28), outline=INK, width=2)
	save("travel", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.polygon([(16, 4), (28, 16), (22, 16), (22, 28), (10, 28), (10, 16), (4, 16)], fill=INK)
	save("hearth", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.polygon([(6, 8), (16, 4), (26, 8), (26, 26), (16, 30), (6, 26)], outline=GOLD, width=2)
	d.line((16, 6, 16, 28), fill=GOLD, width=1)
	save("train", im)

	im = canvas(); d = ImageDraw.Draw(im)
	d.line((6, 16, 13, 24), fill=GREEN, width=3)
	d.line((13, 24, 26, 8), fill=GREEN, width=3)
	save("check", im)


def natural_parchment(image):
	"""Cut the cyan rim and the black corner. Leave the warm painted face."""
	im = image.convert("RGBA")
	pix = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = pix[x, y]
			if a < 40 or (r < 45 and g < 45 and b < 45):
				pix[x, y] = (0, 0, 0, 0)
				continue
			# Cyan and pink rim light on the curl. The face itself stays.
			if b > r + 4 and b > 90:
				pix[x, y] = (0, 0, 0, 0)
				continue
			if r > 160 and b > g + 20 and g < 150:
				pix[x, y] = (0, 0, 0, 0)
	bbox = im.getbbox()
	return im.crop(bbox) if bbox else im


def fit(image, tw, th):
	"""Scale image to fit inside tw,th. No crop, no stretch. Transparent rest."""
	im = image.convert("RGBA")
	w, h = im.size
	s = min(tw / w, th / h)
	nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
	im = im.resize((nw, nh), Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
	ox, oy = (tw - nw) // 2, (th - nh) // 2
	canvas.paste(im, (ox, oy), im)
	return canvas, (ox, oy, nw, nh)


def main():
	book = Image.open(SRC / "book.png").convert("RGBA")
	sheet = Image.open(SRC / "parchment-set.png").convert("RGBA")
	OUT.mkdir(parents=True, exist_ok=True)
	write_icons()

	bw, bh = book.size
	s = BOOK_SCALE_H / bh
	nw, nh = int(round(bw * s)), BOOK_SCALE_H
	placed = book.resize((nw, nh), Image.Resampling.LANCZOS)
	tex_w, tex_h = BOOK_TEX
	book_tex = Image.new("RGBA", (tex_w, tex_h), (0, 0, 0, 0))
	ox = (tex_w - nw) // 2
	book_tex.paste(placed, (ox, 0), placed)
	write_tga(OUT / "journal-book.tga", book_tex)
	uv = (ox / tex_w, (ox + nw) / tex_w, 0.0, 1.0)

	# Leather only, from the open book's left cover, clear of the corner guard.
	leather = book.crop((136, 260, 166, 760))
	spine, _ = fit(leather, 64, 512)
	write_tga(OUT / "journal-spine.tga", spine)

	# Sprite sheet, left to right: scroll, loose parchment, map, letter, open letter.
	# The loose sheet. Drop the cyan rim light and the black corner so the
	# writing face stays the painted warm parchment.
	letter = natural_parchment(sheet.crop((317, 13, 550, 275)))
	letter_tex, _ = fit(letter, 256, 256)
	write_tga(OUT / "journal-letter.tga", letter_tex)

	def keep_red(image):
		out = image.convert("RGBA")
		pix = out.load()
		w, h = out.size
		for y in range(h):
			for x in range(w):
				r, g, b, a = pix[x, y]
				if not (a > 40 and r > 120 and r > g + 25 and r > b + 25):
					pix[x, y] = (0, 0, 0, 0)
		return out

	ribbon = keep_red(sheet.crop((96, 175, 214, 262)))
	ribbon_tex, _ = fit(ribbon, 128, 64)
	write_tga(OUT / "journal-ribbon.tga", ribbon_tex)

	seal = keep_red(sheet.crop((108, 100, 190, 175)))
	seal_tex, _ = fit(seal, 128, 128)
	write_tga(OUT / "journal-seal.tga", seal_tex)

	preview(book, letter, ribbon, seal, uv)
	print("uv", " ".join(f"{v:.6f}" for v in uv))
	print("wrote", OUT)


def preview(book, letter, ribbon, seal, uv):
	"""Composite the sliced paintings at the in-game frame size."""
	W, H = 820, 500
	frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	# The frame shows the book's UV rect, so paste the book to the full frame.
	frame.paste(book.resize((W, H), Image.Resampling.LANCZOS), (0, 0), book.resize((W, H), Image.Resampling.LANCZOS))
	# Cover the rings with the leather strip.
	spine = book.crop((136, 260, 166, 760)).resize((52, 420), Image.Resampling.LANCZOS)
	frame.paste(spine, (386, 48), spine)
	# Parchment note on the lower right page. Text stays inside the face.
	card = letter.resize((240, 150), Image.Resampling.LANCZOS)
	frame.paste(card, (500, 330), card)
	# Ribbon tabs along the top.
	names = [("Leveling", True), ("Class", False), ("Professions", False), ("PvP", False)]
	ink = (0x3A, 0x24, 0x14, 255)
	current = (0x8A, 0x32, 0x22, 255)
	done = (0x2F, 0x6B, 0x3A, 255)
	cinzel = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 15)
	dropf = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 28)
	body = ImageFont.truetype(str(FONTS / "Alegreya-Regular.ttf"), 15)
	small = ImageFont.truetype(str(FONTS / "Alegreya-Regular.ttf"), 13)
	d = ImageDraw.Draw(frame)
	d.text((348, 8), "Northstar", font=cinzel, fill=(226, 196, 140, 255))
	for text, on, x in (("Leveling", True, 108), ("Class", False, 230), ("Professions", False, 468), ("PvP", False, 640)):
		icon = seal.resize((18, 18), Image.Resampling.LANCZOS) if on else ribbon.resize((22, 14), Image.Resampling.LANCZOS)
		frame.paste(icon, (x, 46), icon)
		d.text((x + 26, 44), text, font=small, fill=ink)
	d.text((120, 78), "Zones", font=body, fill=ink)
	zones = [("Mulgore", "1-12", True), ("Durotar", "1-12", False), ("Tirisfal Glades", "1-12", False),
		("Silverpine Forest", "12-20", False), ("The Barrens", "15-21", False)]
	y = 102
	for name, lv, sel in zones:
		if sel:
			mark = seal.resize((16, 16), Image.Resampling.LANCZOS)
			frame.paste(mark, (112, y), mark)
		d.text((132, y - 2), name, font=body, fill=ink)
		d.text((300, y - 2), lv, font=small, fill=ink)
		y += 22
	d.text((470, 78), "M", font=dropf, fill=current)
	d.text((498, 86), "ulgore", font=cinzel, fill=ink)
	d.text((470, 118), "Step 2", font=small, fill=ink)
	d.text((470, 140), "Kill Plainstriders (1/7)", font=body, fill=current)
	d.text((470, 166), "Speak with Grull Hawkwind", font=body, fill=done)
	# Text sits on the letter's white paper.
	neutral = (0x6A, 0x4A, 0x32, 255)
	d.text((470, 188), "Return to Grull Hawkwind", font=small, fill=neutral)
	d.text((470, 208), "Accept The Battleboars", font=small, fill=neutral)
	d.text((530, 368), "The Hunt Begins", font=cinzel, fill=ink)
	d.text((530, 390), "Plainstrider Meat  1/7", font=small, fill=current)
	d.text((530, 408), "Plainstrider Beak  7/7", font=small, fill=done)
	d.text((530, 428), "Ahead, 120 yd", font=small, fill=ink)
	ART.mkdir(parents=True, exist_ok=True)
	ingame(frame, letter)
	frame.convert("RGB").save(ART / "northstar-tome.png")
	print("preview", ART / "northstar-tome.png", "uv", uv)


def ingame(frame, letter):
	"""Lay the real window on Chris's Forever shot.

	Assumption: Use UI Scale is off, so 1 UI unit is 1 screenshot pixel.
	The book is 820 by 500, anchored to the top centre, 80 pixels down.
	The closed note uses that same anchor and is 280 by 130.
	"""
	shot_path = Path("/home/ubuntu/.cursor/projects/workspace/uploads/forever-ui_cebb.png")
	shot = Image.open(shot_path).convert("RGBA")
	sw, sh = shot.size
	ink = (0x3A, 0x24, 0x14, 255)
	current = (0x8A, 0x32, 0x22, 255)
	done = (0x2F, 0x6B, 0x3A, 255)
	cinzel = ImageFont.truetype(str(FONTS / "Cinzel-Regular.ttf"), 13)
	small = ImageFont.truetype(str(FONTS / "Alegreya-Regular.ttf"), 12)

	def place(widget, name):
		canvas = shot.copy()
		x = (sw - widget.width) // 2
		y = 80
		canvas.alpha_composite(widget, (x, y))
		canvas.convert("RGB").save(ART / name)
		print(name, f"{widget.width}x{widget.height}", "at", x, y, "on", f"{sw}x{sh}")

	place(frame, "northstar-ingame-open.png")
	# Closed tracker: a dark panel, top-left, clear of the minimap and the quest list.
	# TOPLEFT 16, -140 on a 1:1 UI scale is x=16, y=140.
	slip = Image.new("RGBA", (260, 112), (0, 0, 0, 0))
	d = ImageDraw.Draw(slip)
	d.rectangle((0, 0, 259, 111), fill=(158, 138, 82, 255))
	d.rectangle((1, 1, 258, 110), fill=(13, 10, 8, int(255 * 0.6)))
	def ink_text(xy, text, fill):
		d.text((xy[0] + 1, xy[1] + 1), text, font=small, fill=(0, 0, 0, 255))
		d.text(xy, text, font=small, fill=fill)
	ink_text((10, 10), "The Hunt Begins", (255, 209, 64, 255))
	ink_text((10, 30), "Kill Plainstriders (1/7)", (255, 255, 255, 255))
	ink_text((10, 50), "Plainstrider Meat", (200, 200, 200, 255))
	ink_text((150, 50), "(1/7)", (226, 192, 86, 255))
	ink_text((10, 70), "Plainstrider Beak", (61, 204, 110, 255))
	ink_text((10, 90), "Ahead, 120 yd", (255, 255, 255, 255))
	canvas = shot.copy()
	canvas.alpha_composite(slip, (16, 140))
	canvas.convert("RGB").save(ART / "northstar-ingame-closed.png")
	print("northstar-ingame-closed.png", "260x112", "at", 16, 140, "on", f"{sw}x{sh}")
	# Guide viewer where the quest list sits, and the waypoint tag at top centre.
	viewer = Image.new("RGBA", (280, 230), (0, 0, 0, 0))
	vd = ImageDraw.Draw(viewer)
	vd.rectangle((0, 0, 279, 229), fill=(158, 138, 82, 255))
	vd.rectangle((1, 1, 278, 228), fill=(13, 10, 8, int(255 * 0.6)))
	def vtext(xy, text, fill, font=small):
		vd.text((xy[0] + 1, xy[1] + 1), text, font=font, fill=(0, 0, 0, 255))
		vd.text(xy, text, font=font, fill=fill)
	vtext((8, 6), "Mulgore 1-12", (255, 209, 64, 255))
	vtext((168, 6), "<  >  B  *  _", (230, 210, 140, 255))
	vd.rectangle((6, 28, 274, 48), fill=(184, 148, 56, 90))
	vtext((8, 30), "2  /  Kill Plainstriders", (255, 255, 255, 255))
	vtext((18, 52), "Plainstrider Meat", (200, 200, 200, 255))
	vtext((150, 52), "(1/7)", (226, 192, 86, 255))
	vtext((8, 74), "3  !  The Battleboars", (220, 220, 220, 255))
	vtext((8, 96), "4  ?  Return to Grull", (220, 220, 220, 255))
	vtext((8, 118), "5  >  Ride to Bloodhoof", (220, 220, 220, 255))
	vd.rectangle((8, 200, 272, 214), fill=(64, 56, 40, 255))
	vd.rectangle((8, 200, 70, 214), fill=(184, 148, 56, 255))
	vtext((8, 176), "2/10   20%", (217, 204, 158, 255))
	arrow = Image.new("RGBA", (168, 36), (0, 0, 0, 0))
	ad = ImageDraw.Draw(arrow)
	ad.rectangle((0, 0, 167, 35), fill=(158, 138, 82, 255))
	ad.rectangle((1, 1, 166, 34), fill=(13, 10, 8, int(255 * 0.6)))
	ad.text((9, 5), ">", font=small, fill=(255, 209, 64, 255))
	ad.text((24, 4), "Plainstrider", font=small, fill=(255, 255, 255, 255))
	ad.text((24, 18), "Ahead, 120 yd", font=small, fill=(230, 220, 180, 255))
	shot2 = shot.copy()
	shot2.alpha_composite(viewer, (sw - 12 - 280, 190))
	shot2.alpha_composite(arrow, ((sw - 168) // 2, 36))
	shot2.convert("RGB").save(ART / "northstar-ingame-viewer.png")
	print("northstar-ingame-viewer.png", "viewer", sw - 12 - 280, 190, "arrow", (sw - 168) // 2, 36)


if __name__ == "__main__":
	main()
