#!/usr/bin/env python3
"""Calcola la posizione di tutte le caselle della mappa originale della galassia (assets/mappa/galassia.jpg):
per ogni pianeta la casella d'Orbita, le cinque caselle della traccia politica e le caselle degli ambienti;
per ogni sistema le caselle Deriva e Deriva 2. Scrive data/mappa_caselle.json (coordinate in pixel della mappa).

Ogni sistema della mappa segue uno di due schemi ad anelli concentrici attorno alla stella (anelli a raggio
106/174/244 oppure 132/200 px); orbita e traccia politica occupano settori fissi dell'anello, mentre le caselle
degli ambienti, di larghezza variabile, si ricavano dalle linee divisorie gialle stampate sulla mappa.
Uso: python3 tools/estrai_caselle_mappa.py [--controllo immagine.png]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NA = 2880  # colonne angolari: 0 = in alto, verso orario

# confini (in colonne angolari) di orbita e traccia politica, per schema e anello
SETTORI = {
    ("A", 1): [4, 480, 710, 939, 1166, 1393, 1618],
    ("A", 2): [4, 280, 417, 557, 695, 831, 967],
    ("A", 3): [4, 197, 297, 395, 493, 591, 690],
    ("B", 1): [4, 380, 562, 744, 926, 1108, 1290],
    ("B", 2): [4, 245, 364, 483, 600, 719, 837],
}
ANELLI = {"A": [(106, 161), (174, 230), (244, 299)], "B": [(132, 186), (200, 255)]}
# caselle di Deriva: (raggio interno, raggio esterno, colonna iniziale, colonna finale)
DERIVA = {"A": (60, 98, 1880, 2250), "B": (70, 110, 1990, 2310)}
DERIVA2 = {("A", 1): (174, 230, 2420, 2820), ("A", 2): (244, 299, 1870, 2160), ("A", 3): (244, 299, 1870, 2160),
           ("B", 1): (200, 255, 2560, 2810), ("B", 2): (200, 255, 2560, 2810)}


def carica():
    g = json.load(open(os.path.join(RADICE, "data/galassia.json")))
    im = np.array(Image.open(os.path.join(RADICE, "assets/mappa/galassia.jpg")).convert("RGB")).astype(float)
    r, gg, b = im[..., 0], im[..., 1], im[..., 2]
    giallo = (r > 100) & (gg > 88) & (gg > 0.74 * r) & (r > b + 38)
    return g, giallo


def srotola(giallo, cx, cy, rmax):
    a = np.linspace(-np.pi / 2, 3 * np.pi / 2, NA, endpoint=False)
    rr = np.arange(rmax)
    X = (cx + rr[:, None] * np.cos(a)[None, :]).astype(int).clip(0, giallo.shape[1] - 1)
    Y = (cy + rr[:, None] * np.sin(a)[None, :]).astype(int).clip(0, giallo.shape[0] - 1)
    return giallo[Y, X]


def casella(cx, cy, rin, rout, c0, c1):
    """Centro, larghezza (arco), altezza e angolo della tangente di un settore d'anello."""
    c = (c0 + c1) / 2.0
    th = -math.pi / 2 + c / NA * 2 * math.pi
    rm = (rin + rout) / 2.0
    return {"x": round(cx + rm * math.cos(th), 1), "y": round(cy + rm * math.sin(th), 1),
            "w": round((c1 - c0) / NA * 2 * math.pi * rm, 1), "h": round(rout - rin, 1),
            "a": round(th + math.pi / 2, 4)}


