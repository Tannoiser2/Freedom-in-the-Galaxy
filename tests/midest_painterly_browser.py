"""Verify the actual Midest globe, shared land material and skin comparison."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import threading
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]

class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Quiet, directory=str(ROOT)))
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'])
        page = browser.new_page(viewport={'width': 1500, 'height': 1000})
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
        resources = []
        page.on('response', lambda r: resources.append(r.url))
        page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/?planet=341&skin=painterly&isolated=1')
        page.wait_for_selector('body[data-ready="true"]', timeout=60000)
        page.click('#pause')
        page.click('#focus')
        page.wait_for_timeout(1200)
        snap = page.evaluate('window.__atlas.snapshot()')
        assert snap['selected'] == 341 and snap['skin'] == 'painterly'
        assert snap['objects'][0]['buildings'] == 0 and not snap['objects'][0]['units']
        out=ROOT/'reborn/atlante'
        catalog=json.loads((out/json.loads((out/'build.json').read_text())['data']).read_text())
        midest=next(p for p in catalog['planets'] if p['id']==341)
        assert all(any(u.endswith(env['material']['color']) for u in resources) for env in midest['ambienti'])
        assert all(any(u.endswith(midest['maps'][key]) for u in resources) for key in ['weights0','weights1'])
        assert page.locator('#skin-select').is_enabled()
        assert '42,86%' in page.locator('#environments').inner_text()
        assert '57,14%' in page.locator('#environments').inner_text()
        page.screenshot(path=str(ROOT/'reborn/anteprime/midest_pittorica.png'))
        painted = page.locator('#scene').screenshot()
        page.select_option('#skin-select', 'original')
        page.wait_for_timeout(1200)
        assert page.evaluate('window.__atlas.snapshot().skin') == 'original'
        assert painted != page.locator('#scene').screenshot()
        page.select_option('#skin-select', 'painterly')
        page.wait_for_timeout(1200)
        assert page.evaluate('window.__atlas.snapshot().skin') == 'painterly'
        assert not errors, errors
        print(json.dumps(snap))
        browser.close()
finally:
    server.shutdown()
