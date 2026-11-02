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
from scipy.ndimage import map_coordinates

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets_reborn/pianeti'
W, H = 2048, 1024
COLORS = {
    'urbano': ((58, 70, 76), (155, 163, 158)),
    'selvaggio': ((12, 37, 26), (83, 112, 58)),
    'sotterraneo': ((42, 31, 31), (163, 125, 105)),
    'liquido': ((5, 22, 58), (24, 125, 148)),
    'aereo': ((39, 69, 110), (171, 198, 207)),
    'fuoco': ((21, 15, 20), (116, 58, 35)),
}
MASK_COLORS = {'urbano': (64, 122, 235), 'selvaggio': (77, 168, 77),
               'sotterraneo': (163, 73, 62), 'liquido': (37, 160, 195),
               'aereo': (137, 208, 230), 'fuoco': (241, 111, 32)}


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
    broad = noise(xyz, pid, 2.8)
    mid = noise(xyz, pid + 1, 9.1)
    fine = noise(xyz, pid + 2, 36.7)
    micro = noise(xyz, pid + 3, 181.3)
    field = .64 * broad + .25 * mid + .11 * fine
    order = np.argsort(field.ravel(), kind='stable')
    cumulative = np.cumsum(weights.ravel()[order], dtype=np.float64)
    thresholds = [field.ravel()[order[np.searchsorted(cumulative, q * cumulative[-1])]]
                  for q in np.cumsum(sizes / total)[:-1]]
    labels = np.digitize(field, thresholds).astype(np.uint8)
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
    grid_x = np.abs(np.sin(xyz[0] * 1450 + fine * 5))
    grid_z = np.abs(np.sin(xyz[2] * 1450 + fine * 5))
    streets = np.maximum(np.clip((grid_x - .966) * 29, 0, 1),
                         np.clip((grid_z - .966) * 29, 0, 1))
    blocks = .5 + .5 * np.sin(xyz[0] * 450) * np.cos(xyz[2] * 470)
    measured = []
    for idx, env in enumerate(envs):
        kind = env['tipo']
        mask = labels == idx
        low, high = map(np.array, COLORS[kind])
        v = np.clip(.1 + .35 * broad + .3 * fine + .25 * micro, 0, 1)
        c = low + (high - low) * v[..., None]
        h = .4 * mid + .3 * fine + .3 * micro
        if kind == 'selvaggio':
            c += rock[..., None] * np.array([65, 58, 43])
            c *= (.78 + .40 * micro)[..., None]
            h = .35 * broad + .65 * rugged
        elif kind == 'urbano':
            c *= (.6 + .65 * blocks)[..., None]
            c += streets[..., None] * np.array([32, 27, 18])
            active = streets * np.clip((fine - .27) * 2.6, 0, 1)
            emission[mask] = (active[..., None] * np.array([255, 173, 61]))[mask]
            h = .25 + .40 * blocks + .2 * micro
        elif kind == 'fuoco':
            lava = np.clip((.065 - np.abs(mid - .5)) * 22, 0, 1) ** 2
            c += lava[..., None] * np.array([160, 39, 3])
            emission[mask] = (lava[..., None] * np.array([255, 69, 8]))[mask]
            h = .8 * rugged + .2 * fine
        elif kind == 'liquido':
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
    return {'id': pid, 'nome': planet['nome'], 'somma_environ': total,
            'raggio_relativo_adare': float(np.sqrt(total / 9)),
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
    report_path.write_text(json.dumps({'regola_dimensione': 'surface_area_proportional_to_sum_environ',
        'raggio': 'sqrt(sum(taglia) / 9), relative to Adare',
        'metodo': 'spherical noise; area-weighted quantiles; cos(latitude) band integration',
        'pianeti': [report[k] for k in sorted(report)]}, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
