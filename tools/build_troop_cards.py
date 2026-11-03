#!/usr/bin/env python3
"""Build all 40 troop types with a surface/orbit presentation of the same unit."""
import hashlib,html,json,shutil
from pathlib import Path
from troop_catalog import ROOT,catalog
OUT=ROOT/'reborn/truppe'
SPACE_ICON='<path d="M16 3l5 12 8 7-10-2-3 9-3-9-10 2 8-7z"/>'
LAND_ICON='<path d="M5 3l4 1 17 19-3 3L6 7zM3 24l5 5m-3-2 6-6M27 3l-4 1-8 9m-2 6L6 26m23-2-5 5m3-2-6-6"/>'
def card(c,pawn=False):
    key=c['key'];env=c['environ'];faction='Ribelli' if c['fazione']=='ribelli' else 'Impero'
    ground='assets/'+c['ground']+'?v='+hashlib.sha256((OUT/'assets'/c['ground']).read_bytes()).hexdigest()[:12]
    orbit='assets/'+c['orbit']+'?v='+hashlib.sha256((OUT/'assets'/c['orbit']).read_bytes()).hexdigest()[:12]
    info=('Unità mobile.' if c['mobile'] else 'Unità non mobile: necessita di trasporto per gli spostamenti spaziali.')
    if c['spazio']==0:info+=' Forza spaziale 0: in orbita è rappresentata da un trasporto, senza forza di combattimento aggiuntiva.'
    if c['terra']==0:info+=' Nessuna forza di combattimento a terra.'
    metrics=''.join(f'<li class="stat" data-stat="{k}"><span class="stat-icon"><svg viewBox="0 0 32 32" aria-hidden="true">{icon}</svg></span><span class="stat-text"><b class="stat-value">{c[k]}</b><span class="stat-label"><span class="combat-prefix">Combattimento<br></span>{label}</span></span></li>' for k,label,icon in [('terra','a terra',LAND_ICON),('spazio','spaziale',SPACE_ICON)])
    envlabel='Tutti gli environ' if env=='tutti' else env.capitalize()
    folder='pedine' if pawn else 'png'
    detail=f'<a class="detail-link" href="schede.html?unita={key}">Scheda grande</a>' if pawn else f'<a href="./?unita={key}">Pedina</a>'
    return f'''<div class="card-item" data-faction="{c['fazione']}" data-environ="{env}" data-class="{c['cat']}" data-key="{key}" data-name="{html.escape((c['nome']+' '+envlabel+' '+faction).lower())}"><div class="card-shell"><article class="card troop-card {'rebel' if c['fazione']=='ribelli' else 'imperial'} {'token' if pawn else ''}" data-ground="{ground}" data-orbit="{orbit}" data-position="terra">
<header class="card-top"><div class="faction-line">{faction} · Truppe</div><h2 class="card-name">{html.escape(c['nome'])}</h2><div class="card-title">{envlabel}</div></header>
<img class="figure" src="{ground}" loading="lazy" alt="Reparto {html.escape(c['nome'])}, superficie"><div class="hero"><ul class="stats">{metrics}</ul><div class="environ-badge" data-environ="{env}"><span class="env-symbol">{envlabel}</span><small>Environ</small></div><div class="position-label">SUPERFICIE</div></div>
<section class="ability"><h3 class="ability-label">PROFILO DELL’UNITÀ</h3><p class="ability-text">{info}</p><div class="card-meta"><span>{faction} · {html.escape(c['nome'])}</span><span>{c['terra']} terra / {c['spazio']} spazio</span></div></section></article></div><div class="unit-actions"><button class="position-toggle" aria-pressed="false">Mostra in orbita</button><a class="card-download" href="{folder}/{key}-terra.png" download>PNG superficie</a><a class="orbit-download" href="{folder}/{key}-orbita.png" download>PNG orbita</a>{detail}</div></div>'''
def main():
    records=catalog();assert len(records)==40
    (OUT/'assets').mkdir(parents=True,exist_ok=True);(OUT/'png').mkdir(exist_ok=True);(OUT/'pedine').mkdir(exist_ok=True)
    for name in {c[k] for c in records for k in ['ground','orbit']}:
        shutil.copyfile(ROOT/'assets_reborn/truppe'/name,OUT/'assets'/name)
    for name in ['truppe.css','truppe.js']:shutil.copyfile(ROOT/'tools/templates/cards'/name,OUT/name)
    version=hashlib.sha256((OUT/'truppe.css').read_bytes()+(OUT/'truppe.js').read_bytes()).hexdigest()[:12]
    filters=''.join(f'<option value="{k}">{v}</option>' for k,v in [('urbano','Urbano'),('sotterraneo','Sotterraneo'),('selvaggio','Selvaggio'),('liquido','Liquido'),('aereo','Aereo'),('fuoco','Fuoco'),('tutti','Tutti gli environ')])
    head=f'''<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,"><title>Truppe · Reborn</title><link rel="stylesheet" href="../carte/cards.css"><link rel="stylesheet" href="truppe.css?v={version}"></head><body><main class="page"><header class="page-head"><div><div class="eyebrow">Freedom in the Galaxy · Reborn</div><h1>Truppe e flotte</h1></div><p>40 tipi di unità · Impero e Ribelli<br>La stessa unità cambia immagine tra superficie e orbita.</p></header><div class="toolbar"><label>Cerca<input id="troop-search" type="search" placeholder="Milizia, linea, élite…"></label><label>Fazione<select id="faction-filter"><option value="">Tutte</option><option value="imperiali">Impero</option><option value="ribelli">Ribelli</option></select></label><label>Environ<select id="environ-filter"><option value="">Tutti</option>{filters}</select></label><label>Posizione<select id="position-filter"><option value="terra">Superficie</option><option value="orbita">Orbita</option></select></label><span id="visible-count">40 unità</span></div><div class="pair">'''
    tail=f'</div><nav class="download-links"><a href="./">Tutte le truppe</a><a href="prova-reparti.html">Milizie ed élite a confronto</a><a href="../carte/">Personaggi</a><a href="../carte/mazzi.html">Altri mazzi</a><a href="../atlante/">Atlante 3D</a></nav><p class="footer">Valori originali delle unità. Gli imperiali operano in tutti gli environ; i ribelli mantengono il proprio tipo di ambiente. La posizione cambia l’illustrazione e il valore evidenziato.</p></main><script src="truppe.js?v={version}"></script></body></html>'
    pawn_head=head.replace('<body>','<body class="pawn-gallery">').replace('<h1>Truppe e flotte</h1>','<h1>Pedine delle truppe</h1>')
    (OUT/'index.html').write_text(pawn_head+''.join(card(c,True) for c in records)+tail)
    (OUT/'schede.html').write_text(head+''.join(map(card,records))+tail)
    proof=[next(c for c in records if c['key']==key) for key in ['imp_milizia','imp_elite_esercito','rib_selvaggio_10','rib_selvaggio_elite']]
    (OUT/'prova-reparti.html').write_text(pawn_head.replace('<h1>Pedine delle truppe</h1>','<h1>Dalla milizia all’élite</h1>')+''.join(card(c,True) for c in proof)+tail)
    (OUT/'data.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    (OUT/'build.json').write_text(json.dumps(dict(count=40,presentations=80,imperiali=10,ribelli=30,primary="pedine",art="reparti",version=version))+'\n')
    print('40 tipi di truppe, 80 presentazioni superficie/orbita')
if __name__=='__main__':main()
