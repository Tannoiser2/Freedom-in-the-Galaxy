"""Inspect reference planets and representative material variants and the round, unbacked environment stages."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import io
import json
import threading
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
        page=browser.new_page(viewport={'width':1500,'height':1000})
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
        out=ROOT/'reborn/atlante'
        catalog=json.loads((out/json.loads((out/'build.json').read_text())['data']).read_text())
        examples=[(432,'solvia'),(341,'midest'),(211,'cieson'),(112,'magro')]
        for kind,index in [('fuoco',1),('fuoco',3),('sotterraneo',3),('aereo',2),('liquido',2)]:
            planet=next(p for p in catalog['planets'] if any(e['tipo']==kind and e['material']['variant']==index for e in p['ambienti']))
            if not any(pid==planet['id'] for pid,_ in examples):examples.append((planet['id'],planet['nome'].lower()))
        for pid,name in examples:
            page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/?planet={pid}&skin=painterly')
            page.wait_for_selector('body[data-ready="true"]',timeout=60000)
            page.click('#pause');page.wait_for_timeout(300)
            snap=page.evaluate('window.__atlas.snapshot()')
            assert snap['selected']==pid and snap['skin']=='painterly'
            assert page.locator('#skin-select').is_enabled()
            assert all(s['floor'] and not s['backdrop'] for s in snap['objects'][0]['platforms'])
            assert not errors,errors
            page.screenshot(path=str(ROOT/f'reborn/anteprime/{name}_piattaforme.png'))
            for control in ['show-units','show-defense','show-labels']:page.uncheck('#'+control)
            page.click('#focus');page.wait_for_timeout(600)
            page.screenshot(path=str(ROOT/f'reborn/anteprime/{name}_pittorica.png'))
            if pid==432:
                page.select_option('#material-mode','2');page.wait_for_timeout(300)
                im=Image.open(io.BytesIO(page.locator('#scene').screenshot())).convert('RGB')
                lights=sum(1 for r,g,b in im.get_flattened_data() if r>85 and g>45 and b<r*.8)
                assert lights>50,('Urban network invisible on night side',lights)
                page.screenshot(path=str(ROOT/'reborn/anteprime/solvia_notturna.png'))
            print(f'{pid} {name}: globo, basi senza fondale e materiali OK',flush=True)
        page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/materiali.html')
        assert page.locator('.card').count()==18
        for width,height in [(1500,1000),(390,844)]:
            page.set_viewport_size({'width':width,'height':height})
            assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
        assert not errors,errors
        browser.close()
finally:server.shutdown()
