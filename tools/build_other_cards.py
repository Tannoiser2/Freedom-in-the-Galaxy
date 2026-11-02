#!/usr/bin/env python3
"""Build every non-character deck, preserving the complete original Italian rules."""
from pathlib import Path
import hashlib,html,json,math,shutil
from build_character_card_examples import ICONS
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reborn/carte'
KINDS=['azione','missione','evento','strategico','possessi']
LABELS={'azione':'Azione','missione':'Missione','evento':'Evento','strategico':'Strategica','possessi':'Possesso'}
ICONS.update({'passeggeri':'<circle cx="11" cy="10" r="4"/><circle cx="23" cy="11" r="3"/><path d="M3 27v-5c0-7 16-7 16 0v5M20 18c6-2 10 1 10 6v3"/>','cannoni':'<circle cx="16" cy="16" r="9"/><circle cx="16" cy="16" r="3"/><path d="M16 1v8m0 14v8M1 16h8m14 0h8"/>'})
def esc(value):return html.escape(str(value))
def field(path,text,tag='p',cls='rule-text'):
    return f'<{tag} class="{cls}" data-field="{path}">{esc(text)}</{tag}>'
def rule(label,path,text):
    return f'<section class="rule-block"><h3>{esc(label)}</h3>{field(path,text)}</section>' if text else ''
def badge(c):return f'<svg class="card-number" viewBox="0 0 100 100" role="img" aria-label="Carta numero {c["nr"]}"><circle cx="50" cy="50" r="46"/><text x="50" y="50" text-anchor="middle">{c["nr"]:02d}</text></svg>'
def title_for(kind,c):
    if kind=='azione':return 'Carta Azione'
    if kind=='strategico':return c['it']
    return c.get('nome_it',c.get('titolo_it',''))
def route(c):
    coords={1:(155,115),2:(445,115),3:(500,385),4:(300,570),5:(100,385)}
    a,b=coords[c['da']],coords[c['a']];dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy)
    start=(a[0]+dx/length*60,a[1]+dy/length*60);end=(b[0]-dx/length*68,b[1]-dy/length*68)
    nodes=''
    for n,(x,y) in coords.items():
        active=n in [c['da'],c['a']]
        nodes+=f'<g class="province {"active" if active else ""}"><circle cx="{x}" cy="{y}" r="52"/><text x="{x}" y="{y+3}" text-anchor="middle" dominant-baseline="central">{n}</text><text class="province-label" x="{x}" y="{y+80}" text-anchor="middle">PROVINCIA {n}</text></g>'
    return f'<svg class="route-map" viewBox="0 0 600 690" role="img" aria-label="Dalla provincia {c["da"]} alla provincia {c["a"]}"><defs><marker id="arrow-{c["nr"]}" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0 0L6 3L0 6Z" fill="#e7c478"/></marker></defs><path class="route-line" d="M{start[0]} {start[1]}L{end[0]} {end[1]}" marker-end="url(#arrow-{c["nr"]})"/>{nodes}</svg>'
def metric(label,key,value,icon):
    return f'<div class="ship-metric"><span class="metric-icon"><svg viewBox="0 0 32 32" aria-hidden="true">{ICONS[icon]}</svg></span><span><b data-field="{key}">{value}</b><small>{label}</small></span></div>'
