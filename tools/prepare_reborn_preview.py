#!/usr/bin/env python3
"""Prepare only the standalone Reborn preview, without rebuilding the game."""
import base64
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/reborn-preview'
SOURCE = ROOT / 'reborn/anteprime'
IMAGES = [
    ('adare_unita_3d.png', 'Adare: truppe, personaggi e PDB operativo', 'Orbita verde; due basi indicano forza 1. Le figure sono sagome in uno spazio 3D.'),
    ('adare_unita_pdb_down.png', 'PDB down', 'Stesse posizioni orbitali, anello rosso e rotazione ferma nello stato DOWN.'),
    ('adare_unita_dettaglio.png', 'Personaggi e pedine da vicino', 'Zina Adora e Adam Starlight sulla piattaforma del Selvaggio.'),
    ('scala_pianeti_3d.png', 'Scala dei pianeti', 'Kelta: 2 environ. Adare: 9. Solvia: 12. Il rapporto dei diametri Solvia/Kelta è circa 2,45.'),
    ('varianti_selvaggio.png', 'Territori Selvaggio differenti', 'Palette, biomi e rilievi cambiano da mondo a mondo. Qui i globi hanno diametro uniforme per confronto.'),
    ('pianeti_acqua_continenti.png', 'Oceani, continenti e isole', 'Continenti separati nei pianeti misti; isole scenografiche sui mondi solo Liquido.'),
]


def main():
    viewer = (SOURCE / 'adare_3d_autonomo_v2.html').read_text()
    assets = json.loads(re.search(r'const ASSETS=(.*?);\n', viewer).group(1))
    assert set(assets) == {'albedo','emission','terrain','heightmap'}
    for item in assets.values():
        assert 'src' not in item
        channels = 1 if item['format'] == 'L' else 3
        assert len(base64.b64decode(item['pixels'], validate=True)) == item['width'] * item['height'] * channels
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'adare').mkdir(exist_ok=True)
    (OUT / 'render').mkdir(exist_ok=True)
    (OUT / 'adare/index.html').write_text(viewer)
    cards = []
    for filename,title,description in IMAGES:
        assert (SOURCE / filename).is_file(), filename
        shutil.copyfile(SOURCE / filename, OUT / 'render' / filename)
        cards.append(f'<section><h2>{html.escape(title)}</h2><p>{html.escape(description)}</p>'
            f'<a href="render/{filename}"><img loading="lazy" src="render/{filename}" alt="{html.escape(title)}"></a></section>')
    landing = '''<!doctype html><html lang="it"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Freedom in the Galaxy · Reborn</title>
<style>*{box-sizing:border-box}body{margin:0;background:#080e16;color:#e9ece6;font:16px system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:40px 24px}h1{font-size:clamp(30px,5vw,60px);font-weight:500;margin:18px 0}h2{font-size:25px;font-weight:500}p{color:#acbdb2;line-height:1.7}a{color:#80d3ac}nav{display:flex;gap:15px;flex-wrap:wrap;margin:30px 0}nav a{padding:14px 20px;border:1px solid #4b7962;border-radius:7px;text-decoration:none}nav a:first-child{background:#224c39;color:white}img{display:block;width:100%;height:auto;border-radius:10px;border:1px solid #263a32}section{margin:55px 0}.eyebrow{font-size:12px;letter-spacing:3px;color:#7acaaa}footer{padding:30px 0;color:#728c7c;font-size:13px}</style>
<main><div class="eyebrow">FREEDOM IN THE GALAXY / REBORN</div><h1>Adare e il nuovo atlante planetario</h1>
<p>Anteprima grafica: 51 pianeti con territori proporzionali agli environ, piattaforme per le unità e difesa planetaria. Il gioco completo resta separato.</p>
<nav><a href="adare/">Apri il pianeta 3D</a><a href="adare_3d.zip">Scarica la versione offline ZIP</a></nav>
<p>Nel pianeta interattivo puoi ruotare, ingrandire e passare tra superficie, ambienti e notte. I render qui sotto mostrano le piattaforme e il PDB; non sono una partita in corso.</p>
''' + '\n'.join(cards) + '<footer>Prototipi grafici da valutare · Texture di produzione 2048×1024 · Nessuna modifica alle regole di gioco</footer></main></html>'
    (OUT / 'index.html').write_text(landing)
    with zipfile.ZipFile(OUT/'adare_3d.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        archive.writestr('Adare_3D.html',viewer)
    (OUT / '_headers').write_text('/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: same-origin\n  Cache-Control: no-cache\n')
    revision = hashlib.sha256(viewer.encode()).hexdigest()
    (OUT/'version.json').write_text(json.dumps({'viewer_sha256':revision,'standalone':True,'render_count':len(IMAGES)})+'\n')
    print(f'Prepared {OUT}: standalone viewer, {len(IMAGES)} renders, ZIP; SHA256 {revision}')


if __name__ == '__main__':
    main()
