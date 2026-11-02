"""Check actual card values and layout, then export the two review examples."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
        page=browser.new_page(viewport={'width':1360,'height':1160},device_scale_factor=2)
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(f'http://127.0.0.1:{server.server_port}/reborn/carte/')
        page.wait_for_function('window.__cardsReady===true')
        page.wait_for_function('Array.from(document.images).every(im=>im.complete&&im.naturalWidth>0)')
        records=json.loads((ROOT/'reborn/carte/data.json').read_text())
        for record,slug in zip(records,['redjac','zina-adora']):
            card=page.locator('#'+slug)
            assert card.locator('.card-title').bounding_box()['y']+card.locator('.card-title').bounding_box()['height']<card.locator('.hero').bounding_box()['y']-8
            figure=card.locator('.figure').bounding_box();ability=card.locator('.ability').bounding_box()
            assert figure['y']<card.locator('.hero').bounding_box()['y']
            assert abs(figure['y']+figure['height']-ability['y'])<4
            assert card.locator('.card-number').evaluate('el=>{const t=el.querySelector("text").getBoundingClientRect(),c=el.getBoundingClientRect();return Math.abs(t.x+t.width/2-c.x-c.width/2)<1 && Math.abs(t.y+t.height/2-c.y-c.height/2)<1}')
            assert card.locator('.stat').count()==6
            assert card.locator('.stat-icon svg').count()==6
            for stat in ['combattimento','resistenza','intelligenza','comando','diplomazia','navigazione']:
                assert card.locator('[data-stat="'+stat+'"] .stat-value').inner_text().split()[0]==str(record[stat])
            assert card.locator('.ability-text').inner_text()==record['speciale_it']
            assert card.locator('.ability-text').evaluate('(el)=>el.scrollHeight<=el.parentElement.clientHeight-50')
            assert card.locator('.figure').evaluate('(el)=>getComputedStyle(el).maskImage.includes("linear-gradient")')
            card.screenshot(path=str(ROOT/f'reborn/carte/{slug}.png'))
        page.locator('.pair').screenshot(path=str(ROOT/'reborn/carte/esempi-carte.png'))
        for width in [1360,1290,900,650,390]:
            page.set_viewport_size({'width':width,'height':844});page.wait_for_timeout(150)
            assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth'),width
        assert not errors,errors
        browser.close()
        print('Due carte: dati esatti, sei icone, abilità complete, sfumature e layout mobile OK.')
finally:server.shutdown()
