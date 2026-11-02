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
    atlas_source = ROOT / 'reborn/atlante'
    atlas = json.loads((atlas_source/'build.json').read_text())
    assert atlas['planets'] == 51 and atlas['systems'] == 25
    shutil.copytree(atlas_source, OUT/'atlante', dirs_exist_ok=True)
    card_source = ROOT/'reborn/carte'
    card_examples = json.loads((card_source/'data.json').read_text())
    assert card_examples == json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    assert len(card_examples) == 32
    other_cards = json.loads((card_source/'mazzi/data.json').read_text())
    original_cards = json.loads((ROOT/'data/carte.json').read_text())
    assert other_cards['decks'] == {k:original_cards[k] for k in ['azione','missione','evento','strategico','possessi']}
    assert other_cards['total'] == 108
    shutil.copytree(card_source, OUT/'carte', dirs_exist_ok=True)
    cards = []
    for filename,title,description in IMAGES:
        assert (SOURCE / filename).is_file(), filename
        shutil.copyfile(SOURCE / filename, OUT / 'render' / filename)
        cards.append(f'<section><h2>{html.escape(title)}</h2><p>{html.escape(description)}</p>'
            f'<a href="render/{filename}"><img loading="lazy" src="render/{filename}" alt="{html.escape(title)}"></a></section>')
    landing = '''<!doctype html><html lang="it"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Freedom in the Galaxy · Reborn</title>
<style>*{box-sizing:border-box}body{margin:0;background:#080e16;color:#e9ece6;font:16px system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:40px 24px}h1{font-size:clamp(30px,5vw,60px);font-weight:500;margin:18px 0}h2{font-size:25px;font-weight:500}p{color:#acbdb2;line-height:1.7}a{color:#80d3ac}nav{display:flex;gap:15px;flex-wrap:wrap;margin:30px 0}nav a{padding:14px 20px;border:1px solid #4b7962;border-radius:7px;text-decoration:none}nav a:first-child{background:#224c39;color:white}img{display:block;width:100%;height:auto;border-radius:10px;border:1px solid #263a32}section{margin:55px 0}.eyebrow{font-size:12px;letter-spacing:3px;color:#7acaaa}footer{padding:30px 0;color:#728c7c;font-size:13px}</style>
<main><div class="eyebrow">FREEDOM IN THE GALAXY / REBORN</div><h1>Atlante interattivo della galassia</h1>
<p>51 pianeti e 25 sistemi selezionabili, con stelle, orbite animate, rotazione dei globi, basi PDB e unità dimostrative sulle piattaforme. La raccolta comprende tutte le 140 carte: personaggi e altri cinque mazzi. Il gioco completo resta separato.</p>
<nav><a href="atlante/">Apri l’atlante 3D completo</a><a href="carte/">Le 32 carte personaggio</a><a href="carte/mazzi.html">Gli altri mazzi · 108 carte</a><a href="adare/">Adare: esempio autonomo</a><a href="adare_3d.zip">Versione offline di Adare</a></nav>
<p>Lo stile pittorico usa 18 texture per i sei ambienti. Le città hanno fondo grigio e strade gialle luminose; Adare non ha acqua. Nell’atlante puoi selezionare ogni mondo o sistema, configurare forza e stato del PDB, mettere in pausa e avvicinarti ai pianeti.</p>
<h2>Archivio dei render della prima iterazione</h2><p>I render sotto documentano la prima prova delle piattaforme. Per materiali e colori aggiornati usa l’atlante interattivo.</p>
''' + '\n'.join(cards) + '<footer>Prototipi grafici da valutare · Texture di produzione 2048×1024 · Nessuna modifica alle regole di gioco</footer></main></html>'
    (OUT / 'index.html').write_text(landing)
    with zipfile.ZipFile(OUT/'adare_3d.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        archive.writestr('Adare_3D.html',viewer)
    (OUT / '_headers').write_text('/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: same-origin\n  Cache-Control: no-cache\n')
    revision = hashlib.sha256(viewer.encode()).hexdigest()
    (OUT/'version.json').write_text(json.dumps({'viewer_sha256':revision,'standalone':True,'render_count':len(IMAGES),
        'atlas_planets':atlas['planets'],'atlas_systems':atlas['systems'],'atlas_data':atlas['data'],
        'atlas_sha256':atlas['script_sha256'],'atlas_material_variants':atlas.get('material_variants',0),'card_examples':2,'character_cards':len(card_examples),'other_cards':other_cards['total'],'total_cards':len(card_examples)+other_cards['total']})+'\n')
    print(f'Prepared {OUT}: standalone viewer, {len(IMAGES)} renders, ZIP; SHA256 {revision}')


if __name__ == '__main__':
    main()
