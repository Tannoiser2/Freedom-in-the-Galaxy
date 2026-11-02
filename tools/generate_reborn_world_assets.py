#!/usr/bin/env python3
"""Build deterministic remastered planets, stars and legacy token inventory."""

import json, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
REBORN = ROOT / "assets_reborn"

PALETTES = {
    "urbano": ((56, 64, 76), (174, 137, 78)),
    "aereo": ((55, 104, 159), (222, 226, 212)),
    "liquido": ((13, 72, 121), (44, 176, 175)),
    "selvaggio": ((31, 91, 55), (143, 113, 60)),
    "deserto": ((127, 67, 35), (222, 174, 89)),
    "ghiaccio": ((94, 151, 181), (232, 242, 239)),
    "sotterraneo": ((55, 37, 43), (135, 91, 64)),
}


def layered_noise(w: int, h: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    layers = []
    for scale, alpha in ((8, 120), (20, 80), (55, 45), (130, 26)):
        raw = bytes(rng.randrange(256) for _ in range(scale * scale * 2))
        layer = Image.frombytes("L", (scale * 2, scale), raw).resize((w, h), Image.Resampling.BICUBIC)
        layers.append((layer, alpha))
    out = Image.new("L", (w, h), 110)
    for layer, alpha in layers: out = Image.blend(out, layer, alpha / 255)
    return out


def texture_for(planet: dict) -> Image.Image:
    w, h = 2048, 1024
    types = [a.get("tipo", "selvaggio") for a in planet.get("ambienti", [])] or ["selvaggio"]
    cols = [PALETTES.get(t, PALETTES["selvaggio"]) for t in types]
    low = tuple(sum(c[0][i] for c in cols)//len(cols) for i in range(3))
    high = tuple(sum(c[1][i] for c in cols)//len(cols) for i in range(3))
    n = layered_noise(w, h, int(planet["id"]))
    colorized = Image.merge("RGB", tuple(n.point(lambda v, a=low[i], b=high[i]: int(a+(b-a)*v/255)) for i in range(3)))
    if "ghiaccio" in types or (int(planet["id"]) % 5 == 0):
        ice = Image.new("L", (w,h))
        d=ImageDraw.Draw(ice)
        d.rectangle((0,0,w,150),fill=210); d.rectangle((0,h-150,w,h),fill=210)
        ice=ice.filter(ImageFilter.GaussianBlur(70))
        colorized=Image.composite(Image.new("RGB",(w,h),(232,239,238)),colorized,ice)
    return colorized.filter(ImageFilter.GaussianBlur(.45))


def planet_disk(texture: Image.Image, throne: bool) -> Image.Image:
    size = 512
    cx = cy = (size-1)/2
    r = 235 if throne else 220
    globe = texture.resize((r*2,r*2),Image.Resampling.LANCZOS).convert("RGBA")
    mask=Image.new("L",(r*2,r*2)); ImageDraw.Draw(mask).ellipse((0,0,r*2-1,r*2-1),fill=255)
    # Directional lighting: bright upper-left, deep terminator lower-right.
    light=Image.new("L",(r*2,r*2),30)
    ld=ImageDraw.Draw(light)
    for rad in range(r*2,r//5,-4):
        val=int(245*(1-rad/(r*2))**.42)
        ld.ellipse((-r//2-rad//2,-r//2-rad//2,-r//2+rad*3//2,-r//2+rad*3//2),fill=val)
    light=light.filter(ImageFilter.GaussianBlur(28))
    dark=Image.new("RGBA",globe.size,(0,0,0,255)); globe=Image.composite(globe,dark,light)
    globe.putalpha(mask)
    im=Image.new("RGBA",(size,size)); im.alpha_composite(globe,(int(cx-r),int(cy-r)))
    glow = Image.new("RGBA", (size,size)); gd=ImageDraw.Draw(glow)
    gd.ellipse((cx-r-4,cy-r-4,cx+r+4,cy+r+4), outline=(130,190,255,150), width=6)
    glow=glow.filter(ImageFilter.GaussianBlur(8)); glow.alpha_composite(im)
    return glow


def stars(data: dict) -> None:
    folder=REBORN/"stelle"; folder.mkdir(parents=True,exist_ok=True)
    colors=[(255,180,92),(255,223,157),(180,215,255),(255,118,74)]
    for star in data["stelle"]:
        sid = sum((i + 1) * ord(ch) for i, ch in enumerate(str(star["id"])))
        rng=random.Random(sid); color=colors[sid%len(colors)]
        im=Image.new("RGBA",(512,512)); d=ImageDraw.Draw(im)
        for rad in range(235,35,-5):
            a=int(2+65*(1-rad/235)**2); d.ellipse((256-rad,256-rad,256+rad,256+rad),fill=(*color,a))
        for _ in range(12):
            a=rng.random()*math.tau; length=rng.randint(150,235)
            d.line((256,256,256+math.cos(a)*length,256+math.sin(a)*length),fill=(*color,90),width=rng.randint(1,3))
        d.ellipse((172,172,340,340),fill=(*color,255))
        im=im.filter(ImageFilter.GaussianBlur(2.2)); im.save(folder/f"{star['id']}.png",optimize=True)


def legacy_tokens() -> None:
    out=REBORN/"pedine"; out.mkdir(parents=True,exist_ok=True)
    for src in sorted((ROOT/"assets"/"pedine").glob("*.jpg")):
        if src.stem.startswith("pg_"): continue
        dst=out/f"{src.stem}.png"
        im=Image.open(src).convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
        im=ImageEnhance.Contrast(im).enhance(1.08)
        im=ImageEnhance.Color(im).enhance(1.12)
        im=im.filter(ImageFilter.UnsharpMask(1.6,135,2))
        im.save(dst,optimize=True)


def main() -> None:
    data=json.loads((ROOT/"data"/"galassia.json").read_text())
    folder=REBORN/"pianeti"; folder.mkdir(parents=True,exist_ok=True)
    for p in data["pianeti"]:
        if (folder/f"{p['id']}.png").exists() and (folder/f"{p['id']}_disco.png").exists():
            continue
        tex=texture_for(p); tex.save(folder/f"{p['id']}.png",optimize=True)
        planet_disk(tex,p["nome"].lower()=="orlog").save(folder/f"{p['id']}_disco.png",optimize=True)
    stars(data); legacy_tokens()
    print(f"Generated {len(data['pianeti'])} planet textures and disks, {len(data['stelle'])} stars")


if __name__ == "__main__": main()