def ambienti(U, rin, rout, inizio, n):
    lo, hi = rin + 5, rout - 4
    B = U[lo:hi]
    Bs = B | np.roll(B, 1, axis=1) | np.roll(B, -1, axis=1) | np.roll(B, 2, axis=1) | np.roll(B, -2, axis=1)
    run = np.zeros(NA)
    cur = np.zeros(NA)
    for row in Bs:
        cur = np.where(row, cur + 1, 0)
        run = np.maximum(run, cur)
    sc = run / (hi - lo)
    bordo = U[rin - 3:rin + 4].any(axis=0) | U[rout - 3:rout + 4].any(axis=0)
    # fine della traccia: il bordo sparisce per più di 30 colonne
    fine = NA - 6
    buco = 0
    for c in range(inizio + 10, NA - 5):
        buco = 0 if bordo[c] else buco + 1
        if buco > 30:
            fine = c - 30
            break
    # divisori fra gli ambienti
    cand = []
    for c in range(inizio + 25, fine - 25):
        if sc[c] >= 0.55 and sc[c] >= sc[c - 1] and sc[c] >= sc[c + 1]:
            if cand and c - cand[-1][0] < 20:
                if sc[c] > cand[-1][1]:
                    cand[-1] = (c, sc[c])
            else:
                cand.append((c, sc[c]))
    if n > 1 and len(cand) >= n - 1:
        divisori = sorted(c for c, _ in sorted(cand, key=lambda t: -t[1])[: n - 1])
    else:
        divisori = [inizio + (fine - inizio) * (k + 1) / n for k in range(n - 1)]
    bordi = [inizio] + divisori + [fine]
    return [(bordi[k], bordi[k + 1]) for k in range(n)]


def main():
    g, giallo = carica()
    stelle = {s["id"]: s for s in g["stelle"] if not s.get("navigazione")}
    per_stella = {}
    for p in g["pianeti"]:
        per_stella.setdefault(p["stella"], []).append(p)
    out = {"pianeti": {}, "stelle": {}}
    for sid, pl in per_stella.items():
        s = stelle[sid]
        cx, cy = s["x"], s["y"]
        U = srotola(giallo, cx, cy, 320)
        prof = U.mean(axis=1)
        schema = "A" if prof[103:110].max() > prof[129:136].max() else "B"
        for p in pl:
            k = int(p["anello"])
            rin, rout = ANELLI[schema][k - 1]
            st = SETTORI[(schema, k)]
            amb = ambienti(U, rin, rout, st[6], len(p["ambienti"]))
            out["pianeti"][str(p["id"])] = {
                "orbita": casella(cx, cy, rin, rout, st[0], st[1]),
                "politica": [casella(cx, cy, rin, rout, st[i], st[i + 1]) for i in range(1, 6)],
                "ambienti": [casella(cx, cy, rin, rout, a, b) for a, b in amb],
            }
        n = len(pl)
        d = DERIVA[schema]
        d2 = DERIVA2[(schema, n)]
        out["stelle"][str(sid)] = {"schema": schema,
                                   "deriva": casella(cx, cy, d[0], d[1], d[2], d[3]),
                                   "deriva2": casella(cx, cy, d2[0], d2[1], d2[2], d2[3])}
    json.dump(out, open(os.path.join(RADICE, "data/mappa_caselle.json"), "w"), ensure_ascii=False, indent=1)
    print("caselle:", sum(2 + 5 + len(v["ambienti"]) for v in out["pianeti"].values()) + 2 * len(out["stelle"]))
    if len(sys.argv) > 2 and sys.argv[1] == "--controllo":
        im = Image.open(os.path.join(RADICE, "assets/mappa/galassia.jpg")).convert("RGB")
        dr = ImageDraw.Draw(im)
        def segna(c, col):
            dr.ellipse([c["x"] - 9, c["y"] - 9, c["x"] + 9, c["y"] + 9], fill=col)
        for v in out["pianeti"].values():
            segna(v["orbita"], (0, 200, 255))
            for i, c in enumerate(v["politica"]):
                segna(c, (255, 255, 255) if i != 2 else (255, 0, 255))
            for c in v["ambienti"]:
                segna(c, (0, 255, 0))
        for v in out["stelle"].values():
            segna(v["deriva"], (255, 60, 60))
            segna(v["deriva2"], (255, 140, 0))
        im.save(sys.argv[2])


if __name__ == "__main__":
    main()
