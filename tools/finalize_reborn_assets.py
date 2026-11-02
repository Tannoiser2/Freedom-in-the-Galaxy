#!/usr/bin/env python3
"""Create damaged ship variants and visual QA contact sheets."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"assets_reborn"
PREV=ROOT/"reborn"/"anteprime"


def ship_damage() -> None:
    for src in (ASSETS/"astronavi").glob("nave_*.png"):
        if src.stem.endswith("_r"): continue
        im=Image.open(src).convert("RGBA")
        overlay=Image.new("RGBA",im.size); d=ImageDraw.Draw(overlay)
        for i in range(7):
            x=int(im.width*(.38+i*.055)); y=int(im.height*(.37+(i%2)*.05))
            d.ellipse((x-18,y-18,x+18,y+18),fill=(20,8,2,180),outline=(245,91,19,220),width=5)
        smoke=Image.new("RGBA",im.size); sd=ImageDraw.Draw(smoke)
        for i in range(9):
            x=int(im.width*(.42+i*.025)); y=int(im.height*(.34-i*.035)); r=30+i*7
            sd.ellipse((x-r,y-r,x+r,y+r),fill=(35,32,30,max(18,95-i*8)))
        smoke=smoke.filter(ImageFilter.GaussianBlur(22))
        im.alpha_composite(smoke); im.alpha_composite(overlay)
        im.save(src.with_name(src.stem+"_r.png"),optimize=True)


def sheet(paths, dst: Path, columns: int, cell=(260,300), title="") -> None:
    paths=list(paths); rows=(len(paths)+columns-1)//columns
    canvas=Image.new("RGB",(columns*cell[0],rows*cell[1]+70),(11,12,17)); d=ImageDraw.Draw(canvas)
    d.text((24,18),title,fill=(235,215,170))
    for i,p in enumerate(paths):
        im=Image.open(p).convert("RGBA"); im.thumbnail((cell[0]-24,cell[1]-50),Image.Resampling.LANCZOS)
        x=(i%columns)*cell[0]+(cell[0]-im.width)//2; y=70+(i//columns)*cell[1]+6
        canvas.paste(im,(x,y),im)
        label=p.stem.replace("pg_","").replace("_disco","").replace("_"," ")[:28]
        d.text(((i%columns)*cell[0]+12,70+(i//columns)*cell[1]+cell[1]-32),label,fill=(220,220,214))
    dst.parent.mkdir(parents=True,exist_ok=True); canvas.save(dst,optimize=True)


def main() -> None:
    ship_damage()
    sheet(sorted((ASSETS/"figure_intere").glob("pg_*.png")),PREV/"inventario_personaggi.png",8,(240,300),"32 PERSONAGGI — FIGURE INTERE")
    sheet(sorted((ASSETS/"pianeti").glob("*_disco.png")),PREV/"inventario_pianeti.png",9,(190,220),"51 PIANETI — DISCHI ILLUMINATI")
    sheet(sorted(p for p in (ASSETS/"astronavi").glob("nave_*.png") if not p.stem.endswith("_r")),PREV/"inventario_astronavi.png",5,(330,330),"ASTRONAVI — MASTER")
    secrets=sorted((ASSETS/"pedine").glob("segreto*.png"))
    if secrets: sheet(secrets,PREV/"inventario_segreti.png",6,(240,270),"SEGRETI PLANETARI")
    print("Damaged variants and QA sheets completed")


if __name__=="__main__": main()
