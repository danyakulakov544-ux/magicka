#!/usr/bin/env python3
"""Compose the journey map from Kenney Tiny Town tiles (CC0)."""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / "assets" / "kenney" / "tiny_town"
OUT = ROOT / "assets" / "generated"
W, H = 640, 360


def load_tile(index: int) -> Image.Image:
    return Image.open(TILES / f"tile_{index:04d}.png").convert("RGBA")


def grade(im: Image.Image, mul: tuple) -> Image.Image:
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                max(0, min(255, int(r * mul[0]))),
                max(0, min(255, int(g * mul[1]))),
                max(0, min(255, int(b * mul[2]))),
                a,
            )
    return im


def scaled(index: int, mul: tuple, scale: int = 2) -> Image.Image:
    im = grade(load_tile(index), mul)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def stack(rows: list, mul: tuple, scale: int = 2) -> Image.Image:
    tiles = [[scaled(i, mul, scale) if i is not None else None for i in row] for row in rows]
    tw = tiles[0][0].width
    th = tiles[0][0].height
    img = Image.new("RGBA", (tw * len(rows[0]), th * len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(tiles):
        for x, tile in enumerate(row):
            if tile is not None:
                img.alpha_composite(tile, (x * tw, y * th))
    return img


def campfire() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line((6, 26, 26, 18), fill=(92, 58, 36, 255), width=3)
    d.line((8, 18, 26, 26), fill=(68, 42, 28, 255), width=3)
    d.polygon([(16, 4), (24, 22), (8, 22)], fill=(210, 96, 36, 255))
    d.polygon([(16, 10), (21, 20), (11, 20)], fill=(255, 196, 96, 255))
    d.polygon([(16, 14), (18, 20), (14, 20)], fill=(255, 236, 190, 255))
    return img


def hero(shirt: tuple) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline = (24, 18, 16, 255)
    skin = (222, 176, 132, 255)
    pants = (42, 36, 40, 255)
    d.rectangle((5, 1, 10, 6), fill=outline)
    d.rectangle((6, 2, 9, 5), fill=skin)
    d.point((7, 3), fill=(40, 28, 24, 255))
    d.point((9, 3), fill=(40, 28, 24, 255))
    d.rectangle((4, 6, 11, 12), fill=outline)
    d.rectangle((5, 7, 10, 11), fill=shirt + (255,))
    d.rectangle((5, 12, 7, 15), fill=pants)
    d.rectangle((9, 12, 11, 15), fill=pants)
    return img.resize((32, 32), Image.NEAREST)


def curve(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    bow = 10.0 if int(abs(a[0] + b[1])) % 2 == 0 else -10.0
    if length < 80:
        bow *= 0.45
    c = ((a[0] + b[0]) / 2 + nx * bow, (a[1] + b[1]) / 2 + ny * bow)
    pts = []
    for i in range(14):
        t = i / 13.0
        u = 1.0 - t
        pts.append((
            int(round(a[0] * u * u + c[0] * 2 * u * t + b[0] * t * t)),
            int(round(a[1] * u * u + c[1] * 2 * u * t + b[1] * t * t)),
        ))
    return pts


def paint_path(draw: ImageDraw.ImageDraw, pts, color, width: int) -> None:
    for i in range(len(pts) - 1):
        draw.line((pts[i], pts[i + 1]), fill=color, width=width)
    r = width // 2
    for p in pts:
        draw.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=color)


def paste_foot(canvas: Image.Image, im: Image.Image, foot) -> None:
    canvas.alpha_composite(im, (int(foot[0] - im.width / 2), int(foot[1] - im.height)))


def build() -> None:
    nodes = json.loads((ROOT / "data" / "map.json").read_text())["nodes"]
    by_id = {n["id"]: (n["x"], n["y"]) for n in nodes}
    rnd = random.Random(4)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = img.load()
    for y in range(H):
        for x in range(W):
            n = rnd.randint(-6, 4)
            t = y / H
            sky = (12 + int(10 * t), 14 + int(8 * t), 18 + int(6 * t))
            ground = (28, 32, 26)
            k = 0.0
            if y > 70:
                k = min(1.0, (y - 70) / 80) * (1.0 - min(1.0, abs(x - 320) / 340))
            c = tuple(int(sky[i] * (1 - k) + ground[i] * k) + n for i in range(3))
            px[x, y] = tuple(max(0, min(255, c[i])) for i in range(3)) + (255,)

    draw = ImageDraw.Draw(img, "RGBA")
    # moon, small and dim
    draw.ellipse((500, 28, 534, 62), fill=(186, 176, 150, 255))
    draw.ellipse((508, 24, 540, 56), fill=(12, 14, 18, 255))
    draw.ellipse((502, 30, 530, 58), fill=(168, 158, 136, 255))

    seen = set()
    for n in nodes:
        for link in n["links"]:
            key = tuple(sorted((n["id"], link)))
            if key in seen:
                continue
            seen.add(key)
            pts = curve((n["x"], n["y"]), by_id[link])
            paint_path(draw, pts, (36, 28, 22, 255), 14)
            paint_path(draw, pts, (78, 58, 40, 255), 8)

    tree_ids = [4, 5, 16, 17, 28]
    tree_mul = (0.34, 0.42, 0.34)
    forbid = [(n["x"], n["y"]) for n in nodes]
    for i in range(70):
        if i < 40:
            x = rnd.randint(0, 100) if i % 2 == 0 else rnd.randint(540, W)
            y = rnd.randint(40, H - 8)
        else:
            x = rnd.randint(40, W - 40)
            y = rnd.randint(20, 110)
        if any((x - fx) ** 2 + (y - fy) ** 2 < 46 ** 2 for fx, fy in forbid):
            continue
        sc = 3 if i % 5 == 0 else 2
        tile = scaled(tree_ids[i % len(tree_ids)], tree_mul, sc)
        paste_foot(img, tile, (x, y))

    # edge shade
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sp = shade.load()
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            d = math.sqrt(dx * dx * 0.7 + dy * dy * 1.1)
            a = int(max(0, min(150, (d - 0.55) * 260)))
            if a:
                sp[x, y] = (4, 6, 8, a)
    img = Image.alpha_composite(img, shade)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "map").mkdir(exist_ok=True)
    img.save(OUT / "map_bg.png")

    wood = (0.78, 0.7, 0.58)
    objects = {
        "tavern": _cabin(wood),
        "shop": _shop(wood),
        "chest": scaled(118, (0.9, 0.78, 0.6), 2),
        "event": scaled(105, (0.7, 0.75, 0.8), 2),
        "rest": campfire(),
        "start": campfire(),
        "battle": scaled(119, (0.85, 0.55, 0.45), 2),
        "elite": scaled(124, (0.7, 0.4, 0.38), 3),
        "boss": _cabin((0.45, 0.4, 0.38)),
    }
    # warm the tavern door
    door = objects["tavern"]
    d = ImageDraw.Draw(door)
    # door sits in the middle column of a 3-wide cabin, lower tile
    d.rectangle((34, 40, 46, 62), fill=(255, 150, 48, 255))
    d.rectangle((38, 46, 42, 56), fill=(255, 214, 140, 255))
    objects["tavern"] = door

    for name, im in objects.items():
        im.save(OUT / "map" / f"obj_{name}.png")
    for i, color in enumerate(((60, 110, 190), (190, 64, 48), (64, 150, 78), (210, 170, 64))):
        hero(color).save(OUT / "map" / f"hero_{i}.png")
    print("world ready", {k: v.size for k, v in objects.items()})


def _cabin(mul) -> Image.Image:
    return stack([[63, 65, 67], [72, 74, 75]], mul, 2)


def _shop(mul) -> Image.Image:
    return stack([[83], [118]], mul, 2)


if __name__ == "__main__":
    build()
