#!/usr/bin/env python3
"""Generate pixel-map backdrop and original card faces. CC0 inputs stay in assets/kenney."""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated"
FONT_PATH = ROOT / "fonts" / "NotoSans-Regular.ttf"

W, H = 168, 236


DECKS = {
    "mages": {
        "paper": (214, 216, 208),
        "paper_dark": (186, 192, 186),
        "frame": (54, 74, 112),
        "metal": (176, 138, 78),
        "ink": (22, 28, 40),
        "plaque": (46, 62, 96),
        "name": (236, 230, 214),
        "fiber": False,
    },
    "kings": {
        "paper": (236, 226, 204),
        "paper_dark": (214, 196, 164),
        "frame": (138, 102, 48),
        "metal": (196, 156, 72),
        "ink": (48, 32, 18),
        "plaque": (92, 64, 28),
        "name": (248, 236, 206),
        "fiber": False,
    },
    "dead": {
        "paper": (176, 174, 166),
        "paper_dark": (146, 144, 136),
        "frame": (92, 90, 84),
        "metal": (214, 206, 188),
        "ink": (32, 30, 28),
        "plaque": (62, 60, 56),
        "name": (230, 224, 210),
        "fiber": True,
    },
    "beasts": {
        "paper": (198, 156, 98),
        "paper_dark": (156, 114, 66),
        "frame": (78, 50, 30),
        "metal": (86, 108, 62),
        "ink": (36, 24, 14),
        "plaque": (62, 40, 24),
        "name": (236, 214, 170),
        "fiber": False,
    },
}

CARDS = [
    ("mages", "Искра", 1, 1, 2, "flame"),
    ("mages", "Щит", 2, 0, 4, "ward"),
    ("mages", "Зов", 2, 2, 2, "hood"),
    ("mages", "Вьюга", 3, 3, 2, "gust"),
    ("kings", "Страж", 2, 1, 4, "helm"),
    ("kings", "Указ", 1, 1, 1, "crown"),
    ("kings", "Казна", 2, 0, 3, "coins"),
    ("kings", "Рыцарь", 3, 3, 3, "knight"),
    ("dead", "Кость", 1, 2, 1, "skull"),
    ("dead", "Склеп", 2, 1, 4, "tomb"),
    ("dead", "Чума", 2, 2, 2, "mist"),
    ("dead", "Тлен", 3, 3, 1, "ash"),
    ("beasts", "Волк", 1, 2, 1, "wolf"),
    ("beasts", "Медведь", 3, 3, 4, "bear"),
    ("beasts", "Сова", 2, 1, 2, "owl"),
    ("beasts", "Олень", 2, 2, 3, "stag"),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size)


def paper_fill(img: Image.Image, deck: dict, seed: int) -> None:
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    base = deck["paper"]
    dark = deck["paper_dark"]
    for y in range(h):
        fy = y / h
        for x in range(w):
            n = rnd.randint(-10, 8)
            band = 6 if deck["fiber"] and (y + rnd.randint(0, 2)) % 7 == 0 else 0
            c = tuple(max(0, min(255, base[i] + n - band - int(8 * fy))) for i in range(3))
            if (x + y) % 17 == 0:
                c = dark
            px[x, y] = c + (255,)


def rounded_rect(draw: ImageDraw.ImageDraw, box, r, fill):
    draw.rounded_rectangle(box, radius=r, fill=fill)


def draw_frame(img: Image.Image, deck: dict) -> None:
    draw = ImageDraw.Draw(img)
    w, h = img.size
    rounded_rect(draw, (0, 0, w - 1, h - 1), 10, deck["frame"])
    rounded_rect(draw, (6, 6, w - 7, h - 7), 7, deck["paper"])
    # metal corner ticks
    m = deck["metal"]
    for x, y, sx, sy in ((10, 10, 1, 1), (w - 11, 10, -1, 1), (10, h - 11, 1, -1), (w - 11, h - 11, -1, -1)):
        draw.line((x, y, x + sx * 16, y), fill=m, width=2)
        draw.line((x, y, x, y + sy * 16), fill=m, width=2)
    draw.rounded_rectangle((8, 8, w - 9, h - 9), radius=6, outline=deck["ink"], width=1)


