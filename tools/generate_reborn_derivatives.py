#!/usr/bin/env python3
"""Derive portraits, game tokens and Meshy reference boards from approved figures."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
FIGURES = ROOT / "assets_reborn" / "figure_intere"
PORTRAITS = ROOT / "assets_reborn" / "ritratti"
TOKENS = ROOT / "assets_reborn" / "pedine"
MESHY = ROOT / "assets_reborn" / "meshy"


def fitted(image: Image.Image, size: tuple[int, int], margin: int = 0) -> Image.Image:
    bbox = image.getbbox() or (0, 0, image.width, image.height)
    subject = image.crop(bbox)
    limit = (size[0] - margin * 2, size[1] - margin * 2)
    subject.thumbnail(limit, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size)
    out.alpha_composite(subject, ((size[0] - subject.width) // 2, size[1] - margin - subject.height))
    return out


def radial_background(size: int, imperial: bool) -> Image.Image:
    inner = (64, 35, 30) if not imperial else (25, 40, 58)
    outer = (8, 7, 9)
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            dx, dy = (x - size * .55) / size, (y - size * .40) / size
            t = min(1.0, (dx * dx + dy * dy) ** .5 * 1.9)
            px[x, y] = tuple(int(inner[i] * (1-t) + outer[i] * t) for i in range(3))
    return im.convert("RGBA")


def portrait(figure: Image.Image, imperial: bool) -> Image.Image:
    bbox = figure.getbbox() or (0, 0, figure.width, figure.height)
    subject = figure.crop(bbox)
    # Upper body fills the frame; this remains derived from the full-body master.
    upper = subject.crop((0, 0, subject.width, max(1, int(subject.height * .62))))
    upper.thumbnail((720, 720), Image.Resampling.LANCZOS)
    bg = radial_background(768, imperial)
    shadow = Image.new("RGBA", bg.size)
    silhouette = Image.new("RGBA", upper.size, (0, 0, 0, 0))
    silhouette.putalpha(upper.getchannel("A").filter(ImageFilter.GaussianBlur(16)))
    shadow.alpha_composite(silhouette, ((768-upper.width)//2 + 10, 768-upper.height + 22))
    bg.alpha_composite(shadow)
    bg.alpha_composite(upper, ((768-upper.width)//2, 768-upper.height + 2))
    return bg


def token(figure: Image.Image, imperial: bool, reverse: bool) -> Image.Image:
    size = 512
    base = radial_background(size, imperial)
    draw = ImageDraw.Draw(base)
    edge = (187, 147, 66, 255) if not reverse else (188, 53, 44, 255)
    draw.ellipse((9, 9, size-10, size-10), outline=(16, 14, 13, 255), width=18)
    draw.ellipse((23, 23, size-24, size-24), outline=edge, width=12)
    draw.ellipse((39, 39, size-40, size-40), outline=(224, 205, 158, 180), width=3)
    art = fitted(figure, (420, 420), 10)
    if reverse:
        tint = Image.new("RGBA", art.size, (120, 10, 5, 55))
        tint.putalpha(art.getchannel("A").point(lambda a: min(a, 75)))
        art.alpha_composite(tint)
    base.alpha_composite(art, (46, 45))
    return base


def meshy_board(figure: Image.Image) -> Image.Image:
    board = Image.new("RGBA", (2048, 1024), (128, 128, 128, 255))
    front = fitted(figure, (620, 940), 18)
    side = front.resize((int(front.width * .45), front.height), Image.Resampling.LANCZOS)
    rear = front.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    board.alpha_composite(front, (35, 42))
    board.alpha_composite(side, (854, 42))
    board.alpha_composite(rear, (1393, 42))
    return board


def main() -> None:
    for folder in (PORTRAITS, TOKENS, MESHY):
        folder.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(FIGURES.glob("pg_*.png")):
        figure = Image.open(path).convert("RGBA")
        imperial = path.stem in {
            "pg_thysa_kymbo", "pg_barca", "pg_saytar", "pg_telmen", "pg_jon_kidu",
            "pg_gelba", "pg_dermond", "pg_redjac", "pg_jin_voles", "pg_vans_ka_tie_a",
            "pg_els_taroff", "pg_coreguya",
        }
        portrait(figure, imperial).save(PORTRAITS / path.name, optimize=True)
        token(figure, imperial, False).save(TOKENS / path.name, optimize=True)
        token(figure, imperial, True).save(TOKENS / f"{path.stem}_r.png", optimize=True)
        meshy_board(figure).save(MESHY / path.name, optimize=True)
        count += 1
    print(f"Generated derivatives for {count} figures")


if __name__ == "__main__":
    main()