def card(kind,c):
    name=title_for(kind,c);extra='';content='';art='';notes='';minimum=24
    if kind=='missione':
        extra=f'<svg class="mission-letter" viewBox="0 0 48 48" role="img" aria-label="Missione {esc(c["lettera"])}"><rect x="1" y="1" width="46" height="46" rx="5"/><text data-field="lettera" x="24" y="24" text-anchor="middle">{esc(c["lettera"])}</text></svg>'
        audience='Solo Ribelli' if c['solo']=='ribelli' else ('Solo Impero' if c['solo']=='imperiali' else 'Entrambe le fazioni')
        notes=f'<div class="deck-audience">{audience} · Star System: {"sì" if c["usata_star_system"] else "no"}</div>'
        art='<div class="deck-art mission-art" data-art-height="110" data-art-min="0"><img loading="lazy" src="assets/missioni.jpg" alt="Scenario di una missione galattica"></div>'
        for key,label in [('descrizione','Obiettivo'),('restrizioni','Restrizioni'),('risultato','Risultato'),('bonus','Pescate bonus')]:content+=rule(label,'it.'+key,c['it'][key])
        minimum=22
    elif kind=='azione':
        for zone,label in [('urbano','Urbano'),('speciale','Speciale'),('selvaggio','Selvaggio')]:
            letters=''.join('<svg class="letter-chip" viewBox="0 0 48 48"><rect width="48" height="48" rx="5"/><text x="24" y="24" text-anchor="middle">'+esc(v)+'</text></svg>' for v in c['en'][zone]['lettere'])
            paths={'urbano':'<path d="M4 29V13h8V4h8v14h8v11M9 18h1m-1 5h1m6-15h1m-1 5h1m-1 5h1m-1 5h1m7 0h1"/>','speciale':'<path d="M16 3l4 9 9 4-9 4-4 9-4-9-9-4 9-4z"/>','selvaggio':'<path d="M16 3L8 14h4L5 24h9v5h4v-5h9l-7-10h4z"/>'}
            symbol='<svg viewBox="0 0 32 32">'+paths[zone]+'</svg>'
            content+=f'<section class="action-zone zone-{zone}"><h3><span class="zone-symbol" aria-hidden="true">{symbol}</span><span>{label}</span><span class="action-letters" data-zone="{zone}">{letters}</span></h3>'+field('it.'+zone+'.evento',c['it'][zone]['evento'])+'</section>'
    elif kind=='evento':
        art='<div class="deck-art event-art" data-art-height="180" data-art-min="60"><img loading="lazy" src="assets/eventi.jpg" alt="Orizzonte della galassia"></div>'
        content=rule('Evento','it',c['it'])
    elif kind=='strategico':
        content=route(c)+f'<div class="route-caption"><span>Da <b data-field="da">{c["da"]}</b></span><span class="route-arrow">→</span><span>A <b data-field="a">{c["a"]}</b></span></div>'
    else:
        ship=c['tipo']=='astronave'
        notes=f'<div class="deck-audience">{esc({"astronave":"Astronave","arma":"Arma","oggetto":"Oggetto","compagno":"Compagno"}[c["tipo"]])}</div>'
        metrics=''
        if ship:
            for label,key,icon in [('Manovra','manovra','navigazione'),('Passeggeri','passeggeri','passeggeri'),('Cannoni','cannoni','cannoni'),('Scudi','scudi','resistenza')]:metrics+=metric(label,key,c[key],icon)
        art=f'<div class="deck-art possession-art {"ship-art" if ship else ""}" data-art-height="{310 if ship else 270}" data-art-min="{280 if ship else 150}"><img loading="lazy" src="assets/{c["file"]}.png" alt="{esc(name)}">'+(f'<div class="ship-metrics">{metrics}</div>' if ship else '')+'</div>'
        content=rule('Caratteristiche e utilizzo','it',c['it'])
        if c['proprietario']:content+=rule('Proprietario','proprietario',c['proprietario'])
        content+=rule('Uso e riparazione','riparazione_it',c['riparazione_it'])
        minimum=24
    titlefield='it' if kind=='strategico' else ('nome_it' if kind in ['missione','possessi'] else 'titolo_it')
    heading=field(titlefield,name,'h2','card-name') if kind!='azione' else '<h2 class="card-name">Carta Azione</h2>'
    return f'''<div class="card-item" data-name="{esc(name.lower())}" data-deck="{kind}" data-slug="{c['file']}"><div class="card-shell"><article class="card deck-card deck-{kind}" id="card-{c['file']}" data-kind="{kind}" data-file="{c['file']}" data-min-font="{minimum}" aria-label="{LABELS[kind]}: {esc(name)}"><header class="card-top"><div class="faction-line"><span>{LABELS[kind]}</span>{extra}</div>{badge(c)}{heading}{notes}</header><div class="deck-body">{art}<div class="rule-content">{content}</div></div><footer class="deck-footer"><strong>{LABELS[kind]}</strong><span>Freedom in the Galaxy</span></footer></article></div><a class="card-download" href="mazzi/{c['file']}.png" download>Scarica {esc(name)} · PNG</a></div>'''