def text_center(draw, xy, text, fnt, fill):
    box = draw.textbbox((0, 0), text, font=fnt)
    tw, th = box[2] - box[0], box[3] - box[1]
    draw.text((xy[0] - tw / 2, xy[1] - th / 2 - box[1]), text, font=fnt, fill=fill)


def ink_poly(draw, pts, fill):
    draw.polygon(pts, fill=fill)


def portrait(draw: ImageDraw.ImageDraw, kind: str, ink, paper, metal) -> None:
    # Portrait window roughly x 16..152, y 40..170
    cx, cy = 84, 108

    def P(*pairs):
        return [(cx + x, cy + y) for x, y in pairs]

    if kind == "flame":
        ink_poly(draw, P((-18, 36), (-28, 8), (-8, 10), (-16, -18), (0, -40), (14, -14), (8, 8), (26, 6), (16, 36)), ink)
        draw.polygon(P((-6, 20), (0, -6), (8, 18)), fill=metal)
    elif kind == "ward":
        ink_poly(draw, P((0, -46), (40, -24), (34, 10), (0, 42), (-34, 10), (-40, -24)), ink)
        draw.polygon(P((0, -30), (22, -14), (18, 6), (0, 26), (-18, 6), (-22, -14)), fill=paper)
        draw.line(P((0, -18), (0, 14)), fill=ink, width=4)
        draw.line(P((-12, -2), (12, -2)), fill=ink, width=4)
    elif kind == "hood":
        ink_poly(draw, P((-34, 40), (-38, 6), (-26, -8), (-30, -36), (0, -48), (30, -36), (26, -8), (38, 6), (34, 40)), ink)
        draw.ellipse((cx - 10, cy - 18, cx - 2, cy - 8), fill=paper)
        draw.ellipse((cx + 4, cy - 18, cx + 12, cy - 8), fill=paper)
        draw.polygon(P((-6, 4), (0, 16), (6, 4)), fill=paper)
    elif kind == "gust":
        for i, rad in enumerate((18, 30, 42)):
            box = (cx - rad, cy - rad + 6, cx + rad, cy + rad + 6)
            draw.arc(box, start=200, end=430, fill=ink, width=6 - i)
        draw.polygon(P((8, -36), (22, -28), (10, -18)), fill=ink)
    elif kind == "helm":
        ink_poly(draw, P((-32, 38), (-36, 4), (-22, -6), (-28, -28), (-8, -44), (18, -36), (30, -16), (24, 4), (34, 38)), ink)
        draw.rectangle((cx - 18, cy - 8, cx + 20, cy + 2), fill=paper)
        draw.polygon(P((18, -16), (34, -6), (16, 0)), fill=metal)
    elif kind == "crown":
        ink_poly(draw, P((-40, 8), (-40, -8), (-28, -36), (-14, -8), (0, -44), (14, -8), (28, -36), (40, -8), (40, 8)), ink)
        draw.rectangle((cx - 40, cy + 8, cx + 40, cy + 22), fill=ink)
        for dx in (-28, 0, 28):
            draw.ellipse((cx + dx - 4, cy - 8, cx + dx + 4, cy), fill=metal)
        ink_poly(draw, P((-36, 36), (-28, 24), (28, 24), (36, 36)), ink)
    elif kind == "coins":
        for i, (dx, dy) in enumerate(((-16, 8), (10, 14), (-4, -16))):
            r = 22 - i * 2
            draw.ellipse((cx + dx - r, cy + dy - r // 2, cx + dx + r, cy + dy + r // 2), fill=ink)
            draw.ellipse((cx + dx - r + 5, cy + dy - r // 2 + 4, cx + dx + r - 5, cy + dy + r // 2 - 4), fill=metal)
    elif kind == "knight":
        ink_poly(draw, P((-10, 40), (-18, 8), (-8, -6), (6, -8), (4, -28), (22, -36), (30, -16), (16, 0), (28, 16), (18, 40)), ink)
        draw.polygon(P((6, -8), (22, -6), (12, 8)), fill=paper)
        draw.line(P((-34, 16), (2, -2)), fill=ink, width=5)
    elif kind == "skull":
        draw.ellipse((cx - 28, cy - 40, cx + 28, cy + 16), fill=ink)
        draw.rectangle((cx - 16, cy + 8, cx + 16, cy + 36), fill=ink)
        draw.ellipse((cx - 16, cy - 18, cx - 2, cy), fill=paper)
        draw.ellipse((cx + 2, cy - 18, cx + 16, cy), fill=paper)
        draw.polygon(P((-5, 4), (0, 16), (5, 4)), fill=paper)
        for dx in (-8, 0, 8):
            draw.rectangle((cx + dx - 3, cy + 18, cx + dx + 3, cy + 30), fill=paper)
    elif kind == "tomb":
        ink_poly(draw, P((-34, 40), (-34, -8), (-22, -36), (22, -36), (34, -8), (34, 40)), ink)
        draw.rectangle((cx - 16, cy - 8, cx + 16, cy + 22), fill=paper)
        draw.line(P((0, -4), (0, 16)), fill=ink, width=3)
        draw.line(P((-8, 6), (8, 6)), fill=ink, width=3)
    elif kind == "mist":
        draw.ellipse((cx - 36, cy - 10, cx + 10, cy + 28), fill=ink)
        draw.ellipse((cx - 8, cy - 28, cx + 40, cy + 16), fill=ink)
        draw.ellipse((cx - 20, cy + 6, cx + 24, cy + 36), fill=ink)
        draw.ellipse((cx - 6, cy - 16, cx + 6, cy - 4), fill=paper)
        draw.ellipse((cx + 12, cy - 8, cx + 22, cy + 2), fill=paper)
    elif kind == "ash":
        ink_poly(draw, P((-38, 30), (-10, 8), (0, 34), (12, 6), (40, 28), (18, 36), (-16, 38)), ink)
        for dx, dy, r in ((-18, -8, 5), (0, -22, 4), (16, -6, 6), (6, -36, 3), (-8, -30, 3)):
            draw.ellipse((cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r), fill=ink)
    elif kind == "wolf":
        ink_poly(draw, P((-40, 10), (-34, -28), (-16, -8), (-6, -40), (8, -16), (22, -36), (30, -6), (40, 16), (16, 28), (6, 16), (-8, 30), (-28, 18)), ink)
        draw.polygon(P((-22, -6), (-14, 2), (-26, 6)), fill=paper)
        draw.polygon(P((14, -2), (24, 4), (12, 8)), fill=paper)
        draw.polygon(P((-4, 10), (4, 10), (0, 20)), fill=paper)
    elif kind == "bear":
        draw.ellipse((cx - 34, cy - 24, cx + 34, cy + 36), fill=ink)
        draw.ellipse((cx - 40, cy - 42, cx - 12, cy - 10), fill=ink)
        draw.ellipse((cx + 12, cy - 42, cx + 40, cy - 10), fill=ink)
        draw.ellipse((cx - 16, cy - 6, cx - 4, cy + 8), fill=paper)
        draw.ellipse((cx + 4, cy - 6, cx + 16, cy + 8), fill=paper)
        draw.ellipse((cx - 8, cy + 10, cx + 8, cy + 22), fill=paper)
    elif kind == "owl":
        ink_poly(draw, P((-32, 36), (-36, -8), (-16, -40), (0, -18), (16, -40), (36, -8), (32, 36)), ink)
        draw.ellipse((cx - 20, cy - 16, cx - 2, cy + 6), fill=paper)
        draw.ellipse((cx + 2, cy - 16, cx + 20, cy + 6), fill=paper)
        draw.ellipse((cx - 14, cy - 10, cx - 6, cy - 2), fill=ink)
        draw.ellipse((cx + 6, cy - 10, cx + 14, cy - 2), fill=ink)
        draw.polygon(P((-5, 8), (5, 8), (0, 16)), fill=metal)
    elif kind == "stag":
        ink_poly(draw, P((-8, 36), (-16, 4), (-6, -8), (8, -6), (18, 10), (14, 36)), ink)
        draw.polygon(P((-6, -8), (2, -16), (-2, -28), (-14, -18)), fill=ink)
        # antlers
        draw.line((cx - 4, cy - 24, cx - 28, cy - 48), fill=ink, width=3)
        draw.line((cx - 18, cy - 36, cx - 30, cy - 30), fill=ink, width=3)
        draw.line((cx - 16, cy - 40, cx - 8, cy - 50), fill=ink, width=3)
        draw.line((cx + 2, cy - 20, cx + 26, cy - 46), fill=ink, width=3)
        draw.line((cx + 16, cy - 34, cx + 30, cy - 28), fill=ink, width=3)
        draw.ellipse((cx - 2, cy - 4, cx + 6, cy + 4), fill=paper)


SIGILS = {
    "mages": ("spark", "ring"),
    "kings": ("crown", "bar"),
    "dead": ("bone", "ring"),
    "beasts": ("leaf", "spark"),
}


def draw_sigil(draw, kind, box, fill):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if kind == "spark":
        draw.line((cx, y0 + 2, cx, y1 - 2), fill=fill, width=2)
        draw.line((x0 + 2, cy, x1 - 2, cy), fill=fill, width=2)
        draw.line((x0 + 4, y0 + 4, x1 - 4, y1 - 4), fill=fill, width=2)
        draw.line((x0 + 4, y1 - 4, x1 - 4, y0 + 4), fill=fill, width=2)
    elif kind == "ring":
        draw.ellipse((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=fill, width=2)
        draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=fill)
    elif kind == "crown":
        draw.polygon([(x0 + 2, y1 - 4), (x0 + 2, cy), (x0 + 8, cy + 4), (cx, y0 + 2), (x1 - 8, cy + 4), (x1 - 2, cy), (x1 - 2, y1 - 4)], fill=fill)
    elif kind == "bar":
        draw.rectangle((x0 + 3, cy - 2, x1 - 3, cy + 2), fill=fill)
        draw.rectangle((cx - 2, y0 + 3, cx + 2, y1 - 3), fill=fill)
    elif kind == "bone":
        draw.line((x0 + 4, y1 - 4, x1 - 4, y0 + 4), fill=fill, width=3)
        draw.ellipse((x0 + 2, y0 + 2, x0 + 8, y0 + 8), fill=fill)
        draw.ellipse((x1 - 8, y1 - 8, x1 - 2, y1 - 2), fill=fill)
    elif kind == "leaf":
        draw.polygon([(cx, y0 + 2), (x1 - 3, cy), (cx, y1 - 2), (x0 + 3, cy)], fill=fill)
        draw.line((cx, y0 + 4, cx, y1 - 4), fill=(0, 0, 0, 0), width=1)


def build_card(deck_id: str, name: str, cost: int, atk: int, hp: int, kind: str, index: int) -> Image.Image:
    deck = DECKS[deck_id]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    paper_fill(img, deck, seed=index * 17 + ord(deck_id[0]))
    # repaint border area before frame so paper noise stays inside
    draw = ImageDraw.Draw(img)
    draw_frame(img, deck)
    draw = ImageDraw.Draw(img)
    # name plaque
    draw.rounded_rectangle((16, 14, 118, 36), radius=4, fill=deck["plaque"])
    text_center(draw, (67, 25), name, font(15), deck["name"])
    # cost badge, top right
    draw.ellipse((124, 10, 156, 42), fill=deck["ink"])
    draw.ellipse((128, 14, 152, 38), fill=deck["metal"])
    text_center(draw, (140, 26), str(cost), font(16), deck["ink"])
    # portrait plate
    draw.rounded_rectangle((16, 42, 152, 176), radius=4, fill=tuple(max(0, c - 18) for c in deck["paper"]))
    portrait(draw, kind, deck["ink"], deck["paper"], deck["metal"])
    # stat plaques
    draw.rounded_rectangle((14, 184, 52, 222), radius=5, fill=deck["plaque"])
    draw.rounded_rectangle((116, 184, 154, 222), radius=5, fill=deck["plaque"])
    text_center(draw, (33, 203), str(atk), font(22), deck["name"])
    text_center(draw, (135, 203), str(hp), font(22), deck["name"])
    # sigils
    a, b = SIGILS[deck_id]
    draw.ellipse((62, 188, 86, 212), outline=deck["ink"], width=2)
    draw.ellipse((90, 188, 114, 212), outline=deck["ink"], width=2)
    draw_sigil(draw, a, (64, 190, 84, 210), deck["ink"])
    draw_sigil(draw, b, (92, 190, 112, 210), deck["metal"] if deck_id != "dead" else deck["name"])
    return img


def card_back() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = img.load()
    rnd = random.Random(3)
    for y in range(H):
        for x in range(W):
            n = rnd.randint(-6, 6)
            px[x, y] = (28 + n, 26 + n // 2, 36 + n, 255)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, W - 1, H - 1), radius=10, outline=(186, 154, 86), width=6)
    draw.rounded_rectangle((12, 12, W - 13, H - 13), radius=8, outline=(92, 78, 120), width=2)
    cx, cy = W // 2, H // 2 - 4
    draw.ellipse((cx - 36, cy - 36, cx + 36, cy + 36), outline=(214, 196, 150), width=3)
    draw.regular_polygon((cx, cy, 26), 4, rotation=0, outline=(214, 196, 150), width=3)
    draw.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=(120, 150, 186))
    # four pips — a seal, not an eye
    for ang in (45, 135, 225, 315):
        r = 52
        x = cx + int(math.cos(math.radians(ang)) * r)
        y = cy + int(math.sin(math.radians(ang)) * r)
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(186, 154, 86))
    draw.arc((28, 28, W - 29, H - 29), 20, 160, fill=(186, 154, 86), width=2)
    draw.arc((28, 28, W - 29, H - 29), 200, 340, fill=(186, 154, 86), width=2)
    return img


DIGITS = {
    "0": ["11111", "10001", "10001", "10001", "10001", "10001", "11111"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["11110", "00001", "00001", "01110", "10000", "10000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["10001", "10001", "10001", "11111", "00001", "00001", "00001"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["01111", "10000", "10000", "11111", "10001", "10001", "11111"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["11111", "10001", "10001", "11111", "10001", "10001", "11111"],
    "9": ["11111", "10001", "10001", "11111", "00001", "00001", "11110"],
}


def save_digits() -> None:
    scale = 4
    gw, gh = 5 * scale, 7 * scale
    sheet = Image.new("RGBA", (gw * 10, gh), (0, 0, 0, 0))
    px = sheet.load()
    for i, ch in enumerate("0123456789"):
        rows = DIGITS[ch]
        for y, row in enumerate(rows):
            for x, bit in enumerate(row):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            px[i * gw + x * scale + sx, y * scale + sy] = (255, 255, 255, 255)
    sheet.save(OUT / "digits.png")


def map_background() -> None:
    w, h = 640, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = img.load()
    rnd = random.Random(7)
    for y in range(h):
        t = y / max(1, h - 1)
        sky = (int(8 + 18 * t), int(10 + 22 * t), int(18 + 26 * t))
        for x in range(w):
            n = rnd.randint(-5, 3)
            # valley floor opens under the board, not a disc in the sky
            if y > 150:
                gt = (y - 150) / 210
                nx = abs(x - 320) / 320
                open_k = max(0.0, 1.0 - nx * 1.15) * min(1.0, gt * 1.4)
                ground = (36 + int(18 * (1 - nx)), 44 + int(14 * (1 - nx)), 34)
                c = tuple(int(sky[i] * (1 - open_k) + ground[i] * open_k) for i in range(3))
            else:
                c = sky
            px[x, y] = tuple(max(0, min(255, c[i] + n)) for i in range(3)) + (255,)
    draw = ImageDraw.Draw(img, "RGBA")
    draw.ellipse((478, 26, 522, 70), fill=(232, 224, 196, 255))
    draw.ellipse((488, 22, 528, 64), fill=(8, 12, 20, 255))
    draw.ellipse((480, 28, 518, 66), fill=(214, 206, 176, 255))
    for _ in range(80):
        x, y = rnd.randint(4, 635), rnd.randint(2, 140)
        if (x - 498) ** 2 + (y - 46) ** 2 < 36 * 36:
            continue
        v = rnd.choice((160, 200, 230))
        px[x, y] = (v, v, max(0, v - 20), 255)
    ridge = []
    for x in range(0, 641, 6):
        ridge.append((x, 132 + int(16 * math.sin(x * 0.02) + 8 * math.sin(x * 0.07 + 1.2))))
    ridge += [(640, 200), (0, 200)]
    draw.polygon(ridge, fill=(22, 32, 44, 255))

    def pine(x, base, height, shade):
        dark = (10 + shade, 22 + shade, 18 + shade, 255)
        mid = (22 + shade, 38 + shade, 30 + shade, 255)
        trunk_h = max(4, int(height * 0.1))
        draw.rectangle((x - 2, base - trunk_h, x + 2, base), fill=(42, 30, 22, 255))
        for i in range(4):
            top = base - trunk_h - int(height * (0.9 - i * 0.15))
            bot = top + int(height * 0.38)
            half = int(height * (0.26 - i * 0.03))
            draw.polygon([(x, top), (x - half, bot), (x + half, bot)], fill=dark if i % 2 == 0 else mid)

    for i in range(18):
        x = 4 + (i % 9) * 14
        pine(x, 368, 120 + (i * 29) % 110, (i % 4) * 3)
    for i in range(18):
        x = 636 - (i % 9) * 14
        pine(x, 368, 130 + (i * 23) % 100, (i % 4) * 3)
    # a few nearer shrubs inside the edge, still clear of the nodes
    for x, hgt in ((78, 70), (96, 48), (548, 64), (566, 46)):
        pine(x, 350, hgt, 6)
    fog = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fpx = fog.load()
    for y in range(h):
        for x in range(w):
            edge = min(x, w - 1 - x) / 90
            bottom = max(0.0, (y - 250) / 110)
            top = max(0.0, (50 - y) / 50)
            a = int(min(120, max(0, 1 - edge) * 110 + bottom * 80 + top * 40))
            if a:
                fpx[x, y] = (150, 168, 176, a)
    img = Image.alpha_composite(img, fog)
    vig = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vpx = vig.load()
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h / 2) / (h / 2)
            d = math.sqrt(dx * dx * 0.85 + dy * dy)
            a = int(max(0, min(160, (d - 0.62) * 320)))
            if a:
                vpx[x, y] = (4, 6, 10, a)
    img = Image.alpha_composite(img, vig)
    img.save(OUT / "map_bg.png")


def fog_blob() -> None:
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    for y in range(s):
        for x in range(s):
            d = math.sqrt((x - s / 2) ** 2 + (y - s / 2) ** 2) / (s / 2)
            a = int(max(0, 1 - d) ** 1.6 * 170)
            px[x, y] = (186, 198, 204, a)
    img.save(OUT / "fog.png")


def flame() -> None:
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        t = y / h
        half = (1 - t) * 10 + 2
        for x in range(w):
            d = abs(x - w / 2) / half
            if d > 1:
                continue
            hot = (1 - d) * (1 - t * 0.3)
            if t < 0.45:
                col = (255, 236, 170)
            elif t < 0.75:
                col = (255, 150, 48)
            else:
                col = (180, 40, 16)
            px[x, y] = col + (int(hot * 230),)
    img.save(OUT / "flame.png")


def slot_mark() -> None:
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = cy = s // 2
    draw.regular_polygon((cx, cy, 46), 4, rotation=0, outline=(255, 214, 150, 255), width=6)
    draw.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=(255, 214, 150, 220), width=3)
    img.save(OUT / "slot_mark.png")


def shard() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(16, 2), (28, 16), (16, 30), (6, 14)], fill=(255, 186, 90, 255))
    draw.polygon([(16, 6), (22, 16), (16, 18), (12, 14)], fill=(255, 236, 200, 255))
    img.save(OUT / "shard.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "cards").mkdir(exist_ok=True)
    meta = []
    sheet = Image.new("RGBA", (W * 4 + 30, H * 4 + 40), (20, 16, 14, 255))
    for i, (deck, name, cost, atk, hp, kind) in enumerate(CARDS):
        img = build_card(deck, name, cost, atk, hp, kind, i)
        fn = f"{deck}_{i % 4}.png"
        img.save(OUT / "cards" / fn)
        meta.append({
            "id": f"{deck}_{i % 4}",
            "deck": deck,
            "name": name,
            "cost": cost,
            "atk": atk,
            "hp": hp,
            "file": f"res://assets/generated/cards/{fn}",
        })
        sheet.paste(img, (10 + (i % 4) * (W + 6), 10 + (i // 4) * (H + 8)))
    card_back().save(OUT / "card_back.png")
    save_digits()
    map_background()
    fog_blob()
    flame()
    slot_mark()
    shard()
    (ROOT / "data" / "cards.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    sheet.save("/tmp/cards_preview.png")
    print("wrote", len(meta), "cards")


if __name__ == "__main__":
    main()
