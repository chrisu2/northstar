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
	# The loose sheet, not the envelope: the envelope's writing panel is too small for the tracker.
	letter = sheet.crop((317, 13, 550, 275))
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
	# Letter card on the lower right page. Text sits on its white paper.
	card = letter.resize((250, 200), Image.Resampling.LANCZOS)
	frame.paste(card, (520, 270), card)
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
	for text, on, x in (("Leveling", True, 120), ("Class", False, 250), ("Professions", False, 370), ("PvP", False, 540)):
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
		d.text((360, y - 2), lv, font=small, fill=ink)
		y += 22
	d.text((470, 78), "M", font=dropf, fill=current)
	d.text((498, 86), "ulgore", font=cinzel, fill=ink)
	d.text((470, 118), "Step 2", font=small, fill=ink)
	d.text((470, 140), "Kill Plainstriders (1/7)", font=body, fill=current)
	d.text((470, 166), "Speak with Grull Hawkwind", font=body, fill=done)
	# Text sits on the letter's white paper.
	d.text((555, 310), "The Hunt Begins", font=cinzel, fill=ink)
	d.text((555, 332), "Plainstrider Meat  1/7", font=small, fill=current)
	d.text((555, 350), "Plainstrider Beak  7/7", font=small, fill=done)
	d.text((555, 372), "Ahead, 120 yd", font=small, fill=ink)
	ART.mkdir(parents=True, exist_ok=True)
	frame.convert("RGB").save(ART / "northstar-tome.png")
	print("preview", ART / "northstar-tome.png", "uv", uv)


if __name__ == "__main__":
	main()
