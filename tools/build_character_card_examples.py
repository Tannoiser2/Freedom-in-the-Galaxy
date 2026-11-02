#!/usr/bin/env python3
"""Build two reviewable character card layouts using the actual game records."""
from pathlib import Path
import hashlib,html,json,shutil
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
def card(c):
    rebel=c['fazione']=='ribelli';slug='zina-adora' if rebel else 'redjac'
    rows=[]
    for key,label in STATS:
        space=c.get('comando_spazio') if key=='comando' else None
        extra=f'<span class="space-command">({space})</span>' if space is not None else ''
        accessible=label+' '+str(c[key])+(f', comando spaziale {space}' if space is not None else '')
        rows.append(f'<li class="stat" data-stat="{key}" aria-label="{accessible}"><span class="stat-icon">{svg(key)}</span><span class="stat-text"><span class="stat-value">{c[key]}{extra}</span><span class="stat-label">{label}</span></span></li>')
    ability=html.escape(c['speciale_it']).replace('una pescata bonus','<strong>una pescata bonus</strong>')
    badge='<path d="M3 17l8 4 5-14 5 14 8-4-4 10H7z"/>' if not rebel else '<path d="M3 9l10 9 3-12 3 12 10-9-6 17H9z"/>'
    return f'''<div class="card-shell"><article class="card {'rebel' if rebel else 'imperial'}" id="{slug}" aria-label="Carta di {html.escape(c['nome'])}">
<header class="card-top"><div class="faction-line"><svg class="faction-symbol" viewBox="0 0 32 32" aria-hidden="true">{badge}</svg><span>{'Alleanza ribelle' if rebel else 'Impero'}</span><span class="card-number">{c['nr']:02d}</span></div><h2 class="card-name">{html.escape(c['nome'])}</h2><div class="card-title">{html.escape(c['titolo_it'] or '')} · {html.escape(c['razza_en'])}</div></header>
<div class="hero"><img class="figure" src="assets/{slug}.png" alt="{html.escape(c['nome'])}, figura intera"><ul class="stats">{''.join(rows)}</ul>{'<div class="command-note">Tra parentesi: comando spaziale</div>' if c.get('comando_spazio') is not None else ''}</div>
<section class="ability"><h3 class="ability-label">ABILITÀ SPECIALE</h3><p class="ability-text">{ability}</p><div class="card-meta"><span>{'Personaggio ribelle' if rebel else 'Cavaliere imperiale'}</span><span>Freedom in the Galaxy</span></div></section></article></div>'''
def main():
    people=json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    records=[next(c for c in people if c['nome']==name) for name in ['Redjac','Zina Adora']]
    (OUT/'assets').mkdir(parents=True,exist_ok=True);(OUT/'fonts').mkdir(exist_ok=True)
    for source,name in [('pg_redjac.png','redjac.png'),('pg_zina_adora.png','zina-adora.png')]:shutil.copyfile(ROOT/'assets_reborn/figure_intere'/source,OUT/'assets'/name)
    for name in ['Exo2.ttf','SairaCondensed-Bold.ttf','OFL-Exo2.txt','OFL-SairaCondensed.txt']:shutil.copyfile(ROOT/'assets/font'/name,OUT/'fonts'/name)
    shutil.copyfile(ROOT/'tools/templates/cards/cards.css',OUT/'cards.css')
    (OUT/'data.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    css_version=hashlib.sha256((OUT/'cards.css').read_bytes()).hexdigest()[:12]
    page='''<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,"><title>Carte personaggio · Reborn</title><link rel="stylesheet" href="cards.css"></head><body><main class="page"><header class="page-head"><div><div class="eyebrow">Freedom in the Galaxy · Reborn</div><h1>Le carte personaggio</h1></div><p>Due esempi della nuova veste grafica.<br>Valori e abilità delle carte del gioco.</p></header><div class="pair">'''+''.join(card(c) for c in records)+'''</div><nav class="download-links"><a href="redjac.png" download>Scarica Redjac</a><a href="zina-adora.png" download>Scarica Zina Adora</a><a href="../atlante/">Atlante dei pianeti</a></nav><p class="footer">Sei caratteristiche: Combattimento, Resistenza, Intelligenza, Comando, Diplomazia e Navigazione. Il valore tra parentesi indica il comando spaziale.</p></main><script>const fit=()=>document.querySelectorAll('.card-shell').forEach(el=>el.style.setProperty('--card-scale',Math.min(1,el.clientWidth/600)));new ResizeObserver(fit).observe(document.body);fit();</script></body></html>'''
    (OUT/'index.html').write_text(page.replace('href="cards.css"','href="cards.css?v='+css_version+'"'))
    print('Esempi: Redjac (imperiale), Zina Adora (ribelle); dati originali conservati.')
if __name__=='__main__':main()