def main():
    source=json.loads((ROOT/'data/carte.json').read_text());decks={k:source[k] for k in KINDS}
    assert sum(map(len,decks.values()))==108
    (OUT/'mazzi').mkdir(exist_ok=True)
    for c in decks['possessi']:shutil.copyfile(ROOT/f'assets_reborn/carte/illustrazioni/{c["file"]}.png',OUT/f'assets/{c["file"]}.png')
    for name in ['decks.css','decks.js']:shutil.copyfile(ROOT/'tools/templates/cards'/name,OUT/name)
    (OUT/'mazzi/data.json').write_text(json.dumps({'decks':decks,'counts':{k:len(v) for k,v in decks.items()},'total':108},ensure_ascii=False,indent=2)+'\n')
    versions={name:hashlib.sha256((OUT/name).read_bytes()).hexdigest()[:12] for name in ['cards.css','decks.css','decks.js']}
    samples=[('possessi',decks['possessi'][0]),('missione',max(decks['missione'],key=lambda c:sum(map(len,c['it'].values())))),('azione',max(decks['azione'],key=lambda c:sum(v['evento'].__len__() for v in c['it'].values()))),('evento',max(decks['evento'],key=lambda c:len(c['it']))),('strategico',decks['strategico'][0]),('possessi',max(decks['possessi'],key=lambda c:len(c['it'])))]
    for filename,selection in [('mazzi.html',[(k,c) for k in KINDS for c in decks[k]]),('prova-mazzi.html',samples)]:
        proof=filename=='prova-mazzi.html'
        title='La prova degli altri mazzi' if proof else 'Gli altri mazzi'
        toolbar='<nav class="toolbar"><a href="mazzi.html">Tutte le 108 carte</a><a href="./">32 personaggi</a></nav>' if proof else '<div class="toolbar"><label>Cerca carta<input type="search" id="deck-search" placeholder="Titolo, nome o numero"></label><label>Mazzo<select id="deck-filter"><option value="">Tutti i mazzi</option>'+''.join(f'<option value="{k}">{LABELS[k]} · {len(v)}</option>' for k,v in decks.items())+'</select></label><span id="deck-count">108 carte</span><a href="prova-mazzi.html">Prova dei testi più lunghi →</a><a href="./">Personaggi</a></div>'
        text=f'''<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,"><title>{title} · Reborn</title><link rel="stylesheet" href="cards.css?v={versions['cards.css']}"><link rel="stylesheet" href="decks.css?v={versions['decks.css']}"></head><body><main class="page"><header class="page-head"><div><div class="eyebrow">Freedom in the Galaxy · Reborn</div><h1>{title}</h1></div><p>30 Azione · 15 Missione · 29 Evento<br>14 Strategiche · 20 Possessi</p></header>{toolbar}<div class="pair">'''+''.join(card(k,c) for k,c in selection)+f'</div><nav class="download-links"><a href="./">Le 32 carte personaggio</a><a href="../atlante/">Atlante dei pianeti</a></nav></main><script src="decks.js?v={versions["decks.js"]}"></script></body></html>'
        text=text.replace('.png" download','.png?v='+versions['decks.css']+'" download')
        (OUT/filename).write_text(text)
    (OUT/'mazzi/build.json').write_text(json.dumps({'total':108,'counts':{k:len(v) for k,v in decks.items()},'proof':[c['file'] for k,c in samples]},indent=2)+'\n')
    print('Preparati tutti gli altri mazzi: 108 carte, cinque famiglie.')
if __name__=='__main__':main()
