#!/usr/bin/env python3
"""Replace text-only planetary-secret counters with symbolic illustrated tokens."""

import math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets_reborn"/"pedine"
KEYS=["segreto","segreto_archivi","segreto_benvenuti","segreto_casino","segreto_clonazione","segreto_deltronics","segreto_droga","segreto_gemme","segreto_impero","segreto_industria","segreto_iper","segreto_ipoc","segreto_morto","segreto_mutanti","segreto_r","segreto_schiavi","segreto_trappola","segreto_vivo"]


def token(key: str, index: int) -> Image.Image:
    s=512; rng=random.Random(8000+index)
    im=Image.new("RGBA",(s,s)); glow=Image.new("RGBA",im.size); gd=ImageDraw.Draw(glow)
    hue=[(43,180,203),(201,78,53),(148,84,196),(222,171,62),(67,190,118)][index%5]
    for r in range(230,30,-5): gd.ellipse((256-r,256-r,256+r,256+r),fill=(*hue,max(2,int(55*(1-r/230)**2))))
    glow=glow.filter(ImageFilter.GaussianBlur(10)); im.alpha_composite(glow); d=ImageDraw.Draw(im)
    d.ellipse((18,18,494,494),fill=(15,20,29,250),outline=(216,177,91,255),width=18)
    d.ellipse((42,42,470,470),outline=(*hue,230),width=8)
    # Starfield and etched circuit texture.
    for _ in range(80):
        x,y=rng.randint(70,442),rng.randint(70,442)
        if (x-256)**2+(y-256)**2<175**2: d.ellipse((x-1,y-1,x+1,y+1),fill=(180,200,220,rng.randint(40,130)))
    col=(236,219,170,255); accent=(*hue,255)
    if key=="segreto":
        d.ellipse((170,150,342,322),outline=col,width=16); d.arc((202,190,310,298),20,340,fill=accent,width=14); d.line((256,320,256,386),fill=col,width=18)
    elif "archivi" in key:
        for x in (150,220,290): d.rounded_rectangle((x,150,x+55,355),8,outline=col,width=10); d.line((x+10,190,x+45,190),fill=accent,width=8)
    elif "casino" in key:
        d.rounded_rectangle((145,145,367,367),30,outline=col,width=14)
        for x,y in ((195,195),(317,195),(256,256),(195,317),(317,317)): d.ellipse((x-14,y-14,x+14,y+14),fill=accent)
    elif "clonazione" in key or "mutanti" in key:
        pts=[]
        for y in range(135,380,8):
            x=256+int(math.sin(y/28)*75); pts.append((x,y))
        d.line(pts,fill=col,width=13); d.line([(512-x,y) for x,y in pts],fill=accent,width=13)
        for y in range(155,365,35): d.line((190,y,322,y),fill=(190,190,210,220),width=6)
    elif "deltronics" in key or "ipoc" in key:
        d.rounded_rectangle((160,160,352,352),22,outline=col,width=16); d.ellipse((210,210,302,302),outline=accent,width=16)
        for v in range(180,350,42): d.line((v,120,v,160),fill=col,width=9); d.line((v,352,v,392),fill=col,width=9)
    elif "droga" in key:
        d.rounded_rectangle((210,130,302,370),35,outline=col,width=14); d.rectangle((220,250,292,350),fill=(*hue,180)); d.line((225,180,287,180),fill=accent,width=10)
    elif "gemme" in key:
        d.polygon([(256,118),(370,220),(320,374),(192,374),(142,220)],outline=col,fill=(*hue,100)); d.line((142,220,370,220),fill=accent,width=10); d.line((256,118,192,374),fill=col,width=8); d.line((256,118,320,374),fill=col,width=8)
    elif "impero" in key:
        for a in range(0,360,30):
            x=256+int(math.cos(math.radians(a))*135); y=256+int(math.sin(math.radians(a))*135); d.line((256,256,x,y),fill=col,width=14)
        d.ellipse((188,188,324,324),fill=(20,20,25,255),outline=accent,width=15)
    elif "industria" in key:
        d.ellipse((145,145,367,367),outline=col,width=22); d.ellipse((220,220,292,292),outline=accent,width=18)
        for a in range(0,360,45):
            x=256+int(math.cos(math.radians(a))*130); y=256+int(math.sin(math.radians(a))*130); d.rectangle((x-18,y-18,x+18,y+18),fill=col)
    elif "iper" in key:
        for r in (45,85,125): d.ellipse((256-r,256-r,256+r,256+r),outline=accent,width=10)
        for a in range(0,360,45): d.line((256,256,256+math.cos(math.radians(a))*175,256+math.sin(math.radians(a))*175),fill=col,width=8)
    elif "morto" in key:
        d.ellipse((165,125,347,315),outline=col,width=15); d.ellipse((200,195,235,235),fill=accent); d.ellipse((277,195,312,235),fill=accent); d.polygon([(220,315),(292,315),(320,380),(192,380)],outline=col)
    elif "schiavi" in key:
        d.arc((110,150,280,330),290,70,fill=col,width=26); d.arc((232,180,402,360),110,250,fill=col,width=26); d.line((225,240,285,300),fill=accent,width=20)
    elif "trappola" in key:
        d.polygon([(256,115),(390,370),(122,370)],outline=col,width=18); d.line((256,190,256,300),fill=accent,width=22); d.ellipse((245,330,267,352),fill=accent)
    elif "vivo" in key or "benvenuti" in key:
        d.ellipse((130,175,382,337),outline=col,width=16); d.ellipse((205,205,307,307),fill=accent); d.ellipse((238,238,274,274),fill=(10,15,20,255))
    else:
        d.polygon([(256,110),(390,256),(256,402),(122,256)],outline=col,fill=(*hue,90)); d.ellipse((210,210,302,302),outline=accent,width=14)
    return im


def main() -> None:
    for i,key in enumerate(KEYS): token(key,i).save(OUT/f"{key}.png",optimize=True)
    print(f"Generated {len(KEYS)} symbolic secret tokens")


if __name__=="__main__": main()
