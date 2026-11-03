#!/usr/bin/env python3
"""Pedine Reborn delle unità militari, disegnate a vettori: stemma del tipo d'unità, colore della parte
e dell'ambiente, valori Ambiente-Spazio. Scrive le copie per il gioco in assets/reborn/pedine/ (WebP).

Uso: python3 tools/genera_unita_reborn.py   (lo chiama anche tools/prepara_reborn_gioco.py)
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(RADICE, "assets", "reborn", "pedine")
LATO = 512
FINALE = 176
TITOLO = os.path.join(RADICE, "assets/font/SairaCondensed-ExtraBold.ttf")
TESTO = os.path.join(RADICE, "assets/font/SairaCondensed-Bold.ttf")

ORO = (245, 189, 51)
ROSSO = (225, 77, 56)
AMBIENTI = {
    "urbano": ((64, 122, 235), "URBANO"),
    "selvaggio": ((77, 168, 77), "SELVAGGIO"),
    "sotterraneo": ((176, 74, 52), "SOTTERRANEO"),
    "liquido": ((60, 170, 200), "LIQUIDO"),
    "aereo": ((140, 190, 235), "AEREO"),
    "fuoco": ((240, 130, 40), "FUOCO"),
}


def font(f, n):
    return ImageFont.truetype(f, n)


def sfondo(c1, c2, bordo):
    im = Image.new("RGBA", (LATO, LATO), (0, 0, 0, 0))
    grad = Image.new("RGBA", (LATO, LATO))
    d = ImageDraw.Draw(grad)
    for y in range(LATO):
        t = y / (LATO - 1)
        d.line([(0, y), (LATO, y)], fill=tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)) + (255,))
    # vignetta e riflesso
    luce = Image.new("L", (LATO, LATO), 0)
    ImageDraw.Draw(luce).ellipse([-120, -260, LATO + 120, 260], fill=70)
    luce = luce.filter(ImageFilter.GaussianBlur(60))
    grad = Image.composite(Image.new("RGBA", (LATO, LATO), (255, 255, 255, 255)), grad, luce.point(lambda v: v // 3))
    maschera = Image.new("L", (LATO, LATO), 0)
    ImageDraw.Draw(maschera).rounded_rectangle([8, 8, LATO - 8, LATO - 8], radius=56, fill=255)
    im.paste(grad, (0, 0), maschera)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([8, 8, LATO - 8, LATO - 8], radius=56, outline=bordo + (255,), width=14)
    d.rounded_rectangle([30, 30, LATO - 30, LATO - 30], radius=40, outline=bordo + (110,), width=3)
    return im


def testo_centro(d, y, t, f, col, ombra=True):
    w = d.textlength(t, font=f)
    if ombra:
        d.text(((LATO - w) / 2 + 3, y + 4), t, font=f, fill=(0, 0, 0, 150))
    d.text(((LATO - w) / 2, y), t, font=f, fill=col)


def gallone(d, cx, cy, w, h, col, spessore=22):
    pts = [(cx - w, cy - h / 2), (cx, cy + h / 2), (cx + w, cy - h / 2)]
    d.line(pts, fill=col, width=spessore, joint="curve")


def stella(d, cx, cy, r, col):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=col)


def nave(d, cx, cy, s, col, grande=False):
    # sagoma di nave da guerra vista dall'alto
    pts = [(cx, cy - 1.0 * s), (cx + 0.32 * s, cy + 0.2 * s), (cx + 0.85 * s, cy + 0.55 * s), (cx + 0.3 * s, cy + 0.5 * s),
           (cx + 0.18 * s, cy + 0.8 * s), (cx - 0.18 * s, cy + 0.8 * s), (cx - 0.3 * s, cy + 0.5 * s), (cx - 0.85 * s, cy + 0.55 * s),
           (cx - 0.32 * s, cy + 0.2 * s)]
    d.polygon(pts, fill=col)
    d.line([(cx, cy - 0.6 * s), (cx, cy + 0.6 * s)], fill=(0, 0, 0, 90), width=6)
    if grande:
        d.ellipse([cx - 0.22 * s, cy - 0.05 * s, cx + 0.22 * s, cy + 0.39 * s], fill=(255, 90, 60, 255))


def scudo(d, cx, cy, s, col):
    pts = [(cx - s, cy - s * 0.8), (cx + s, cy - s * 0.8), (cx + s, cy), (cx, cy + s), (cx - s, cy)]
    d.polygon(pts, fill=col)


def mirino(d, cx, cy, r, col):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=16)
    d.ellipse([cx - r * 0.25, cy - r * 0.25, cx + r * 0.25, cy + r * 0.25], fill=col)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        d.line([(cx + dx * r * 0.55, cy + dy * r * 0.55), (cx + dx * r * 1.25, cy + dy * r * 1.25)], fill=col, width=16)


def simbolo_ambiente(d, tipo, cx, cy, r, col):
    if tipo == "urbano":
        for i, h in enumerate((0.9, 1.4, 1.1)):
            x = cx - r + i * r * 0.7
            d.rectangle([x, cy + r * 0.6 - r * h, x + r * 0.55, cy + r * 0.6], fill=col)
    elif tipo == "selvaggio":
        d.polygon([(cx - r, cy + r * 0.6), (cx - r * 0.3, cy - r * 0.7), (cx + r * 0.3, cy + r * 0.6)], fill=col)
        d.polygon([(cx - r * 0.1, cy + r * 0.6), (cx + r * 0.5, cy - r * 0.4), (cx + r, cy + r * 0.6)], fill=col)
    elif tipo == "sotterraneo":
        d.pieslice([cx - r, cy - r * 0.6, cx + r, cy + r * 1.4], 180, 360, fill=col)
        d.pieslice([cx - r * 0.45, cy - r * 0.05, cx + r * 0.45, cy + r * 0.85], 180, 360, fill=(0, 0, 0, 160))
    elif tipo == "liquido":
        d.ellipse([cx - r * 0.6, cy - r * 0.2, cx + r * 0.6, cy + r], fill=col)
        d.polygon([(cx - r * 0.55, cy + r * 0.15), (cx, cy - r * 0.9), (cx + r * 0.55, cy + r * 0.15)], fill=col)
    elif tipo == "aereo":
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=18)
        d.arc([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], 200, 340, fill=col, width=14)
    elif tipo == "fuoco":
        d.polygon([(cx, cy - r), (cx + r * 0.7, cy + r * 0.1), (cx + r * 0.45, cy + r * 0.8), (cx - r * 0.45, cy + r * 0.8), (cx - r * 0.7, cy + r * 0.1)], fill=col)
        d.polygon([(cx, cy - r * 0.2), (cx + r * 0.3, cy + r * 0.5), (cx - r * 0.3, cy + r * 0.5)], fill=(255, 230, 120, 255))


def imperiale(chiave, nome, f, s, disegno, retro=False):
    im = sfondo((44, 58, 96), (12, 16, 32), ORO)
    d = ImageDraw.Draw(im)
    if retro:
        # lato coperto: solo lo stemma imperiale, il valore resta nascosto
        cx, cy = LATO / 2, LATO / 2
        for i in range(16):
            a = i * math.pi / 8
            d.line([(cx + math.cos(a) * 60, cy + math.sin(a) * 60), (cx + math.cos(a) * 150, cy + math.sin(a) * 150)], fill=ORO + (255,), width=18)
        d.ellipse([cx - 80, cy - 80, cx + 80, cy + 80], fill=(20, 26, 48, 255), outline=ORO + (255,), width=14)
        stella(d, cx, cy, 52, ORO + (255,))
        return im
    testo_centro(d, 44, nome.upper(), font(TITOLO, 58 if len(nome) < 14 else 46), ORO + (255,))
    disegno(d)
    testo_centro(d, 285, "%d-%d" % (f, s), font(TITOLO, 140), (250, 246, 232, 255))
    return im


def ribelle(tipo, cat, f, s, elite, retro=False):
    col, nome = AMBIENTI[tipo]
    scuro = tuple(int(c * 0.35) for c in col)
    medio = tuple(int(c * 0.75) for c in col)
    im = sfondo(medio, scuro, ROSSO)
    d = ImageDraw.Draw(im)
    testo_centro(d, 44, nome + (" ÉLITE" if elite else ""), font(TITOLO, 54 if not elite else 46), (255, 236, 220, 255))
    bianco = (255, 250, 240, 255)
    simbolo_ambiente(d, tipo, LATO / 2 - 70, 215, 62, bianco)
    # gradi: 1-0 un punto, 2-1 un gallone, 2-3 due, 4-3 tre, élite una stella
    gx = LATO / 2 + 95
    if elite:
        stella(d, gx, 215, 66, ORO + (255,))
    elif cat == "r10":
        d.ellipse([gx - 26, 189, gx + 26, 241], fill=bianco)
    else:
        n = {"r21": 1, "r23": 2, "r43": 3}[cat]
        for i in range(n):
            gallone(d, gx, 175 + i * 40, 52, 40, bianco, 18)
    testo_centro(d, 285, "%d-%d" % (f, s), font(TITOLO, 140), (255, 250, 240, 255))
    if retro:
        im = Image.blend(im, Image.new("RGBA", im.size, (0, 0, 0, 255)), 0.35)
    return im


def main():
    U = json.load(open(os.path.join(RADICE, "data/regole_avanzate.json")))["unita"]
    os.makedirs(DEST, exist_ok=True)
    c = LATO / 2
    disegni = {
        "milizia": lambda d: scudo(d, c, 215, 70, ORO + (255,)),
        "pattuglia": lambda d: gallone(d, c, 215, 80, 60, ORO + (255,)),
        "linea": lambda d: [gallone(d, c, 185 + i * 50, 80, 55, ORO + (255,)) for i in range(2)],
        "veterano": lambda d: [gallone(d, c, 165 + i * 45, 80, 50, ORO + (255,)) for i in range(3)],
        "elite_esercito": lambda d: (stella(d, c, 212, 82, ORO + (255,)), scudo(d, c, 300, 0, ORO + (255,))),
        "elite_flotta": lambda d: (nave(d, c - 10, 215, 95, ORO + (255,)), stella(d, c + 120, 160, 34, (255, 255, 255, 255))),
        "suicida": lambda d: mirino(d, c, 215, 70, (255, 90, 60, 255)),
        "resolution": lambda d: nave(d, c, 215, 105, (200, 210, 230, 255), True),
        "peacemaker": lambda d: nave(d, c, 215, 105, (180, 190, 210, 255), True),
        "stabilizzatore": lambda d: (d.ellipse([c - 95, 120, c + 95, 310], fill=(170, 175, 195, 255), outline=(255, 90, 60, 255), width=10),
                                     d.ellipse([c - 30, 185, c + 30, 245], fill=(255, 90, 60, 255))),
    }
    n = 0
    for cat, u in U.items():
        if int(u["fz"]) == 1:
            nome = u["nome"].replace("Esercito d'élite", "Élite esercito").replace("Flotta d'élite", "Élite flotta").replace("Planet Stabilizer", "Stabilizzatore")
            for retro in (False, True):
                im = imperiale(u["ped"], nome, int(u["f"]), int(u["s"]), disegni[cat], retro)
                salva(im, u["ped"] + ("_r" if retro else ""))
                n += 1
        else:
            for tipo in AMBIENTI:
                ped = "elite" if cat == "r44" else str(u["ped"])
                for retro in (False, True):
                    im = ribelle(tipo, cat, int(u["f"]), int(u["s"]), cat == "r44", retro)
                    salva(im, "rib_%s_%s%s" % (tipo, ped, "_r" if retro else ""))
                    n += 1
    n += navi()
    print("pedine delle unità:", n)


def navi():
    """Pedine delle astronavi dei personaggi con le illustrazioni Reborn (retro = danneggiata)."""
    import glob
    poss = {int(c["nr"]): c for c in json.load(open(os.path.join(RADICE, "data/carte.json")))["possessi"]}
    n = 0
    for f in sorted(glob.glob(os.path.join(RADICE, "assets_reborn/astronavi/nave_*.png"))):
        nome_file = os.path.basename(f)[:-4]
        retro = nome_file.endswith("_r")
        chiave = nome_file[:-2] if retro else nome_file
        imperiale = chiave in ("nave_imperiale", "nave_redjac")
        if chiave == "nave_imperiale":
            nome = "Imperiale"
        elif chiave == "nave_redjac":
            nome = "Redjac"
        else:
            nome = str(poss.get(int(chiave.split("_")[1]), {}).get("nome_it", ""))
        im = sfondo((44, 58, 96), (12, 16, 32), ORO) if imperiale else sfondo((40, 70, 110), (10, 20, 40), (92, 200, 245))
        arte = Image.open(f).convert("RGBA")
        k = min(440 / arte.width, 300 / arte.height)
        arte = arte.resize((int(arte.width * k), int(arte.height * k)), Image.LANCZOS)
        im.alpha_composite(arte, (int((LATO - arte.width) / 2), int(250 - arte.height / 2)))
        d = ImageDraw.Draw(im)
        testo_centro(d, 400, nome.upper(), font(TITOLO, 56 if len(nome) < 14 else 44), (255, 240, 210, 255))
        if retro:
            testo_centro(d, 40, "DANNEGGIATA", font(TITOLO, 50), (255, 110, 80, 255))
        salva(im, chiave + ("_r" if retro else ""))
        n += 1
    return n


def salva(im, nome):
    im.resize((FINALE, FINALE), Image.LANCZOS).save(os.path.join(DEST, nome + ".webp"), "WEBP", quality=90, method=6)
    if os.environ.get("ANTEPRIMA"):
        os.makedirs("/tmp/unita", exist_ok=True)
        im.save("/tmp/unita/%s.png" % nome)


if __name__ == "__main__":
    main()
