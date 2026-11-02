#!/usr/bin/env python3
"""Validate exported surface masks against original environment data."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PALETTE = {'urbano': (64,122,235), 'selvaggio': (77,168,77),
    'sotterraneo': (163,73,62), 'liquido': (37,160,195),
    'aereo': (137,208,230), 'fuoco': (241,111,32)}


def main():
    planets = json.loads((ROOT / 'data/galassia.json').read_text())['pianeti']
    lat = np.linspace(np.pi/2, -np.pi/2, 1024, dtype=np.float32)
    edges = np.r_[np.pi/2, (lat[:-1]+lat[1:])/2, -np.pi/2]
    weights = np.broadcast_to((np.sin(edges[:-1])-np.sin(edges[1:]))[:,None],
                               (1024,2048)).copy()
    weights[:,(0,-1)] *= .5
    worst = 0
    for planet in planets:
        pid = planet['id']
        base = ROOT / 'assets_reborn/pianeti'
        with Image.open(base / f'{pid}_ambienti.png') as im:
            mask = np.array(im)
        expected = {}
        for env in planet['ambienti']:
            expected[env['tipo']] = expected.get(env['tipo'],0)+env['taglia']
        total = sum(expected.values())
        accounted = np.zeros((1024,2048), dtype=bool)
        for kind,size in expected.items():
            match = np.all(mask == PALETTE[kind],axis=-1)
            actual = float(weights[match].sum()/weights.sum())
            error = abs(actual-size/total)
            worst = max(worst,error)
            assert error < .0001, (pid,kind,'surface fraction',actual,size/total)
            accounted |= match
        assert accounted.all(), (pid,'unexpected terrain')
        for suffix in ['', '_ambienti','_emission','_height','_normal']:
            with Image.open(base / f'{pid}{suffix}.png') as im:
                assert im.size == (2048,1024), (pid,suffix,'size')
                a = np.array(im)
                assert np.array_equal(a[:,0],a[:,-1]), (pid,suffix,'UV seam')
                assert np.all(a[0]==a[0,0]) and np.all(a[-1]==a[-1,0]), (pid,suffix,'poles')
        with Image.open(base / f'{pid}_emission.png') as im:
            e = np.array(im)
        luminous = np.any(e>0,axis=-1)
        allowed = np.all(mask==PALETTE['urbano'],axis=-1) | np.all(mask==PALETTE['fuoco'],axis=-1)
        assert not np.any(luminous & ~allowed), (pid,'emission outside city/lava')
        with Image.open(base / f'{pid}_disco.png') as im:
            assert im.size==(512,512) and im.mode=='RGBA', (pid,'disk')
    print(f'{len(planets)} planets: coverage, sizes, seams, poles and emission OK')
    print(f'Maximum surface error: {worst*100:.8f} percentage points')


if __name__=='__main__':
    main()
