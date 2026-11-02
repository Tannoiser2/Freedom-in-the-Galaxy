#!/usr/bin/env python3
"""Package the actual planet textures in an offline interactive WebGL viewer."""
import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def main():
    import json
    source = ROOT / 'reborn/anteprime/planet_viewer.html'
    names = {'albedo': '142.png', 'emission': '142_emission.png',
             'terrain': '142_ambienti.png', 'heightmap': '142_height.png'}
    assets = {key: 'data:image/png;base64,' + base64.b64encode(
        (ROOT / 'assets_reborn/pianeti' / file).read_bytes()).decode()
              for key, file in names.items()}
    html = source.read_text().replace('/*ASSET_DATA*/null', json.dumps(assets))
    out = ROOT / 'reborn/anteprime/adare_3d.html'
    out.write_text(html)
    print(out)

if __name__ == '__main__':
    main()
