#!/usr/bin/env python3
"""Build the local, dependency-free-to-host Three.js planetary atlas.

Only the builder needs Pillow. Generated preview files and vendored Three.js
are committed so publication only copies files, without npm or a CDN.
"""
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reborn/atlante'
TEMPLATE = ROOT / 'tools/templates/atlas'


def write_hashed(folder, stem, suffix, raw):
    folder.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(raw).hexdigest()[:12]
    name = f'{stem}-{digest}.{suffix}'
    path = folder / name
    path.write_bytes(raw)
    return str(path.relative_to(OUT))


def image(source, folder, stem, size, mode='RGB', jpeg=False, nearest=False):
    import io
    with Image.open(source) as im:
        im = im.convert(mode)
        im.thumbnail(size, Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        if jpeg:
            im.save(buffer, 'JPEG', quality=93, subsampling=0, optimize=True)
        else:
            im.save(buffer, 'PNG', optimize=True)
    return write_hashed(folder,stem,'jpg' if jpeg else 'png',buffer.getvalue())


def character_key(name):
    name = name.lower().replace('doctor ', 'doctor_').replace('professor ', 'prof_')
    name = name.replace('senator ', '').replace('emperor ', '')
    return 'pg_'+name.replace('-','_').replace(' ','_')


def main():
    galaxy = json.loads((ROOT/'data/galassia.json').read_text())
    cards = json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    profiles = {p['id']:p for p in json.loads((ROOT/'reborn/pianeti_superfici.json').read_text())['pianeti']}
    OUT.mkdir(parents=True,exist_ok=True)
    used = set()
    unit_cache = {}
    def unit_image(key,character):
        if key not in unit_cache:
            source = ROOT/'assets_reborn'/('figure_intere' if character else 'pedine')/(key+'.png')
            unit_cache[key] = image(source,OUT/'units',key,(400,560) if character else (320,320),mode='RGBA')
        used.add(unit_cache[key])
        return unit_cache[key]
    planets=[]
    for p in galaxy['pianeti']:
        pid=p['id'];total=sum(e['taglia'] for e in p['ambienti'])
        maps={}
        for key,suffix,size,mode,jpeg in [('color','',(1024,512),'RGB',True),
            ('terrain','_ambienti',(512,256),'RGB',False),
            ('emission','_emission',(512,256),'RGB',False),
            ('height','_height',(512,256),'L',False)]:
            maps[key]=image(ROOT/f'assets_reborn/pianeti/{pid}{suffix}.png',OUT/'textures',f'{pid}-{key}',size,mode,jpeg,key=='terrain')
            used.add(maps[key])
        roster=[c for c in cards if p['nome'] in (c.get('pianeti_natali') or [])]
        if pid==142:
            roster=[next(c for c in cards if c['nome']==name) for name in ['Zina Adora','Adam Starlight']]
        for candidate in [cards[pid%len(cards)],cards[(pid+7)%len(cards)],*cards]:
            if len(roster)>=2:break
            if candidate not in roster:roster.append(candidate)
        units=[{'nome':c['nome'],'fazione':c['fazione'],'image':unit_image(character_key(c['nome']),True)} for c in roster[:2]]
        envs=[]
        for e in p['ambienti']:
            key='imp_linea' if e['tipo']=='urbano' else f'rib_{e["tipo"]}_23'
            if not (ROOT/f'assets_reborn/pedine/{key}.png').is_file():key='imp_milizia'
            envs.append({'tipo':e['tipo'],'taglia':e['taglia'],'token':unit_image(key,False)})
        dominant=max(p['ambienti'],key=lambda e:e['taglia'])['tipo']
        profile=profiles[pid]['profilo_artistico']['bioma_selvaggio'] if any(e['tipo']=='selvaggio' for e in p['ambienti']) else {
            'urbano':'metropoli, quartieri e infrastrutture','liquido':'oceani e arcipelaghi',
            'sotterraneo':'rilievi e bacini rocciosi','aereo':'atmosfera a bande','fuoco':'crosta vulcanica e lava'}[dominant]
        planets.append({'id':pid,'nome':p['nome'],'stella':p['stella'],'anello':p['anello'],
            'total':total,'radius':2.3*(total/9)**.5,'ambienti':envs,'maps':maps,'units':units,
            'profile':profile})
        print(f'Atlas {pid} {p["nome"]}',flush=True)
    star_ids={p['stella'] for p in planets}
    systems=[{'id':s['id'],'nome':s['nome'],'provincia':s['provincia'],
        'planets':[p['id'] for p in sorted(planets,key=lambda p:p['anello']) if p['stella']==s['id']]}
        for s in galaxy['stelle'] if s['id'] in star_ids]
    assert len(planets)==51 and len(systems)==25
    manifest={'version':1,'demo':True,'planets':planets,'systems':systems}
    data_path=write_hashed(OUT,'data','json',json.dumps(manifest,ensure_ascii=False,separators=(',',':')).encode())
    used.add(data_path)
    script=(TEMPLATE/'atlas.js').read_text().replace('__ATLAS_DATA_URL__',data_path)
    (OUT/'atlas.js').write_text(script)
    style=(TEMPLATE/'atlas.css').read_bytes();(OUT/'atlas.css').write_bytes(style)
    html=(TEMPLATE/'index.html').read_text().replace('__SCRIPT_VERSION__',hashlib.sha256(script.encode()).hexdigest()[:12]).replace('__STYLE_VERSION__',hashlib.sha256(style).hexdigest()[:12])
    (OUT/'index.html').write_text(html)
    # Remove only obsolete content-addressed outputs owned by this builder.
    for folder in [OUT/'textures',OUT/'units']:
        for path in folder.glob('*'):
            if re.search(r'-[a-f0-9]{12}\.(png|jpg)$',path.name) and str(path.relative_to(OUT)) not in used:path.unlink()
    for path in OUT.glob('data-*.json'):
        if str(path.relative_to(OUT))!=data_path:path.unlink()
    (OUT/'build.json').write_text(json.dumps({'planets':51,'systems':25,'data':data_path,'script_sha256':hashlib.sha256(script.encode()).hexdigest()},indent=2)+'\n')
    print('Built atlas: 51 planets, 25 systems, '+str(len(unit_cache))+' unit textures')


if __name__=='__main__':
    main()
