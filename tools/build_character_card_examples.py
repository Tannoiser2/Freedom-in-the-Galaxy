#!/usr/bin/env python3
"""Build the complete character-card collection and the two longest-text proofs."""
from pathlib import Path
import hashlib,html,json,re,shutil,unicodedata
from build_planet_atlas import character_key
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reborn/carte'
STATS=[('combattimento','Combattimento'),('resistenza','Resistenza'),('intelligenza','Intelligenza'),('comando','Comando'),('diplomazia','Diplomazia'),('navigazione','Navigazione')]
ICONS={
'combattimento':'<path d="M5 3l4 1 17 19-3 3L6 7zM3 24l5 5m-3-2 6-6M27 3l-4 1-8 9m-2 6L6 26m23-2-5 5m3-2-6-6"/>',
'resistenza':'<path d="M16 3l11 4v8c0 7-6 12-11 15C11 27 5 22 5 15V7z"/><path d="M16 8v16M10 14h12"/>',
'intelligenza':'<path d="M16 7c-3-7-10-3-9 2-6 1-6 9-2 11-2 5 3 9 7 7 2 3 4 1 4-2V7zM16 7c3-7 10-3 9 2 6 1 6 9 2 11 2 5-3 9-7 7-2 3-4 1-4-2"/><path d="M7 9l4 2-1 5M5 20l6-2 2 4M25 9l-4 2 1 5M27 20l-6-2-2 4"/>',
'comando':'<path d="M7 12l9-6 9 6M7 18l9-6 9 6M7 24l9-6 9 6"/><path d="M10 28h12"/>',
'diplomazia':'<path d="M3 12l5-4 6 2 5-2 10 6-5 12-7 3-10-6zM14 10l-5 7 4 2 6-4 7 7M6 10l4 13M26 12l-4 10M12 24l5 4M16 21l6 5"/>',
'navigazione':'<circle cx="16" cy="16" r="12"/><path d="M21 9l-2 10-10 4 4-10zM16 1v3m0 24v3M1 16h3m24 0h3"/><path d="M13 13l6 6"/>'}
def svg(key):return f'<svg viewBox="0 0 32 32" aria-hidden="true">{ICONS[key]}</svg>'
def slug_for(c):
    name=unicodedata.normalize('NFKD',c['nome']).encode('ascii','ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+','-',name).strip('-')

