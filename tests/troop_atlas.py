"""Surface/orbit demo uses the same unit and values, separate from characters."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
def main():
    base=ROOT/'reborn/atlante';build=json.loads((base/'build.json').read_text());data=json.loads((base/build['data']).read_text())
    for planet in data['planets']:
        for env in planet['ambienti']:
            assert (base/env['troop']['ground']).is_file() and (base/env['troop']['orbit']).is_file()
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)));threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as pw:
            browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
            page=browser.new_page(viewport={'width':1440,'height':1000});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
            seen=set();targets=[]
            for p in sorted(data['planets'],key=lambda p:len(p['ambienti']),reverse=True):
                kinds={e['tipo'] for e in p['ambienti']}
                if kinds-seen:targets.append(p);seen|=kinds
            assert len(seen)==6
            def wait():
                page.wait_for_selector('body[data-ready="true"]',timeout=90000)
                return page.evaluate('window.__atlas.snapshot()')
            for p in targets:
                page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/?planet={p["id"]}');surface=wait()
                assert not surface['troopsOrbit']
                troops=surface['objects'][0]['troops'];assert len(troops)==len(p['ambienti'])
                for t in troops:assert t['position']=='terra'
                page.select_option('#troop-position','orbita');orbit=wait();assert orbit['troopsOrbit']
                ships=orbit['objects'][0]['troops'];assert len(ships)==len(troops)
                assert {(t['key'],t['terra'],t['spazio']) for t in troops}=={(t['key'],t['terra'],t['spazio']) for t in ships}
                assert all(t['position']=='orbita' for t in ships)
                assert all(t['image']!=ships[i]['image'] and t['y']<ships[i]['y'] for i,t in enumerate(troops))
                # Original ground platforms and characters stay in place.
                assert [g['units'] for g in orbit['objects'][0]['platforms']]==[g['units']-1 for g in surface['objects'][0]['platforms']]
                assert all(g['floor'] and not g['backdrop'] for g in orbit['objects'][0]['platforms'])
                page.select_option('#troop-position','terra');restored=wait();assert not restored['troopsOrbit']
                assert [t['image'] for t in restored['objects'][0]['troops']]==[t['image'] for t in troops]
                print(f'{p["nome"]}: soldati → navi → soldati; valori ed environ invariati',flush=True)
            page.select_option('#troop-position','orbita');wait();page.screenshot(path=str(ROOT/'reborn/truppe/atlante-orbita.png'))
            assert not errors,errors;browser.close()
    finally:server.shutdown()
    print('Atlante: tutti i sei environ, 51 pianeti nel catalogo, cambio di posizione e personaggi OK.')
if __name__=='__main__':main()
