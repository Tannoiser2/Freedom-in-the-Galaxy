#!/usr/bin/env python3
"""Package the actual planet textures in an offline interactive WebGL viewer."""
import base64
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
def main():
    source = ROOT / 'tools/templates/planet_viewer.html.template'
    names = {'albedo': '142.png', 'emission': '142_emission.png',
             'terrain': '142_ambienti.png', 'heightmap': '142_height.png'}
    # Upload pixel buffers directly: no data: image URLs, image decoder, fetch,
    # object URLs or server are needed by the self-contained delivery file.
    # 1024x512 is sufficient for this portable viewer; production maps stay 2K.
    assets = {}
    for key, file in names.items():
        with Image.open(ROOT / 'assets_reborn/pianeti' / file) as image:
            mode = 'L' if key == 'heightmap' else 'RGB'
            image = image.convert(mode).resize((1024, 512), Image.Resampling.LANCZOS)
            assets[key] = {'width': image.width, 'height': image.height,
                'format': mode, 'pixels': base64.b64encode(image.tobytes()).decode('ascii')}
    html, count = re.subn(r'/\*ASSET_DATA_START\*/.*?/\*ASSET_DATA_END\*/',
        lambda _: json.dumps(assets, separators=(',', ':')),
        source.read_text(), flags=re.S)
    if count != 1:
        raise ValueError('Expected exactly one asset payload marker in the viewer')
    html = html.replace('ATLANTE PLANETARIO · PROTOTIPO 01',
                        'ATLANTE PLANETARIO · VERSIONE 02 · FILE AUTONOMO')
    # Preserve both previous links without leaving a misleading source HTML.
    # A versioned delivery filename also avoids reopening an older download.
    for name in ['adare_3d.html', 'planet_viewer.html', 'adare_3d_autonomo_v2.html']:
        out = ROOT / 'reborn/anteprime' / name
        out.write_text(html)
        print(out)

if __name__ == '__main__':
    main()
