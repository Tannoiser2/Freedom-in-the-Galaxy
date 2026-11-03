#!/usr/bin/env python3
"""Prepara le immagini Reborn per il gioco: copie ridotte e compresse (WebP) in assets/reborn/.

Gli originali ad alta risoluzione restano in assets_reborn/ e reborn/ (esclusi da Godot con .gdignore).
Uso: python3 tools/prepara_reborn_gioco.py
"""
import glob
import os
from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(RADICE, "assets", "reborn")


def salva(src, dst, lato_max=None, dimensioni=None, qualita=86):
    im = Image.open(src)
    im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
    if dimensioni:
        im = im.resize(dimensioni, Image.LANCZOS)
    elif lato_max and max(im.size) > lato_max:
        k = lato_max / max(im.size)
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, "WEBP", quality=qualita, method=6)


def main():
    n = 0
    for f in glob.glob(os.path.join(RADICE, "assets_reborn/pedine/*.png")):
        salva(f, os.path.join(DEST, "pedine", os.path.basename(f)[:-4] + ".webp"), lato_max=176)
        n += 1
    for f in glob.glob(os.path.join(RADICE, "reborn/carte/*.png")):
        nome = os.path.basename(f)[:-4]
        if nome in ("esempi-carte", "prova-limiti"):
            continue
        salva(f, os.path.join(DEST, "carte", nome + ".webp"), lato_max=860, qualita=88)
        n += 1
    for f in glob.glob(os.path.join(RADICE, "reborn/carte/mazzi/*.png")):
        salva(f, os.path.join(DEST, "carte", os.path.basename(f)[:-4] + ".webp"), lato_max=860, qualita=88)
        n += 1
    for f in glob.glob(os.path.join(RADICE, "assets_reborn/pianeti/*.png")):
        b = os.path.basename(f)[:-4]
        if b.isdigit():
            salva(f, os.path.join(DEST, "pianeti", b + ".webp"), dimensioni=(1024, 512), qualita=84)
        elif b.endswith("_disco"):
            salva(f, os.path.join(DEST, "pianeti", b + ".webp"), lato_max=224)
        elif b.endswith("_normal"):
            salva(f, os.path.join(DEST, "pianeti", b + ".webp"), dimensioni=(1024, 512), qualita=88)
        elif b.endswith("_emission"):
            salva(f, os.path.join(DEST, "pianeti", b + ".webp"), dimensioni=(512, 256), qualita=80)
        else:
            continue
        n += 1
    for f in glob.glob(os.path.join(RADICE, "assets_reborn/figure_intere/*.png")):
        salva(f, os.path.join(DEST, "figure", os.path.basename(f)[:-4] + ".webp"), lato_max=420)
        n += 1
    for f in glob.glob(os.path.join(RADICE, "assets_reborn/astronavi/*.png")):
        salva(f, os.path.join(DEST, "astronavi", os.path.basename(f)[:-4] + ".webp"), lato_max=320)
        n += 1
    for f in glob.glob(os.path.join(RADICE, "reborn/atlante/environs/*.jpg")):
        salva(f, os.path.join(DEST, "ambienti", os.path.basename(f)[:-4] + ".webp"), lato_max=512, qualita=82)
        n += 1
    print("immagini preparate:", n)
    # le unità militari si disegnano a vettori (sostituiscono le copie delle pedine originali)
    import subprocess, sys
    subprocess.run([sys.executable, os.path.join(RADICE, "tools", "genera_unita_reborn.py")], check=True)
    subprocess.run([sys.executable, os.path.join(RADICE, "tools", "package_troop_game.py")], check=True)


if __name__ == "__main__":
    main()
