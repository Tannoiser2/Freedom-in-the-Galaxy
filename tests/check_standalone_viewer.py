#!/usr/bin/env python3
"""Check isolated HTML downloads offline with external images forbidden.

Requires Playwright and Chromium. The managed browser forbids file: navigation,
so isolated file contents run in an offline about:blank document, without a
filesystem base URL or companion assets.
"""
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['adare_3d.html', 'planet_viewer.html', 'adare_3d_autonomo_v2.html']


def main():
    paths = [ROOT / 'reborn/anteprime' / name for name in NAMES]
    assert len({hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}) == 1
    csp = ('<meta http-equiv="Content-Security-Policy" content="'
           "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
           "img-src 'none'; connect-src 'none'" + '">')
    with tempfile.TemporaryDirectory() as directory, sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader',
                  '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'])
        try:
            for path in paths:
                isolated = Path(directory) / path.name
                shutil.copyfile(path, isolated)
                html = isolated.read_text()
                assets = json.loads(re.search(r'const ASSETS=(.*?);\n', html).group(1))
                assert set(assets) == {'albedo', 'emission', 'terrain', 'heightmap'}
                for asset in assets.values():
                    assert 'src' not in asset
                    raw = base64.b64decode(asset['pixels'], validate=True)
                    channels = 1 if asset['format'] == 'L' else 3
                    assert len(raw) == asset['width'] * asset['height'] * channels
                assert 'ASSET_DATA_START' not in html and 'new Image(' not in html
                context = browser.new_context(offline=True, viewport={'width':960,'height':720})
                page = context.new_page()
                errors, requests = [], []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('request', lambda request: requests.append(request.url))
                page.set_content(html.replace('<html lang="it">', '<html lang="it">'+csp), wait_until='load')
                page.wait_for_selector('body[data-ready="true"]', timeout=30000)
                page.locator('#spin').click()
                page.wait_for_timeout(200)
                surface = page.locator('canvas').screenshot()
                page.locator('[data-mode="1"]').click()
                page.wait_for_timeout(200)
                assert surface != page.locator('canvas').screenshot(), 'Terrain mode must change the rendered planet'
                assert page.locator('#error').is_hidden()
                assert not requests, requests
                assert not errors, errors
                context.close()
                print(path.name + ': isolated copy OK, offline, img-src none, zero requests, rendered modes differ')
        finally:
            browser.close()


if __name__ == '__main__':
    main()
