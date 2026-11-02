#!/usr/bin/env python3
"""Deterministic spherical terrain, weighted by environment taglia (surface area).

Each environment owns taglia/sum(taglia) of the sphere, not of the UV rectangle.
The same environment mask drives albedo, relief and night-side city lights.
No gameplay data or original artwork is changed. --ids 142 builds Adare only.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, label, distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets_reborn/pianeti'
W, H = 2048, 1024
COLORS = {
    # Warm stone/bronze roofs, distinct from blue water even in daylight.
    'urbano': ((67, 44, 27), (192, 154, 105)),
    'selvaggio': ((12, 37, 26), (83, 112, 58)),
    'sotterraneo': ((42, 31, 31), (163, 125, 105)),
    'liquido': ((5, 22, 58), (24, 125, 148)),
    'aereo': ((39, 69, 110), (171, 198, 207)),
    'fuoco': ((21, 15, 20), (116, 58, 35)),
}
MASK_COLORS = {'urbano': (64, 122, 235), 'selvaggio': (77, 168, 77),
               'sotterraneo': (163, 73, 62), 'liquido': (37, 160, 195),
               'aereo': (137, 208, 230), 'fuoco': (241, 111, 32)}

WILD_BIOMES = [
    ('foreste temperate smeraldo', (11, 37, 24), (87, 120, 60), (88, 79, 62)),
    ('taiga blu e conifere', (10, 32, 39), (58, 100, 103), (109, 128, 137)),
    ('savane dorate e boschi radi', (47, 44, 19), (157, 143, 67), (144, 105, 64)),
    ('foreste ramate e altipiani', (43, 25, 24), (138, 85, 52), (123, 98, 87)),
    ('giungle turchesi e muschio', (10, 40, 35), (61, 128, 89), (88, 104, 77)),
    ('brughiere fredde e abeti', (25, 37, 30), (108, 123, 91), (137, 140, 128)),
]


def planet_profile(pid):
    rng = np.random.default_rng(pid * 7919)
    biome = WILD_BIOMES[0 if pid == 142 else pid % len(WILD_BIOMES)]
    return {'bioma_selvaggio': biome[0], 'palette_selvaggio': biome[1:3],
            'roccia': biome[3], 'frequenza_continenti': float(rng.uniform(1.6, 2.9)),
            'densita_montagne': float(rng.uniform(.4, .85)),
            'frequenza_citta': float(rng.uniform(90, 160)),
            'tinta_citta': rng.uniform(.8, 1.18, 3).tolist(),
            'tinta_acqua': rng.uniform(.72, 1.25, 3).tolist(),
            'colore_luci': [255, int(rng.integers(145, 205)), int(rng.integers(55, 125))]}


def land_components(land, weights):
    """Connected land areas on a sphere, joining both ends of the UV seam."""
    labels, n = label(land)
    parent = np.arange(n + 1)
    def root(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for a, b in zip(labels[:, 0], labels[:, -1]):
        if a and b:
            parent[root(a)] = root(b)
    areas = np.bincount(labels.ravel(), weights=weights.ravel(), minlength=n + 1)
    merged = {}
    for i in range(1, n + 1):
        k = root(i)
        merged[k] = merged.get(k, 0) + areas[i] / weights.sum()
    return sorted(merged.values(), reverse=True)


def geometry():
    lon = np.linspace(-np.pi, np.pi, W, dtype=np.float32)
    lat = np.linspace(np.pi / 2, -np.pi / 2, H, dtype=np.float32)
    x = np.cos(lat[:, None]) * np.cos(lon[None, :])
    y = np.broadcast_to(np.sin(lat[:, None]), (H, W)).copy()
    z = np.cos(lat[:, None]) * np.sin(lon[None, :])
    xyz = np.array([x, y, z], dtype=np.float32)
    # Exact spherical area of each latitude band; duplicated seam has half weight.
    edges = np.r_[np.pi / 2, (lat[:-1] + lat[1:]) / 2, -np.pi / 2]
    band = np.sin(edges[:-1]) - np.sin(edges[1:])
    weights = np.broadcast_to(band[:, None], (H, W)).copy()
    weights[:, (0, -1)] *= .5
    return xyz, weights


def noise(xyz, seed, frequency):
    rng = np.random.default_rng(seed)
    grid = rng.random((64, 64, 64), dtype=np.float32)
    return map_coordinates(grid, (xyz + 3) * frequency + seed % 13,
                           order=1, mode='wrap', prefilter=False)


def save(name, array):
    a = np.uint8(np.clip(array, 0, 255))
    # Periodic UV seam and a single color per pole.
    a[:, -1] = a[:, 0]
    a[0] = a[0, 0]
    a[-1] = a[-1, 0]
    Image.fromarray(a).save(OUT / name)


def build(planet, xyz, weights):
    pid = planet['id']
    envs = planet['ambienti']
    sizes = np.array([float(e['taglia']) for e in envs])
    if np.any(sizes <= 0):
        raise ValueError(f'Invalid environment size: {pid}')
    total = float(sizes.sum())
    profile = planet_profile(pid)
    broad = noise(xyz, pid, profile['frequenza_continenti'])
    mid = noise(xyz, pid + 1, 9.1)
    fine = noise(xyz, pid + 2, 36.7)
    micro = noise(xyz, pid + 3, 181.3)
    field = .64 * broad + .25 * mid + .11 * fine
    water_indices = [i for i,e in enumerate(envs) if e['tipo'] == 'liquido']
    if water_indices:
        # Ocean channels occupy the borders between tectonic regions. Unlike a
        # single thresholded noise island, this preserves several separate
        # continents even when terrestrial environments cover most of the world.
        count = 6 + pid % 3
        rng = np.random.default_rng(pid + 14200)
        rotation, _ = np.linalg.qr(rng.normal(size=(3,3)))
        best = np.full((H,W), -2, dtype=np.float32)
        second = best.copy()
        warped = xyz + .16 * np.stack([mid-.5, fine-.5, broad-.5])
        warped /= np.linalg.norm(warped, axis=0, keepdims=True)
        for i in range(count):
            y = 1 - 2*(i+.5)/count
            azimuth = i*np.pi*(3-np.sqrt(5))
            center = rotation @ np.array([np.sqrt(1-y*y)*np.cos(azimuth),y,np.sqrt(1-y*y)*np.sin(azimuth)])
            dot = np.einsum('i,ihw->hw',center.astype(np.float32),warped)
            second = np.maximum(second,np.minimum(best,dot))
            best = np.maximum(best,dot)
        field = .78*np.clip((best-second)*2.4,0,1) + .15*broad + .07*fine
    env_order = sorted(range(len(envs)), key=lambda i: (i not in water_indices,i))
    order = np.argsort(field.ravel(), kind='stable')
    cumulative = np.cumsum(weights.ravel()[order], dtype=np.float64)
    thresholds = [field.ravel()[order[np.searchsorted(cumulative, q * cumulative[-1])]]
                  for q in np.cumsum(sizes[env_order] / total)[:-1]]
    labels = np.array(env_order,dtype=np.uint8)[np.digitize(field, thresholds)]
    # Pole/seam reconciliation precedes coverage reporting.
    labels[:, -1] = labels[:, 0]
    labels[0] = labels[0, 0]
    labels[-1] = labels[-1, 0]
    albedo = np.zeros((H, W, 3), dtype=np.float32)
    emission = np.zeros_like(albedo)
    relief = np.zeros((H, W), dtype=np.float32)
    diagnostic = np.zeros_like(albedo)
    rugged = np.clip(1 - np.abs(mid - .5) * 2, 0, 1) ** 5
    rock = np.clip((broad - .48) * 7, 0, 1) * rugged
    frequency = profile['frequenza_citta']
    city_x = xyz[0] * frequency + mid * 2.5
    city_z = xyz[2] * frequency * .93 + fine * 2.5
    street_distance = np.minimum(np.minimum(np.mod(city_x,1),1-np.mod(city_x,1)),
                                 np.minimum(np.mod(city_z,1),1-np.mod(city_z,1)))
    streets = np.clip((.095-street_distance)*12,0,1)
    blocks = np.mod(np.sin(np.floor(city_x)*12.9898+np.floor(city_z)*78.233+pid)*43758.5453,1)
    water = np.isin(labels, water_indices)
    pure_water = bool(water_indices) and len(water_indices) == len(envs)
    islands = np.zeros((H,W), dtype=bool)
    if pure_water:
        # Decorative islands belong to the Liquid environment; no new game biome.
        ordered = np.argsort(field.ravel())
        area = np.cumsum(weights.ravel()[ordered], dtype=np.float64)
        threshold = field.ravel()[ordered[np.searchsorted(area, .95 * area[-1])]]
        islands = field > threshold
        islands[:, -1] = islands[:, 0]
        islands[0] = islands[0,0]; islands[-1] = islands[-1,0]
    shore = np.exp(-distance_transform_edt(water & ~islands)/9) if water_indices else np.zeros((H,W))
    measured = []
    for idx, env in enumerate(envs):
        kind = env['tipo']
        mask = labels == idx
        low, high = map(np.array, COLORS[kind])
        if kind == 'selvaggio':
            low, high = map(np.array, profile['palette_selvaggio'])
        v = np.clip(.1 + .35 * broad + .3 * fine + .25 * micro, 0, 1)
        c = low + (high - low) * v[..., None]
        h = .4 * mid + .3 * fine + .3 * micro
        if kind == 'selvaggio':
            c += rock[..., None] * np.array(profile['roccia']) * profile['densita_montagne']
            c *= (.78 + .40 * micro)[..., None]
            h = .35 * broad + .65 * rugged
        elif kind == 'urbano':
            c *= (.65 + .70 * blocks)[..., None] * np.array(profile['tinta_citta'])
            c *= (1-.65*streets)[...,None]
            active = streets * np.clip((fine - .27) * 2.6, 0, 1)
            emission[mask] = (active[..., None] * np.array(profile['colore_luci']))[mask]
            h = .30 + .05 * blocks + .025 * micro
        elif kind == 'fuoco':
            lava = np.clip((.065 - np.abs(mid - .5)) * 22, 0, 1) ** 2
            c += lava[..., None] * np.array([160, 39, 3])
            emission[mask] = (lava[..., None] * np.array([255, 69, 8]))[mask]
            h = .8 * rugged + .2 * fine
        elif kind == 'liquido':
            c *= np.array(profile['tinta_acqua'])
            c += shore[...,None] * np.array([10,47,39])
            if pure_water:
                green = np.array([38,78,49]) + micro[...,None]*np.array([46,44,18])
                c[islands] = green[islands]
            h = .48 + .02 * micro
        elif kind == 'aereo':
            bands = .5 + .5 * np.sin(xyz[1] * 55 + broad * 7 + fine)
            c = low + (high - low) * bands[..., None]
            h = .5 + .02 * fine
        elif kind == 'sotterraneo':
            h = .6 * rugged + .4 * fine
            c *= (.7 + .6 * rugged)[..., None]
        albedo[mask] = c[mask]
        relief[mask] = h[mask]
        diagnostic[mask] = MASK_COLORS[kind]
        measured.append({'tipo': kind, 'taglia': float(sizes[idx]),
                         'frazione_richiesta': float(sizes[idx] / total),
                         'frazione_superficie': float(weights[mask].sum() / weights.sum())})
    prefix = str(pid)
    save(prefix + '.png', albedo)
    save(prefix + '_emission.png', emission)
    save(prefix + '_ambienti.png', diagnostic)
    save(prefix + '_height.png', relief * 255)
    # Tangent-space normals correct longitude derivative for latitude stretching.
    dy, dx = np.gradient(relief)
    coslat = np.sqrt(np.maximum(0, 1 - xyz[1] ** 2))
    dx = dx / np.maximum(coslat, .08)
    normal = np.stack([-dx * 3.5, dy * 3.5, np.ones_like(dx)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    save(prefix + '_normal.png', (normal * .5 + .5) * 255)
    disk = render_disk(albedo, emission)
    Image.fromarray(disk).save(OUT / (prefix + '_disco.png'))
    continents = land_components(~water | islands, weights) if water_indices else []
    return {'id': pid, 'nome': planet['nome'], 'somma_environ': total,
            'raggio_relativo_adare': float(np.sqrt(total / 9)),
            'raggio_scena': float(2.3 * np.sqrt(total / 9)),
            'profilo_artistico': profile,
            'continenti_maggiori': int(sum(a >= .01 for a in continents)),
            'aree_continenti': continents[:20],
            'isole_scenografiche_frazione': float(weights[islands].sum()/weights.sum()),
            'ambienti': measured, 'texture': f'assets_reborn/pianeti/{pid}.png',
            'dimensioni': [W, H], 'seed': pid}


def render_disk(albedo, emission):
    n = 512
    q = np.linspace(-1.14, 1.14, n)
    x, y = np.meshgrid(q, -q)
    inside = x * x + y * y <= 1
    z = np.sqrt(np.maximum(0, 1 - x * x - y * y))
    lon = np.arctan2(z, x)
    lat = np.arcsin(np.clip(y, -1, 1))
    uv = np.array([(np.pi / 2 - lat) / np.pi * (H - 1),
                   (lon + np.pi) / (2 * np.pi) * (W - 1)])
    a = np.stack([map_coordinates(albedo[..., i], uv, order=1, mode='nearest') for i in range(3)], -1)
    e = np.stack([map_coordinates(emission[..., i], uv, order=1, mode='nearest') for i in range(3)], -1)
    light = np.clip(-.65 * x + .35 * y + .67 * z, 0, 1)
    rgb = a * (.09 + .95 * light[..., None]) + e * (1 - light[..., None]) ** 4 * .9
    rim = (1 - z) ** 4 * np.clip(light + .2, 0, 1)
    rgb += rim[..., None] * np.array([24, 80, 130])
    out = np.zeros((n, n, 4), dtype=np.uint8)
    out[..., :3] = np.uint8(np.clip(rgb, 0, 255))
    out[..., 3] = inside * 255
    out[~inside, :3] = 0
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ids', default='')
    args = ap.parse_args()
    selected = {int(v) for v in args.ids.split(',') if v}
    planets = json.loads((ROOT / 'data/galassia.json').read_text())['pianeti']
    xyz, weights = geometry()
    OUT.mkdir(parents=True, exist_ok=True)
    report_path = ROOT / 'reborn/pianeti_superfici.json'
    previous = json.loads(report_path.read_text())['pianeti'] if report_path.exists() else []
    report = {p['id']: p for p in previous}
    for p in planets:
        if selected and p['id'] not in selected:
            continue
        report[p['id']] = build(p, xyz, weights)
        print(f"{p['id']} {p['nome']}: generated", flush=True)
    smallest = min(planets, key=lambda p: sum(e['taglia'] for e in p['ambienti']))
    largest = max(planets, key=lambda p: sum(e['taglia'] for e in p['ambienti']))
    scale = {'criterio': 'surface_area_proportional_to_sum_environ',
             'minimo': {'id': smallest['id'], 'nome': smallest['nome'], 'somma': sum(e['taglia'] for e in smallest['ambienti'])},
             'massimo': {'id': largest['id'], 'nome': largest['nome'], 'somma': sum(e['taglia'] for e in largest['ambienti'])},
             'raggio_adare': 2.3, 'formula': '2.3 * sqrt(sum(taglia)/9)'}
    (ROOT / 'reborn/scala_planetaria.json').write_text(json.dumps(scale, ensure_ascii=False, indent=2)+'\n')
    report_path.write_text(json.dumps({'regola_dimensione': 'surface_area_proportional_to_sum_environ',
        'raggio': 'sqrt(sum(taglia) / 9), relative to Adare',
        'metodo': 'spherical noise; area-weighted quantiles; cos(latitude) band integration',
        'pianeti': [report[k] for k in sorted(report)]}, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
