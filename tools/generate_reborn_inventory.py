#!/usr/bin/env python3
"""Complete the REBORN visual inventory with high-resolution compatibility assets."""

import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets_reborn"


def save_scaled(src: Path, dst: Path, box: tuple[int,int]) -> None:
    im=Image.open(src).convert("RGBA")
    im.thumbnail(box,Image.Resampling.LANCZOS)
    canvas=Image.new("RGBA",box)
    canvas.alpha_composite(im,((box[0]-im.width)//2,(box[1]-im.height)//2))
    canvas=ImageEnhance.Contrast(canvas).enhance(1.05).filter(ImageFilter.UnsharpMask(1.2,110,2))
    dst.parent.mkdir(parents=True,exist_ok=True); canvas.save(dst,optimize=True)


def ships() -> None:
    folder=OUT/"astronavi"; folder.mkdir(parents=True,exist_ok=True)
    for stem in [*(f"nave_{i}" for i in range(33,41)),"nave_imperiale","nave_redjac"]:
        for suffix in ("","_r"):
            src=ROOT/"assets"/"pedine"/f"{stem}{suffix}.jpg"
            if src.exists(): save_scaled(src,folder/f"{stem}{suffix}.png",(1024,1024))


def card_sources() -> None:
    # Clean 2x working masters for every scanned card; generated frames stay separate.
    folder=OUT/"carte_sorgenti"; folder.mkdir(parents=True,exist_ok=True)
    for src in sorted((ROOT/"assets"/"carte"/"scansioni").glob("*.webp")):
        im=Image.open(src).convert("RGB")
        im=im.resize((im.width*2,im.height*2),Image.Resampling.LANCZOS)
        im=ImageEnhance.Contrast(im).enhance(1.04).filter(ImageFilter.UnsharpMask(1.0,90,2))
        im.save(folder/f"{src.stem}.jpg",quality=91,optimize=True)


def interface() -> None:
    folder=OUT/"interfaccia"; folder.mkdir(parents=True,exist_ok=True)
    rng=random.Random(1979)
    im=Image.new("RGB",(1920,1080),(3,5,13)); d=ImageDraw.Draw(im)
    for _ in range(1100):
        x,y=rng.randrange(1920),rng.randrange(1080); b=rng.randrange(85,256); r=1 if rng.random()<.96 else 2
        d.ellipse((x-r,y-r,x+r,y+r),fill=(b,b,min(255,b+rng.randrange(0,40))))
    for cx,cy,col in ((330,270,(41,27,76)),(1500,700,(18,50,73)),(1100,210,(68,33,27))):
        glow=Image.new("RGBA",im.size); gd=ImageDraw.Draw(glow)
        gd.ellipse((cx-420,cy-260,cx+420,cy+260),fill=(*col,120))
        glow=glow.filter(ImageFilter.GaussianBlur(130)); im=Image.alpha_composite(im.convert("RGBA"),glow).convert("RGB")
    im.save(folder/"sfondo_menu.png",optimize=True)


if __name__=="__main__":
    ships(); card_sources(); interface(); print("Compatibility inventory completed")
