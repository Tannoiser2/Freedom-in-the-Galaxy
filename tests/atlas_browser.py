#!/usr/bin/env python3
"""Exercise all 51 planets and all 25 systems through the actual atlas UI."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import threading

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def main():
    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    build=json.loads((ROOT/'reborn/atlante/build.json').read_text())
    catalog=json.loads((ROOT/'reborn/atlante'/build['data']).read_text())
    errors=[]
    def wait(page):
        page.wait_for_selector('body[data-ready="true"]',timeout=60000)
        page.evaluate('() => new Promise(resolve => requestAnimationFrame(resolve))')
        assert page.locator('#error').is_hidden()
        assert not errors, errors
        return page.evaluate('window.__atlas.snapshot()')
    def current(page):
        return page.evaluate('window.__atlas.snapshot()')
    try:
        with sync_playwright() as pw:
            browser=pw.chromium.launch(executable_path=shutil.which('chromium'),headless=True,
                args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
            page=browser.new_page(viewport={'width':1440,'height':1000})
            page.on('pageerror',lambda e:errors.append(str(e)))
            page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
            page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/')
            snap=wait(page)
            assert page.locator('#planet-select option').count()==51
            assert page.locator('#system-select option').count()==25
            assert snap['objects'][0]['buildings']>0
            assert 'Nessun environ Liquido' in page.locator('#terrain-note').inner_text()
            assert '44,44%' in page.locator('#environments').inner_text()
            for level in [0,1,2]:
                page.select_option('#pdb-level',str(level))
                assert current(page)['objects'][0]['bases']==level+1
            page.locator('#pdb-toggle').click()
            before=current(page)['objects'][0]
            page.wait_for_timeout(650)
            after=current(page)['objects'][0]
            assert after['defense']==before['defense'] and after['spin']!=before['spin']
            assert after['defenseColor']=='ff6651' and not after['up']
            page.locator('#pdb-toggle').click()
            before=current(page)['objects'][0]['defense']
            page.wait_for_timeout(500)
            assert current(page)['objects'][0]['defense']!=before
            assert current(page)['objects'][0]['defenseColor']=='55e887'
            page.locator('#pause').click()
            page.screenshot(path=str(ROOT/'reborn/anteprime/atlante_adare.png'),full_page=True)
            before=current(page)['cameraDistance']
            page.locator('#focus').click()
            assert current(page)['cameraDistance']<before
            page.screenshot(path=str(ROOT/'reborn/anteprime/atlante_adare_dettaglio.png'),full_page=True)
            page.locator('#reset').click()
            for p in catalog['planets']:
                page.select_option('#planet-select',str(p['id']))
                snap=wait(page)
                assert snap['selected']==p['id'] and snap['mode']=='planet'
                assert len(snap['objects'])==1 and snap['objects'][0]['id']==p['id']
                assert snap['objects'][0]['unitCount']==len(p['ambienti'])+len(p['units'])
                assert snap['objects'][0]['buildings']>0 if any(e['tipo']=='urbano' for e in p['ambienti']) else snap['objects'][0]['buildings']==0
                assert snap['cacheSize']<=8
            print('51/51 planet previews: loaded, rendered, units present, bounded texture cache',flush=True)
            for s in catalog['systems']:
                page.select_option('#system-select',str(s['id']))
                snap=wait(page)
                assert snap['system']==s['id'] and snap['mode']=='system'
                assert {p['id'] for p in snap['objects']}==set(s['planets'])
                assert all(p['unitCount']>=3 and p['bases']>=1 for p in snap['objects'])
                assert snap['cacheSize']<=8
            print('25/25 system previews: correct planets, PDB and unit platforms',flush=True)
            page.select_option('#system-select','14');wait(page)
            page.locator('#pause').click()
            before=current(page)
            page.wait_for_timeout(700)
            after=current(page)
            assert any(a['position']!=b['position'] for a,b in zip(before['objects'],after['objects']))
            assert all(a['spin']!=b['spin'] for a,b in zip(before['objects'],after['objects']))
            page.locator('#pause').click()
            page.screenshot(path=str(ROOT/'reborn/anteprime/atlante_atriard.png'),full_page=True)
            page.locator('#focus').click()
            assert current(page)['cameraDistance']<before['cameraDistance']
            page.select_option('#planet-select','113');wait(page)
            page.screenshot(path=str(ROOT/'reborn/anteprime/atlante_fliad.png'),full_page=True)
            page.select_option('#planet-select','142');wait(page)
            page.select_option('#material-mode','1')
            page.wait_for_timeout(100)
            page.select_option('#material-mode','2')
            page.wait_for_timeout(100)
            page.select_option('#material-mode','0')
            page.set_viewport_size({'width':390,'height':844})
            page.wait_for_timeout(400)
            assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
            page.screenshot(path=str(ROOT/'reborn/anteprime/atlante_mobile.png'),full_page=True)
            assert not errors,errors
            print('Motion, self rotation, PDB strengths/UP/DOWN, focus, material modes and mobile OK',flush=True)
            browser.close()
    finally:
        server.shutdown();server.server_close()


if __name__=='__main__':
    main()
