#!/usr/bin/env python3
"""Package the actual planet textures in an offline interactive WebGL viewer."""
import base64
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
def main():
    source = ROOT / 'reborn/anteprime/planet_viewer.html'
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
    out = ROOT / 'reborn/anteprime/adare_3d.html'
    out.write_text(html)
    print(out)

if __name__ == '__main__':
    main()