def card(c):
    rebel=c['fazione']=='ribelli';slug=slug_for(c)
    rows=[]
    for key,label in STATS:
        space=c.get('comando_spazio') if key=='comando' else None
        extra=f'<span class="space-command">({space})</span>' if space is not None else ''
        accessible=label+' '+str(c[key])+(f', comando spaziale {space}' if space is not None else '')
        rows.append(f'<li class="stat" data-stat="{key}" aria-label="{accessible}"><span class="stat-icon">{svg(key)}</span><span class="stat-text"><span class="stat-value">{c[key]}{extra}</span><span class="stat-label">{label}</span></span></li>')
    ability=re.sub(r'(una pescata bonus|due pescate bonus|tre pescate bonus)',r'<strong>\1</strong>',html.escape(c['speciale_it'] or 'Nessuna abilità speciale.'))
    subtitle=' · '.join(v for v in [c.get('titolo_it'),c.get('razza_en')] if v)
    role='Personaggio ribelle' if rebel else ('Cavaliere imperiale' if c.get('cavaliere_imperiale') else 'Personaggio imperiale')
    badge='<path d="M3 17l8 4 5-14 5 14 8-4-4 10H7z"/>' if not rebel else '<path d="M3 9l10 9 3-12 3 12 10-9-6 17H9z"/>'
    return f'''<div class="card-item" data-name="{html.escape(c['nome'].lower())}" data-faction="{c['fazione']}" data-slug="{slug}"><div class="card-shell"><article class="card {'rebel' if rebel else 'imperial'}" id="{slug}" aria-label="Carta di {html.escape(c['nome'])}">
<header class="card-top"><div class="faction-line"><svg class="faction-symbol" viewBox="0 0 32 32" aria-hidden="true">{badge}</svg><span>{'Alleanza ribelle' if rebel else 'Impero'}</span><svg class="card-number" viewBox="0 0 100 100" role="img" aria-label="Carta numero {c['nr']}"><circle cx="50" cy="50" r="46"/><text x="50" y="50" text-anchor="middle">{c['nr']:02d}</text></svg></div><h2 class="card-name">{html.escape(c['nome'])}</h2><div class="card-title">{html.escape(subtitle)}</div></header>
<img class="figure" loading="lazy" decoding="async" src="assets/{slug}.png" alt="{html.escape(c['nome'])}, figura intera"><div class="hero"><ul class="stats">{''.join(rows)}</ul>{'<div class="command-note">Tra parentesi: comando spaziale</div>' if c.get('comando_spazio') is not None else ''}</div>
<section class="ability"><h3 class="ability-label">ABILITÀ SPECIALE</h3><p class="ability-text">{ability}</p><div class="card-meta"><span>{role}</span><span>Freedom in the Galaxy</span></div></section></article></div><a class="card-download" href="{slug}.png" download>Scarica {html.escape(c['nome'])} · PNG</a></div>'''
def main():
    records=json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    assert len(records)==32
    longest_name=max(records,key=lambda c:len(c['nome']))
    longest_ability=max(records,key=lambda c:len(c['speciale_it'] or ''))
    proof=[longest_name,longest_ability]
    (OUT/'assets').mkdir(parents=True,exist_ok=True);(OUT/'fonts').mkdir(exist_ok=True)
    for c in records:
        source=ROOT/'assets_reborn/figure_intere'/(character_key(c['nome'])+'.png')
        assert source.is_file(),source
        shutil.copyfile(source,OUT/'assets'/(slug_for(c)+'.png'))
    for name in ['Exo2.ttf','SairaCondensed-Bold.ttf','OFL-Exo2.txt','OFL-SairaCondensed.txt']:shutil.copyfile(ROOT/'assets/font'/name,OUT/'fonts'/name)
    shutil.copyfile(ROOT/'tools/templates/cards/cards.css',OUT/'cards.css')
    (OUT/'data.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    css_version=hashlib.sha256((OUT/'cards.css').read_bytes()).hexdigest()[:12]
    script=(ROOT/'tools/templates/cards/cards.js').read_text()
    (OUT/'cards.js').write_text(script)
    script_version=hashlib.sha256(script.encode()).hexdigest()[:12]
    for filename,selection,is_proof in [('index.html',records,False),('prova-limiti.html',proof,True)]:
        title='La prova dei testi più lunghi' if is_proof else 'Le carte personaggio'
        info='Emperor Coreguya · nome più lungo<br>Thysa Kymbo · abilità più lunga' if is_proof else '32 personaggi · 20 ribelli e 12 imperiali<br>Valori e abilità originali del gioco'
        toolbar=('<nav class="toolbar"><a href="./">Tutte le 32 carte</a></nav>' if is_proof else '<div class="toolbar"><label>Cerca personaggio<input id="card-search" type="search" placeholder="Nome del personaggio"></label><label>Fazione<select id="faction-filter"><option value="">Tutte</option><option value="ribelli">Ribelli</option><option value="imperiali">Impero</option></select></label><a href="prova-limiti.html">Prova dei testi più lunghi →</a><a href="mazzi.html">Gli altri mazzi · 108 carte →</a><a href="../truppe/">Truppe e flotte →</a><span id="visible-count">32 carte</span></div>')
        head='<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,"><title>'+title+' · Reborn</title><link rel="stylesheet" href="cards.css?v='+css_version+'"></head><body><main class="page"><header class="page-head"><div><div class="eyebrow">Freedom in the Galaxy · Reborn</div><h1>'+title+'</h1></div><p>'+info+'</p></header>'+toolbar+'<div class="pair">'
        tail='</div><nav class="download-links"><a href="../atlante/">Atlante dei pianeti</a><a href="esempi-carte.png">Confronto Redjac e Zina Adora</a></nav><p class="footer">Sei caratteristiche: Combattimento, Resistenza, Intelligenza, Comando, Diplomazia e Navigazione. Il valore tra parentesi indica il comando spaziale.</p></main><script src="cards.js?v='+script_version+'"></script></body></html>'
        page=head+''.join(card(c) for c in selection)+tail
        page=re.sub(r'href="([^"/]+\.png)"',lambda m:'href="'+m.group(1)+'?v='+css_version+'"',page)
        (OUT/filename).write_text(page)
    (OUT/'build.json').write_text(json.dumps({'count':len(records),'factions':{'ribelli':20,'imperiali':12},'proof':[c['nome'] for c in proof],'css':css_version,'script':script_version},indent=2)+'\n')
    print('32 carte personaggio; prove: '+longest_name['nome']+' e '+longest_ability['nome'])
if __name__=='__main__':main()
