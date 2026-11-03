#!/usr/bin/env python3
"""Build the local, dependency-free-to-host Three.js planetary atlas.

Only the builder needs Pillow. Generated preview files and vendored Three.js
are committed so publication only copies files, without npm or a CDN.
"""
import hashlib
import html
import json
from pathlib import Path
import re

from PIL import Image, ImageFile


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reborn/atlante'
TEMPLATE = ROOT / 'tools/templates/atlas'
ENVIRONMENTS = ('urbano','sotterraneo','selvaggio','liquido','aereo','fuoco')
MASK_COLORS = ((64,122,235),(163,73,62),(77,168,77),(37,160,195),(137,208,230),(241,111,32))
VARIANT_NAMES = {
    'urbano': ['Nuclei radiali','Conglomerati ramificati','Città a corridoio'],
    'sotterraneo': ['Crepacci e altopiani','Caverne e doline','Faglie con lava'],
    'selvaggio': ['Catene e foreste','Massicci e altopiani','Valli e dorsali'],
    'liquido': ['Isolotti radi','Isole maggiori','Atolli e arcipelaghi'],
    'aereo': ['Tempeste rosse','Vortici scuri','Fronti turbolenti'],
    'fuoco': ['Fiumi di lava','Caldere vulcaniche','Rift incandescenti'],
}


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
            # Dense painted JPEGs need a larger encoder buffer; preserve PNG encoding.
            block = ImageFile.MAXBLOCK
            try:
                ImageFile.MAXBLOCK = 1024 * 1024
                im.save(buffer, 'JPEG', quality=93, subsampling=0, optimize=True)
            finally:
                ImageFile.MAXBLOCK = block
        else:
            im.save(buffer, 'PNG', optimize=True)
    return write_hashed(folder,stem,'jpg' if jpeg else 'png',buffer.getvalue())


def character_key(name):
    name = name.lower().replace('doctor ', 'doctor_').replace('professor ', 'prof_')
    name = name.replace('senator ', '').replace('emperor ', '')
    return 'pg_'+name.replace('-','_').replace(' ','_')


def material_library(used):
    library = {}
    for kind in ENVIRONMENTS:
        variants = []
        for index,name in enumerate(VARIANT_NAMES[kind],1):
            source = ROOT/f'reborn/materiali_pittorici/{kind}-{index}.jpg'
            color = write_hashed(OUT/'textures',f'material-{kind}-{index}','jpg',source.read_bytes())
            platform = image(source,OUT/'textures',f'base-{kind}-{index}',(512,256),jpeg=True)
            used.update((color,platform))
            variants.append({'variant':index,'name':name,'color':color,'platform':platform})
        library[kind] = variants
    return library


def environment_weights(pid, used):
    """Losslessly pack the six original categories in two linearly filtered RGB maps."""
    import io
    with Image.open(ROOT/f'assets_reborn/pianeti/{pid}_ambienti.png') as source:
        source = source.convert('RGB')
        assert set(color for _,color in source.getcolors(7)) <= set(MASK_COLORS)
        red = source.getchannel('R')
        channels = [red.point([255 if value==rgb[0] else 0 for value in range(256)]) for rgb in MASK_COLORS]
        paths = {}
        for offset in (0,3):
            buffer = io.BytesIO()
            Image.merge('RGB',channels[offset:offset+3]).save(buffer,'PNG',optimize=True)
            key = 'weights'+str(offset//3)
            paths[key] = write_hashed(OUT/'textures',f'{pid}-{key}','png',buffer.getvalue())
            used.add(paths[key])
        return paths


def material_gallery(materials, planets):
    labels = {'urbano':'Urbano','sotterraneo':'Sotterraneo','selvaggio':'Selvaggio',
        'liquido':'Liquido','aereo':'Aereo','fuoco':'Fuoco'}
    sections = []
    for kind,variants in materials.items():
        cards = []
        for v in variants:
            example = next(p for p in planets if any(e['tipo']==kind and e['material']['variant']==v['variant'] for e in p['ambienti']))
            name = html.escape(v['name'])
            cards.append(f'<a class="card" href="./?planet={example["id"]}&amp;skin=painterly"><img src="{v["platform"]}" alt="{name}" loading="lazy"><strong>{name}</strong><span>Vedi su {html.escape(example["nome"])}</span></a>')
        sections.append(f'<section><h2>{labels[kind]}</h2><div class="grid">'+''.join(cards)+'</div></section>')
    (OUT/'materiali.html').write_text('''<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="icon" href="data:,"><title>Varianti degli ambienti · Reborn</title>
<style>body{margin:0;background:#081018;color:#ede9d8;font:16px system-ui}main{max-width:1150px;margin:auto;padding:32px 24px}a{color:#92cfb3}h1{font-size:32px;font-weight:500}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}.card{background:#111f29;border:1px solid #32453f;border-radius:12px;overflow:hidden;text-decoration:none;display:flex;flex-direction:column}.card:hover{border-color:#92cfb3}.card img{width:100%;aspect-ratio:2;object-fit:cover}.card strong,.card span{padding:10px 14px 0}.card span{padding-bottom:16px;font-size:14px;color:#a6b7ad}section{margin:32px 0}h2{font-weight:500}@media(max-width:650px){.grid{grid-template-columns:1fr}}</style>
<main><a href="./">← Atlante della galassia</a><h1>Varianti degli ambienti</h1><p>Tre interpretazioni per ciascun ambiente, distribuite sui 51 pianeti. Seleziona una variante per vedere un pianeta che la utilizza.</p>'''+''.join(sections)+'</main></html>')


def main():
    from troop_catalog import catalog
    troops={c['key']:c for c in catalog()}
    galaxy = json.loads((ROOT/'data/galassia.json').read_text())
    cards = json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    profiles = {p['id']:p for p in json.loads((ROOT/'reborn/pianeti_superfici.json').read_text())['pianeti']}
    OUT.mkdir(parents=True,exist_ok=True)
    used = set()
    materials = material_library(used)
    assignments = {}
    approved = {432,341,112,211}
    for kind in ENVIRONMENTS:
        offset = 1
        for planet in sorted(galaxy['pianeti'],key=lambda p:p['id']):
            if not any(e['tipo']==kind for e in planet['ambienti']):continue
            if planet['id'] in approved:
                variant = 0
            else:
                variant = offset%3
                offset += 1
            assignments[planet['id'],kind] = materials[kind][variant]
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
        maps.update(environment_weights(pid,used))
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
            troop=troops[key]
            pictures={}
            for position,field in [('ground','ground'),('orbit','orbit')]:
                path=image(ROOT/'assets_reborn/truppe'/troop[field],OUT/'units',troop[field].replace('.webp',''),(400,560),mode='RGBA')
                used.add(path);pictures[position]=path
            envs.append({'tipo':e['tipo'],'taglia':e['taglia'],'token':pictures['ground'],
                'troop':dict(key=key,nome=troop['nome'],fazione=troop['fazione'],terra=troop['terra'],spazio=troop['spazio'],**pictures),
                'material':assignments[pid,e['tipo']]})
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
    manifest={'version':2,'demo':True,'materials':materials,'planets':planets,'systems':systems}
    material_gallery(materials,planets)
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
    (OUT/'build.json').write_text(json.dumps({'planets':51,'systems':25,'data':data_path,'script_sha256':hashlib.sha256(script.encode()).hexdigest(),'material_variants':sum(map(len,materials.values())),'default_skin':'painterly'},indent=2)+'\n')
    print('Built atlas: 51 planets, 25 systems, '+str(len(unit_cache))+' unit textures')


if __name__=='__main__':
    main()
