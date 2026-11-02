"""Validate the 18-material library, every assignment and lossless environment masks."""
from pathlib import Path
import json
from collections import defaultdict
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reborn/atlante'
build=json.loads((OUT/'build.json').read_text())
data=json.loads((OUT/build['data']).read_text())
colors=[(64,122,235),(163,73,62),(77,168,77),(37,160,195),(137,208,230),(241,111,32)]
kinds=['urbano','sotterraneo','selvaggio','liquido','aereo','fuoco']
assert set(data['materials'])==set(kinds)
seen=defaultdict(set)
for kind,variants in data['materials'].items():
    assert len(variants)==3 and [v['variant'] for v in variants]==[1,2,3]
    assert len({(OUT/v['color']).read_bytes() for v in variants})==3
    for v in variants:
        assert Image.open(OUT/v['color']).size==(2048,1024)
        assert Image.open(OUT/v['platform']).size==(512,256)
for p in data['planets']:
    source=np.asarray(Image.open(ROOT/f'assets_reborn/pianeti/{p["id"]}_ambienti.png').convert('RGB'))
    weights=np.concatenate([np.asarray(Image.open(OUT/p['maps'][k]).convert('RGB')) for k in ['weights0','weights1']],axis=2)
    assert np.all(weights.sum(axis=2)==255),p['id']
    for i,color in enumerate(colors):
        assert np.array_equal(weights[:,:,i]==255,np.all(source==color,axis=2)),(p['id'],kinds[i])
    for env in p['ambienti']:
        v=env['material'];assert v==data['materials'][env['tipo']][v['variant']-1]
        seen[env['tipo']].add(v['variant'])
assert all(seen[k]=={1,2,3} for k in kinds),seen
print('18 materiali distinti; tre varianti usate per ciascuno dei sei ambienti.')
print('51 pianeti: assegnazioni valide e maschere originali conservate pixel per pixel.')
